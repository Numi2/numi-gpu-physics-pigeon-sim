import simd

struct CrowRumpTailUnderlayerSegment: Equatable {
  let startOffset: SIMD3<Float>
  let endOffset: SIMD3<Float>
  let startRadiusMeters: Float
  let endRadiusMeters: Float
}

struct CrowFoldedWingTailUnderlayerSegment: Equatable {
  let startOffset: SIMD3<Float>
  let endOffset: SIMD3<Float>
  let startRadiusMeters: Float
  let endRadiusMeters: Float
}

/// Soft underplumage volume beneath the upper- and undertail covert shells.
/// It begins inside the pelvic loft and narrows around the closed rectrix roots,
/// preventing rear cameras from seeing background through their insertion.
enum CrowRumpTailUnderlayer {
  static let foldedWingTailReleaseStartPhase: Float = 0.125
  static let foldedWingTailReleaseEndPhase: Float = 0.375

  static func segment() -> CrowRumpTailUnderlayerSegment {
    let centerRectrix = CrowClosedTailAnatomy.pose(fraction: 0.5)
    return CrowRumpTailUnderlayerSegment(
      startOffset: SIMD3<Float>(-0.124, 0, -0.002),
      endOffset: centerRectrix.rootOffset + 0.043 * centerRectrix.direction,
      startRadiusMeters: 0.030,
      endRadiusMeters: 0.0135
    )
  }

  /// A paired deep underplumage lobe runs from the rump volume into the folded
  /// outer rectrix/wing junction. It is entirely optical and collapses inside
  /// the rump before the distal wing articulates freely.
  static func foldedWingTailSegment(
    left: Bool
  ) -> CrowFoldedWingTailUnderlayerSegment {
    CrowFoldedWingTailUnderlayerSegment(
      startOffset: segment().endOffset,
      endOffset: SIMD3<Float>(-0.245, left ? 0.047 : -0.047, -0.031),
      startRadiusMeters: 0.008,
      endRadiusMeters: 0.008
    )
  }

  static func foldedWingTailWeight(presentationPhase: Float) -> Float {
    let progress = min(
      max(
        (presentationPhase - foldedWingTailReleaseStartPhase)
          / (foldedWingTailReleaseEndPhase - foldedWingTailReleaseStartPhase),
        0
      ),
      1
    )
    return 1
      - progress * progress * progress
        * (progress * (progress * 6 - 15) + 10)
  }
}
