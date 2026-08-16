import simd

/// Resolved shaft, aggregate barb, and terminal-tip structure for the crural
/// contour field. The closed vane remains the optical shell; this full-density
/// layer breaks the smooth conical leg read while retaining the same feather
/// root, plane, camber, and deterministic radial/station identity.
enum CrowCruralFeatherDetail {
  static let barbPairCount = 4
  static let terminalBundleCount = 3

  static func segments(
    for feather: CrowLegPlumageFeather,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    guard projectedPixelsPerMeter >= 1_400 else { return [] }
    let direction = normalized(
      feather.tip - feather.root,
      fallback: SIMD3<Float>(0, 0, -1)
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
      feather.root + fraction * (feather.tip - feather.root)
        + normal * (feather.camberMeters * sin(Float.pi * fraction) + 0.00007)
    }
    func halfWidth(at fraction: Float) -> Float {
      let envelope = feather.rootEnvelopeRatio
        + (1 - feather.rootEnvelopeRatio)
          * pow(max(sin(Float.pi * fraction), 0), 0.58)
      let tipTaper = 1 - 0.985 * pow(fraction, 3.2)
      return
        (feather.rootWidthMeters * (1 - fraction)
        + feather.maximumWidthMeters * fraction) * envelope * tipTaper
    }

    var result: [CrowFeatherMesostructureSegment] = []
    result.reserveCapacity(1 + 2 * barbPairCount + terminalBundleCount)
    result.append(
      CrowFeatherMesostructureSegment(
        kind: .rachis,
        start: center(at: 0.14),
        end: center(at: 0.96),
        startRadiusMeters: 0.00016,
        endRadiusMeters: 0.000040
      )
    )
    for pair in 0..<barbPairCount {
      let axial = 0.30 + 0.15 * Float(pair)
      let reach = axial + 0.080
      for side: Float in [-1, 1] {
        result.append(
          CrowFeatherMesostructureSegment(
            kind: .edgeBarbGroup,
            start: center(at: axial) + normal * 0.000045,
            end: center(at: reach)
              + side * widthAxis * (halfWidth(at: reach) + 0.00028)
              + normal * 0.000095,
            startRadiusMeters: 0.000065,
            endRadiusMeters: 0.000021
          )
        )
      }
    }

    let identityPhase = sin(
      Float(feather.radialIndex + 1) * 12.9898
        + Float(feather.stationIndex + 1) * 78.233
    )
    for bundle in 0..<terminalBundleCount {
      let lane = Float(bundle - 1) * 0.58
      let startAxial: Float = 0.80 + 0.025 * Float(bundle)
      let start = center(at: startAxial)
        + lane * widthAxis * halfWidth(at: startAxial) * 0.48
        + normal * 0.000075
      let extensionMeters = 0.00034 * (
        0.90 + 0.08 * identityPhase + 0.025 * lane
      )
      let end = feather.tip + direction * extensionMeters
        + lane * widthAxis * halfWidth(at: 0.82) * 0.14
        + normal * 0.00013
      result.append(
        CrowFeatherMesostructureSegment(
          kind: .edgeBarbGroup,
          start: start,
          end: end,
          startRadiusMeters: 0.000060,
          endRadiusMeters: 0.000020
        )
      )
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
