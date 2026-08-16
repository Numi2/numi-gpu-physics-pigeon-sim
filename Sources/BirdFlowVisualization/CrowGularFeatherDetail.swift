import simd

/// Resolved rachis and aggregate barb groups for cranial throat feathers.
///
/// The base vane remains the closed optical shell. At full presentation
/// density these segments add directional mesostructure to the gular field,
/// preventing a smooth material patch immediately behind the bill.
enum CrowGularFeatherDetail {
  static let barbPairCount = 3

  static func segments(
    for feather: CrowCranialFeatherSample,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    guard feather.region == .throat, projectedPixelsPerMeter >= 1_400 else {
      return []
    }
    let direction = normalized(
      feather.tip - feather.root,
      fallback: SIMD3<Float>(-1, 0, 0)
    )
    let normal = normalized(
      feather.planeNormal - direction * simd_dot(feather.planeNormal, direction),
      fallback: feather.planeNormal
    )
    let widthAxis = normalized(
      simd_cross(normal, direction),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    func center(at fraction: Float) -> SIMD3<Float> {
      feather.root + fraction * (feather.tip - feather.root)
        + normal * (feather.camberMeters * sin(Float.pi * fraction) + 0.00010)
    }
    func halfWidth(at fraction: Float) -> Float {
      let envelope = 0.32 + 0.68 * pow(max(sin(Float.pi * fraction), 0), 0.58)
      let tipTaper = 1 - 0.985 * pow(fraction, 3.2)
      return
        (feather.rootWidthMeters * (1 - fraction)
        + feather.maximumWidthMeters * fraction) * envelope * tipTaper
    }

    var result: [CrowFeatherMesostructureSegment] = []
    result.reserveCapacity(1 + 2 * barbPairCount)
    result.append(
      CrowFeatherMesostructureSegment(
        kind: .rachis,
        start: center(at: 0.16),
        end: center(at: 0.94),
        startRadiusMeters: 0.00017,
        endRadiusMeters: 0.000045
      )
    )
    for pair in 0..<barbPairCount {
      let axial = 0.32 + 0.18 * Float(pair)
      let reach = axial + 0.075
      for side: Float in [-1, 1] {
        let start = center(at: axial) + normal * 0.00006
        let end =
          center(at: reach)
          + side * widthAxis * (halfWidth(at: reach) + 0.00045)
          + normal * 0.00012
        result.append(
          CrowFeatherMesostructureSegment(
            kind: .edgeBarbGroup,
            start: start,
            end: end,
            startRadiusMeters: 0.000075,
            endRadiusMeters: 0.000025
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
