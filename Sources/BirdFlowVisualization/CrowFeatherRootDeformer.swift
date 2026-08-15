import BirdFlowMetal
import Foundation
import Metal
import simd

struct CrowFeatherRootFrame {
  fileprivate let slot: Int
  let outputBuffer: MTLBuffer
  let currentPhase: Float
  let previousPhase: Float
}

/// Retained Metal state for the persistent feather inventory.
///
/// This pass owns render-time current/previous root correspondence. It does not
/// claim that the coarse surface resolves a rachis or vane: root anchors remain
/// metadata tying the future beauty representation to the executable surface.
final class CrowFeatherRootDeformer {
  private static let bufferedFrameCount = 3

  private let backend: VisualizationBackend
  private let dataset: MeasuredBirdSurfaceSequence
  private let asset: BirdRealityAsset
  private let pipeline: MTLComputePipelineState
  private let sourcePointsBuffer: MTLBuffer
  private let bindingBuffer: MTLBuffer
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
    let bindings = zip(feathers, hashes).map { feather, hash in
      CrowFeatherRootBindingGPU(
        sourceAndIdentity: SIMD4<UInt32>(
          UInt32(feather.physicsRootVertexIndex),
          hash,
          UInt32(feather.physicsSurfacePartIdentifier),
          Self.packedIdentity(feather)
        ),
        restDirectionAndLength: SIMD4<Float>(
          feather.restDirection,
          feather.lengthMeters
        ),
        widthRachisAndPadding: SIMD4<Float>(
          feather.maximumWidthMeters,
          feather.rachisRadiusMeters,
          0,
          0
        )
      )
    }
    bindingBuffer = try Self.sharedBuffer(values: bindings, backend: backend)
    featherCount = bindings.count

    let stateBytes =
      MemoryLayout<CrowFeatherRootStateGPU>.stride
      * bindings.count
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
    commandBuffer: MTLCommandBuffer
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
    return CrowFeatherRootFrame(
      slot: slot,
      outputBuffer: output,
      currentPhase: currentPhase,
      previousPhase: previousPhase
    )
  }

  func states(for frame: CrowFeatherRootFrame) -> [CrowFeatherRootStateGPU] {
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
    return zip(asset.feathers, asset.stableFeatherIdentifierHashes)
      .enumerated()
      .map { index, item in
        let (feather, hash) = item
        let current = dataset.state(
          timeSeconds: currentTime,
          vertexIndex: feather.physicsRootVertexIndex
        ).positionMeters
        let previous = dataset.state(
          timeSeconds: previousTime,
          vertexIndex: feather.physicsRootVertexIndex
        ).positionMeters
        return CrowFeatherRootStateGPU(
          currentPositionAndLength: SIMD4<Float>(
            current,
            feather.lengthMeters
          ),
          previousPositionAndWidth: SIMD4<Float>(
            previous,
            feather.maximumWidthMeters
          ),
          restDirectionAndRachis: SIMD4<Float>(
            feather.restDirection,
            feather.rachisRadiusMeters
          ),
          identity: SIMD4<UInt32>(
            UInt32(index),
            hash,
            UInt32(feather.physicsSurfacePartIdentifier),
            Self.packedIdentity(feather)
          )
        )
      }
  }

  private func interpolationInterval(
    phase: Float
  ) -> (first: Int, second: Int, blend: Float) {
    let time = timeSeconds(phase: phase)
    if time <= dataset.frameTimesSeconds[0] {
      return (0, 1, 0)
    }
    let last = dataset.frameCount - 1
    if time >= dataset.frameTimesSeconds[last] {
      return (last - 1, last, 1)
    }
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
    let duration =
      dataset.frameTimesSeconds[upper]
      - dataset.frameTimesSeconds[lower]
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

  private static func packedIdentity(_ feather: BirdRealityFeather) -> UInt32 {
    classCode(feather.featherClass) | (sideCode(feather.side) << 8)
  }

  private static func classCode(
    _ featherClass: BirdRealityFeatherClass
  ) -> UInt32 {
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
