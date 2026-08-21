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
  #expect(MemoryLayout<ColoredVertex>.stride == 64)
  #expect(MemoryLayout<CrowStandingFeatherUniforms>.stride == 32)
  #expect(MemoryLayout<CrowSurfaceTemporalVertexGPU>.stride == 96)
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
  #expect(localRoots.map(\.x).min()! > -0.158)
  #expect(Set(moving.map { $0.identity.y }).count == 54)

  let rectrices =
    moving
    .filter { $0.identity.w & 255 == 3 }
    .sorted { (($0.identity.w >> 16) & 255) < (($1.identity.w >> 16) & 255) }
  #expect(rectrices.count == 12)
  #expect(
    rectrices.enumerated().allSatisfy { order, rectrix in
      ((rectrix.identity.w >> 16) & 255) == UInt32(order)
        && ((rectrix.identity.w >> 24) & 255) == 12
    })
  let rectrixWidths = rectrices.map(\.previousPositionAndWidth.w)
  let rectrixCambers = rectrices.map(\.previousDirectionAndCamber.w)
  #expect(rectrixWidths.max()! - rectrixWidths.min()! > 0.0009)
  #expect(rectrixCambers.max()! - rectrixCambers.min()! > 0.0009)
  for pairIndex in 0..<6 {
    #expect(abs(rectrixWidths[pairIndex] - rectrixWidths[11 - pairIndex]) < 1e-7)
    #expect(abs(rectrixCambers[pairIndex] - rectrixCambers[11 - pairIndex]) < 1e-7)
  }

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

  for sideCode: UInt32 in [1, 2] {
    let side: Float = sideCode == 1 ? 1 : -1
    let primaries =
      moving
      .filter {
        $0.identity.w & 255 == 1
          && ($0.identity.w >> 8) & 255 == sideCode
      }
    let lateralRectrix =
      moving
      .filter { $0.identity.w & 255 == 3 }
      .max {
        side * $0.currentPositionAndLength.y
          < side * $1.currentPositionAndLength.y
      }!
    let tailRoot = SIMD3<Float>(
      lateralRectrix.currentPositionAndLength.x,
      lateralRectrix.currentPositionAndLength.y,
      lateralRectrix.currentPositionAndLength.z
    )
    let tailDirection = SIMD3<Float>(
      lateralRectrix.currentDirectionAndRachis.x,
      lateralRectrix.currentDirectionAndRachis.y,
      lateralRectrix.currentDirectionAndRachis.z
    )
    let tailNormal = SIMD3<Float>(
      lateralRectrix.currentNormalAndPadding.x,
      lateralRectrix.currentNormalAndPadding.y,
      lateralRectrix.currentNormalAndPadding.z
    )
    let tailLength = lateralRectrix.currentPositionAndLength.w
    let orthogonalTailNormal = simd_normalize(
      tailNormal - tailDirection * simd_dot(tailNormal, tailDirection)
    )
    let tailWidthAxis = simd_normalize(
      simd_cross(orthogonalTailNormal, tailDirection)
    )
    var evaluatedPrimaryCount = 0
    for primary in primaries {
      let primaryRoot = SIMD3<Float>(
        primary.currentPositionAndLength.x,
        primary.currentPositionAndLength.y,
        primary.currentPositionAndLength.z
      )
      let primaryDirection = SIMD3<Float>(
        primary.currentDirectionAndRachis.x,
        primary.currentDirectionAndRachis.y,
        primary.currentDirectionAndRachis.z
      )
      let primaryTip =
        primaryRoot + primary.currentPositionAndLength.w * primaryDirection
      let tailAxial = simd_dot(primaryTip - tailRoot, tailDirection) / tailLength
      guard tailAxial > 0.15 && tailAxial < 0.92 else { continue }
      evaluatedPrimaryCount += 1
      let rectrixProfile = CrowRectrixVaneAnatomy.profile(
        packedIdentity: lateralRectrix.identity.w
      )!
      let outwardSignedWidth: Float = side * tailWidthAxis.y >= 0 ? 1 : -1
      let tailHalfWidth = CrowRectrixVaneAnatomy.halfWidthMeters(
        maximumWidthMeters: lateralRectrix.previousPositionAndWidth.w,
        axial: tailAxial,
        signedWidth: outwardSignedWidth,
        profile: rectrixProfile
      )
      let tailCenter =
        tailRoot + tailLength * tailAxial * tailDirection
        + orthogonalTailNormal
        * (lateralRectrix.previousDirectionAndCamber.w
          * CrowRectrixVaneAnatomy.camberEnvelope(
            axial: tailAxial,
            profile: rectrixProfile
          ))
      let lateralTailEdge =
        side * tailCenter.y + abs(tailWidthAxis.y) * tailHalfWidth
      #expect(side * primaryTip.y < lateralTailEdge - 0.0005)
      let primaryOrder = (primary.identity.w >> 16) & 255
      if primaryOrder >= 7 {
        #expect(side * primaryTip.y < lateralTailEdge - 0.002)
      }
      #expect(abs(primaryTip.z - tailCenter.z) < 0.0045)
    }
    #expect(evaluatedPrimaryCount >= 6)
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
    #expect(abs(leftRear.rootOffset.y - leftFront.rootOffset.y) < 1e-7)
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

  let anteriorPrimaryTipOffset = CrowFoldedWingAnatomy
    .primaryTipLateralOffsetMeters(fraction: 0)
  let posteriorPrimaryTipOffset = CrowFoldedWingAnatomy
    .primaryTipLateralOffsetMeters(fraction: 1)
  let anteriorSecondaryTipOffset = CrowFoldedWingAnatomy
    .secondaryTipLateralOffsetMeters(fraction: 0)
  let posteriorSecondaryTipOffset = CrowFoldedWingAnatomy
    .secondaryTipLateralOffsetMeters(fraction: 1)
  #expect(abs(CrowFoldedWingAnatomy.primaryRootLateralOffsetMeters - 0.042) < 1e-7)
  #expect(abs(anteriorPrimaryTipOffset - 0.003) < 1e-7)
  #expect(abs(posteriorPrimaryTipOffset - 0.001) < 1e-7)
  #expect(abs(anteriorSecondaryTipOffset - 0.027) < 1e-7)
  #expect(abs(posteriorSecondaryTipOffset - 0.029) < 1e-7)
  #expect(posteriorSecondaryTipOffset - posteriorPrimaryTipOffset <= 0.0281)
  #expect(
    CrowFoldedWingAnatomy.primaryTipLateralOffsetMeters(fraction: 7.0 / 9.0)
      < 0.0024
  )
  #expect(
    CrowFoldedWingAnatomy.primaryTipLateralOffsetMeters(fraction: 8.0 / 9.0)
      < 0.0018
  )

  let centerTail = CrowFoldedWingAnatomy.pose(
    featherClass: 3,
    side: 0,
    fraction: 0.5
  )
  let edgeTail = CrowFoldedWingAnatomy.pose(
    featherClass: 3,
    side: 0,
    fraction: 0
  )
  #expect(centerTail.rootOffset.z > 0.006)
  #expect(edgeTail.rootOffset.z >= 0.002)
  #expect(abs(edgeTail.rootOffset.y) >= 0.0059)
  #expect(centerTail.direction.z < 0)
  let tailLength: Float = 0.166
  let centerTailTip = centerTail.rootOffset + tailLength * centerTail.direction
  let edgeTailTip = edgeTail.rootOffset + tailLength * edgeTail.direction
  #expect(abs(centerTailTip.y) < 1e-6)
  #expect(abs(edgeTailTip.y) <= 0.0061)
  #expect(abs(centerTailTip.z + 0.025) < 1e-5)
  #expect(abs(edgeTailTip.z + 0.031) < 1e-5)
}

@Test("takeoff unfolds retained rectrices on Metal while remiges collapse")
func takeoffRetainedRectricesMatchMetalReference() throws {
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
  let deformer = try CrowTakeoffFeatherRootDeformer(
    backend: backend,
    asset: asset,
    referenceBodyCenter: bodyCenter
  )
  #expect(MemoryLayout<CrowTakeoffFeatherBlendUniforms>.stride == 48)
  #expect(deformer.featherCount == 54)

  for phases: (Float, Float) in [(0, 0), (0.36, 0.34), (0.56, 0.54), (1, 0.98)] {
    guard let commandBuffer = backend.queue.makeCommandBuffer() else {
      Issue.record("unable to allocate takeoff crow command buffer")
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
      #expect(
        simd_length(gpu.currentPositionAndLength - cpu.currentPositionAndLength)
          < 4e-7
      )
      #expect(
        simd_length(gpu.previousPositionAndWidth - cpu.previousPositionAndWidth)
          < 4e-7
      )
      #expect(
        simd_length(gpu.currentDirectionAndRachis - cpu.currentDirectionAndRachis)
          < 4e-6
      )
      #expect(
        simd_length(gpu.previousDirectionAndCamber - cpu.previousDirectionAndCamber)
          < 4e-6
      )
      #expect(
        simd_length(gpu.currentNormalAndPadding - cpu.currentNormalAndPadding)
          < 4e-6
      )
      #expect(
        simd_length(gpu.previousNormalAndPadding - cpu.previousNormalAndPadding)
          < 4e-6
      )
      #expect(gpu.identity == cpu.identity)
    }
  }

  let held = deformer.referenceStates(currentPhase: 0, previousPhase: 0)
  let flight = deformer.referenceStates(currentPhase: 1, previousPhase: 1)
  let heldRectrices = held.filter { $0.identity.w & 255 == 3 }
  let flightRectrices = flight.filter { $0.identity.w & 255 == 3 }
  #expect(heldRectrices.count == 12)
  #expect(flightRectrices.count == 12)
  #expect(
    zip(heldRectrices, flightRectrices).allSatisfy {
      $0.currentPositionAndLength.w == $1.currentPositionAndLength.w
        && $0.previousPositionAndWidth.w == $1.previousPositionAndWidth.w
        && $0.currentDirectionAndRachis.w == $1.currentDirectionAndRachis.w
        && $0.previousDirectionAndCamber.w == $1.previousDirectionAndCamber.w
    }
  )
  #expect(
    zip(heldRectrices, flightRectrices).contains {
      simd_length(
        SIMD3<Float>(
          $0.currentPositionAndLength.x,
          $0.currentPositionAndLength.y,
          $0.currentPositionAndLength.z
        ) - SIMD3<Float>(
          $1.currentPositionAndLength.x,
          $1.currentPositionAndLength.y,
          $1.currentPositionAndLength.z
        )
      ) > 0.02
    }
  )
  let flightTips = flightRectrices.map {
    SIMD3<Float>(
      $0.currentPositionAndLength.x,
      $0.currentPositionAndLength.y,
      $0.currentPositionAndLength.z
    ) + $0.currentPositionAndLength.w * SIMD3<Float>(
      $0.currentDirectionAndRachis.x,
      $0.currentDirectionAndRachis.y,
      $0.currentDirectionAndRachis.z
    )
  }
  #expect(flightTips.map(\.y).max()! - flightTips.map(\.y).min()! > 0.125)

  let collapsedRemiges = flight.filter {
    let featherClass = $0.identity.w & 255
    return featherClass == 1 || featherClass == 2
  }
  #expect(collapsedRemiges.count == 42)
  #expect(collapsedRemiges.allSatisfy {
    $0.currentPositionAndLength.w == 0
      && $0.previousPositionAndWidth.w == 0
      && $0.currentDirectionAndRachis.w == 0
      && $0.previousDirectionAndCamber.w == 0
  })
}
