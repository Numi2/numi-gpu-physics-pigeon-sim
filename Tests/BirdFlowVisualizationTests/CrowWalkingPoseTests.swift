import Testing
import simd
@testable import BirdFlowVisualization

@Test("estimated walk alternates support and plants toes in the implied world")
func walkingSupportAndSwing() {
  let phases: [Float] = [0.03, 0.08, 0.12]
  let tips = phases.map { phase in
    let pose = CrowStandingPose.sample(phase: phase, walking: true)
    return pose.leftFoot.digitTips.map { $0 + SIMD3<Float>(CrowWalkingPose.impliedBodyTravel(phase: phase), 0, 0) }
  }
  for index in 0..<4 {
    for sample in tips.dropFirst() { #expect(simd_distance(sample[index], tips[0][index]) < 1e-5) }
  }
  let swingPhase: Float = 0.20
  let pose = CrowStandingPose.sample(phase: swingPhase, walking: true)
  #expect(!CrowWalkingPose.isStance(phase: swingPhase, left: true))
  #expect(CrowWalkingPose.isStance(phase: swingPhase, left: false))
  #expect(pose.leftFoot.digitTips.allSatisfy { $0.z > pose.supportHeight + 0.01 })
  #expect(pose.rightFoot.digitTips.allSatisfy { abs($0.z - pose.supportHeight) < 1e-6 })
}

@Test("estimated walk stays continuous and preserves both leg lengths")
func walkingContinuityAndLegLengths() {
  for index in 0..<400 {
    let phase = Float(index) / 400
    let quiet = CrowStandingPose.sample(phase: phase)
    let walk = CrowStandingPose.sample(phase: phase, walking: true)
    for (base, foot) in [(quiet.leftFoot, walk.leftFoot), (quiet.rightFoot, walk.rightFoot)] {
      #expect(abs(simd_distance(foot.hip, foot.hock) - simd_distance(base.hip, base.hock)) < 1e-5)
      #expect(abs(simd_distance(foot.hock, foot.ankle) - simd_distance(base.hock, base.ankle)) < 1e-5)
      #expect(foot.digits.allSatisfy { $0.nodes.first == foot.ankle })
      #expect(foot.digitTips.allSatisfy { $0.z >= walk.supportHeight - 1e-6 })
    }
  }
  for phase: Float in [0.155, 0.25, 0.5, 1] {
    let before = CrowStandingPose.sample(phase: phase - 0.00001, walking: true)
    let after = CrowStandingPose.sample(phase: phase + 0.00001, walking: true)
    #expect(simd_distance(before.leftFoot.ankle, after.leftFoot.ankle) < 0.0001)
    #expect(simd_distance(before.rightFoot.ankle, after.rightFoot.ankle) < 0.0001)
    #expect(simd_distance(before.bodyCenter, after.bodyCenter) < 0.0001)
  }
}
