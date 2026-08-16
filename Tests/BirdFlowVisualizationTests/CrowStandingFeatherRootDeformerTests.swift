import BirdFlowMetal
import Metal
import Testing
import simd

@testable import BirdFlowVisualization

@Test("standing crow feather roots stay folded and match Metal temporally")
func standingCrowFeatherRootsMatchMetalReference() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
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
  let body = surface.components.first { $0.partIdentifier == 1 }!
  var bodyCenter = SIMD3<Float>.zero
  for index in body.vertexOffset..<(body.vertexOffset + body.vertexCount) {
    bodyCenter += surface.vertex(frame: 0, index: index)
  }
  bodyCenter /= Float(body.vertexCount)

  let backend = try VisualizationBackend(device: device)
  let deformer = try CrowStandingFeatherRootDeformer(
    backend: backend,
    asset: asset,
    referenceBodyCenter: bodyCenter
  )
  #expect(MemoryLayout<CrowStandingFeatherBindingGPU>.stride == 48)
  #expect(MemoryLayout<CrowStandingFeatherUniforms>.stride == 32)
  #expect(MemoryLayout<CrowSurfaceTemporalVertexGPU>.stride == 80)
  #expect(MemoryLayout<CrowTemporalCameraUniforms>.stride == 160)
  #expect(deformer.featherCount == 54)

  for phases: (Float, Float) in [(0, 0), (0.22, 0.19), (0.61, 0.58), (1, 0.97)] {
    guard let commandBuffer = backend.queue.makeCommandBuffer() else {
      Issue.record("unable to allocate standing crow command buffer")
      return
    }
    let frame = try deformer.encode(
      currentPhase: phases.0,
      previousPhase: phases.1,
      commandBuffer: commandBuffer,
      auditReadback: true
    )
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    #expect(commandBuffer.status == .completed)
    let actual = deformer.states(for: frame)
    let expected = deformer.referenceStates(
      currentPhase: phases.0,
      previousPhase: phases.1
    )
    #expect(actual.count == expected.count)
    for (gpu, cpu) in zip(actual, expected) {
      #expect(simd_length(gpu.currentPositionAndLength - cpu.currentPositionAndLength) < 2e-7)
      #expect(simd_length(gpu.previousPositionAndWidth - cpu.previousPositionAndWidth) < 2e-7)
      #expect(simd_length(gpu.currentDirectionAndRachis - cpu.currentDirectionAndRachis) < 2e-6)
      #expect(simd_length(gpu.previousDirectionAndCamber - cpu.previousDirectionAndCamber) < 2e-6)
      #expect(simd_length(gpu.currentNormalAndPadding - cpu.currentNormalAndPadding) < 2e-6)
      #expect(simd_length(gpu.previousNormalAndPadding - cpu.previousNormalAndPadding) < 2e-6)
      #expect(gpu.identity == cpu.identity)
    }
  }

  let loopStart = deformer.referenceStates(currentPhase: 0, previousPhase: 0)
  let loopEnd = deformer.referenceStates(currentPhase: 1, previousPhase: 1)
  #expect(loopStart == loopEnd)
  let moving = deformer.referenceStates(currentPhase: 0.61, previousPhase: 0.58)
  #expect(
    moving.contains {
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
    }
  )

  let localRoots = moving.map {
    SIMD3<Float>(
      $0.currentPositionAndLength.x,
      $0.currentPositionAndLength.y,
      $0.currentPositionAndLength.z
    ) - bodyCenter
  }
  #expect(localRoots.map { abs($0.y) }.max()! < 0.07)
  #expect(localRoots.map(\.x).min()! > -0.14)
  #expect(Set(moving.map { $0.identity.y }).count == 54)

  for featherClass: UInt32 in [1, 2] {
    for sideCode: UInt32 in [1, 2] {
      let tips = moving.compactMap { state -> SIMD3<Float>? in
        let packedIdentity = state.identity.w
        guard packedIdentity & 255 == featherClass,
          (packedIdentity >> 8) & 255 == sideCode
        else { return nil }
        let root = SIMD3<Float>(
          state.currentPositionAndLength.x,
          state.currentPositionAndLength.y,
          state.currentPositionAndLength.z
        )
        let direction = SIMD3<Float>(
          state.currentDirectionAndRachis.x,
          state.currentDirectionAndRachis.y,
          state.currentDirectionAndRachis.z
        )
        return root + direction * state.currentPositionAndLength.w
      }
      #expect(tips.count >= 10)
      #expect(tips.map(\.y).max()! - tips.map(\.y).min()! < 0.004)
      #expect(tips.map(\.z).max()! - tips.map(\.z).min()! < 0.046)
    }
  }

  for featherClass: UInt32 in [1, 2] {
    let leftFront = CrowFoldedWingAnatomy.pose(
      featherClass: featherClass,
      side: 1,
      fraction: 0
    )
    let leftRear = CrowFoldedWingAnatomy.pose(
      featherClass: featherClass,
      side: 1,
      fraction: 1
    )
    let rightRear = CrowFoldedWingAnatomy.pose(
      featherClass: featherClass,
      side: -1,
      fraction: 1
    )
    #expect(leftRear.rootOffset.x < leftFront.rootOffset.x)
    #expect(leftRear.rootOffset.y > leftFront.rootOffset.y)
    #expect(leftRear.rootOffset.z < leftFront.rootOffset.z)
    #expect(leftRear.direction.y < 0 && leftFront.direction.y < 0)
    #expect(leftRear.direction.z < 0 && leftFront.direction.z < 0)
    #expect(abs(leftRear.rootOffset.x - rightRear.rootOffset.x) < 1e-7)
    #expect(abs(leftRear.rootOffset.y + rightRear.rootOffset.y) < 1e-7)
    #expect(abs(leftRear.direction.y + rightRear.direction.y) < 1e-7)
    #expect(abs(simd_length(leftRear.direction) - 1) < 1e-6)
    #expect(abs(simd_length(leftRear.normal) - 1) < 1e-6)

    let frontLength: Float = featherClass == 1 ? 0.155 : 0.112
    let rearLength: Float = featherClass == 1 ? 0.205 : 0.142
    let frontTip = leftFront.rootOffset + frontLength * leftFront.direction
    let rearTip = leftRear.rootOffset + rearLength * leftRear.direction
    #expect(abs(frontTip.y - rearTip.y) < 0.004)
    #expect(abs(frontTip.z - rearTip.z) < 0.046)
  }
}
