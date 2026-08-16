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
      return CrowStandingFeatherBindingGPU(
        identity: SIMD4<UInt32>(
          UInt32(index),
          hash,
          UInt32(feather.physicsSurfacePartIdentifier),
          Self.packedIdentity(feather)
        ),
        orderCountClassSide: SIMD4<UInt32>(
          UInt32(order),
          UInt32(groupedCounts[key] ?? 1),
          Self.classCode(feather.featherClass),
          Self.sideCode(feather.side)
        ),
        morphology: SIMD4<Float>(
          feather.lengthMeters,
          feather.maximumWidthMeters,
          feather.rachisRadiusMeters,
          Self.camberMeters(feather)
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
      return CrowFeatherRootStateGPU(
        currentPositionAndLength: SIMD4<Float>(current.root, binding.morphology.x),
        previousPositionAndWidth: SIMD4<Float>(previous.root, binding.morphology.y),
        currentDirectionAndRachis: SIMD4<Float>(current.direction, binding.morphology.z),
        previousDirectionAndCamber: SIMD4<Float>(previous.direction, binding.morphology.w),
        currentNormalAndPadding: SIMD4<Float>(current.normal, 0),
        previousNormalAndPadding: SIMD4<Float>(previous.normal, 0),
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
    let root: SIMD3<Float>
    let direction: SIMD3<Float>
    let normal: SIMD3<Float>
    switch featherClass {
    case 1:
      root =
        center
        + SIMD3<Float>(
          0.015 - 0.105 * fraction,
          side * (0.054 + 0.003 * fraction),
          0.012 - 0.060 * fraction
        )
      direction = safeNormalize(
        SIMD3<Float>(-0.99, -side * (0.025 + 0.045 * fraction), -0.08),
        fallback: SIMD3<Float>(-1, 0, 0)
      )
      normal = SIMD3<Float>(0.06, side, 0.10)
    case 2:
      root =
        center
        + SIMD3<Float>(
          0.074 - 0.175 * fraction,
          side * (0.055 + 0.002 * fraction),
          0.024 - 0.045 * fraction
        )
      direction = safeNormalize(
        SIMD3<Float>(-0.995, -side * 0.025, -0.065),
        fallback: SIMD3<Float>(-1, 0, 0)
      )
      normal = SIMD3<Float>(0.04, side, 0.08)
    default:
      let lateral = (fraction - 0.5) * 0.082
      root = center + SIMD3<Float>(-0.125, lateral * 0.30, -0.005)
      direction = safeNormalize(
        SIMD3<Float>(-0.995, lateral * 0.32, -0.055),
        fallback: SIMD3<Float>(-1, 0, 0)
      )
      normal = SIMD3<Float>(0, 0.04 * side, 1)
    }
    return (
      root,
      direction,
      safeNormalize(normal, fallback: SIMD3<Float>(0, 0, 1))
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
