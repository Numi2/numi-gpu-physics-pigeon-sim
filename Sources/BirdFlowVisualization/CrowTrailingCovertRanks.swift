import Foundation

/// Two overlapping anatomical ranks replace the single overlong trailing
/// covert sheet while retaining its accepted outer envelope.
///
/// At every axial station, the hidden bed retains the accepted width and at
/// least one exposed rank retains its complete 98%-inset margin. Rank-end taper
/// is therefore hidden beneath the neighboring rank instead of cutting a new
/// notch into the wing silhouette.
enum CrowTrailingCovertRanks {
  enum Rank: CaseIterable {
    case proximal
    case distal
  }

  struct Range: Equatable {
    let start: Float
    let end: Float
  }

  static let proximalRange = Range(start: 0, end: 0.72)
  static let distalRange = Range(start: 0.34, end: 1)
  static let distalFullCoverageFraction: Float = 0.44
  static let proximalTaperStartFraction: Float = 0.62
  static let rankSurfaceClearanceMeters: Float = 0.00002
  static let maximumLayerSeparationMeters: Float = 0.00016
  static let visibleRankWidthScale: Float = 0.98
  static let deploymentStartProgress: Float = 0.25
  static let deploymentEndProgress: Float = 0.85

  static func range(for rank: Rank) -> Range {
    switch rank {
    case .proximal: proximalRange
    case .distal: distalRange
    }
  }

  static func coverageWeight(rank: Rank, axialFraction: Float) -> Float {
    let fraction = min(max(axialFraction, 0), 1)
    switch rank {
    case .proximal:
      guard fraction <= proximalRange.end else { return 0 }
      return 1
        - smoothstep(
          (fraction - proximalTaperStartFraction)
            / (proximalRange.end - proximalTaperStartFraction)
        )
    case .distal:
      guard fraction >= distalRange.start else { return 0 }
      return smoothstep(
        (fraction - distalRange.start)
          / (distalFullCoverageFraction - distalRange.start)
      )
    }
  }

  /// Separates the distal rank only inside the shared overlap. Its exposed
  /// outer half returns to the common base clearance above the accepted bed.
  static func normalOffsetMeters(rank: Rank, axialFraction: Float) -> Float {
    guard rank == .distal else { return rankSurfaceClearanceMeters }
    let rise = smoothstep(
      (axialFraction - distalRange.start)
        / (distalFullCoverageFraction - distalRange.start)
    )
    let fall =
      1
      - smoothstep(
        (axialFraction - proximalTaperStartFraction)
          / (proximalRange.end - proximalTaperStartFraction)
      )
    return rankSurfaceClearanceMeters
      + maximumLayerSeparationMeters * rise * fall
  }

  static func deploymentWeight(transitionProgress: Float) -> Float {
    smoothstep(
      (transitionProgress - deploymentStartProgress)
        / (deploymentEndProgress - deploymentStartProgress)
    )
  }

  private static func smoothstep(_ value: Float) -> Float {
    let t = min(max(value, 0), 1)
    return t * t * (3 - 2 * t)
  }
}
