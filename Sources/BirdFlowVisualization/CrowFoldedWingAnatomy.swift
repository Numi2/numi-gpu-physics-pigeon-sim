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
  static let primaryRootLateralOffsetMeters: Float = 0.042

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
      rootOffset = SIMD3<Float>(
        0.040 - 0.132 * fraction,
        side * primaryRootLateralOffsetMeters,
        0.032 - 0.024 * fraction
      )
      let lateralDirection =
        side
        * (primaryTipLateralOffsetMeters(fraction: fraction)
          - primaryRootLateralOffsetMeters)
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
        SIMD3<Float>(0.030, side, 0.20 + 0.08 * fraction),
        fallback: SIMD3<Float>(0, side, 0)
      )
    case 2:
      let length = 0.112 + 0.030 * fraction
      rootOffset = SIMD3<Float>(
        0.082 - 0.142 * fraction,
        side * 0.047,
        0.044 - 0.024 * fraction
      )
      let lateralDirection = side * (0.031 + 0.003 * fraction - 0.047) / length
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
  static func primaryTipLateralOffsetMeters(fraction rawFraction: Float) -> Float {
    let fraction = min(max(rawFraction, 0), 1)
    return 0.003 + 0.001 * fraction - 0.003 * fraction * fraction * fraction
  }

  private static func safeNormalize(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let magnitude = simd_length(value)
    return magnitude > 1e-12 ? value / magnitude : fallback
  }
}
