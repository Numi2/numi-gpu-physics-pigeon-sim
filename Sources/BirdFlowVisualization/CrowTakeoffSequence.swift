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

  struct FlightRectrixPose: Equatable {
    let rootOffset: SIMD3<Float>
    let tipOffset: SIMD3<Float>
    let direction: SIMD3<Float>
    let normal: SIMD3<Float>
  }

  static let standingHoldEnd: Float = 0.20
  static let transitionEnd: Float = 0.56
  static let foldedShellCollapseStartProgress: Float = 0.16
  static let foldedShellCollapseEndProgress: Float = 0.82
  /// Retained remiges collapse while the same retained rectrix records unfold.
  /// These values mirror `blendCrowTakeoffFeatherRoots` in Metal.
  static let retainedFeatherHandoffStartProgress: Float = 0.08
  static let retainedFeatherHandoffEndProgress: Float = 0.62
  static let terminalPrimaryHandoffMaximumLateralOffsetMeters: Float = 0.004
  static let terminalPrimaryHandoffStartProgress: Float = 0.004
  static let terminalPrimaryHandoffPeakProgress: Float = 0.018
  static let terminalPrimaryHandoffReleaseStartProgress: Float = 0.045
  static let terminalPrimaryHandoffEndProgress: Float = 0.080

  /// Briefly carries the terminal primary toward the deploying caudal covert
  /// shell after the standing hold. The retained vane returns to its normal
  /// live-flight course before free articulation; bilateral roots and feather
  /// identity remain unchanged.
  static func terminalPrimaryHandoffLateralOffsetMeters(
    featherClass: UInt32,
    order: Int,
    count: Int,
    transitionProgress: Float
  ) -> Float {
    guard featherClass == 1, count > 0, order == count - 1 else { return 0 }
    let rise = smootherstep(
      min(
        max(
          (transitionProgress - terminalPrimaryHandoffStartProgress)
            / (terminalPrimaryHandoffPeakProgress
              - terminalPrimaryHandoffStartProgress),
          0
        ),
        1
      )
    )
    let release = smootherstep(
      min(
        max(
          (transitionProgress - terminalPrimaryHandoffReleaseStartProgress)
            / (terminalPrimaryHandoffEndProgress
              - terminalPrimaryHandoffReleaseStartProgress),
          0
        ),
        1
      )
    )
    return terminalPrimaryHandoffMaximumLateralOffsetMeters
      * rise * (1 - release)
  }

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

  /// Collapses the body-seated folded-wing shell as the live wing deploys.
  ///
  /// Geometry records are retained at zero area after the handoff so current
  /// and previous takeoff meshes keep identical topology. This is an estimated
  /// presentation transition rather than feather-level deployment dynamics.
  static func foldedShellScale(transitionProgress: Float) -> Float {
    let normalized = min(
      max(
        (transitionProgress - foldedShellCollapseStartProgress)
          / (foldedShellCollapseEndProgress
            - foldedShellCollapseStartProgress),
        0
      ),
      1
    )
    return 1 - smootherstep(normalized)
  }

  /// Complement of the retained folded-remex visibility used by Metal.
  /// Rectrices remain full-sized and interpolate from their closed stack to
  /// their open-flight fan; this weight controls pose, never raster blending.
  static func liveRectrixDeploymentWeight(
    transitionProgress: Float
  ) -> Float {
    let normalized = min(
      max(
        (transitionProgress - retainedFeatherHandoffStartProgress)
          / (retainedFeatherHandoffEndProgress
            - retainedFeatherHandoffStartProgress),
        0
      ),
      1
    )
    return normalized * normalized * (3 - 2 * normalized)
  }

  /// Topology-stable target for one retained rectrix during takeoff.
  static func transitionRectrixPose(
    order: Int,
    count: Int,
    transitionProgress: Float
  ) -> FlightRectrixPose {
    let deployment = liveRectrixDeploymentWeight(
      transitionProgress: transitionProgress
    )
    let fraction = Float(order) / Float(max(count - 1, 1))
    let closed = CrowClosedTailAnatomy.pose(fraction: fraction)
    if deployment <= 0 {
      return FlightRectrixPose(
        rootOffset: closed.rootOffset,
        tipOffset: closed.tipOffset,
        direction: closed.direction,
        normal: closed.normal
      )
    }
    let flight = flightRectrixPose(order: order, count: count)
    if deployment >= 1 { return flight }
    let root = mix(closed.rootOffset, flight.rootOffset, deployment)
    let tip = mix(closed.tipOffset, flight.tipOffset, deployment)
    return FlightRectrixPose(
      rootOffset: root,
      tipOffset: tip,
      direction: safeNormalize(tip - root, fallback: closed.direction),
      normal: safeNormalize(
        mix(closed.normal, flight.normal, deployment),
        fallback: closed.normal
      )
    )
  }

  /// Open-flight target for one presentation rectrix. Centralizing the fan
  /// geometry keeps the CPU vane course, coverage tests, and future retained
  /// topology handoff on one deterministic anatomical contract.
  static func flightRectrixPose(order: Int, count: Int) -> FlightRectrixPose {
    let boundedCount = max(count, 1)
    let fraction = Float(order) / Float(max(boundedCount - 1, 1))
    let lateral = (fraction - 0.5) * 0.145
    let central = 1 - abs(2 * fraction - 1)
    let rootOffset = SIMD3<Float>(
      -0.125,
      lateral * 0.24,
      0.005 + 0.006 * central
    )
    let tipOffset =
      SIMD3<Float>(-0.125, 0, 0.005)
      + SIMD3<Float>(-0.190, 0, -0.018) * (0.96 + 0.02 * central)
      + SIMD3<Float>(
        -0.002 * central,
        lateral,
        (fraction - 0.5) * 0.036 - 0.003 * abs(2 * fraction - 1)
      )
    return FlightRectrixPose(
      rootOffset: rootOffset,
      tipOffset: tipOffset,
      direction: safeNormalize(
        tipOffset - rootOffset,
        fallback: SIMD3<Float>(-1, 0, 0)
      ),
      normal: safeNormalize(
        SIMD3<Float>(0, -1, 0.12),
        fallback: SIMD3<Float>(0, -1, 0)
      )
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

  private static func safeNormalize(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-12 ? value / length : fallback
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
