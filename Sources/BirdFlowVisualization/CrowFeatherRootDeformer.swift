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
/// Each feather is attached to an oriented triangle on the fixed-topology
/// surface. The kernel transports its estimated rest direction through the
/// triangle's current and previous tangent frames, retaining exact identity
/// while avoiding a per-frame CPU transform upload.
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
    bindings = try zip(feathers, hashes).map { feather, hash in
      let surfaceFrame = try Self.surfaceFrameBinding(
        feather: feather,
        dataset: dataset
      )
      return CrowFeatherRootBindingGPU(
        sourceIndicesAndHash: SIMD4<UInt32>(
          UInt32(feather.physicsRootVertexIndex),
          UInt32(surfaceFrame.firstNeighbor),
          UInt32(surfaceFrame.secondNeighbor),
          hash
        ),
        ownershipAndIdentity: SIMD4<UInt32>(
          UInt32(feather.physicsSurfacePartIdentifier),
          Self.packedIdentity(feather),
          0,
          0
        ),
        localDirectionAndLength: SIMD4<Float>(
          surfaceFrame.localDirection,
          feather.lengthMeters
        ),
        widthRachisAndPadding: SIMD4<Float>(
          feather.maximumWidthMeters,
          feather.rachisRadiusMeters,
          Self.camberMeters(feather),
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
            feather.maximumWidthMeters
          ),
          currentDirectionAndRachis: SIMD4<Float>(
            current.direction,
            feather.rachisRadiusMeters
          ),
          previousDirectionAndCamber: SIMD4<Float>(
            previous.direction,
            Self.camberMeters(feather)
          ),
          currentNormalAndPadding: SIMD4<Float>(current.normal, 0),
          previousNormalAndPadding: SIMD4<Float>(previous.normal, 0),
          identity: SIMD4<UInt32>(
            UInt32(index),
            hash,
            UInt32(feather.physicsSurfacePartIdentifier),
            Self.packedIdentity(feather)
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
    let first = dataset.state(
      timeSeconds: timeSeconds,
      vertexIndex: Int(indices.y)
    ).positionMeters
    let second = dataset.state(
      timeSeconds: timeSeconds,
      vertexIndex: Int(indices.z)
    ).positionMeters
    let basis = Self.frameBasis(root: root, first: first, second: second)
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
    firstNeighbor: Int,
    secondNeighbor: Int,
    localDirection: SIMD3<Float>
  ) {
    let rootIndex = feather.physicsRootVertexIndex
    var selected: (first: Int, second: Int, areaSquared: Float)?
    for triangleIndex in 0..<dataset.triangleCount
    where dataset.trianglePartIdentifiers[triangleIndex]
      == feather.physicsSurfacePartIdentifier
    {
      let triangle = dataset.triangle(triangleIndex)
      let indices = [Int(triangle.x), Int(triangle.y), Int(triangle.z)]
      guard let corner = indices.firstIndex(of: rootIndex) else { continue }
      let first = indices[(corner + 1) % 3]
      let second = indices[(corner + 2) % 3]
      let root = dataset.vertex(frame: 0, index: rootIndex)
      let edgeA = dataset.vertex(frame: 0, index: first) - root
      let edgeB = dataset.vertex(frame: 0, index: second) - root
      let areaSquared = simd_length_squared(simd_cross(edgeA, edgeB))
      if let current = selected {
        if areaSquared > current.areaSquared {
          selected = (first, second, areaSquared)
        }
      } else {
        selected = (first, second, areaSquared)
      }
    }
    guard let selected, selected.areaSquared > 1e-16 else {
      throw VisualizationError.pipeline(
        "feather \(feather.identifier) has no nondegenerate surface frame"
      )
    }
    let root = dataset.vertex(frame: 0, index: rootIndex)
    let basis = frameBasis(
      root: root,
      first: dataset.vertex(frame: 0, index: selected.first),
      second: dataset.vertex(frame: 0, index: selected.second)
    )
    let direction = safeNormalize(
      feather.restDirection,
      fallback: basis.tangent
    )
    return (
      selected.first,
      selected.second,
      SIMD3<Float>(
        simd_dot(direction, basis.tangent),
        simd_dot(direction, basis.bitangent),
        simd_dot(direction, basis.normal)
      )
    )
  }

  private static func frameBasis(
    root: SIMD3<Float>,
    first: SIMD3<Float>,
    second: SIMD3<Float>
  ) -> (tangent: SIMD3<Float>, bitangent: SIMD3<Float>, normal: SIMD3<Float>) {
    let tangent = safeNormalize(first - root, fallback: SIMD3<Float>(1, 0, 0))
    let normal = safeNormalize(
      simd_cross(first - root, second - root),
      fallback: SIMD3<Float>(0, 0, 1)
    )
    return (
      tangent,
      safeNormalize(simd_cross(normal, tangent), fallback: SIMD3<Float>(0, 1, 0)),
      normal
    )
  }

  private static func safeNormalize(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let magnitude = simd_length(value)
    return magnitude > 1e-12 ? value / magnitude : fallback
  }

  private static func camberMeters(_ feather: BirdRealityFeather) -> Float {
    let scale: Float
    switch feather.featherClass {
    case .primary: scale = 0.045
    case .secondary: scale = 0.040
    case .tail: scale = 0.030
    case .covert: scale = 0.025
    case .contour: scale = 0.020
    }
    return feather.lengthMeters * scale
  }

  private static func packedIdentity(_ feather: BirdRealityFeather) -> UInt32 {
    classCode(feather.featherClass) | (sideCode(feather.side) << 8)
  }

  private static func classCode(_ featherClass: BirdRealityFeatherClass) -> UInt32 {
    switch featherClass {
    case .primary: return 1
    case .secondary: return 2
    case .tail: return 3
    case .covert: return 4
    case .contour: return 5
    }
  }

  private static func sideCode(_ side: BirdRealitySide) -> UInt32 {
    switch side {
    case .center: return 0
    case .left: return 1
    case .right: return 2
    }
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
