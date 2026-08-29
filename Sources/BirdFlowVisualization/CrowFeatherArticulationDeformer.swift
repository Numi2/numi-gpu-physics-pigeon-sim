import Foundation
import Metal
import simd

/// Composes exact accepted Numi terminal-link deltas onto BirdFlow's retained
/// estimated primary, secondary, and rectrix root records before high-density
/// vane expansion. The estimated feather morphology is deliberately retained.
final class CrowFeatherArticulationDeformer {
  private static let bufferedFrameCount = 3

  private let backend: VisualizationBackend
  private let pipeline: MTLComputePipelineState
  private let outputBuffers: [MTLBuffer]
  private let transformBuffers: [MTLBuffer]
  private let featherCount: Int
  private let pivots: [UInt8: SIMD3<Float>]
  private var nextSlot = 0

  init(
    backend: VisualizationBackend,
    featherCount: Int,
    pivots: [UInt8: SIMD3<Float>]
  ) throws {
    self.backend = backend
    self.featherCount = featherCount
    self.pivots = pivots
    pipeline = try backend.compute("articulateCrowFeatherRoots")
    outputBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(
        length: MemoryLayout<CrowFeatherRootStateGPU>.stride * featherCount
      )
    }
    transformBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(
        length: MemoryLayout<CrowFeatherLinkTransformGPU>.stride * 6,
        shared: true
      )
    }
  }

  func encode(
    rootFrame: CrowFeatherRootFrame,
    current: CrowNumiReplay.ArticulationFrame,
    previous: CrowNumiReplay.ArticulationFrame,
    commandBuffer: MTLCommandBuffer
  ) throws -> CrowFeatherRootFrame {
    let slot = nextSlot
    nextSlot = (nextSlot + 1) % Self.bufferedFrameCount
    let transforms = try [
      (current, CrowNumiReplay.ArticulatedLink.leftWing, UInt8(2)),
      (current, CrowNumiReplay.ArticulatedLink.rightWing, UInt8(3)),
      (current, CrowNumiReplay.ArticulatedLink.tail, UInt8(4)),
      (previous, CrowNumiReplay.ArticulatedLink.leftWing, UInt8(2)),
      (previous, CrowNumiReplay.ArticulatedLink.rightWing, UInt8(3)),
      (previous, CrowNumiReplay.ArticulatedLink.tail, UInt8(4)),
    ].map { frame, link, partIdentifier in
      try transform(
        frame: frame, link: link, partIdentifier: partIdentifier
      )
    }
    let destination = transformBuffers[slot].contents().bindMemory(
      to: CrowFeatherLinkTransformGPU.self,
      capacity: transforms.count
    )
    for (index, transform) in transforms.enumerated() {
      destination[index] = transform
    }
    var count = UInt32(featherCount)
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow feather articulation encoder")
    }
    encoder.label = "Exact Numi crow feather-link articulation"
    encoder.setBuffer(rootFrame.outputBuffer, offset: 0, index: 0)
    encoder.setBuffer(outputBuffers[slot], offset: 0, index: 1)
    encoder.setBuffer(transformBuffers[slot], offset: 0, index: 2)
    encoder.setBytes(&count, length: MemoryLayout<UInt32>.stride, index: 3)
    backend.dispatch1D(encoder, pipeline: pipeline, count: featherCount)
    encoder.endEncoding()
    return CrowFeatherRootFrame(
      slot: slot,
      readbackReady: false,
      outputBuffer: outputBuffers[slot],
      currentPhase: rootFrame.currentPhase,
      previousPhase: rootFrame.previousPhase
    )
  }

  private func transform(
    frame: CrowNumiReplay.ArticulationFrame,
    link: CrowNumiReplay.ArticulatedLink,
    partIdentifier: UInt8
  ) throws -> CrowFeatherLinkTransformGPU {
    guard let delta = frame.delta(for: link),
      let registrationPivot = pivots[partIdentifier]
    else {
      throw VisualizationError.pipeline(
        "missing \(link.rawValue) feather articulation registration"
      )
    }
    return CrowFeatherLinkTransformGPU(
      rotationXYZW: delta.rotationXYZW,
      translationAndPartIdentifier: SIMD4(
        delta.translation, Float(partIdentifier)
      ),
      registrationPivot: SIMD4(registrationPivot, 0)
    )
  }
}
