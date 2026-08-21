import Foundation

/// Identity-derived presentation morphology for retained wing coverts.
///
/// The packed order traverses three secondary-covert courses of 27 stations;
/// primary coverts use one 27-station course. Bilateral counterparts share all
/// scalar morphology and reverse only the exposed signed-width axis.
struct CrowCovertVaneProfile: Equatable {
  let featherClass: UInt32
  let spanFraction: Float
  let courseFraction: Float
  let exposedSignedWidth: Float
  let vaneAsymmetry: Float
  let camberSkew: Float
  let crownRatio: Float
  let rootWidthRatio: Float
  let edgeAmplitude: Float
  let edgePhase: Float
  let firstEdgeCycles: Float
  let secondEdgeCycles: Float
}

/// Bounded non-cloned vane shape for reverse-wing classes 12/13 and dorsal
/// trailing-rank classes 14/15.
///
/// The values are estimated render morphology. They encode only general
/// feather principles—layered overlap, bilateral mirroring, and a structured
/// distal pennaceous margin—and are not measurements from an American crow.
enum CrowCovertVaneAnatomy {
  static let secondaryClass: UInt32 = 12
  static let primaryClass: UInt32 = 13
  static let trailingProximalClass =
    CrowTrailingCovertRanks.proximalSurfaceFeatherClass
  static let trailingDistalClass =
    CrowTrailingCovertRanks.distalSurfaceFeatherClass
  static let spanStationCount = 27

  static func profile(packedIdentity: UInt32) -> CrowCovertVaneProfile? {
    profile(
      featherClass: packedIdentity & 255,
      sideCode: (packedIdentity >> 8) & 255,
      order: Int((packedIdentity >> 16) & 255),
      count: Int((packedIdentity >> 24) & 255)
    )
  }

  static func profile(
    featherClass: UInt32,
    sideCode: UInt32,
    order: Int,
    count: Int
  ) -> CrowCovertVaneProfile? {
    guard isLiveCovertClass(featherClass) else {
      return nil
    }
    let courseCount = featherClass == secondaryClass ? 3 : 1
    let safeCount = max(count, 1)
    let resolvedSpanCount = max(safeCount / courseCount, 1)
    let safeOrder = min(max(order, 0), safeCount - 1)
    let courseIndex =
      featherClass == secondaryClass
      ? min(safeOrder / resolvedSpanCount, courseCount - 1)
      : 0
    let spanOrder = safeOrder % resolvedSpanCount
    let spanFraction = Float(spanOrder) / Float(max(resolvedSpanCount - 1, 1))
    let courseFraction: Float
    switch featherClass {
    case secondaryClass:
      courseFraction = Float(courseIndex) / Float(courseCount)
    case trailingProximalClass:
      courseFraction = 0.42
    default:
      courseFraction = 1
    }
    let distalFraction = abs(2 * spanFraction - 1)
    let exposedSignedWidth: Float = sideCode == 2 ? -1 : 1
    return CrowCovertVaneProfile(
      featherClass: featherClass,
      spanFraction: spanFraction,
      courseFraction: courseFraction,
      exposedSignedWidth: exposedSignedWidth,
      vaneAsymmetry: 0.012 + 0.010 * courseFraction
        + 0.006 * distalFraction,
      camberSkew: -0.035 + 0.050 * courseFraction
        + 0.020 * (spanFraction - 0.5),
      crownRatio: 0.052 - 0.015 * courseFraction
        + 0.004 * (1 - distalFraction),
      rootWidthRatio: isTrailingRankClass(featherClass)
        ? 0.44 / 0.78
        : 0.585 + 0.030 * (1 - courseFraction)
          + 0.005 * (1 - distalFraction),
      edgeAmplitude: 0.007 + 0.004 * courseFraction
        + 0.002 * distalFraction,
      edgePhase: 0.45 + 2.15 * spanFraction + 0.85 * courseFraction,
      firstEdgeCycles: 3.75 + 1.25 * courseFraction,
      secondEdgeCycles: 8.25 + 1.75 * courseFraction
    )
  }

  static func isLiveCovertClass(_ featherClass: UInt32) -> Bool {
    featherClass == secondaryClass || featherClass == primaryClass
      || isTrailingRankClass(featherClass)
  }

  static func isTrailingRankClass(_ featherClass: UInt32) -> Bool {
    featherClass == trailingProximalClass || featherClass == trailingDistalClass
  }

  static func geometryAxialFraction(
    localAxialFraction: Float,
    featherClass: UInt32
  ) -> Float {
    guard
      let rank = CrowTrailingCovertRanks.rank(
        forSurfaceFeatherClass: featherClass
      )
    else { return min(max(localAxialFraction, 0), 1) }
    return CrowTrailingCovertRanks.globalAxialFraction(
      rank: rank,
      localAxialFraction: localAxialFraction
    )
  }

  static func rankCoverageScale(
    localAxialFraction: Float,
    featherClass: UInt32
  ) -> Float {
    guard
      let rank = CrowTrailingCovertRanks.rank(
        forSurfaceFeatherClass: featherClass
      )
    else { return 1 }
    return CrowTrailingCovertRanks.coverageWeight(
      rank: rank,
      axialFraction: CrowTrailingCovertRanks.globalAxialFraction(
        rank: rank,
        localAxialFraction: localAxialFraction
      )
    )
  }

  static func rankNormalOffsetMeters(
    localAxialFraction: Float,
    featherClass: UInt32
  ) -> Float {
    guard
      let rank = CrowTrailingCovertRanks.rank(
        forSurfaceFeatherClass: featherClass
      )
    else { return 0 }
    return CrowTrailingCovertRanks.normalOffsetMeters(
      rank: rank,
      axialFraction: CrowTrailingCovertRanks.globalAxialFraction(
        rank: rank,
        localAxialFraction: localAxialFraction
      )
    )
  }

  static func edgeModulation(
    axial rawAxial: Float,
    signedWidth: Float,
    profile: CrowCovertVaneProfile
  ) -> Float {
    let terms = edgeTerms(
      axial: rawAxial,
      signedWidth: signedWidth,
      profile: profile
    )
    return 1 + profile.edgeAmplitude * terms.envelope * terms.wave
  }

  static func edgeModulationAxialDerivative(
    axial rawAxial: Float,
    signedWidth: Float,
    profile: CrowCovertVaneProfile
  ) -> Float {
    let terms = edgeTerms(
      axial: rawAxial,
      signedWidth: signedWidth,
      profile: profile
    )
    return profile.edgeAmplitude
      * (terms.envelopeDerivative * terms.wave
        + terms.envelope * terms.waveAxialDerivative)
  }

  static func edgeModulationSignedWidthDerivative(
    axial rawAxial: Float,
    signedWidth: Float,
    profile: CrowCovertVaneProfile
  ) -> Float {
    let terms = edgeTerms(
      axial: rawAxial,
      signedWidth: signedWidth,
      profile: profile
    )
    return profile.edgeAmplitude * terms.envelope * terms.waveSignedWidthDerivative
  }

  static func camberEnvelope(
    axial rawAxial: Float,
    profile: CrowCovertVaneProfile
  ) -> Float {
    let axial = min(max(rawAxial, 0), 1)
    return sin(Float.pi * axial) * (1 + profile.camberSkew * (2 * axial - 1))
  }

  private static func edgeTerms(
    axial rawAxial: Float,
    signedWidth: Float,
    profile: CrowCovertVaneProfile
  ) -> (
    envelope: Float,
    envelopeDerivative: Float,
    wave: Float,
    waveAxialDerivative: Float,
    waveSignedWidthDerivative: Float
  ) {
    let axial = min(max(rawAxial, 0), 1)
    let sine = max(sin(Float.pi * axial), 0)
    let cosine = cos(Float.pi * axial)
    let sinePower = pow(sine, 0.9)
    let distalBias = 0.42 + 0.58 * axial
    let envelope = sinePower * distalBias
    let envelopeDerivative =
      0.9 * pow(max(sine, 1e-6), -0.1) * Float.pi * cosine * distalBias
      + 0.58 * sinePower
    let phase =
      profile.edgePhase
      + 0.42 * signedWidth * profile.exposedSignedWidth
    let firstFrequency = 2 * Float.pi * profile.firstEdgeCycles
    let secondFrequency = 2 * Float.pi * profile.secondEdgeCycles
    let firstAngle = firstFrequency * axial + phase
    let secondAngle = secondFrequency * axial - 0.68 * phase
    let wave = 0.70 * sin(firstAngle) + 0.30 * sin(secondAngle)
    let waveAxialDerivative =
      0.70 * firstFrequency * cos(firstAngle)
      + 0.30 * secondFrequency * cos(secondAngle)
    let phaseSignedWidthDerivative = 0.42 * profile.exposedSignedWidth
    let waveSignedWidthDerivative =
      0.70 * cos(firstAngle) * phaseSignedWidthDerivative
      - 0.30 * 0.68 * cos(secondAngle) * phaseSignedWidthDerivative
    return (
      envelope: envelope,
      envelopeDerivative: envelopeDerivative,
      wave: wave,
      waveAxialDerivative: waveAxialDerivative,
      waveSignedWidthDerivative: waveSignedWidthDerivative
    )
  }
}
