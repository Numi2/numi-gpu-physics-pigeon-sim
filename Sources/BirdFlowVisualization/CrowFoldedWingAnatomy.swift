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
      rootOffset = SIMD3<Float>(
        0.035 - 0.130 * fraction,
        side * (0.054 + 0.012 * fraction),
        0.030 - 0.035 * fraction
      )
      direction = safeNormalize(
        SIMD3<Float>(
          -0.989,
          -side * (0.0375 + 0.0575 * fraction),
          -0.1375 - 0.0125 * fraction
        ),
        fallback: SIMD3<Float>(-1, 0, 0)
      )
      normal = safeNormalize(
        SIMD3<Float>(0.030, side, 0.160 + 0.120 * fraction),
        fallback: SIMD3<Float>(0, side, 0)
      )
    case 2:
      rootOffset = SIMD3<Float>(
        0.082 - 0.142 * fraction,
        side * (0.053 + 0.009 * fraction),
        0.040 - 0.035 * fraction
      )
      direction = safeNormalize(
        SIMD3<Float>(
          -0.992,
          -side * (0.030 + 0.0365 * fraction),
          -0.105 - 0.035 * fraction
        ),
        fallback: SIMD3<Float>(-1, 0, 0)
      )
      normal = safeNormalize(
        SIMD3<Float>(0.025, side, 0.140 + 0.100 * fraction),
        fallback: SIMD3<Float>(0, side, 0)
      )
    default:
      let lateral = (fraction - 0.5) * 0.082
      rootOffset = SIMD3<Float>(-0.138, lateral * 0.18, -0.002)
      direction = safeNormalize(
        SIMD3<Float>(-0.999, lateral * 0.20, -0.018),
        fallback: SIMD3<Float>(-1, 0, 0)
      )
      normal = safeNormalize(
        SIMD3<Float>(0, 0.04 * side, 1),
        fallback: SIMD3<Float>(0, 0, 1)
      )
    }
    return CrowFoldedFeatherPose(
      rootOffset: rootOffset,
      direction: direction,
      normal: normal
    )
  }

  private static func safeNormalize(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let magnitude = simd_length(value)
    return magnitude > 1e-12 ? value / magnitude : fallback
  }
}
