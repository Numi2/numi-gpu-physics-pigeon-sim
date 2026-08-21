import simd

/// Shafts and paired aggregate barb bundles attached to the two visible
/// trailing-covert ranks.
///
/// Detail stations occupy only the full-width interiors of their owning rank.
/// The original continuous vane and its detail remain the hidden folded bed;
/// these ribbons grow from zero radius as the two exposed ranks deploy.
enum CrowTrailingCovertDetail {
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
    baseRadiusMeters: Float,
    deployment: Float,
    lodLengthMeters: Float,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    let tessellation = CrowFeatherCoverageLOD.tessellation(
      lengthMeters: lodLengthMeters,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      baseAxialSections: 7
    )
    guard tessellation.rachisSections > 0 else { return [] }
    let axis = normalized(tip - root, fallback: SIMD3<Float>(-1, 0, 0))
    let normal = normalized(
      planeNormal - axis * simd_dot(planeNormal, axis),
      fallback: planeNormal
    )
    let widthAxis = normalized(
      simd_cross(normal, axis),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    func centerline(
      rank: CrowTrailingCovertRanks.Rank,
      fraction: Float
    ) -> SIMD3<Float> {
      root + fraction * (tip - root)
        + normal
        * (camberMeters * sin(Float.pi * fraction)
          + deployment
          * CrowTrailingCovertRanks.normalOffsetMeters(
            rank: rank,
            axialFraction: fraction
          ))
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
        * CrowTrailingCovertRanks.visibleRankWidthScale
        * (1 + vaneAsymmetry * signedSide)
    }
    func surfacePoint(
      rank: CrowTrailingCovertRanks.Rank,
      fraction: Float,
      signedWidth: Float
    ) -> SIMD3<Float> {
      let width = halfWidth(fraction, signedSide: signedWidth)
      let transverseEnvelope = max(0, 1 - signedWidth * signedWidth)
      return centerline(rank: rank, fraction: fraction)
        + widthAxis * (signedWidth * width)
        + normal * (width * transverseCamberRatio * transverseEnvelope)
    }

    let shaftSectionCount = max(tessellation.rachisSections / 2, 2)
    let barbPairCount = max(tessellation.edgeBarbPairs / 2, 1)
    let radiusWeight = min(max(deployment, 0), 1)
    var result: [CrowFeatherMesostructureSegment] = []
    result.reserveCapacity(
      2 * shaftSectionCount + 4 * barbPairCount
    )
    for rank in CrowTrailingCovertRanks.Rank.allCases {
      let shaftRange: (Float, Float)
      let barbRange: (Float, Float)
      switch rank {
      case .proximal:
        shaftRange = (0.04, 0.64)
        barbRange = (0.16, 0.56)
      case .distal:
        shaftRange = (0.38, 0.965)
        barbRange = (0.49, 0.86)
      }
      for section in 0..<shaftSectionCount {
        let first = Float(section) / Float(shaftSectionCount)
        let second = Float(section + 1) / Float(shaftSectionCount)
        let startFraction =
          shaftRange.0
          + (shaftRange.1 - shaftRange.0) * first
        let endFraction =
          shaftRange.0
          + (shaftRange.1 - shaftRange.0) * second
        result.append(
          CrowFeatherMesostructureSegment(
            kind: .rachis,
            start: surfacePoint(
              rank: rank,
              fraction: startFraction,
              signedWidth: 0
            ),
            end: surfacePoint(
              rank: rank,
              fraction: endFraction,
              signedWidth: 0
            ),
            startRadiusMeters: radiusWeight * baseRadiusMeters
              * (1 - 0.72 * first),
            endRadiusMeters: radiusWeight * baseRadiusMeters
              * (1 - 0.72 * second)
          )
        )
      }
      for pair in 0..<barbPairCount {
        let pairFraction = Float(pair + 1) / Float(barbPairCount + 1)
        let axial = barbRange.0 + (barbRange.1 - barbRange.0) * pairFraction
        let reach = min(axial + 0.055, rank == .proximal ? 0.615 : 0.92)
        for side: Float in [-1, 1] {
          result.append(
            CrowFeatherMesostructureSegment(
              kind: .edgeBarbGroup,
              start: surfacePoint(
                rank: rank,
                fraction: axial,
                signedWidth: 0
              ),
              end: surfacePoint(
                rank: rank,
                fraction: reach,
                signedWidth: side * 0.76
              ),
              startRadiusMeters: radiusWeight * 0.000050,
              endRadiusMeters: radiusWeight * 0.000012
            )
          )
        }
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
