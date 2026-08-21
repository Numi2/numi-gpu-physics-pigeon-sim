import simd

/// LOD-selected paired barb bundles contained by a dorsal covert vane.
///
/// These are aggregate ribbons, not individual biological barbs. Their roots
/// follow the rachis crown and their tips stop inside the owning vane edge. The
/// fixed coverage tiers can therefore spend future compute on denser bundles
/// without changing the accepted feather silhouette.
enum CrowWingCovertBarbDetail {
  static let terminalWidthFraction: Float = 0.82
  static let normalClearanceMeters: Float = 0.00003

  static func segments(
    root: SIMD3<Float>,
    tip: SIMD3<Float>,
    planeNormal: SIMD3<Float>,
    rootWidthMeters: Float,
    maximumWidthMeters: Float,
    camberMeters: Float,
    transverseCamberRatio: Float,
    vaneAsymmetry: Float,
    edgeRippleAmplitude: Float,
    edgeRipplePhase: Float,
    edgeRippleCycles: Float,
    lodLengthMeters: Float,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    let tessellation = CrowFeatherCoverageLOD.tessellation(
      lengthMeters: lodLengthMeters,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      baseAxialSections: 7
    )
    let pairCount = tessellation.edgeBarbPairs
    guard pairCount > 0 else { return [] }
    let axis = normalized(tip - root, fallback: SIMD3<Float>(-1, 0, 0))
    let normal = normalized(
      planeNormal - axis * simd_dot(planeNormal, axis),
      fallback: planeNormal
    )
    let widthAxis = normalized(
      simd_cross(normal, axis),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    func centerline(_ fraction: Float) -> SIMD3<Float> {
      root + fraction * (tip - root)
        + normal * (camberMeters * sin(Float.pi * fraction))
    }
    func halfWidth(_ fraction: Float, signedSide: Float) -> Float {
      let rootEnvelope: Float = 0.32
      let bodyEnvelope =
        rootEnvelope
        + (1 - rootEnvelope)
        * pow(max(sin(Float.pi * fraction), 0), 0.58)
      let tipTaper = 1 - 0.985 * pow(fraction, 3.2)
      let rippleEnvelope = pow(max(sin(Float.pi * fraction), 0), 2)
      let edgeRipple =
        1
        + edgeRippleAmplitude
        * sin(
          2 * Float.pi * edgeRippleCycles * fraction + edgeRipplePhase
        ) * rippleEnvelope
      let interpolatedWidth =
        rootWidthMeters * (1 - fraction)
        + maximumWidthMeters * fraction
      return interpolatedWidth * bodyEnvelope * tipTaper * edgeRipple
        * (1 + vaneAsymmetry * signedSide)
    }
    func surfacePoint(_ fraction: Float, signedWidth: Float) -> SIMD3<Float> {
      let width = halfWidth(fraction, signedSide: signedWidth)
      let transverseEnvelope = max(0, 1 - signedWidth * signedWidth)
      return centerline(fraction)
        + widthAxis * (signedWidth * width)
        + normal
        * (width * transverseCamberRatio * transverseEnvelope
          + normalClearanceMeters)
    }

    var result: [CrowFeatherMesostructureSegment] = []
    result.reserveCapacity(2 * pairCount)
    for pair in 0..<pairCount {
      let fraction = Float(pair + 1) / Float(pairCount + 1)
      let axial = 0.18 + 0.66 * fraction
      let reach = min(axial + 0.075, 0.92)
      for side: Float in [-1, 1] {
        result.append(
          CrowFeatherMesostructureSegment(
            kind: .edgeBarbGroup,
            start: surfacePoint(axial, signedWidth: 0),
            end: surfacePoint(
              reach,
              signedWidth: side * terminalWidthFraction
            ),
            startRadiusMeters: 0.000055,
            endRadiusMeters: 0.000014
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
    return length > 1e-12 ? value / length : fallback
  }
}
