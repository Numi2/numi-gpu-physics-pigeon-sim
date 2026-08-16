import simd

struct CrowClosedTailPose: Equatable {
  let radialFraction: Float
  let rootOffset: SIMD3<Float>
  let tipOffset: SIMD3<Float>
  let direction: SIMD3<Float>
  let normal: SIMD3<Float>
}

/// Estimated quiet-standing rectrix stack.
///
/// Medial rectrices sit dorsally and each successive lateral rectrix is
/// slightly lower, preserving visible feather identities without opening
/// background gaps. The two sides form a shallow tent rather than one
/// coplanar sheet. Dimensions remain presentation estimates.
enum CrowClosedTailAnatomy {
  static let rectrixCount = 12
  static let rectrixLengthMeters: Float = 0.166
  static let lateralSpanMeters: Float = 0.012
  static let rootLayerDepthMeters: Float = 0.004
  static let tipLayerDepthMeters: Float = 0.006

  static func pose(fraction rawFraction: Float) -> CrowClosedTailPose {
    let fraction = min(max(rawFraction, 0), 1)
    let centered = 2 * fraction - 1
    let radialFraction = abs(centered)
    let side: Float = centered == 0 ? 0 : (centered > 0 ? 1 : -1)
    let rootOffset = SIMD3<Float>(
      -0.154 + 0.003 * radialFraction,
      0.5 * lateralSpanMeters * centered,
      0.0065 - rootLayerDepthMeters * radialFraction
    )
    let tipOffset = SIMD3<Float>(
      0,
      rootOffset.y,
      -0.025 - tipLayerDepthMeters * radialFraction
    )
    let verticalDirection = (tipOffset.z - rootOffset.z) / rectrixLengthMeters
    let direction = normalized(
      SIMD3<Float>(
        -sqrt(max(0, 1 - verticalDirection * verticalDirection)),
        0,
        verticalDirection
      ),
      fallback: SIMD3<Float>(-1, 0, 0)
    )
    let resolvedTip = rootOffset + rectrixLengthMeters * direction
    let normal = normalized(
      SIMD3<Float>(
        0.04,
        side * (0.045 + 0.110 * radialFraction),
        1
      ),
      fallback: SIMD3<Float>(0, 0, 1)
    )
    return CrowClosedTailPose(
      radialFraction: radialFraction,
      rootOffset: rootOffset,
      tipOffset: SIMD3<Float>(resolvedTip.x, tipOffset.y, tipOffset.z),
      direction: direction,
      normal: normal
    )
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-12 ? value / length : fallback
  }
}
