import simd

/// Resolved rachis and aggregate barb groups for upper-tail coverts.
///
/// The vane remains the closed optical shell. These full-density segments make
/// the posterior rump-to-wing overlap read as interleaved feathers rather than
/// one broad dark patch when future-output coverage can resolve the structure.
enum CrowUppertailCovertDetail {
  static let barbPairCount = 3

  static func segments(
    for feather: CrowUppertailCovertSample,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    guard projectedPixelsPerMeter >= 1_400 else { return [] }
    let direction = normalized(
      feather.tipOffset - feather.rootOffset,
      fallback: SIMD3<Float>(-1, 0, 0)
    )
    let normal = normalized(
      feather.planeNormal
        - direction * simd_dot(feather.planeNormal, direction),
      fallback: feather.planeNormal
    )
    let widthAxis = normalized(
      simd_cross(normal, direction),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    func center(at fraction: Float) -> SIMD3<Float> {
      feather.rootOffset
        + fraction * (feather.tipOffset - feather.rootOffset)
        + normal * (feather.camberMeters * sin(Float.pi * fraction) + 0.00008)
    }
    func halfWidth(at fraction: Float) -> Float {
      let envelope = 0.36 + 0.64 * pow(max(sin(Float.pi * fraction), 0), 0.58)
      let tipTaper = 1 - 0.985 * pow(fraction, 3.15)
      return
        (feather.rootWidthMeters * (1 - fraction)
        + feather.maximumWidthMeters * fraction) * envelope * tipTaper
    }

    var result: [CrowFeatherMesostructureSegment] = []
    result.reserveCapacity(1 + 2 * barbPairCount)
    result.append(
      CrowFeatherMesostructureSegment(
        kind: .rachis,
        start: center(at: 0.18),
        end: center(at: 0.95),
        startRadiusMeters: 0.00018,
        endRadiusMeters: 0.000045
      )
    )
    for pair in 0..<barbPairCount {
      let axial = 0.32 + 0.18 * Float(pair)
      let reach = axial + 0.08
      for side: Float in [-1, 1] {
        result.append(
          CrowFeatherMesostructureSegment(
            kind: .edgeBarbGroup,
            start: center(at: axial) + normal * 0.00005,
            end: center(at: reach)
              + side * widthAxis * (halfWidth(at: reach) + 0.00035)
              + normal * 0.00010,
            startRadiusMeters: 0.000070,
            endRadiusMeters: 0.000024
          )
        )
      }
    }
    return result
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-8 ? value / length : fallback
  }
}
