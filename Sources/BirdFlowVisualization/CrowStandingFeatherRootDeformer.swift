import BirdFlowMetal
import Foundation
import Metal
import simd

/// Generates a folded, loop-closed standing feather pose directly on Metal.
///
/// This is deliberately independent of the flight surface deformation: a
/// standing bird is not represented by slowing an outstretched wingbeat.
final class CrowStandingFeatherRootDeformer: CrowFeatherRootDeforming {
  private static let bufferedFrameCount = 3

  private let backend: VisualizationBackend
  private let pipeline: MTLComputePipelineState
  private let bindings: [CrowStandingFeatherBindingGPU]
  private let bindingBuffer: MTLBuffer
  private let outputBuffers: [MTLBuffer]
  private let readbackBuffers: [MTLBuffer]
  private let referenceBodyCenter: SIMD3<Float>
  private var nextSlot = 0

  let featherCount: Int

  init(
    backend: VisualizationBackend,
    asset: BirdRealityAsset,
    referenceBodyCenter: SIMD3<Float>
  ) throws {
    self.backend = backend
    self.referenceBodyCenter = referenceBodyCenter
    pipeline = try backend.compute("poseStandingCrowFeatherRoots")

    let hashes = asset.stableFeatherIdentifierHashes
    let groupedCounts = Dictionary(grouping: asset.feathers) {
      "\($0.featherClass.rawValue):\($0.side.rawValue)"
    }.mapValues(\.count)
    var orders: [String: Int] = [:]
    bindings = zip(asset.feathers, hashes).enumerated().map { index, pair in
      let (feather, hash) = pair
      let key = "\(feather.featherClass.rawValue):\(feather.side.rawValue)"
      let order = orders[key, default: 0]
      orders[key] = order + 1
      let count = groupedCounts[key] ?? 1
      return CrowStandingFeatherBindingGPU(
        identity: SIMD4<UInt32>(
          UInt32(index),
          hash,
          UInt32(feather.physicsSurfacePartIdentifier),
          CrowPersistentFeatherIdentity.packed(
            feather: feather,
            order: order,
            count: count
          )
        ),
        orderCountClassSide: SIMD4<UInt32>(
          UInt32(order),
          UInt32(count),
          CrowPersistentFeatherIdentity.classCode(feather.featherClass),
          CrowPersistentFeatherIdentity.sideCode(feather.side)
        ),
        morphology: SIMD4<Float>(
          feather.lengthMeters,
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
          )
        )
      )
    }
    featherCount = bindings.count
    bindingBuffer = try Self.sharedBuffer(values: bindings, backend: backend)
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
    let slot = nextSlot
    nextSlot = (nextSlot + 1) % Self.bufferedFrameCount
    let output = outputBuffers[slot]
    var uniforms = CrowStandingFeatherUniforms(
      phaseAndCount: SIMD4<Float>(
        Self.wrapped(currentPhase),
        Self.wrapped(previousPhase),
        Float(featherCount),
        0
      ),
      referenceBodyCenter: SIMD4<Float>(referenceBodyCenter, 0)
    )
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("standing crow feather-root compute encoder")
    }
    encoder.label = "Grounded crow feather-root pose"
    encoder.setBuffer(bindingBuffer, offset: 0, index: 0)
    encoder.setBuffer(output, offset: 0, index: 1)
    encoder.setBytes(
      &uniforms,
      length: MemoryLayout<CrowStandingFeatherUniforms>.stride,
      index: 2
    )
    backend.dispatch1D(encoder, pipeline: pipeline, count: featherCount)
    encoder.endEncoding()

    if auditReadback {
      guard let blit = commandBuffer.makeBlitCommandEncoder() else {
        throw VisualizationError.pipeline("standing crow feather-root readback encoder")
      }
      blit.label = "Standing crow feather-root audit readback"
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
    precondition(frame.readbackReady, "standing feather roots lack audit readback")
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
    bindings.map { binding in
      let current = Self.pose(
        binding: binding,
        phase: Self.wrapped(currentPhase),
        bodyCenter: referenceBodyCenter
      )
      let previous = Self.pose(
        binding: binding,
        phase: Self.wrapped(previousPhase),
        bodyCenter: referenceBodyCenter
      )
      let featherClass = binding.orderCountClassSide.z
      let count = max(Int(binding.orderCountClassSide.y), 1)
      let fraction = Float(binding.orderCountClassSide.x) / Float(max(count - 1, 1))
      let lengthScale =
        featherClass == 3
        ? CrowClosedTailAnatomy.lengthMeters(
          radialFraction: abs(2 * fraction - 1)
        ) / CrowClosedTailAnatomy.rectrixLengthMeters
        : 1
      let widthScale =
        featherClass == 2
        ? CrowFoldedWingAnatomy.secondaryStandingWidthScale(
          fraction: fraction
        )
        : 1
      var previousMorphology = binding.morphology
      previousMorphology.x *= lengthScale
      previousMorphology.y *= widthScale
      return CrowFeatherRootStateGPU(
        currentPositionAndLength: SIMD4<Float>(
          current.root,
          binding.morphology.x * lengthScale
        ),
        previousPositionAndWidth: SIMD4<Float>(
          previous.root,
          binding.morphology.y * widthScale
        ),
        currentDirectionAndRachis: SIMD4<Float>(current.direction, binding.morphology.z),
        previousDirectionAndCamber: SIMD4<Float>(previous.direction, binding.morphology.w),
        currentNormalAndPadding: SIMD4<Float>(current.normal, 0),
        previousNormalAndPadding: SIMD4<Float>(previous.normal, 0),
        previousMorphology: previousMorphology,
        identity: binding.identity
      )
    }
  }

  private static func pose(
    binding: CrowStandingFeatherBindingGPU,
    phase: Float,
    bodyCenter: SIMD3<Float>
  ) -> (root: SIMD3<Float>, direction: SIMD3<Float>, normal: SIMD3<Float>) {
    let angle = 2 * Float.pi * phase
    let motion = SIMD3<Float>(
      0.0007 * sin(angle + 0.35),
      0.0018 * sin(angle),
      0.0011 * sin(2 * angle - 0.45)
    )
    let center = bodyCenter + motion
    let count = max(Int(binding.orderCountClassSide.y), 1)
    let fraction = Float(binding.orderCountClassSide.x) / Float(max(count - 1, 1))
    let featherClass = binding.orderCountClassSide.z
    let sideCode = binding.orderCountClassSide.w
    let side: Float = sideCode == 1 ? 1 : (sideCode == 2 ? -1 : 0)
    let folded = CrowFoldedWingAnatomy.pose(
      featherClass: featherClass,
      side: side,
      fraction: fraction
    )
    return (
      center + folded.rootOffset,
      folded.direction,
      folded.normal
    )
  }

  private static func wrapped(_ phase: Float) -> Float {
    let remainder = phase.truncatingRemainder(dividingBy: 1)
    return remainder >= 0 ? remainder : remainder + 1
  }

  private static func safeNormalize(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-12 ? value / length : fallback
  }

  private static func sharedBuffer<T>(
    values: [T],
    backend: VisualizationBackend
  ) throws -> MTLBuffer {
    let buffer = try backend.buffer(
      length: MemoryLayout<T>.stride * values.count,
      shared: true
    )
    values.withUnsafeBytes { bytes in
      guard let baseAddress = bytes.baseAddress else { return }
      memcpy(buffer.contents(), baseAddress, bytes.count)
    }
    return buffer
  }
}
