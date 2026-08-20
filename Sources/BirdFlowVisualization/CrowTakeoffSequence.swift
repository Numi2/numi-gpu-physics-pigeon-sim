import simd

/// Deterministic presentation timing for a grounded crow becoming airborne.
///
/// This is a geometric pose schedule, not an image-space transition. The same
/// body, leg, wing-surface, and persistent-feather identities are retained from
/// the quiet hold through wing deployment and the first sustained wingbeats.
enum CrowTakeoffSequence {
  /// Fixes takeoff tessellation above the full-density 720p feather threshold
  /// while the cinematic camera changes distance. Geometry topology therefore
  /// stays temporal-stable without dropping the held standing pose to coarse
  /// leg and body tracts.
  static let topologyLODReferenceCameraDistanceMeters: Float = 0.55

  struct Sample: Equatable {
    let standingPhase: Float
    let flightPhase: Float
    let transitionProgress: Float
    let flightProgress: Float
    let bodyTranslation: SIMD3<Float>
  }

  static let standingHoldEnd: Float = 0.20
  static let transitionEnd: Float = 0.56

  static func sample(phase: Float) -> Sample {
    let bounded = min(max(phase, 0), 1)
    let transition = smootherstep(
      min(max((bounded - standingHoldEnd) / (transitionEnd - standingHoldEnd), 0), 1)
    )
    let flight = min(max((bounded - transitionEnd) / (1 - transitionEnd), 0), 1)
    let standingPhase = 0.14 * min(bounded / standingHoldEnd, 1)
    let flightPhase = 0.25 + 0.30 * transition + 1.20 * flight
    let lift = 0.105 * transition + 0.075 * smootherstep(flight)
    let forward = 0.018 * transition + 0.050 * flight
    return Sample(
      standingPhase: standingPhase,
      flightPhase: flightPhase,
      transitionProgress: transition,
      flightProgress: flight,
      bodyTranslation: SIMD3<Float>(forward, 0, lift)
    )
  }

  static func standingPose(phase: Float) -> CrowStandingPoseSample {
    let sequence = sample(phase: phase)
    let planted = CrowStandingPose.sample(phase: sequence.standingPhase)
    let bodyCenter = planted.bodyCenter + sequence.bodyTranslation
    let retraction = smootherstep(
      min(max((sequence.transitionProgress - 0.28) / 0.72, 0), 1)
    )
    return CrowStandingPoseSample(
      bodyCenter: bodyCenter,
      neckPose: planted.neckPose,
      supportHeight: planted.supportHeight,
      leftFoot: retract(
        planted.leftFoot,
        bodyCenter: bodyCenter,
        side: 1,
        progress: retraction
      ),
      rightFoot: retract(
        planted.rightFoot,
        bodyCenter: bodyCenter,
        side: -1,
        progress: retraction
      )
    )
  }

  static func foldedWingPoint(
    spanIndex: Int,
    chordIndex: Int,
    left: Bool
  ) -> SIMD3<Float> {
    let span = Float(spanIndex) / Float(CrowFlightWingBodyIntegration.spanCount - 1)
    let chord = Float(chordIndex) / Float(CrowFlightWingBodyIntegration.chordCount - 1)
    let side: Float = left ? 1 : -1
    let root = CrowFlightWingBodyIntegration.bodyRoot(chordIndex: chordIndex, left: left)
    return SIMD3<Float>(
      root.x - 0.205 * span + 0.020 * chord * span,
      side * (0.040 + 0.010 * chord + 0.004 * sin(Float.pi * span)),
      root.z - 0.030 * span + 0.008 * chord
    )
  }

  static func mix(_ first: SIMD3<Float>, _ second: SIMD3<Float>, _ blend: Float)
    -> SIMD3<Float>
  {
    first + blend * (second - first)
  }

  private static func retract(
    _ foot: CrowStandingFootPose,
    bodyCenter: SIMD3<Float>,
    side: Float,
    progress: Float
  ) -> CrowStandingFootPose {
    let tuckedHip = bodyCenter + SIMD3<Float>(-0.025, side * 0.035, -0.060)
    let tuckedHock = bodyCenter + SIMD3<Float>(-0.055, side * 0.032, -0.052)
    let tuckedAnkle = bodyCenter + SIMD3<Float>(-0.078, side * 0.029, -0.072)
    let hock = mix(foot.hock, tuckedHock, progress)
    let ankle = mix(foot.ankle, tuckedAnkle, progress)
    let digits = foot.digits.map { digit in
      let targetTip = tuckedAnkle + SIMD3<Float>(-0.020, side * 0.004, 0.008)
      return CrowStandingDigitPose(
        digitNumber: digit.digitNumber,
        nodes: digit.nodes.enumerated().map { index, node in
          let fraction = Float(index) / Float(max(digit.nodes.count - 1, 1))
          let target = tuckedAnkle + fraction * (targetTip - tuckedAnkle)
          return mix(node, target, progress)
        }
      )
    }
    return CrowStandingFootPose(
      hip: mix(foot.hip, tuckedHip, min(progress * 1.35, 1)),
      hock: hock,
      ankle: ankle,
      digits: digits
    )
  }

  private static func smootherstep(_ value: Float) -> Float {
    value * value * value * (value * (value * 6 - 15) + 10)
  }
}
