import simd

struct CrowRumpTailUnderlayerSegment: Equatable {
  let startOffset: SIMD3<Float>
  let endOffset: SIMD3<Float>
  let startRadiusMeters: Float
  let endRadiusMeters: Float
}

/// Soft underplumage volume beneath the upper- and undertail covert shells.
/// It begins inside the pelvic loft and narrows around the closed rectrix roots,
/// preventing rear cameras from seeing background through their insertion.
enum CrowRumpTailUnderlayer {
  static func segment() -> CrowRumpTailUnderlayerSegment {
    let centerRectrix = CrowClosedTailAnatomy.pose(fraction: 0.5)
    return CrowRumpTailUnderlayerSegment(
      startOffset: SIMD3<Float>(-0.124, 0, -0.002),
      endOffset: centerRectrix.rootOffset + 0.043 * centerRectrix.direction,
      startRadiusMeters: 0.030,
      endRadiusMeters: 0.0135
    )
  }
}
