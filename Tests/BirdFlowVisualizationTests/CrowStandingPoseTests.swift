import Testing
import simd

@testable import BirdFlowVisualization

@Test("standing crow keeps anisodactyl contacts planted under a millimetric sway")
func standingCrowPoseKeepsContactsPlanted() {
  let phases: [Float] = [0, 0.125, 0.25, 0.5, 0.875, 1]
  let samples = phases.map { CrowStandingPose.sample(phase: $0) }
  #expect(samples.first == samples.last)

  for sample in samples {
    #expect(sample.leftFoot.digitTips.count == 4)
    #expect(sample.rightFoot.digitTips.count == 4)
    for tip in sample.leftFoot.digitTips + sample.rightFoot.digitTips {
      #expect(abs(tip.z - sample.supportHeight) < 1e-7)
    }
    #expect(sample.leftFoot.ankle.y > 0)
    #expect(sample.rightFoot.ankle.y < 0)
    #expect(sample.leftFoot.digitTips[1].x > sample.leftFoot.ankle.x)
    #expect(sample.leftFoot.digitTips[3].x < sample.leftFoot.ankle.x)
    #expect(sample.rightFoot.digitTips[1].x > sample.rightFoot.ankle.x)
    #expect(sample.rightFoot.digitTips[3].x < sample.rightFoot.ankle.x)

    let supportMinimumY = min(
      sample.leftFoot.digitTips.map(\.y).min()!,
      sample.rightFoot.digitTips.map(\.y).min()!
    )
    let supportMaximumY = max(
      sample.leftFoot.digitTips.map(\.y).max()!,
      sample.rightFoot.digitTips.map(\.y).max()!
    )
    #expect(sample.bodyCenter.y > supportMinimumY)
    #expect(sample.bodyCenter.y < supportMaximumY)
    #expect(simd_length(sample.bodyCenter) < 0.003)
  }

  let ankleTravel = samples.map {
    simd_distance($0.leftFoot.ankle, samples[0].leftFoot.ankle)
  }.max()!
  #expect(ankleTravel > 0)
  #expect(ankleTravel < 0.0015)
}
