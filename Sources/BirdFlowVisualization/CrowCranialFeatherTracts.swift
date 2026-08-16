import simd

enum CrowCranialFeatherRegion: UInt8, CaseIterable {
  case nape
  case crown
  case cheek
  case throat
}

struct CrowCranialFeatherSample: Equatable {
  let region: CrowCranialFeatherRegion
  let axialIndex: Int
  let angularIndex: Int
  let thetaRadians: Float
  let root: SIMD3<Float>
  let tip: SIMD3<Float>
  let planeNormal: SIMD3<Float>
  let rootWidthMeters: Float
  let maximumWidthMeters: Float
  let camberMeters: Float
  let materialVariation: Float
  let surfaceFeatherClass: UInt32
}

/// Small overlapping contour tracts attached to the estimated cranial loft.
///
/// The tracts break the analytic head silhouette without covering the orbit or
/// bill base. Their roots are evaluated on the same longitudinal rings as the
/// visible cranium, so breathing and the graded neck transform keep them bound
/// to the underlying surface.
enum CrowCranialFeatherTracts {
  static let angularCount = 32
  static let fullDensityPixelsPerMeter: Float = 1_400
  static let mediumDensityPixelsPerMeter: Float = 900

  static var axialRings: [CrowCranialLoftRing] {
    CrowCranialAnatomy.sampledLoftRings()
      .enumerated()
      .filter { $0.element.axialFraction <= 0.84 }
      .map(\.element)
  }

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
      return complete.filter {
        ($0.axialIndex + $0.angularIndex).isMultiple(of: 2)
      }
    }
    return complete.filter {
      $0.axialIndex.isMultiple(of: 2)
        && $0.angularIndex.isMultiple(of: 2)
    }
  }

  static func samples(
    center: SIMD3<Float>,
    radii: SIMD3<Float>,
    breathingScale: Float
  ) -> [CrowCranialFeatherSample] {
    let effectiveRadii = radii * SIMD3<Float>(breathingScale, 1, breathingScale)
    let rings = axialRings
    var result: [CrowCranialFeatherSample] = []
    result.reserveCapacity(rings.count * angularCount)

    for axialIndex in rings.indices {
      let ring = rings[axialIndex]
      let previousRing = rings[max(0, axialIndex - 1)]
      let nextRing = rings[min(rings.count - 1, axialIndex + 1)]
      for angularIndex in 0..<angularCount {
        let baseTheta = 2 * Float.pi * Float(angularIndex) / Float(angularCount)
        guard !reservesOrbit(ring: ring, theta: baseTheta) else { continue }
        let angularStep = 2 * Float.pi / Float(angularCount)
        let phase = axialIndex.isMultiple(of: 2) ? Float.zero : 0.5
        let angularIdentity = identityVariation(
          axialIndex: axialIndex,
          angularIndex: angularIndex,
          salt: 0x9E37_79B9
        )
        let theta = baseTheta + angularStep * (phase + 0.10 * angularIdentity)
        if ring.axialFraction > 0.55, abs(sin(theta)) < 0.50 { continue }
        append(
          axialIndex: axialIndex,
          angularIndex: angularIndex,
          ring: ring,
          previousRing: previousRing,
          nextRing: nextRing,
          theta: theta,
          center: center,
          effectiveRadii: effectiveRadii,
          to: &result
        )
      }
    }
    return result
  }

  private static func append(
    axialIndex: Int,
    angularIndex: Int,
    ring: CrowCranialLoftRing,
    previousRing: CrowCranialLoftRing,
    nextRing: CrowCranialLoftRing,
    theta: Float,
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
    let angularStep = Float.pi / Float(angularCount)
    let angularTangent =
      CrowCranialAnatomy.surfacePoint(
        center: center,
        effectiveRadii: effectiveRadii,
        ring: ring,
        theta: theta + angularStep
      )
      - CrowCranialAnatomy.surfacePoint(
        center: center,
        effectiveRadii: effectiveRadii,
        ring: ring,
        theta: theta - angularStep
      )
    let axialTangent =
      CrowCranialAnatomy.surfacePoint(
        center: center,
        effectiveRadii: effectiveRadii,
        ring: nextRing,
        theta: theta
      )
      - CrowCranialAnatomy.surfacePoint(
        center: center,
        effectiveRadii: effectiveRadii,
        ring: previousRing,
        theta: theta
      )
    let normal = normalized(
      simd_cross(angularTangent, axialTangent),
      fallback: SIMD3<Float>(0, cos(theta), sin(theta))
    )
    let region = region(for: ring, theta: theta)
    let lengthIdentity = identityVariation(
      axialIndex: axialIndex,
      angularIndex: angularIndex,
      salt: 0x85EB_CA6B
    )
    let materialIdentity = identityVariation(
      axialIndex: axialIndex,
      angularIndex: angularIndex,
      salt: 0xC2B2_AE35
    )
    let directionIdentity = identityVariation(
      axialIndex: axialIndex,
      angularIndex: angularIndex,
      salt: 0x27D4_EB2F
    )
    let length = axialLength(region: region, ring: ring) * (1 + 0.04 * lengthIdentity)
    let direction = normalized(
      -axialTangent
        + (region == .throat ? 0.085 : 0.035) * directionIdentity * angularTangent
        + SIMD3<Float>(0, 0, region == .throat ? -0.16 : -0.035)
        * simd_length(axialTangent),
      fallback: SIMD3<Float>(-1, 0, 0)
    )
    let root = surface + 0.00030 * normal
    let tip = root + length * direction + 0.00020 * normal
    let neighbour = CrowCranialAnatomy.surfacePoint(
      center: center,
      effectiveRadii: effectiveRadii,
      ring: ring,
      theta: theta + 2 * angularStep
    )
    let circumferentialSpacing = simd_distance(surface, neighbour)
    let width = min(0.0048, max(0.0024, 0.62 * circumferentialSpacing))
    result.append(
      CrowCranialFeatherSample(
        region: region,
        axialIndex: axialIndex,
        angularIndex: angularIndex,
        thetaRadians: theta,
        root: root,
        tip: tip,
        planeNormal: normal,
        rootWidthMeters: 0.55 * width,
        maximumWidthMeters: width,
        camberMeters: (0.00055 + (region == .nape ? 0.00020 : 0))
          * (1 + 0.08 * materialIdentity),
        materialVariation: materialIdentity,
        surfaceFeatherClass: surfaceFeatherClass(for: region)
      )
    )
  }

  /// Cranial contour vanes continue the corresponding body-material response
  /// across the head instead of falling back to the generic feather class.
  static func surfaceFeatherClass(
    for region: CrowCranialFeatherRegion
  ) -> UInt32 {
    switch region {
    case .nape, .crown:
      return 5
    case .cheek:
      return 6
    case .throat:
      return 7
    }
  }

  private static func region(
    for ring: CrowCranialLoftRing,
    theta: Float
  ) -> CrowCranialFeatherRegion {
    if ring.axialFraction < -0.45 { return .nape }
    if sin(theta) > 0.35 { return .crown }
    if sin(theta) < -0.35 { return .throat }
    return .cheek
  }

  private static func axialLength(
    region: CrowCranialFeatherRegion,
    ring: CrowCranialLoftRing
  ) -> Float {
    switch region {
    case .nape:
      return 0.0145 + 0.0015 * min(max((-ring.axialFraction - 0.45) / 0.60, 0), 1)
    case .crown: return 0.012
    case .cheek: return 0.0115
    case .throat: return 0.013
    }
  }

  private static func reservesOrbit(
    ring: CrowCranialLoftRing,
    theta: Float
  ) -> Bool {
    guard ring.axialFraction >= 0.02 && ring.axialFraction <= 0.62 else {
      return false
    }
    let firstOrbit: Float = 0.28
    let secondOrbit = Float.pi - firstOrbit
    return angularDistance(theta, firstOrbit) < 0.32
      || angularDistance(theta, secondOrbit) < 0.32
  }

  private static func angularDistance(_ first: Float, _ second: Float) -> Float {
    let difference = abs(first - second).truncatingRemainder(dividingBy: 2 * .pi)
    return min(difference, 2 * .pi - difference)
  }

  private static func identityVariation(
    axialIndex: Int,
    angularIndex: Int,
    salt: UInt32
  ) -> Float {
    var value = UInt32(truncatingIfNeeded: axialIndex) &* 0x9E37_79B9
    value ^= UInt32(truncatingIfNeeded: angularIndex) &* 0x85EB_CA6B
    value ^= salt
    value ^= value >> 16
    value &*= 0x7FEB_352D
    value ^= value >> 15
    value &*= 0x846C_A68B
    value ^= value >> 16
    return 2 * Float(value & 0x00FF_FFFF) / Float(0x00FF_FFFF) - 1
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-10 ? value / length : fallback
  }
}
