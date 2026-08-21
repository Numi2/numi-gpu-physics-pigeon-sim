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
  private let readbackBuffers: [MTLBuffer]
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
    readbackBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(length: byteCount, shared: true)
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
    if auditReadback {
      guard let blit = commandBuffer.makeBlitCommandEncoder() else {
        throw VisualizationError.pipeline("takeoff feather-root readback encoder")
      }
      blit.label = "Takeoff crow feather-root audit readback"
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
    precondition(frame.readbackReady, "takeoff feather roots lack audit readback")
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
    let current = CrowTakeoffSequence.sample(phase: currentPhase)
    let previous = CrowTakeoffSequence.sample(phase: previousPhase)
    return standing.referenceStates(
      currentPhase: current.standingPhase,
      previousPhase: previous.standingPhase
    ).map {
      Self.blendedState($0, current: current, previous: previous)
    }
  }

  private static func blendedState(
    _ grounded: CrowFeatherRootStateGPU,
    current: CrowTakeoffSequence.Sample,
    previous: CrowTakeoffSequence.Sample
  ) -> CrowFeatherRootStateGPU {
    let packedIdentity = grounded.identity.w
    let featherClass = packedIdentity & 255
    if featherClass == 3 {
      let order = Int((packedIdentity >> 16) & 255)
      let count = max(Int((packedIdentity >> 24) & 255), 1)
      let fraction = Float(order) / Float(max(count - 1, 1))
      let closed = CrowClosedTailAnatomy.pose(fraction: fraction)
      let currentPose = CrowTakeoffSequence.transitionRectrixPose(
        order: order,
        count: count,
        transitionProgress: current.transitionProgress
      )
      let previousPose = CrowTakeoffSequence.transitionRectrixPose(
        order: order,
        count: count,
        transitionProgress: previous.transitionProgress
      )
      let closedLengthScale = CrowClosedTailAnatomy.lengthMeters(
        radialFraction: closed.radialFraction
      ) / CrowClosedTailAnatomy.rectrixLengthMeters
      let currentLengthScale = closedLengthScale
        + CrowTakeoffSequence.liveRectrixDeploymentWeight(
          transitionProgress: current.transitionProgress
        ) * (1 - closedLengthScale)
      let previousLengthScale = closedLengthScale
        + CrowTakeoffSequence.liveRectrixDeploymentWeight(
          transitionProgress: previous.transitionProgress
        ) * (1 - closedLengthScale)
      let currentRoot = xyz(grounded.currentPositionAndLength)
        + current.bodyTranslation
        + (currentPose.rootOffset - closed.rootOffset)
      let previousRoot = xyz(grounded.previousPositionAndWidth)
        + previous.bodyTranslation
        + (previousPose.rootOffset - closed.rootOffset)
      return CrowFeatherRootStateGPU(
        currentPositionAndLength: SIMD4<Float>(
          currentRoot,
          grounded.currentPositionAndLength.w
            * currentLengthScale / closedLengthScale
        ),
        previousPositionAndWidth: SIMD4<Float>(
          previousRoot,
          grounded.previousPositionAndWidth.w
        ),
        currentDirectionAndRachis: SIMD4<Float>(
          currentPose.direction,
          grounded.currentDirectionAndRachis.w
        ),
        previousDirectionAndCamber: SIMD4<Float>(
          previousPose.direction,
          grounded.previousDirectionAndCamber.w
        ),
        currentNormalAndPadding: SIMD4<Float>(currentPose.normal, 0),
        previousNormalAndPadding: SIMD4<Float>(previousPose.normal, 0),
        previousMorphology: SIMD4<Float>(
          grounded.previousMorphology.x
            * previousLengthScale / closedLengthScale,
          grounded.previousMorphology.y,
          grounded.previousMorphology.z,
          grounded.previousMorphology.w
        ),
        identity: grounded.identity
      )
    }

    let order = Int((packedIdentity >> 16) & 255)
    let count = max(Int((packedIdentity >> 24) & 255), 1)
    let currentFoldedVisibility = CrowTakeoffSequence.retainedRemexVisibility(
      featherClass: featherClass,
      order: order,
      count: count,
      transitionProgress: current.transitionProgress
    )
    let previousFoldedVisibility = CrowTakeoffSequence.retainedRemexVisibility(
      featherClass: featherClass,
      order: order,
      count: count,
      transitionProgress: previous.transitionProgress
    )
    let sideCode = (packedIdentity >> 8) & 255
    let side: Float = sideCode == 1 ? 1 : (sideCode == 2 ? -1 : 0)
    let inverseLength = 1 / max(grounded.currentPositionAndLength.w, 1e-6)
    let currentDirection = normalized(
      xyz(grounded.currentDirectionAndRachis)
        + SIMD3<Float>(
          0,
          side * inverseLength
            * CrowTakeoffSequence.terminalPrimaryHandoffLateralOffsetMeters(
              featherClass: featherClass,
              order: order,
              count: count,
              transitionProgress: current.transitionProgress
            ),
          0
        ),
      fallback: xyz(grounded.currentDirectionAndRachis)
    )
    let previousDirection = normalized(
      xyz(grounded.previousDirectionAndCamber)
        + SIMD3<Float>(
          0,
          side * inverseLength
            * CrowTakeoffSequence.terminalPrimaryHandoffLateralOffsetMeters(
              featherClass: featherClass,
              order: order,
              count: count,
              transitionProgress: previous.transitionProgress
            ),
          0
        ),
      fallback: xyz(grounded.previousDirectionAndCamber)
    )
    return CrowFeatherRootStateGPU(
      currentPositionAndLength: SIMD4<Float>(
        xyz(grounded.currentPositionAndLength)
          + current.bodyTranslation,
        grounded.currentPositionAndLength.w * currentFoldedVisibility
      ),
      previousPositionAndWidth: SIMD4<Float>(
        xyz(grounded.previousPositionAndWidth)
          + previous.bodyTranslation,
        grounded.previousPositionAndWidth.w * previousFoldedVisibility
      ),
      currentDirectionAndRachis: SIMD4<Float>(
        currentDirection,
        grounded.currentDirectionAndRachis.w * currentFoldedVisibility
      ),
      previousDirectionAndCamber: SIMD4<Float>(
        previousDirection,
        grounded.previousDirectionAndCamber.w * previousFoldedVisibility
      ),
      currentNormalAndPadding: grounded.currentNormalAndPadding,
      previousNormalAndPadding: grounded.previousNormalAndPadding,
      previousMorphology: grounded.previousMorphology * previousFoldedVisibility,
      identity: grounded.identity
    )
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-8 ? value / length : fallback
  }

  private static func xyz(_ value: SIMD4<Float>) -> SIMD3<Float> {
    SIMD3<Float>(value.x, value.y, value.z)
  }
}
