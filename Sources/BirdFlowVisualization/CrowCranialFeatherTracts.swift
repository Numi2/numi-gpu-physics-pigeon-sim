import simd

enum CrowCranialFeatherRegion: UInt8, CaseIterable {
  case nape
  case crown
  case forehead
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
  /// Posterior gular-only optical handoff encoded in the otherwise body-range
  /// material tag. Geometry and semantic class remain unchanged.
  let gularBridgeMaterialBlend: Float
  let surfaceFeatherClass: UInt32
}

/// Immutable identity and loft parameterization for one cranial contour vane.
/// Live breathing and quiet head motion are reconstructed from these values;
/// no expanded feather vertex belongs in the retained inventory.
struct CrowCranialFeatherMorphology: Equatable {
  let region: CrowCranialFeatherRegion
  let axialIndex: Int
  let angularIndex: Int
  let thetaRadians: Float
  let ring: CrowCranialLoftRing
  let previousRing: CrowCranialLoftRing
  let nextRing: CrowCranialLoftRing
  let lengthIdentity: Float
  let materialIdentity: Float
  let directionIdentity: Float
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
  static let billBaseApertureSineThreshold: Float = 0.28
  static let coarseBillBaseApertureSineThreshold: Float = 0.50
  static let coarseAnteriorLoftLimit: Float = 0.84
  static let anteriorLoftLimit: Float = 1.02
  static let standardCircumferentialOverlapScale: Float = 0.62
  static let throatCircumferentialOverlapScale: Float = 0.75
  static let gularBridgeMaterialTagScale: Float = 0.01

  static var axialRings: [CrowCranialLoftRing] {
    CrowCranialAnatomy.sampledLoftRings()
      .enumerated()
      .filter { $0.element.axialFraction <= anteriorLoftLimit }
      .map(\.element)
  }

  static var coarseAxialRings: [CrowCranialLoftRing] {
    axialRings.filter { $0.axialFraction <= coarseAnteriorLoftLimit }
  }

  static func visibleSamples(
    center: SIMD3<Float>,
    radii: SIMD3<Float>,
    breathingScale: Float,
    projectedPixelsPerMeter: Float
  ) -> [CrowCranialFeatherSample] {
    if projectedPixelsPerMeter >= fullDensityPixelsPerMeter {
      return samples(
        center: center,
        radii: radii,
        breathingScale: breathingScale
      )
    }
    let coarse = morphologySamples(
      rings: coarseAxialRings,
      billBaseApertureSineThreshold: coarseBillBaseApertureSineThreshold
    ).map { morphology in
      sample(
        feather(
          morphology: morphology,
          center: center,
          radii: radii,
          breathingScale: breathingScale
        ),
        surfaceFeatherClass: coarseSurfaceFeatherClass(for: morphology.region)
      )
    }
    if projectedPixelsPerMeter >= mediumDensityPixelsPerMeter {
      return coarse.filter {
        ($0.axialIndex + $0.angularIndex).isMultiple(of: 2)
      }
    }
    return coarse.filter {
      $0.axialIndex.isMultiple(of: 2)
        && $0.angularIndex.isMultiple(of: 2)
    }
  }

  static func samples(
    center: SIMD3<Float>,
    radii: SIMD3<Float>,
    breathingScale: Float
  ) -> [CrowCranialFeatherSample] {
    morphologySamples().map {
      feather(
        morphology: $0,
        center: center,
        radii: radii,
        breathingScale: breathingScale
      )
    }
  }

  static func morphologySamples() -> [CrowCranialFeatherMorphology] {
    morphologySamples(
      rings: axialRings,
      billBaseApertureSineThreshold: billBaseApertureSineThreshold
    )
  }

  private static func morphologySamples(
    rings: [CrowCranialLoftRing],
    billBaseApertureSineThreshold: Float
  ) -> [CrowCranialFeatherMorphology] {
    var result: [CrowCranialFeatherMorphology] = []
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
        if ring.axialFraction > 0.55,
          abs(sin(theta)) < billBaseApertureSineThreshold
        {
          continue
        }
        let region = region(for: ring, theta: theta)
        result.append(
          CrowCranialFeatherMorphology(
            region: region,
            axialIndex: axialIndex,
            angularIndex: angularIndex,
            thetaRadians: theta,
            ring: ring,
            previousRing: previousRing,
            nextRing: nextRing,
            lengthIdentity: identityVariation(
              axialIndex: axialIndex,
              angularIndex: angularIndex,
              salt: 0x85EB_CA6B
            ),
            materialIdentity: identityVariation(
              axialIndex: axialIndex,
              angularIndex: angularIndex,
              salt: 0xC2B2_AE35
            ),
            directionIdentity: identityVariation(
              axialIndex: axialIndex,
              angularIndex: angularIndex,
              salt: 0x27D4_EB2F
            )
          )
        )
      }
    }
    return result
  }

  static func feather(
    morphology: CrowCranialFeatherMorphology,
    center: SIMD3<Float>,
    radii: SIMD3<Float>,
    breathingScale: Float
  ) -> CrowCranialFeatherSample {
    let ring = morphology.ring
    let previousRing = morphology.previousRing
    let nextRing = morphology.nextRing
    let theta = morphology.thetaRadians
    let effectiveRadii = radii * SIMD3<Float>(breathingScale, 1, breathingScale)
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
    let region = morphology.region
    let materialIdentity = morphology.materialIdentity
    let directionIdentity = morphology.directionIdentity
    let length = axialLength(for: morphology)
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
    let overlapScale = circumferentialOverlapScale(for: region)
    let width = min(0.0048, max(0.0024, overlapScale * circumferentialSpacing))
    return CrowCranialFeatherSample(
      region: region,
      axialIndex: morphology.axialIndex,
      angularIndex: morphology.angularIndex,
      thetaRadians: theta,
      root: root,
      tip: tip,
      planeNormal: normal,
      rootWidthMeters: 0.55 * width,
      maximumWidthMeters: width,
      camberMeters: (0.00055 + (region == .nape ? 0.00020 : 0))
        * (1 + 0.08 * materialIdentity),
      materialVariation: materialIdentity,
      gularBridgeMaterialBlend: gularBridgeMaterialBlend(
        region: region,
        ring: ring
      ),
      surfaceFeatherClass: surfaceFeatherClass(for: region)
    )
  }

  /// Cranial contour vanes own optical regions distinct from the trunk. This
  /// preserves the measured head/body separation and the low-luminance dorsal
  /// forehead instead of forcing every short cranial vane through body bands.
  static func surfaceFeatherClass(
    for region: CrowCranialFeatherRegion
  ) -> UInt32 {
    switch region {
    case .nape, .crown, .cheek:
      return 8
    case .forehead:
      return 9
    case .throat:
      return 10
    }
  }

  static func circumferentialOverlapScale(
    for region: CrowCranialFeatherRegion
  ) -> Float {
    region == .throat
      ? throatCircumferentialOverlapScale
      : standardCircumferentialOverlapScale
  }

  static func axialLength(
    for morphology: CrowCranialFeatherMorphology
  ) -> Float {
    axialLength(region: morphology.region, ring: morphology.ring)
      * (1 + (morphology.region == .throat ? 0.16 : 0.04)
        * morphology.lengthIdentity)
  }

  static func lodReferenceLengthMeters(
    for morphology: CrowCranialFeatherMorphology
  ) -> Float {
    // The live root-tip vector adds a 0.2 mm normal lift to the prescribed
    // shaft direction. Their angle changes slightly with breathing, so the
    // triangle-inequality bound keeps retained topology stable and can never
    // select a coarser tier than the former per-frame CPU distance.
    axialLength(for: morphology) + 0.00020
  }

  /// Smoothly limits collar suppression to the posterior throat rings that
  /// overlap the class-7 bridge. Anterior gular material remains unchanged.
  static func gularBridgeMaterialBlend(
    region: CrowCranialFeatherRegion,
    ring: CrowCranialLoftRing
  ) -> Float {
    guard region == .throat else { return 0 }
    let bounded = min(max((0.52 - ring.axialFraction) / 0.84, 0), 1)
    return bounded * bounded * (3 - 2 * bounded)
  }

  /// Below full output density, preserve broad head/body material bands; the
  /// finer regional separation would be subpixel and destabilize temporal
  /// reconstruction rather than add resolvable optical information.
  static func coarseSurfaceFeatherClass(
    for region: CrowCranialFeatherRegion
  ) -> UInt32 {
    switch region {
    case .nape, .crown, .forehead: return 5
    case .cheek: return 6
    case .throat: return 7
    }
  }

  private static func sample(
    _ source: CrowCranialFeatherSample,
    surfaceFeatherClass: UInt32
  ) -> CrowCranialFeatherSample {
    CrowCranialFeatherSample(
      region: source.region,
      axialIndex: source.axialIndex,
      angularIndex: source.angularIndex,
      thetaRadians: source.thetaRadians,
      root: source.root,
      tip: source.tip,
      planeNormal: source.planeNormal,
      rootWidthMeters: source.rootWidthMeters,
      maximumWidthMeters: source.maximumWidthMeters,
      camberMeters: source.camberMeters,
      materialVariation: source.materialVariation,
      gularBridgeMaterialBlend: source.gularBridgeMaterialBlend,
      surfaceFeatherClass: surfaceFeatherClass
    )
  }

  private static func region(
    for ring: CrowCranialLoftRing,
    theta: Float
  ) -> CrowCranialFeatherRegion {
    if ring.axialFraction < -0.45 { return .nape }
    if ring.axialFraction >= 0.40, sin(theta) > 0.35 { return .forehead }
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
    case .crown, .forehead: return 0.012
    case .cheek: return 0.0115
    case .throat: return 0.014
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
