import simd

/// Estimated follow-camera walk. Foot paths are relative to a body advancing
/// at a constant implied speed; this does not change a Numi physics state.
enum CrowWalkingPose {
  static let cyclesPerPresentation: Float = 4
  static let stanceFraction: Float = 0.62
  static let stanceTravelMeters: Float = 0.050
  static let swingClearanceMeters: Float = 0.020

  static func cycle(_ phase: Float) -> Float {
    let p = phase * cyclesPerPresentation
    return p - floor(p)
  }

  static func bodyOffset(phase: Float) -> SIMD3<Float> {
    let angle = 2 * Float.pi * cycle(phase)
    return SIMD3<Float>(
      0.0015 * sin(2 * angle),
      0.0035 * sin(angle),
      -0.014 + 0.0025 * cos(2 * angle)
    )
  }

  static func impliedBodyTravel(phase: Float) -> Float {
    phase * cyclesPerPresentation * stanceTravelMeters / stanceFraction
  }

  static func legPhase(phase: Float, left: Bool) -> Float {
    let p = phase * cyclesPerPresentation + (left ? 0 : 0.5)
    return p - floor(p)
  }

  static func isStance(phase: Float, left: Bool) -> Bool {
    legPhase(phase: phase, left: left) < stanceFraction
  }

  static func sample(base: CrowStandingPoseSample, phase: Float) -> CrowStandingPoseSample {
    let bodyMotion = bodyOffset(phase: phase)
    let angle = 2 * Float.pi * cycle(phase)
    let neck = CrowStandingNeckPose(
      translation: base.neckPose.translation + SIMD3<Float>(-0.003 * sin(angle), 0, 0),
      yawRadians: base.neckPose.yawRadians,
      pitchRadians: base.neckPose.pitchRadians - 0.012 * sin(angle),
      rollRadians: base.neckPose.rollRadians
    )
    return CrowStandingPoseSample(
      bodyCenter: base.bodyCenter + bodyMotion, neckPose: neck,
      supportHeight: base.supportHeight,
      leftFoot: foot(base.leftFoot, phase: phase, left: true, bodyMotion: bodyMotion),
      rightFoot: foot(base.rightFoot, phase: phase, left: false, bodyMotion: bodyMotion)
    )
  }

  private static func foot(
    _ base: CrowStandingFootPose, phase: Float, left: Bool, bodyMotion: SIMD3<Float>
  ) -> CrowStandingFootPose {
    let p = legPhase(phase: phase, left: left)
    let x: Float
    let lift: Float
    if p < stanceFraction {
      x = stanceTravelMeters * (0.5 - p / stanceFraction)
      lift = 0
    } else {
      let s = (p - stanceFraction) / (1 - stanceFraction)
      let s2 = s * s, s3 = s2 * s
      let tangent = -stanceTravelMeters * (1 - stanceFraction) / stanceFraction
      x = (2 * s3 - 3 * s2 + 1) * (-0.5 * stanceTravelMeters)
        + (s3 - 2 * s2 + s) * tangent
        + (-2 * s3 + 3 * s2) * (0.5 * stanceTravelMeters)
        + (s3 - s2) * tangent
      let height = sin(Float.pi * s)
      lift = swingClearanceMeters * height * height
    }
    let shift = SIMD3<Float>(x, 0, lift)
    let hip = base.hip + bodyMotion
    let ankle = base.ankle + shift
    // Two-link inverse kinematics preserves both visible segment lengths.
    // The selected stride and lowered posture are kept within reach by tests.
    let upperLength = simd_distance(base.hip, base.hock)
    let lowerLength = simd_distance(base.hock, base.ankle)
    let axis = ankle - hip
    let distance = simd_length(axis)
    let direction = axis / max(distance, 1e-6)
    let projection = (upperLength * upperLength - lowerLength * lowerLength
      + distance * distance) / max(2 * distance, 1e-6)
    let bend = sqrt(max(upperLength * upperLength - projection * projection, 0))
    let prior = base.hock - base.hip
    let perpendicular = prior - simd_dot(prior, direction) * direction
    let bendDirection = simd_normalize(perpendicular)
    let hock = hip + projection * direction + bend * bendDirection
    let digits = base.digits.map { digit in
      CrowStandingDigitPose(digitNumber: digit.digitNumber, nodes:
        digit.nodes.enumerated().map { index, node in
          let f = Float(index) / Float(max(digit.nodes.count - 1, 1))
          return node + shift + SIMD3<Float>(0, 0, 0.12 * lift * sin(Float.pi * f))
        })
    }
    return CrowStandingFootPose(hip: hip, hock: hock, ankle: ankle, digits: digits)
  }
}
