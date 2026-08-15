import BirdFlowMetal
import Metal
import Testing
import simd

@testable import BirdFlowVisualization

private var crowRealityRepositoryRootURL: URL {
  URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
}

@Test("crow feather-root GPU records match the locked surface and temporal state")
func crowFeatherRootGPUDeformationMatchesCPUReference() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let root = crowRealityRepositoryRootURL
  let asset = try BirdRealityAssetLoader.load(
    assetURL: root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-reality-v1.json"
    ),
    repositoryRootURL: root
  )
  let surface = try MeasuredBirdSurfaceSequenceLoader.load(
    manifestURL: root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"
    )
  )
  let backend = try VisualizationBackend(device: device)
  let deformer = try CrowFeatherRootDeformer(
    backend: backend,
    dataset: surface,
    asset: asset
  )

  #expect(MemoryLayout<CrowFeatherRootBindingGPU>.stride == 48)
  #expect(MemoryLayout<CrowFeatherRootStateGPU>.stride == 64)
  #expect(MemoryLayout<CrowFeatherDeformationUniforms>.stride == 48)
  #expect(deformer.featherCount == 54)

  let phases: [(current: Float, previous: Float)] = [
    (0, 0),
    (0.271, 0.249),
    (0.503, 0.481),
    (0.997, 0.975),
  ]
  for phase in phases {
    guard let commandBuffer = backend.queue.makeCommandBuffer() else {
      Issue.record("unable to allocate crow feather-root command buffer")
      return
    }
    let frame = try deformer.encode(
      currentPhase: phase.current,
      previousPhase: phase.previous,
      commandBuffer: commandBuffer
    )
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    #expect(commandBuffer.status == .completed)

    let actual = deformer.states(for: frame)
    let expected = deformer.referenceStates(
      currentPhase: phase.current,
      previousPhase: phase.previous
    )
    #expect(actual.count == expected.count)
    for (gpu, cpu) in zip(actual, expected) {
      #expect(simd_length(gpu.currentPositionAndLength - cpu.currentPositionAndLength) < 1e-7)
      #expect(simd_length(gpu.previousPositionAndWidth - cpu.previousPositionAndWidth) < 1e-7)
      #expect(simd_length(gpu.restDirectionAndRachis - cpu.restDirectionAndRachis) < 1e-7)
      #expect(gpu.identity == cpu.identity)
    }
  }

  let movingFrame = deformer.referenceStates(
    currentPhase: 0.503,
    previousPhase: 0.481
  )
  #expect(
    movingFrame.contains {
      simd_length(
        SIMD3<Float>(
          $0.currentPositionAndLength.x,
          $0.currentPositionAndLength.y,
          $0.currentPositionAndLength.z
        )
          - SIMD3<Float>(
            $0.previousPositionAndWidth.x,
            $0.previousPositionAndWidth.y,
            $0.previousPositionAndWidth.z
          )
      ) > 1e-5
    })
  #expect(Set(movingFrame.map { $0.identity.y }).count == 54)
}
