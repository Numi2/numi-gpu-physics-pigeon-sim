import simd

struct CrowLegPlumageFeather: Equatable {
  let radialIndex: Int
  let stationIndex: Int
  let root: SIMD3<Float>
  let tip: SIMD3<Float>
  let planeNormal: SIMD3<Float>
  let rootWidthMeters: Float
  let maximumWidthMeters: Float
  let camberMeters: Float
  let vaneAsymmetry: Float
  let edgeRippleAmplitude: Float
  let edgeRipplePhase: Float
  let edgeRippleCycles: Float
  let rootEnvelopeRatio: Float
  let materialVariation: Float
  let bodyMaterialBlend: Float
}

/// Estimated crural contour feathers joining the pelvic plumage to the hock.
///
/// The underlying limb remains a tapered support, but it is no longer the
/// visible silhouette. Staggered feather rows overlap axially and wrap around
/// the limb; their distal tips cross the hock to break the artificial cuff.
enum CrowLegPlumage {
  static let radialCount = 18
  static let stationCount = 9
  static let proximalUnderlayerRadiusMeters: Float = 0.014
  static let distalUnderlayerRadiusMeters: Float = 0.0065
  static let visibleRootEnvelopeRatio: Float = 0.70
  static let minimumLODTessellationLengthMeters: Float = 0.018
  static let surfaceFeatherClass: UInt32 = 7

  static func visibleSamples(
    hip: SIMD3<Float>,
    hock: SIMD3<Float>,
    projectedPixelsPerMeter: Float
  ) -> [CrowLegPlumageFeather] {
    if projectedPixelsPerMeter >= 1_400 { return samples(hip: hip, hock: hock) }
    return coarseSamples(hip: hip, hock: hock)
  }

  static func samples(
    hip: SIMD3<Float>,
    hock: SIMD3<Float>
  ) -> [CrowLegPlumageFeather] {
    let axis = normalized(hock - hip, fallback: SIMD3<Float>(0, 0, -1))
    let helper: SIMD3<Float> =
      abs(axis.z) < 0.82
      ? SIMD3<Float>(0, 0, 1)
      : SIMD3<Float>(0, 1, 0)
    let first = normalized(simd_cross(axis, helper), fallback: SIMD3<Float>(1, 0, 0))
    let second = normalized(simd_cross(axis, first), fallback: SIMD3<Float>(0, 1, 0))
    var result: [CrowLegPlumageFeather] = []
    result.reserveCapacity(radialCount * stationCount)
    for radialIndex in 0..<radialCount {
      let stagger: Float = radialIndex.isMultiple(of: 2) ? 0 : 0.5
      for stationIndex in 0..<stationCount {
        let shapeIdentity = identityVariation(
          radialIndex: radialIndex,
          stationIndex: stationIndex,
          salt: 0x9E37_79B9
        )
        let materialIdentity = identityVariation(
          radialIndex: radialIndex,
          stationIndex: stationIndex,
          salt: 0xC2B2_AE35
        )
        let tipIdentity = identityVariation(
          radialIndex: radialIndex,
          stationIndex: stationIndex,
          salt: 0x1656_67B1
        )
        let edgeIdentity = identityVariation(
          radialIndex: radialIndex,
          stationIndex: stationIndex,
          salt: 0x68E3_1DA4
        )
        let cycleIdentity = identityVariation(
          radialIndex: radialIndex,
          stationIndex: stationIndex,
          salt: 0x27D4_EB2F
        )
        let baseTheta = 2 * Float.pi * Float(radialIndex) / Float(radialCount)
        let theta =
          baseTheta
          + 0.08 * (2 * Float.pi / Float(radialCount)) * shapeIdentity
        let radial = cos(theta) * first + sin(theta) * second
        let rootFraction = min(
          0.84,
          0.025 + 0.095 * (Float(stationIndex) + stagger)
        )
        let distalFringeWeight = smootherstep(
          min(max((rootFraction - 0.55) / 0.27, 0), 1)
        )
        let tipFraction = min(
          1.13,
          rootFraction
            + 0.30 * (1 + 0.055 * shapeIdentity + 0.025 * tipIdentity)
            + 0.028 * distalFringeWeight * tipIdentity
        )
        let rootRadius = radius(at: rootFraction)
        let tipRadius = radius(at: tipFraction)
        let root = mix(hip, hock, rootFraction) + rootRadius * radial
        let tip = mix(hip, hock, tipFraction) + tipRadius * radial
        let circumferentialSpacing =
          2 * Float.pi * rootRadius / Float(radialCount)
        let maximumWidth =
          max(0.0022, 0.76 * circumferentialSpacing)
          * (1 + 0.04 * shapeIdentity)
        result.append(
          CrowLegPlumageFeather(
            radialIndex: radialIndex,
            stationIndex: stationIndex,
            root: root,
            tip: tip,
            planeNormal: radial,
            rootWidthMeters: 0.54 * maximumWidth,
            maximumWidthMeters: maximumWidth,
            camberMeters: 0.00040 * (1 + 0.10 * shapeIdentity),
            vaneAsymmetry: 0.045 * tipIdentity,
            edgeRippleAmplitude: 0.012 + 0.018 * (0.5 + 0.5 * edgeIdentity),
            edgeRipplePhase: Float.pi * (edgeIdentity + 1),
            edgeRippleCycles: 1.25 + 0.65 * (0.5 + 0.5 * cycleIdentity),
            rootEnvelopeRatio: visibleRootEnvelopeRatio,
            materialVariation: materialIdentity,
            bodyMaterialBlend:
              0.62 - 0.47 * Float(stationIndex) / Float(stationCount - 1)
          )
        )
      }
    }
    return result
  }

  private static func coarseSamples(
    hip: SIMD3<Float>,
    hock: SIMD3<Float>
  ) -> [CrowLegPlumageFeather] {
    let coarseRadialCount = 10
    let coarseStationCount = 5
    let axis = normalized(hock - hip, fallback: SIMD3<Float>(0, 0, -1))
    let helper: SIMD3<Float> =
      abs(axis.z) < 0.82
      ? SIMD3<Float>(0, 0, 1)
      : SIMD3<Float>(0, 1, 0)
    let first = normalized(simd_cross(axis, helper), fallback: SIMD3<Float>(1, 0, 0))
    let second = normalized(simd_cross(axis, first), fallback: SIMD3<Float>(0, 1, 0))
    var result: [CrowLegPlumageFeather] = []
    result.reserveCapacity(coarseRadialCount * coarseStationCount)
    for radialIndex in 0..<coarseRadialCount {
      let theta = 2 * Float.pi * Float(radialIndex) / Float(coarseRadialCount)
      let radial = cos(theta) * first + sin(theta) * second
      let stagger: Float = radialIndex.isMultiple(of: 2) ? 0 : 0.5
      for stationIndex in 0..<coarseStationCount {
        let rootFraction = min(
          0.78,
          0.03 + 0.18 * (Float(stationIndex) + stagger)
        )
        let tipFraction = min(1.10, rootFraction + 0.34)
        let rootRadius = radius(at: rootFraction)
        let tipRadius = radius(at: tipFraction)
        let root = mix(hip, hock, rootFraction) + rootRadius * radial
        let tip = mix(hip, hock, tipFraction) + tipRadius * radial
        let circumferentialSpacing =
          2 * Float.pi * rootRadius / Float(coarseRadialCount)
        let maximumWidth = max(0.0024, 0.68 * circumferentialSpacing)
        result.append(
          CrowLegPlumageFeather(
            radialIndex: radialIndex,
            stationIndex: stationIndex,
            root: root,
            tip: tip,
            planeNormal: radial,
            rootWidthMeters: 0.58 * maximumWidth,
            maximumWidthMeters: maximumWidth,
            camberMeters: 0.00045,
            vaneAsymmetry: 0,
            edgeRippleAmplitude: 0,
            edgeRipplePhase: 0,
            edgeRippleCycles: 0,
            rootEnvelopeRatio: 0.58,
            materialVariation: 0,
            bodyMaterialBlend: 0
          )
        )
      }
    }
    return result
  }

  private static func smootherstep(_ value: Float) -> Float {
    value * value * value * (value * (value * 6 - 15) + 10)
  }

  private static func radius(at fraction: Float) -> Float {
    let clamped = min(max(fraction, 0), 1)
    return proximalUnderlayerRadiusMeters * (1 - clamped)
      + distalUnderlayerRadiusMeters * clamped
      - 0.002 * max(0, fraction - 1) / 0.10
  }

  private static func mix(
    _ first: SIMD3<Float>,
    _ second: SIMD3<Float>,
    _ blend: Float
  ) -> SIMD3<Float> {
    first + blend * (second - first)
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-8 ? value / length : fallback
  }

  private static func identityVariation(
    radialIndex: Int,
    stationIndex: Int,
    salt: UInt32
  ) -> Float {
    var value = UInt32(truncatingIfNeeded: radialIndex) &* 0x9E37_79B9
    value ^= UInt32(truncatingIfNeeded: stationIndex) &* 0x85EB_CA6B
    value ^= salt
    value ^= value >> 16
    value &*= 0x7FEB_352D
    value ^= value >> 15
    value &*= 0x846C_A68B
    value ^= value >> 16
    return 2 * Float(value & 0x00FF_FFFF) / Float(0x00FF_FFFF) - 1
  }
}
