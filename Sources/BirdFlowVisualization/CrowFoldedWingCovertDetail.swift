import simd

/// Resolved shafts and aggregate barb groups for the visible folded-wing shell.
///
/// The vane remains the closed optical surface. At full density, this layer
/// follows the same root, tip, camber, ripple, asymmetry, and transverse crown
/// used by the rendered blade so the added hierarchy stays attached instead of
/// floating above or disappearing beneath the feather.
enum CrowFoldedWingCovertDetail {
  static let barbPairCount = 3

  static func segments(
    for feather: CrowFoldedWingCovertSample,
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
      fallback: SIMD3<Float>(0, feather.side, 0)
    )
    func centerline(at fraction: Float) -> SIMD3<Float> {
      feather.rootOffset
        + fraction * (feather.tipOffset - feather.rootOffset)
        + normal * feather.camberMeters * sin(Float.pi * fraction)
    }
    func halfWidth(at fraction: Float, side: Float) -> Float {
      let rootEnvelope = min(max(feather.rootEnvelopeRatio, 0.05), 1)
      let bodyEnvelope =
        rootEnvelope
        + (1 - rootEnvelope) * pow(max(sin(Float.pi * fraction), 0), 0.58)
      let tipTaper = 1 - 0.985 * pow(fraction, 3.2)
      let rippleEnvelope = pow(max(sin(Float.pi * fraction), 0), 2)
      let edgeRipple =
        1
        + feather.edgeRippleAmplitude
        * sin(
          2 * Float.pi * feather.edgeRippleCycles * fraction
            + feather.edgeRipplePhase
        )
        * rippleEnvelope
      let interpolatedWidth =
        feather.rootWidthMeters * (1 - fraction)
        + feather.maximumWidthMeters * fraction
      return
        interpolatedWidth * bodyEnvelope * tipTaper * edgeRipple
        * (1 + side * feather.vaneAsymmetry)
    }
    func crown(at fraction: Float) -> SIMD3<Float> {
      centerline(at: fraction)
        + normal * (0.26 * halfWidth(at: fraction, side: 0) + 0.00010)
    }

    var result: [CrowFeatherMesostructureSegment] = []
    result.reserveCapacity(1 + 2 * barbPairCount)
    result.append(
      CrowFeatherMesostructureSegment(
        kind: .rachis,
        start: crown(at: 0.12),
        end: crown(at: 0.96),
        startRadiusMeters: 0.00017,
        endRadiusMeters: 0.000040
      )
    )
    for pair in 0..<barbPairCount {
      let axial = 0.32 + 0.18 * Float(pair)
      let reach = axial + 0.09
      for side: Float in [-1, 1] {
        result.append(
          CrowFeatherMesostructureSegment(
            kind: .edgeBarbGroup,
            start: crown(at: axial) + normal * 0.000045,
            end: centerline(at: reach)
              + side * widthAxis * (halfWidth(at: reach, side: side) + 0.00028)
              + normal * 0.00009,
            startRadiusMeters: 0.000060,
            endRadiusMeters: 0.000020
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
