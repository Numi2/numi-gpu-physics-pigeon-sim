import Testing
import simd

@testable import BirdFlowVisualization

@Test("crow digital pads meet support under articulated phalanges")
func crowDigitalPadsMeetSupportUnderArticulatedPhalanges() {
  let pose = CrowStandingPose.sample(phase: 0.37)
  for foot in [pose.leftFoot, pose.rightFoot] {
    for digit in foot.digits {
      let pads = CrowFootAnatomy.plantarPads(
        digit: digit,
        supportHeight: pose.supportHeight
      )
      #expect(pads.count == digit.phalangealSegmentCount)
      #expect(
        pads.allSatisfy {
          abs(($0.center.z - $0.heightRadiusMeters) - pose.supportHeight) < 1e-7
            && $0.longitudinalRadiusMeters > $0.heightRadiusMeters
            && $0.lateralRadiusMeters > $0.heightRadiusMeters
        }
      )

      let vertices = CrowFootAnatomy.vertices(
        digit: digit,
        supportHeight: pose.supportHeight,
        keratinColor: SIMD4<Float>(0.048, 0.053, 0.061, 0.58),
        padColor: SIMD4<Float>(0.036, 0.040, 0.047, 0.62),
        clawColor: SIMD4<Float>(0.010, 0.012, 0.016, 0.64)
      )
      #expect(vertices.count > digit.phalangealSegmentCount * 180)
      #expect(
        vertices.allSatisfy {
          let position = SIMD3<Float>($0.position.x, $0.position.y, $0.position.z)
          let normal = SIMD3<Float>($0.normal.x, $0.normal.y, $0.normal.z)
          return position.x.isFinite && position.y.isFinite && position.z.isFinite
            && normal.x.isFinite && normal.y.isFinite && normal.z.isFinite
            && abs(simd_length(normal) - 1) < 1e-5
        }
      )
    }
  }
}
