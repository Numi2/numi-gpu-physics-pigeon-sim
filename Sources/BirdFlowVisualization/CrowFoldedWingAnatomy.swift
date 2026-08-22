import simd

struct CrowFoldedFeatherPose: Equatable {
  let rootOffset: SIMD3<Float>
  let direction: SIMD3<Float>
  let normal: SIMD3<Float>
}

/// Estimated rest envelope for persistent flight feathers in a grounded pose.
///
/// Primaries and secondaries occupy distinct, slightly fanned layers over the
/// flank. This avoids collapsing every vane into one planar slab while keeping
/// the retained feather lengths and stable identities from the reality asset.
enum CrowFoldedWingAnatomy {
  static let anteriorPrimaryRootLateralOffsetMeters: Float = 0.042
  static let posteriorPrimaryRootInsetMeters: Float = 0.0024
  static let primaryStackSurfaceLiftMaximumMeters: Float = 0.0022

  static func pose(
    featherClass: UInt32,
    side: Float,
    fraction rawFraction: Float
  ) -> CrowFoldedFeatherPose {
    let fraction = min(max(rawFraction, 0), 1)
    let rootOffset: SIMD3<Float>
    let direction: SIMD3<Float>
    let normal: SIMD3<Float>
    switch featherClass {
    case 1:
      let length = 0.155 + 0.050 * fraction
      let stackSurfaceLift = primaryStackSurfaceLiftMeters(fraction: fraction)
      let rootLateralOffset = primaryRootLateralOffsetMeters(fraction: fraction)
        + stackSurfaceLift
      rootOffset = SIMD3<Float>(
        0.040 - 0.132 * fraction,
        side * rootLateralOffset,
        0.032 - 0.024 * fraction
      )
      let lateralDirection =
        side
        * (primaryTipLateralOffsetMeters(fraction: fraction) + stackSurfaceLift
          - rootLateralOffset)
        / length
      let tipHeight = -0.068 * fraction * fraction + 0.062 * fraction - 0.018
      let verticalDirection = (tipHeight - rootOffset.z) / length
      direction = safeNormalize(
        SIMD3<Float>(
          -sqrt(
            max(
              0,
              1 - lateralDirection * lateralDirection
                - verticalDirection * verticalDirection)),
          lateralDirection,
          verticalDirection
        ),
        fallback: SIMD3<Float>(-1, 0, 0)
      )
      normal = safeNormalize(
        SIMD3<Float>(
          0.030,
          side,
          0.20 + 0.08 * fraction + primaryStackNormalLift(fraction: fraction)
        ),
        fallback: SIMD3<Float>(0, side, 0)
      )
    case 2:
      let length = 0.112 + 0.030 * fraction
      rootOffset = SIMD3<Float>(
        0.082 - 0.142 * fraction,
        side * 0.047,
        0.044 - 0.024 * fraction
      )
      let lateralDirection =
        side * (secondaryTipLateralOffsetMeters(fraction: fraction) - 0.047)
        / length
      let verticalDirection = (-0.012 * fraction - rootOffset.z) / length
      direction = safeNormalize(
        SIMD3<Float>(
          -sqrt(
            max(
              0,
              1 - lateralDirection * lateralDirection
                - verticalDirection * verticalDirection)),
          lateralDirection,
          verticalDirection
        ),
        fallback: SIMD3<Float>(-1, 0, 0)
      )
      normal = safeNormalize(
        SIMD3<Float>(0.025, side, 0.24 + 0.06 * fraction),
        fallback: SIMD3<Float>(0, side, 0)
      )
    case 3:
      let tail = CrowClosedTailAnatomy.pose(fraction: fraction)
      rootOffset = tail.rootOffset
      direction = tail.direction
      normal = tail.normal
    default:
      rootOffset = SIMD3<Float>(-0.138, 0, 0)
      direction = safeNormalize(
        SIMD3<Float>(-1, 0, -0.02),
        fallback: SIMD3<Float>(-1, 0, 0)
      )
      normal = SIMD3<Float>(0, 0, 1)
    }
    return CrowFoldedFeatherPose(
      rootOffset: rootOffset,
      direction: direction,
      normal: normal
    )
  }

  /// Primaries settle medially over the outer rectrix, with posterior vanes
  /// carrying a little farther inward to preserve overlap through their taper.
  static func primaryRootLateralOffsetMeters(
    fraction rawFraction: Float
  ) -> Float {
    let fraction = min(max(rawFraction, 0), 1)
    return anteriorPrimaryRootLateralOffsetMeters
      - posteriorPrimaryRootInsetMeters * fraction * fraction * fraction
  }

  static func primaryTipLateralOffsetMeters(fraction rawFraction: Float) -> Float {
    let fraction = min(max(rawFraction, 0), 1)
    return 0.003 + 0.001 * fraction - 0.003 * fraction * fraction * fraction
  }

  /// Redistributes the standing primary stack away from a single terminal
  /// plate. Intermediate posterior vanes retain more exposed overlap while
  /// the already broadened terminal vane gives back a bounded twelve percent.
  /// Flight morphology remains unchanged.
  static func primaryStandingWidthScale(fraction rawFraction: Float) -> Float {
    let fraction = min(max(rawFraction, 0), 1)
    let exposureCoordinate = min(max((fraction - 0.58) / 0.42, 0), 1)
    let exposure = sin(Float.pi * exposureCoordinate)
    let intermediateScale = 1 + 0.12 * exposure * exposure
    let terminalCoordinate = min(max((fraction - 0.88) / 0.12, 0), 1)
    let terminalWeight = terminalCoordinate * terminalCoordinate
      * (3 - 2 * terminalCoordinate)
    return intermediateScale * (1 - 0.12 * terminalWeight)
  }

  /// Seats intermediate primaries just above their wider terminal neighbour.
  /// Both root and tip receive the same bilateral translation, preserving each
  /// feather's direction while leaving terminal handoff endpoints fixed.
  static func primaryStackSurfaceLiftMeters(fraction rawFraction: Float) -> Float {
    let fraction = min(max(rawFraction, 0), 1)
    let posterior = min(max((fraction - 0.55) / 0.45, 0), 1)
    let envelope = sin(Float.pi * posterior)
    return primaryStackSurfaceLiftMaximumMeters * envelope * envelope
  }

  /// Raises the intermediate primary crowns between fixed roots and tips so
  /// their exposed overlap edges remain distinct from the terminal vane.
  static func primaryStackNormalLift(fraction rawFraction: Float) -> Float {
    let fraction = min(max(rawFraction, 0), 1)
    let envelope = sin(Float.pi * fraction)
    return 0.18 * envelope * envelope
  }

  /// Posterior secondaries settle inward over the terminal primary instead of
  /// leaving the two folded remex series edge-to-edge at their distal taper.
  static func secondaryTipLateralOffsetMeters(
    fraction rawFraction: Float
  ) -> Float {
    let fraction = min(max(rawFraction, 0), 1)
    return 0.027 + 0.002 * fraction
      - 0.018 * pow(fraction, 6)
  }

  /// Only the posterior folded secondaries narrow toward the rectrix stack.
  /// The sixth-power envelope leaves the anterior course effectively exact
  /// while preventing one terminal vane from reading as a broad tail lobe in
  /// the reverse quarter. Flight morphology remains owned by the live wing.
  static func secondaryStandingWidthScale(
    fraction rawFraction: Float
  ) -> Float {
    let fraction = min(max(rawFraction, 0), 1)
    return 1 - 0.18 * pow(fraction, 6)
  }

  private static func safeNormalize(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let magnitude = simd_length(value)
    return magnitude > 1e-12 ? value / magnitude : fallback
  }
}
