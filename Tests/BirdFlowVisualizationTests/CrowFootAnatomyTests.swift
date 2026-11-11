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
          abs(($0.center.z - $0.heightRadiusMeters)
            - max(pose.supportHeight, digit.nodes[$0.jointIndex].z)) < 1e-7
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
          $0.parameters.w == Float(CrowFootAnatomy.surfaceIdentityClassCode)
        }
      )
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


@Test("crow lifted digit retains pads and claws")
func crowLiftedDigitRetainsPadsAndClaws() {
  let pose = CrowStandingPose.sample(phase: 0.37)
  for foot in [pose.leftFoot, pose.rightFoot] {
    for digit in foot.digits {
      let lift: Float = 0.15
      let lifted = CrowStandingDigitPose(
        digitNumber: digit.digitNumber,
        nodes: digit.nodes.map { $0 + SIMD3<Float>(0, 0, lift) }
      )
      let vertices = CrowFootAnatomy.vertices(
        digit: lifted, supportHeight: pose.supportHeight,
        keratinColor: .zero, padColor: .zero, clawColor: .zero
      )
      #expect(!vertices.isEmpty)
      #expect(vertices.allSatisfy {
        $0.position.z > pose.supportHeight + lift - 0.005
      })
    }
  }
}

@Test("lifted toe pads follow each individual phalanx")
func crowArchedDigitPadsFollowTheirJoints() {
  let digit = CrowStandingDigitPose(digitNumber: 1, nodes: [
    SIMD3(0, 0, 0), SIMD3(0.01, 0, 0.02),
    SIMD3(0.02, 0, 0.04), SIMD3(0.03, 0, 0.01),
  ])
  let pads = CrowFootAnatomy.plantarPads(digit: digit, supportHeight: 0)
  for pad in pads {
    #expect(abs(pad.center.z - pad.heightRadiusMeters - digit.nodes[pad.jointIndex].z) < 1e-6)
  }
}

@Test("distal toe motion preserves proximal mesh and rotates the distal mesh")
func crowDistalToeMeshFollowsRecordedJoint() {
  let digit = CrowStandingDigitPose(digitNumber: 2, nodes: [
    SIMD3(0, 0, 0.04), SIMD3(0.018, 0, 0.04), SIMD3(0.036, 0, 0.04),
  ])
  let angle: Float = 0.5
  let delta = CrowNumiReplay.LinkDelta(
    rotationXYZW: SIMD4(0, sin(angle / 2), 0, cos(angle / 2)), translation: .zero)
  let base = CrowFootAnatomy.vertices(digit: digit, supportHeight: 0,
    keratinColor: .zero, padColor: .zero, clawColor: .zero)
  let moved = CrowFootAnatomy.vertices(digit: digit, supportHeight: 0,
    keratinColor: .zero, padColor: .zero, clawColor: .zero,
    distalJointIndex: 1, distalDelta: delta, distalPivot: digit.nodes[1])
  #expect(base.count == moved.count)
  let firstSegmentVertexCount = CrowFootAnatomy.phalanxRadialSegments
    * (CrowFootAnatomy.phalanxAxialStations - 1) * 6
  #expect(firstSegmentVertexCount < base.count)
  #expect(zip(base.prefix(firstSegmentVertexCount), moved.prefix(firstSegmentVertexCount))
    .allSatisfy { simd_distance($0.position, $1.position) < 1e-7 })
  #expect(zip(base.dropFirst(firstSegmentVertexCount), moved.dropFirst(firstSegmentVertexCount))
    .contains { simd_distance($0.position, $1.position) > 1e-4 })
  #expect(moved.allSatisfy { $0.position.x.isFinite && $0.normal.x.isFinite })
}
