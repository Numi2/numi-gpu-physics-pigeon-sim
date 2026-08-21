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

  #expect(MemoryLayout<CrowFeatherRootBindingGPU>.stride == 64)
  #expect(MemoryLayout<CrowFeatherRootStateGPU>.stride == 128)
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
      commandBuffer: commandBuffer,
      auditReadback: true
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
      #expect(simd_length(gpu.currentDirectionAndRachis - cpu.currentDirectionAndRachis) < 1e-5)
      #expect(
        simd_length(gpu.previousDirectionAndCamber - cpu.previousDirectionAndCamber) < 1e-5
      )
      #expect(simd_length(gpu.currentNormalAndPadding - cpu.currentNormalAndPadding) < 1e-5)
      #expect(simd_length(gpu.previousNormalAndPadding - cpu.previousNormalAndPadding) < 1e-5)
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
  #expect(
    movingFrame.allSatisfy {
      abs(
        simd_length(
          SIMD3<Float>(
            $0.currentDirectionAndRachis.x,
            $0.currentDirectionAndRachis.y,
            $0.currentDirectionAndRachis.z
          )) - 1) < 1e-6
    }
  )
  for packedIdentity in [UInt32(1 | (1 << 8)), UInt32(1 | (2 << 8))] {
    let primaries = movingFrame.filter { ($0.identity.w & 0xffff) == packedIdentity }
    #expect(primaries.count == 10)
    let referenceNormal = SIMD3<Float>(
      primaries[0].currentNormalAndPadding.x,
      primaries[0].currentNormalAndPadding.y,
      primaries[0].currentNormalAndPadding.z
    )
    #expect(
      primaries.allSatisfy {
        simd_distance(
          SIMD3<Float>(
            $0.currentNormalAndPadding.x,
            $0.currentNormalAndPadding.y,
            $0.currentNormalAndPadding.z
          ),
          referenceNormal
        ) < 1e-5
      }
    )
    for (first, second) in zip(primaries, primaries.dropFirst()) {
      let firstDirection = SIMD3<Float>(
        first.currentDirectionAndRachis.x,
        first.currentDirectionAndRachis.y,
        first.currentDirectionAndRachis.z
      )
      let secondDirection = SIMD3<Float>(
        second.currentDirectionAndRachis.x,
        second.currentDirectionAndRachis.y,
        second.currentDirectionAndRachis.z
      )
      #expect(simd_dot(firstDirection, secondDirection) > 0.97)
    }
  }
}
