import simd

enum CrowCranialFeatherRegion: UInt8, CaseIterable {
  case nape
  case crown
  case cheek
  case throat
}

struct CrowCranialFeatherSample: Equatable {
  let region: CrowCranialFeatherRegion
  let root: SIMD3<Float>
  let tip: SIMD3<Float>
  let planeNormal: SIMD3<Float>
  let rootWidthMeters: Float
  let maximumWidthMeters: Float
  let camberMeters: Float
}

/// Small overlapping contour tracts attached to the estimated cranial loft.
///
/// The tracts break the analytic head silhouette without covering the orbit or
/// bill base. Their roots are evaluated on the same longitudinal rings as the
/// visible cranium, so breathing and the graded neck transform keep them bound
/// to the underlying surface.
enum CrowCranialFeatherTracts {
  static let fullDensityPixelsPerMeter: Float = 1_800
  static let mediumDensityPixelsPerMeter: Float = 1_100

  static func visibleSamples(
    center: SIMD3<Float>,
    radii: SIMD3<Float>,
    breathingScale: Float,
    projectedPixelsPerMeter: Float
  ) -> [CrowCranialFeatherSample] {
    let complete = samples(
      center: center,
      radii: radii,
      breathingScale: breathingScale
    )
    if projectedPixelsPerMeter >= fullDensityPixelsPerMeter {
      return complete
    }
    if projectedPixelsPerMeter >= mediumDensityPixelsPerMeter {
      return complete.enumerated().compactMap {
        $0.offset % 3 == 2 ? nil : $0.element
      }
    }
    return complete.enumerated().compactMap {
      $0.offset.isMultiple(of: 2) ? $0.element : nil
    }
  }

  static func samples(
    center: SIMD3<Float>,
    radii: SIMD3<Float>,
    breathingScale: Float
  ) -> [CrowCranialFeatherSample] {
    let effectiveRadii = radii * SIMD3<Float>(breathingScale, 1, breathingScale)
    let rings = CrowCranialAnatomy.loftRings
    var result: [CrowCranialFeatherSample] = []
    result.reserveCapacity(54)

    for ringIndex in [0, 1, 2] {
      for angularIndex in 0..<6 {
        let theta = -0.95 + 2.85 * Float(angularIndex) / 5
        append(
          region: .nape,
          ring: rings[ringIndex],
          theta: theta,
          axialLength: 0.016 - 0.002 * Float(ringIndex),
          width: 0.0046,
          center: center,
          effectiveRadii: effectiveRadii,
          to: &result
        )
      }
    }

    for ringIndex in [2, 3, 4] {
      for angularIndex in 0..<5 {
        let theta = 0.72 + 1.70 * Float(angularIndex) / 4
        append(
          region: .crown,
          ring: rings[ringIndex],
          theta: theta,
          axialLength: 0.010,
          width: 0.0035,
          center: center,
          effectiveRadii: effectiveRadii,
          to: &result
        )
      }
    }

    for side: Float in [-1, 1] {
      let sideCenter: Float = side > 0 ? 0 : Float.pi
      for ringIndex in [3, 4] {
        for angularIndex in 0..<3 {
          let theta = sideCenter + side * (-0.42 + 0.42 * Float(angularIndex))
          append(
            region: .cheek,
            ring: rings[ringIndex],
            theta: theta,
            axialLength: 0.0085,
            width: 0.0032,
            center: center,
            effectiveRadii: effectiveRadii,
            to: &result
          )
        }
      }
    }

    for ringIndex in [2, 3, 4] {
      for angularIndex in 0..<3 {
        let theta = -1.92 + 0.70 * Float(angularIndex) / 2
        append(
          region: .throat,
          ring: rings[ringIndex],
          theta: theta,
          axialLength: 0.012,
          width: 0.0037,
          center: center,
          effectiveRadii: effectiveRadii,
          to: &result
        )
      }
    }
    return result
  }

  private static func append(
    region: CrowCranialFeatherRegion,
    ring: CrowCranialLoftRing,
    theta: Float,
    axialLength: Float,
    width: Float,
    center: SIMD3<Float>,
    effectiveRadii: SIMD3<Float>,
    to result: inout [CrowCranialFeatherSample]
  ) {
    let surface = CrowCranialAnatomy.surfacePoint(
      center: center,
      effectiveRadii: effectiveRadii,
      ring: ring,
      theta: theta
    )
    let radial = normalized(
      SIMD3<Float>(
        region == .nape ? -0.24 : 0.08,
        cos(theta) / max(effectiveRadii.y * ring.halfWidthFraction, 0.001),
        sin(theta)
          / max(
            effectiveRadii.z
              * (sin(theta) >= 0
                ? ring.dorsalRadiusFraction
                : ring.ventralRadiusFraction),
            0.001
          )
      ),
      fallback: SIMD3<Float>(0, cos(theta), sin(theta))
    )
    let root = surface + 0.00035 * radial
    let downward: Float = region == .throat ? -0.0022 : -0.0008
    let outward: Float = region == .cheek ? 0.0012 : 0.0005
    let tip = root
      + SIMD3<Float>(-axialLength, outward * radial.y, downward + outward * radial.z)
    result.append(
      CrowCranialFeatherSample(
        region: region,
        root: root,
        tip: tip,
        planeNormal: radial,
        rootWidthMeters: 0.55 * width,
        maximumWidthMeters: width,
        camberMeters: 0.0007 + (region == .nape ? 0.0003 : 0)
      )
    )
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-10 ? value / length : fallback
  }
}
