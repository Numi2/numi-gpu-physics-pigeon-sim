import BirdFlowMetal
import Metal
import simd

/// Retracts retained folded vanes into the body while the live wing surface
/// deploys from the same persistent topology.
/// All change is geometric on Metal; no raster frames are mixed or dissolved.
final class CrowTakeoffFeatherRootDeformer: CrowFeatherRootDeforming {
  private static let bufferedFrameCount = 3

  private let backend: VisualizationBackend
  private let standing: CrowStandingFeatherRootDeformer
  private let pipeline: MTLComputePipelineState
  private let outputBuffers: [MTLBuffer]
  private var nextSlot = 0

  let featherCount: Int

  init(
    backend: VisualizationBackend,
    asset: BirdRealityAsset,
    referenceBodyCenter: SIMD3<Float>
  ) throws {
    self.backend = backend
    standing = try CrowStandingFeatherRootDeformer(
      backend: backend,
      asset: asset,
      referenceBodyCenter: referenceBodyCenter
    )
    featherCount = standing.featherCount
    pipeline = try backend.compute("blendCrowTakeoffFeatherRoots")
    let byteCount = MemoryLayout<CrowFeatherRootStateGPU>.stride * featherCount
    outputBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(length: byteCount)
    }
  }

  func encode(
    currentPhase: Float,
    previousPhase: Float,
    commandBuffer: MTLCommandBuffer,
    auditReadback: Bool = false
  ) throws -> CrowFeatherRootFrame {
    let current = CrowTakeoffSequence.sample(phase: currentPhase)
    let previous = CrowTakeoffSequence.sample(phase: previousPhase)
    let standingFrame = try standing.encode(
      currentPhase: current.standingPhase,
      previousPhase: previous.standingPhase,
      commandBuffer: commandBuffer,
      auditReadback: false
    )
    let slot = nextSlot
    nextSlot = (nextSlot + 1) % Self.bufferedFrameCount
    let output = outputBuffers[slot]
    var uniforms = CrowTakeoffFeatherBlendUniforms(
      blendAndCount: SIMD4<Float>(
        current.transitionProgress,
        previous.transitionProgress,
        Float(featherCount),
        0
      ),
      currentBodyTranslation: SIMD4<Float>(current.bodyTranslation, 0),
      previousBodyTranslation: SIMD4<Float>(previous.bodyTranslation, 0)
    )
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("takeoff feather-root blend encoder")
    }
    encoder.label = "Crow folded-to-flight feather-root blend"
    encoder.setBuffer(standingFrame.outputBuffer, offset: 0, index: 0)
    encoder.setBuffer(output, offset: 0, index: 1)
    encoder.setBytes(
      &uniforms,
      length: MemoryLayout<CrowTakeoffFeatherBlendUniforms>.stride,
      index: 2
    )
    backend.dispatch1D(encoder, pipeline: pipeline, count: featherCount)
    encoder.endEncoding()
    return CrowFeatherRootFrame(
      slot: slot,
      readbackReady: auditReadback,
      outputBuffer: output,
      currentPhase: currentPhase,
      previousPhase: previousPhase
    )
  }
}
