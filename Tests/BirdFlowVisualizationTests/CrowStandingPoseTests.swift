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
    for foot in [sample.leftFoot, sample.rightFoot] {
      let orderedDigits = foot.digits.sorted { $0.digitNumber < $1.digitNumber }
      #expect(orderedDigits.map(\.phalangealSegmentCount) == [2, 3, 4, 5])
      #expect(orderedDigits.map(\.digitNumber) == [1, 2, 3, 4])
      for digit in orderedDigits {
        #expect(digit.nodes.first == foot.ankle)
        #expect(digit.nodes.allSatisfy { $0.z >= sample.supportHeight })
        #expect(
          zip(digit.nodes, digit.nodes.dropFirst()).allSatisfy {
            simd_distance($0, $1) > 0.002
          }
        )
      }
    }
    for tip in sample.leftFoot.digitTips + sample.rightFoot.digitTips {
      #expect(abs(tip.z - sample.supportHeight) < 1e-7)
    }
    #expect(sample.leftFoot.ankle.y > 0)
    #expect(sample.rightFoot.ankle.y < 0)
    #expect(sample.leftFoot.digitTips[1].x > sample.leftFoot.ankle.x)
    #expect(sample.leftFoot.digitTips[3].x < sample.leftFoot.ankle.x)
    #expect(sample.rightFoot.digitTips[1].x > sample.rightFoot.ankle.x)
    #expect(sample.rightFoot.digitTips[3].x < sample.rightFoot.ankle.x)
    #expect(
      abs(
        simd_distance(sample.leftFoot.hock, sample.leftFoot.ankle)
          - CrowStandingPose.tarsusLengthMeters
      ) < 1e-6
    )
    #expect(
      abs(
        simd_distance(sample.rightFoot.hock, sample.rightFoot.ankle)
          - CrowStandingPose.tarsusLengthMeters
      ) < 1e-6
    )
    #expect(sample.bodyCenter.z - sample.supportHeight < 0.175)

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

  for digitIndex in 0..<4 {
    let leftTipTravel = samples.map {
      simd_distance(
        $0.leftFoot.digitTips[digitIndex],
        samples[0].leftFoot.digitTips[digitIndex]
      )
    }.max()!
    let rightTipTravel = samples.map {
      simd_distance(
        $0.rightFoot.digitTips[digitIndex],
        samples[0].rightFoot.digitTips[digitIndex]
      )
    }.max()!
    #expect(leftTipTravel < 1e-8)
    #expect(rightTipTravel < 1e-8)
  }
}
