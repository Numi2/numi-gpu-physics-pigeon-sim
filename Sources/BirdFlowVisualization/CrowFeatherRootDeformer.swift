import BirdFlowMetal
import Foundation
import Metal
import simd

struct CrowFeatherRootFrame {
  let slot: Int
  let readbackReady: Bool
  let outputBuffer: MTLBuffer
  let currentPhase: Float
  let previousPhase: Float
}

protocol CrowFeatherRootDeforming: AnyObject {
  var featherCount: Int { get }

  func encode(
    currentPhase: Float,
    previousPhase: Float,
    commandBuffer: MTLCommandBuffer,
    auditReadback: Bool
  ) throws -> CrowFeatherRootFrame
}

/// Retained Metal state for the persistent feather inventory.
///
/// Each feather root is attached to an exact vertex on the fixed-topology
/// surface. Its direction is transported through a coherent part frame defined
/// by the shoulder-to-tip axis (or tail base-to-tip axis), rather than by the
/// orientation of one tiny surface triangle. The latter is too noisy under a
/// large wing stroke and can make adjacent vanes rotate independently.
final class CrowFeatherRootDeformer {
  private static let bufferedFrameCount = 3

  private let backend: VisualizationBackend
  private let dataset: MeasuredBirdSurfaceSequence
  private let asset: BirdRealityAsset
  private let pipeline: MTLComputePipelineState
  private let sourcePointsBuffer: MTLBuffer
  private let bindingBuffer: MTLBuffer
  private let bindings: [CrowFeatherRootBindingGPU]
  private let outputBuffers: [MTLBuffer]
  private let readbackBuffers: [MTLBuffer]
  private var nextSlot = 0

  let featherCount: Int

  init(
    backend: VisualizationBackend,
    dataset: MeasuredBirdSurfaceSequence,
    asset: BirdRealityAsset
  ) throws {
    self.backend = backend
    self.dataset = dataset
    self.asset = asset
    pipeline = try backend.compute("deformCrowFeatherRoots")

    let sourcePoints = dataset.verticesMeters.map { SIMD4<Float>($0, 0) }
    sourcePointsBuffer = try Self.sharedBuffer(
      values: sourcePoints,
      backend: backend
    )

    let feathers = asset.feathers
    let hashes = asset.stableFeatherIdentifierHashes
    let groupedCounts = Dictionary(grouping: feathers) {
      "\($0.featherClass.rawValue):\($0.side.rawValue)"
    }.mapValues(\.count)
    var orders: [String: Int] = [:]
    bindings = try zip(feathers, hashes).map { feather, hash in
      let key = "\(feather.featherClass.rawValue):\(feather.side.rawValue)"
      let order = orders[key, default: 0]
      orders[key] = order + 1
      let count = groupedCounts[key] ?? 1
      let surfaceFrame = try Self.surfaceFrameBinding(
        feather: feather,
        dataset: dataset
      )
      return CrowFeatherRootBindingGPU(
        sourceIndicesAndHash: SIMD4<UInt32>(
          UInt32(feather.physicsRootVertexIndex),
          UInt32(surfaceFrame.partRoot),
          UInt32(surfaceFrame.partTip),
          hash
        ),
        ownershipAndIdentity: SIMD4<UInt32>(
          UInt32(feather.physicsSurfacePartIdentifier),
          CrowPersistentFeatherIdentity.packed(
            feather: feather,
            order: order,
            count: count
          ),
          UInt32(surfaceFrame.partChord),
          0
        ),
        localDirectionAndLength: SIMD4<Float>(
          surfaceFrame.localDirection,
          feather.lengthMeters
        ),
        widthRachisAndPadding: SIMD4<Float>(
          CrowRectrixVaneAnatomy.maximumWidthMeters(
            assetWidthMeters: feather.maximumWidthMeters,
            featherClass: feather.featherClass,
            order: order,
            count: count
          ),
          feather.rachisRadiusMeters,
          CrowRectrixVaneAnatomy.camberMeters(
            lengthMeters: feather.lengthMeters,
            featherClass: feather.featherClass,
            order: order,
            count: count
          ),
          0
        )
      )
    }
    bindingBuffer = try Self.sharedBuffer(values: bindings, backend: backend)
    featherCount = bindings.count

    let stateBytes = MemoryLayout<CrowFeatherRootStateGPU>.stride * bindings.count
    outputBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(length: stateBytes)
    }
    readbackBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(length: stateBytes, shared: true)
    }
  }

  func encode(
    currentPhase: Float,
    previousPhase: Float,
    commandBuffer: MTLCommandBuffer,
    auditReadback: Bool = false
  ) throws -> CrowFeatherRootFrame {
    let slot = nextSlot
    nextSlot = (nextSlot + 1) % Self.bufferedFrameCount
    let output = outputBuffers[slot]
    let current = interpolationInterval(phase: currentPhase)
    let previous = interpolationInterval(phase: previousPhase)
    var uniforms = CrowFeatherDeformationUniforms(
      frameIndices: SIMD4<UInt32>(
        UInt32(current.first),
        UInt32(current.second),
        UInt32(previous.first),
        UInt32(previous.second)
      ),
      counts: SIMD4<UInt32>(
        UInt32(dataset.vertexCount),
        UInt32(featherCount),
        UInt32(dataset.frameCount),
        0
      ),
      interpolation: SIMD4<Float>(
        current.blend,
        previous.blend,
        0,
        0
      )
    )
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow feather-root compute encoder")
    }
    encoder.label = "Persistent crow feather-root deformation"
    encoder.setBuffer(sourcePointsBuffer, offset: 0, index: 0)
    encoder.setBuffer(bindingBuffer, offset: 0, index: 1)
    encoder.setBuffer(output, offset: 0, index: 2)
    encoder.setBytes(
      &uniforms,
      length: MemoryLayout<CrowFeatherDeformationUniforms>.stride,
      index: 3
    )
    backend.dispatch1D(encoder, pipeline: pipeline, count: featherCount)
    encoder.endEncoding()

    if auditReadback {
      guard let blit = commandBuffer.makeBlitCommandEncoder() else {
        throw VisualizationError.pipeline("crow feather-root readback encoder")
      }
      blit.label = "Crow feather-root temporal audit readback"
      blit.copy(
        from: output,
        sourceOffset: 0,
        to: readbackBuffers[slot],
        destinationOffset: 0,
        size: MemoryLayout<CrowFeatherRootStateGPU>.stride * featherCount
      )
      blit.endEncoding()
    }
    return CrowFeatherRootFrame(
      slot: slot,
      readbackReady: auditReadback,
      outputBuffer: output,
      currentPhase: currentPhase,
      previousPhase: previousPhase
    )
  }

  func states(for frame: CrowFeatherRootFrame) -> [CrowFeatherRootStateGPU] {
    precondition(frame.readbackReady, "feather-root frame was not encoded for readback")
    let pointer = readbackBuffers[frame.slot].contents().bindMemory(
      to: CrowFeatherRootStateGPU.self,
      capacity: featherCount
    )
    return Array(UnsafeBufferPointer(start: pointer, count: featherCount))
  }

  func referenceStates(
    currentPhase: Float,
    previousPhase: Float
  ) -> [CrowFeatherRootStateGPU] {
    let currentTime = timeSeconds(phase: currentPhase)
    let previousTime = timeSeconds(phase: previousPhase)
    return zip(zip(asset.feathers, asset.stableFeatherIdentifierHashes), bindings)
      .enumerated()
      .map { index, item in
        let ((feather, hash), binding) = item
        let current = sampleFrame(timeSeconds: currentTime, binding: binding)
        let previous = sampleFrame(timeSeconds: previousTime, binding: binding)
        return CrowFeatherRootStateGPU(
          currentPositionAndLength: SIMD4<Float>(
            current.root,
            feather.lengthMeters
          ),
          previousPositionAndWidth: SIMD4<Float>(
            previous.root,
            binding.widthRachisAndPadding.x
          ),
          currentDirectionAndRachis: SIMD4<Float>(
            current.direction,
            feather.rachisRadiusMeters
          ),
          previousDirectionAndCamber: SIMD4<Float>(
            previous.direction,
            binding.widthRachisAndPadding.z
          ),
          currentNormalAndPadding: SIMD4<Float>(current.normal, 0),
          previousNormalAndPadding: SIMD4<Float>(previous.normal, 0),
          identity: SIMD4<UInt32>(
            UInt32(index),
            hash,
            UInt32(feather.physicsSurfacePartIdentifier),
            binding.ownershipAndIdentity.y
          )
        )
      }
  }

  private func sampleFrame(
    timeSeconds: Float,
    binding: CrowFeatherRootBindingGPU
  ) -> (root: SIMD3<Float>, direction: SIMD3<Float>, normal: SIMD3<Float>) {
    let indices = binding.sourceIndicesAndHash
    let root = dataset.state(
      timeSeconds: timeSeconds,
      vertexIndex: Int(indices.x)
    ).positionMeters
    let partRoot = dataset.state(
      timeSeconds: timeSeconds,
      vertexIndex: Int(indices.y)
    ).positionMeters
    let partTip = dataset.state(
      timeSeconds: timeSeconds,
      vertexIndex: Int(indices.z)
    ).positionMeters
    let packedIdentity = binding.ownershipAndIdentity.y
    let partChord = dataset.state(
      timeSeconds: timeSeconds,
      vertexIndex: Int(binding.ownershipAndIdentity.z)
    ).positionMeters
    let basis = Self.frameBasis(
      root: root,
      partRoot: partRoot,
      partTip: partTip,
      partChord: partChord,
      featherClass: packedIdentity & 255,
      side: (packedIdentity >> 8) & 255
    )
    let local = SIMD3<Float>(
      binding.localDirectionAndLength.x,
      binding.localDirectionAndLength.y,
      binding.localDirectionAndLength.z
    )
    return (
      root,
      Self.safeNormalize(
        local.x * basis.tangent
          + local.y * basis.bitangent
          + local.z * basis.normal,
        fallback: basis.tangent
      ),
      basis.normal
    )
  }

  private func interpolationInterval(
    phase: Float
  ) -> (first: Int, second: Int, blend: Float) {
    let time = timeSeconds(phase: phase)
    if time <= dataset.frameTimesSeconds[0] { return (0, 1, 0) }
    let last = dataset.frameCount - 1
    if time >= dataset.frameTimesSeconds[last] { return (last - 1, last, 1) }
    var lower = 0
    var upper = last
    while lower + 1 < upper {
      let middle = lower + (upper - lower) / 2
      if time < dataset.frameTimesSeconds[middle] {
        upper = middle
      } else {
        lower = middle
      }
    }
    let duration = dataset.frameTimesSeconds[upper] - dataset.frameTimesSeconds[lower]
    return (
      lower,
      upper,
      (time - dataset.frameTimesSeconds[lower]) / duration
    )
  }

  private func timeSeconds(phase: Float) -> Float {
    let remainder = phase.truncatingRemainder(dividingBy: 1)
    let wrapped = remainder >= 0 ? remainder : remainder + 1
    return wrapped * dataset.frameTimesSeconds.last!
  }

  private static func surfaceFrameBinding(
    feather: BirdRealityFeather,
    dataset: MeasuredBirdSurfaceSequence
  ) throws -> (
    partRoot: Int,
    partTip: Int,
    partChord: Int,
    localDirection: SIMD3<Float>
  ) {
    let rootIndex = feather.physicsRootVertexIndex
    guard
      let component = dataset.components.first(where: {
        $0.partIdentifier == feather.physicsSurfacePartIdentifier
      })
    else {
      throw VisualizationError.pipeline(
        "feather \(feather.identifier) has no owning surface component"
      )
    }
    let body = dataset.components.first { $0.partIdentifier == 1 }!
    var bodyCenter = SIMD3<Float>.zero
    for index in body.vertexOffset..<(body.vertexOffset + body.vertexCount) {
      bodyCenter += dataset.vertex(frame: 0, index: index)
    }
    bodyCenter /= Float(body.vertexCount)
    let partIndices = component.vertexOffset..<(component.vertexOffset + component.vertexCount)
    guard
      let partRoot = partIndices.min(by: {
        simd_distance_squared(dataset.vertex(frame: 0, index: $0), bodyCenter)
          < simd_distance_squared(dataset.vertex(frame: 0, index: $1), bodyCenter)
      }),
      let partTip = partIndices.max(by: {
        simd_distance_squared(
          dataset.vertex(frame: 0, index: $0),
          dataset.vertex(frame: 0, index: partRoot)
        )
          < simd_distance_squared(
            dataset.vertex(frame: 0, index: $1),
            dataset.vertex(frame: 0, index: partRoot)
          )
      })
    else {
      throw VisualizationError.pipeline(
        "feather \(feather.identifier) has no coherent part frame"
      )
    }
    let partAxis = safeNormalize(
      dataset.vertex(frame: 0, index: partTip)
        - dataset.vertex(frame: 0, index: partRoot),
      fallback: SIMD3<Float>(
        0,
        CrowPersistentFeatherIdentity.sideCode(feather.side) == 2 ? -1 : 1,
        0
      )
    )
    let partChord =
      partIndices.max(by: {
        let first =
          dataset.vertex(frame: 0, index: $0)
          - dataset.vertex(frame: 0, index: partRoot)
        let second =
          dataset.vertex(frame: 0, index: $1)
          - dataset.vertex(frame: 0, index: partRoot)
        let firstPerpendicular = first - partAxis * simd_dot(first, partAxis)
        let secondPerpendicular = second - partAxis * simd_dot(second, partAxis)
        return simd_length_squared(firstPerpendicular)
          < simd_length_squared(secondPerpendicular)
      }) ?? partRoot
    let root = dataset.vertex(frame: 0, index: rootIndex)
    let basis = frameBasis(
      root: root,
      partRoot: dataset.vertex(frame: 0, index: partRoot),
      partTip: dataset.vertex(frame: 0, index: partTip),
      partChord: dataset.vertex(frame: 0, index: partChord),
      featherClass: CrowPersistentFeatherIdentity.classCode(feather.featherClass),
      side: CrowPersistentFeatherIdentity.sideCode(feather.side)
    )
    let direction = safeNormalize(
      feather.restDirection,
      fallback: basis.tangent
    )
    return (
      partRoot,
      partTip,
      partChord,
      SIMD3<Float>(
        simd_dot(direction, basis.tangent),
        simd_dot(direction, basis.bitangent),
        simd_dot(direction, basis.normal)
      )
    )
  }

  private static func frameBasis(
    root: SIMD3<Float>,
    partRoot: SIMD3<Float>,
    partTip: SIMD3<Float>,
    partChord: SIMD3<Float>,
    featherClass: UInt32,
    side: UInt32
  ) -> (tangent: SIMD3<Float>, bitangent: SIMD3<Float>, normal: SIMD3<Float>) {
    _ = root
    let partAxis = safeNormalize(
      partTip - partRoot,
      fallback: featherClass == 3
        ? SIMD3<Float>(-1, 0, 0)
        : SIMD3<Float>(0, side == 2 ? -1 : 1, 0)
    )
    if featherClass == 3 {
      let tangent = partAxis
      let bitangent = safeNormalize(
        SIMD3<Float>(0, 1, 0) - tangent * tangent.y,
        fallback: SIMD3<Float>(0, 1, 0)
      )
      let normal = safeNormalize(
        -simd_cross(tangent, bitangent),
        fallback: SIMD3<Float>(0, 0, 1)
      )
      return (tangent, bitangent, normal)
    }
    let bitangent = partAxis
    let chord = partChord - partRoot
    let tangent = safeNormalize(
      chord - bitangent * simd_dot(chord, bitangent),
      fallback: SIMD3<Float>(1, 0, 0)
    )
    let mirror: Float = side == 2 ? -1 : 1
    let normal = safeNormalize(
      mirror * simd_cross(tangent, bitangent),
      fallback: SIMD3<Float>(0, 0, 1)
    )
    return (tangent, bitangent, normal)
  }

  private static func safeNormalize(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let magnitude = simd_length(value)
    return magnitude > 1e-12 ? value / magnitude : fallback
  }

  private static func sharedBuffer<T>(
    values: [T],
    backend: VisualizationBackend
  ) throws -> MTLBuffer {
    let length = MemoryLayout<T>.stride * values.count
    let buffer = try backend.buffer(length: length, shared: true)
    values.withUnsafeBytes { bytes in
      guard let baseAddress = bytes.baseAddress else { return }
      memcpy(buffer.contents(), baseAddress, bytes.count)
    }
    return buffer
  }
}

extension CrowFeatherRootDeformer: CrowFeatherRootDeforming {}
