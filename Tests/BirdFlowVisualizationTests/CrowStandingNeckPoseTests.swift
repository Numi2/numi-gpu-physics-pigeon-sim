import Testing
import simd

@testable import BirdFlowVisualization

@Test("standing crow neck pose is loop closed and anatomically bounded")
func standingCrowNeckPoseIsLoopClosedAndBounded() {
  let samples = (0...64).map {
    CrowStandingPose.sample(phase: Float($0) / 64)
  }
  #expect(samples.first == samples.last)
  #expect(samples.allSatisfy { abs($0.neckPose.yawRadians) <= 0.0201 })
  #expect(samples.allSatisfy { abs($0.neckPose.pitchRadians) <= 0.0171 })
  #expect(samples.allSatisfy { abs($0.neckPose.rollRadians) <= 0.0071 })

  let headOffset = SIMD3<Float>(0.164, 0, 0.052)
  let displacement = samples.map {
    simd_distance($0.neckPose.transform(offset: headOffset, coupling: 1), headOffset)
  }.max()!
  #expect(displacement > 0.001)
  #expect(displacement < 0.006)
}

@Test("neck transform preserves rigid head distances and graded shoulder continuity")
func neckTransformPreservesHeadDistancesAndShoulderContinuity() {
  let pose = CrowStandingNeckPose(
    translation: SIMD3<Float>(0.0012, -0.0021, 0.0014),
    yawRadians: 0.019,
    pitchRadians: -0.015,
    rollRadians: 0.006
  )
  let billBase = SIMD3<Float>(0.202, 0, 0.051)
  let eye = SIMD3<Float>(0.186, 0.031, 0.063)
  let transformedBill = pose.transform(offset: billBase, coupling: 1)
  let transformedEye = pose.transform(offset: eye, coupling: 1)
  #expect(
    abs(simd_distance(transformedBill, transformedEye) - simd_distance(billBase, eye))
      < 1e-6
  )

  let shoulder = SIMD3<Float>(0.086, 0.030, 0.040)
  let middle = SIMD3<Float>(0.118, 0.028, 0.048)
  let cranial = SIMD3<Float>(0.148, 0.022, 0.052)
  let fixedShoulder = pose.transform(offset: shoulder, coupling: 0)
  let movedMiddle = pose.transform(offset: middle, coupling: 0.45)
  let movedCranial = pose.transform(offset: cranial, coupling: 0.88)
  #expect(simd_distance(fixedShoulder, shoulder) < 1e-8)
  #expect(simd_distance(movedMiddle, middle) > 0)
  #expect(simd_distance(movedCranial, cranial) > simd_distance(movedMiddle, middle))

  let normal = simd_normalize(SIMD3<Float>(0.2, 0.7, 0.4))
  #expect(abs(simd_length(pose.rotated(normal, coupling: 1)) - 1) < 1e-6)
}

@Test("head-neck coupling anchors the nape and reaches a rigid cranium")
func headNeckCouplingAnchorsNapeAndReachesRigidCranium() {
  let samples = (0...64).map { index in
    CrowHeadNeckBlend.coupling(
      axialOffsetMeters: 0.090 + 0.085 * Float(index) / 64
    )
  }
  #expect(samples.first == 0)
  #expect(samples.last == 1)
  #expect(zip(samples, samples.dropFirst()).allSatisfy { $0 <= $1 })
  #expect(
    abs(
      CrowHeadNeckBlend.coupling(axialOffsetMeters: 0.1305) - 0.5
    ) < 1e-6
  )

  let pose = CrowStandingNeckPose(
    translation: SIMD3<Float>(0.0015, -0.0024, 0.0017),
    yawRadians: 0.018,
    pitchRadians: -0.014,
    rollRadians: 0.006
  )
  let bodyCenter = SIMD3<Float>(0.001, -0.002, 0.0005)
  let nape = bodyCenter + SIMD3<Float>(0.100, 0.012, 0.050)
  let rigidCranium = bodyCenter + SIMD3<Float>(0.170, 0.012, 0.050)
  #expect(
    simd_distance(
      CrowHeadNeckBlend.position(
        nape,
        bodyCenter: bodyCenter,
        neckPose: pose
      ),
      nape
    ) < 1e-8
  )
  #expect(
    simd_distance(
      CrowHeadNeckBlend.position(
        rigidCranium,
        bodyCenter: bodyCenter,
        neckPose: pose
      ),
      bodyCenter
        + pose.transform(
          offset: rigidCranium - bodyCenter,
          coupling: 1
        )
    ) < 1e-8
  )

  let normal = simd_normalize(SIMD3<Float>(0.15, 0.70, 0.45))
  for axialOffset: Float in stride(from: 0.095, through: 0.170, by: 0.0025) {
    let position = bodyCenter + SIMD3<Float>(axialOffset, 0.012, 0.050)
    let transformed = CrowHeadNeckBlend.normal(
      normal,
      position: position,
      bodyCenter: bodyCenter,
      neckPose: pose
    )
    #expect(abs(simd_length(transformed) - 1) < 1e-6)
  }
  let anchoredNormal = CrowHeadNeckBlend.normal(
    normal,
    position: nape,
    bodyCenter: bodyCenter,
    neckPose: pose
  )
  #expect(simd_distance(anchoredNormal, normal) < 1e-5)
  let rigidNormal = CrowHeadNeckBlend.normal(
    normal,
    position: rigidCranium,
    bodyCenter: bodyCenter,
    neckPose: pose
  )
  #expect(simd_distance(rigidNormal, pose.rotated(normal, coupling: 1)) < 1e-4)
}
