import Foundation
import BirdFlowMetal
import Metal
import Testing
import simd
@testable import BirdFlowVisualization

@Test("walking feather roots follow the body on Metal")
func walkingFeatherRootsOnMetal() throws {
  guard let device = MTLCreateSystemDefaultDevice() else {
    Issue.record("Metal device unavailable")
    return
  }
  let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
  let asset = try BirdRealityAssetLoader.load(
    assetURL: root.appendingPathComponent("ValidationInputs/american-crow-hybrid-reality-v1.json"),
    repositoryRootURL: root)
  let backend = try VisualizationBackend(device: device)
  let deformer = try CrowStandingFeatherRootDeformer(
    backend: backend, asset: asset, referenceBodyCenter: .zero, walking: true)
  for (current, previous): (Float, Float) in [(0.02, 0), (0.15, 0.14), (0.52, 0.50), (1, 0.99)] {
    let command = try #require(backend.queue.makeCommandBuffer())
    let frame = try deformer.encode(currentPhase: current, previousPhase: previous,
      commandBuffer: command, auditReadback: true)
    command.commit()
    command.waitUntilCompleted()
    #expect(command.status == .completed)
    let actual = deformer.states(for: frame)
    let expected = deformer.referenceStates(currentPhase: current, previousPhase: previous)
    #expect(actual.count == expected.count)
    for (gpu, cpu) in zip(actual, expected) {
      #expect(simd_length(gpu.currentPositionAndLength - cpu.currentPositionAndLength) < 3e-7)
      #expect(simd_length(gpu.previousPositionAndWidth - cpu.previousPositionAndWidth) < 3e-7)
      #expect(gpu.identity == cpu.identity)
    }
  }
}
