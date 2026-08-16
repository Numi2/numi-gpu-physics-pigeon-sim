import simd

struct CrowFoldedFlightCovertSample: Equatable {
  let side: Float
  let featherClass: UInt32
  let order: Int
  let count: Int
  let flightRootOffset: SIMD3<Float>
  let flightDirection: SIMD3<Float>
  let flightLengthMeters: Float
  let rootOffset: SIMD3<Float>
  let tipOffset: SIMD3<Float>
  let planeNormal: SIMD3<Float>
  let rootWidthMeters: Float
  let maximumWidthMeters: Float
  let camberMeters: Float
  let vaneAsymmetry: Float
  let edgeRippleAmplitude: Float
  let edgeRipplePhase: Float
  let materialVariation: Float
}

/// Greater coverts tied to each persistent folded primary and secondary.
///
/// The dense body shell owns lesser and median covert coverage. This final
/// rank begins over the same stable flight-feather roots used by the standing
/// Metal pose and overlaps their proximal vanes, preventing a background slit
/// between body plumage and the retained remiges from oblique rear cameras.
enum CrowFoldedFlightCoverts {
  static let primaryCount = 10
  static let secondaryCount = 11
  static let rootClearanceMeters: Float = 0.0010
  /// CPU-authored greater coverts use a dedicated packed class so the live
  /// crow material can keep their short overlapping vanes rougher than the
  /// exposed remiges they bury.
  static let surfaceFeatherClass: UInt32 = 4

  /// Keep greater coverts inside the body-feather material band. Crossing the
  /// flight-feather boundary makes neighboring coverts acquire inconsistent
  /// remex highlights from identity variation alone.
  static func materialValue(variation: Float) -> Float {
    0.18 + 0.006 * min(max(variation, -1), 1)
  }

  static func visibleSamples(
    projectedPixelsPerMeter: Float
  ) -> [CrowFoldedFlightCovertSample] {
    guard projectedPixelsPerMeter >= 1_400 else { return [] }
    return samples()
  }

  static func samples() -> [CrowFoldedFlightCovertSample] {
    var result: [CrowFoldedFlightCovertSample] = []
    result.reserveCapacity(2 * (primaryCount + secondaryCount))
    for side: Float in [-1, 1] {
      appendSeries(
        featherClass: 1,
        count: primaryCount,
        side: side,
        to: &result
      )
      appendSeries(
        featherClass: 2,
        count: secondaryCount,
        side: side,
        to: &result
      )
    }
    return result
  }

  private static func appendSeries(
    featherClass: UInt32,
    count: Int,
    side: Float,
    to result: inout [CrowFoldedFlightCovertSample]
  ) {
    for order in 0..<count {
      let fraction = Float(order) / Float(max(count - 1, 1))
      let pose = CrowFoldedWingAnatomy.pose(
        featherClass: featherClass,
        side: side,
        fraction: fraction
      )
      let flightLength = interpolated(
        featherClass == 1 ? 0.155 : 0.112,
        featherClass == 1 ? 0.205 : 0.142,
        fraction
      )
      let flightWidth = interpolated(
        featherClass == 1 ? 0.020 : 0.021,
        featherClass == 1 ? 0.015 : 0.018,
        fraction
      )
      let shapeIdentity = identityVariation(
        featherClass: featherClass,
        order: order,
        salt: 0x85EB_CA6B
      )
      let edgeIdentity = identityVariation(
        featherClass: featherClass,
        order: order,
        salt: 0x68E3_1DA4
      )
      let materialIdentity = identityVariation(
        featherClass: featherClass,
        order: order,
        salt: 0xC2B2_AE35
      )
      let root =
        pose.rootOffset
        + rootClearanceMeters * pose.normal
        + SIMD3<Float>(0.006, 0, 0.0015)
      let coverageFraction =
        (featherClass == 1
          ? 0.36 + 0.06 * fraction
          : 0.42 + 0.05 * fraction)
        * (1 + 0.025 * shapeIdentity)
      let tip =
        pose.rootOffset
        + coverageFraction * flightLength * pose.direction
        + 0.0006 * pose.normal
      let maximumWidth =
        flightWidth * (featherClass == 1 ? 0.86 : 0.90)
        * (1 + 0.035 * shapeIdentity)
      result.append(
        CrowFoldedFlightCovertSample(
          side: side,
          featherClass: featherClass,
          order: order,
          count: count,
          flightRootOffset: pose.rootOffset,
          flightDirection: pose.direction,
          flightLengthMeters: flightLength,
          rootOffset: root,
          tipOffset: tip,
          planeNormal: pose.normal,
          rootWidthMeters: 0.56 * maximumWidth,
          maximumWidthMeters: maximumWidth,
          camberMeters: (0.0016 + 0.0005 * fraction)
            * (1 + 0.08 * shapeIdentity),
          vaneAsymmetry: 0.025 * shapeIdentity,
          edgeRippleAmplitude: 0.012 + 0.008 * abs(edgeIdentity),
          edgeRipplePhase: Float.pi * (edgeIdentity + 1),
          materialVariation: materialIdentity
        )
      )
    }
  }

  private static func interpolated(
    _ first: Float,
    _ last: Float,
    _ fraction: Float
  ) -> Float {
    first + (last - first) * fraction
  }

  private static func identityVariation(
    featherClass: UInt32,
    order: Int,
    salt: UInt32
  ) -> Float {
    var value = featherClass &* 0x9E37_79B9
    value ^= UInt32(truncatingIfNeeded: order) &* 0x85EB_CA6B
    value ^= salt
    value ^= value >> 16
    value &*= 0x7FEB_352D
    value ^= value >> 15
    value &*= 0x846C_A68B
    value ^= value >> 16
    return 2 * Float(value & 0x00FF_FFFF) / Float(0x00FF_FFFF) - 1
  }
}
