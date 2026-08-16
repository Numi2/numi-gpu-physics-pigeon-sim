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
      let length = 0.155 + 0.050 * fraction
      rootOffset = SIMD3<Float>(
        0.040 - 0.132 * fraction,
        side * 0.050,
        0.032 - 0.024 * fraction
      )
      let lateralDirection = side * (0.026 + 0.003 * fraction - 0.050) / length
      let verticalDirection = (-0.018 - 0.010 * fraction - rootOffset.z) / length
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
    default:
      let lateral = (fraction - 0.5) * 0.012
      rootOffset = SIMD3<Float>(
        -0.154 + 0.003 * abs(2 * fraction - 1),
        lateral,
        0.006 - 0.003 * abs(2 * fraction - 1)
      )
      let length: Float = 0.166
      let targetLateral = (fraction - 0.5) * 0.012
      let lateralDirection = (targetLateral - lateral) / length
      let verticalDirection = (-0.055 - rootOffset.z) / length
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
        SIMD3<Float>(0.04, 0.20 * lateral, 1),
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
