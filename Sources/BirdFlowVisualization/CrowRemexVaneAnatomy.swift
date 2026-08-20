import BirdFlowMetal
import Foundation

struct CrowRemexVaneProfile: Equatable {
  let featherClass: UInt32
  let seriesFraction: Float
  let dorsalSignedWidth: Float
  let maximumWidthScale: Float
  let camberLengthScale: Float
  let vaneAsymmetry: Float
  let camberSkew: Float
  let crownRatio: Float
  let edgeAmplitude: Float
  let edgePhase: Float
  let firstEdgeCycles: Float
  let secondEdgeCycles: Float
}

/// Identity-specific vane morphology for persistent primaries and secondaries.
///
/// Primaries become progressively flatter and more asymmetric toward the long
/// outer series. Secondaries retain a broader, more crowned vane. Bilateral
/// counterparts reverse only the signed dorsal axis, so the physical shape is
/// mirrored rather than independently randomized.
enum CrowRemexVaneAnatomy {
  static let posteriorPrimaryOverlapMaximumWidthScale: Float = 1.60

  /// Broadens only the two caudal-most primary vanes where their folded
  /// envelope meets the posterior secondary and live covert shell. Rachis
  /// position, length, camber, and the other remiges remain unchanged.
  static func posteriorPrimaryOverlapWidthScale(
    featherClass: BirdRealityFeatherClass,
    order: Int,
    count: Int
  ) -> Float {
    guard featherClass == .primary else { return 1 }
    let fraction = Float(min(max(order, 0), max(count - 1, 0)))
      / Float(max(count - 1, 1))
    let weight = min(max((fraction - 0.8) / 0.2, 0), 1)
    return 1 + (posteriorPrimaryOverlapMaximumWidthScale - 1) * weight
  }

  static func profile(
    featherClass: BirdRealityFeatherClass,
    order: Int,
    count: Int
  ) -> CrowRemexVaneProfile? {
    let classCode: UInt32
    switch featherClass {
    case .primary: classCode = 1
    case .secondary: classCode = 2
    default: return nil
    }
    return profile(
      featherClass: classCode,
      sideCode: 1,
      order: order,
      count: count
    )
  }

  static func profile(packedIdentity: UInt32) -> CrowRemexVaneProfile? {
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
  ) -> CrowRemexVaneProfile? {
    guard featherClass == 1 || featherClass == 2 else { return nil }
    let safeCount = max(count, 1)
    let fraction =
      Float(min(max(order, 0), safeCount - 1))
      / Float(max(safeCount - 1, 1))
    let dorsalSignedWidth: Float = sideCode == 2 ? -1 : 1
    if featherClass == 1 {
      return CrowRemexVaneProfile(
        featherClass: featherClass,
        seriesFraction: fraction,
        dorsalSignedWidth: dorsalSignedWidth,
        maximumWidthScale: 1.010 - 0.020 * fraction,
        camberLengthScale: 0.041 - 0.007 * fraction,
        vaneAsymmetry: 0.075 + 0.095 * fraction,
        camberSkew: 0.015 + 0.055 * fraction,
        crownRatio: 0.122 - 0.018 * fraction,
        edgeAmplitude: 0.012 + 0.008 * fraction,
        edgePhase: 0.65 + 2.70 * fraction,
        firstEdgeCycles: 5,
        secondEdgeCycles: 11
      )
    }
    return CrowRemexVaneProfile(
      featherClass: featherClass,
      seriesFraction: fraction,
      dorsalSignedWidth: dorsalSignedWidth,
      maximumWidthScale: 1.015 - 0.012 * fraction,
      camberLengthScale: 0.046 - 0.004 * fraction,
      vaneAsymmetry: 0.040 + 0.035 * fraction,
      camberSkew: -0.035 + 0.025 * fraction,
      crownRatio: 0.158 - 0.012 * fraction,
      edgeAmplitude: 0.010 + 0.004 * fraction,
      edgePhase: 1.10 + 2.10 * fraction,
      firstEdgeCycles: 4,
      secondEdgeCycles: 9
    )
  }

  static func edgeModulation(
    axial rawAxial: Float,
    signedWidth: Float,
    profile: CrowRemexVaneProfile
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
    profile: CrowRemexVaneProfile
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
    profile: CrowRemexVaneProfile
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
    profile: CrowRemexVaneProfile
  ) -> Float {
    let axial = min(max(rawAxial, 0), 1)
    return sin(Float.pi * axial) * (1 + profile.camberSkew * (2 * axial - 1))
  }

  private static func edgeTerms(
    axial rawAxial: Float,
    signedWidth: Float,
    profile: CrowRemexVaneProfile
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
    let distalBias = 0.30 + 0.70 * axial
    let envelope = sinePower * distalBias
    let envelopeDerivative =
      0.9 * pow(max(sine, 1e-6), -0.1) * Float.pi * cosine * distalBias
      + 0.70 * sinePower
    let phase =
      profile.edgePhase
      + 0.38 * signedWidth * profile.dorsalSignedWidth
    let firstFrequency = 2 * Float.pi * profile.firstEdgeCycles
    let secondFrequency = 2 * Float.pi * profile.secondEdgeCycles
    let firstAngle = firstFrequency * axial + phase
    let secondAngle = secondFrequency * axial - 0.65 * phase
    let wave = 0.72 * sin(firstAngle) + 0.28 * sin(secondAngle)
    let waveAxialDerivative =
      0.72 * firstFrequency * cos(firstAngle)
      + 0.28 * secondFrequency * cos(secondAngle)
    let phaseSignedWidthDerivative = 0.38 * profile.dorsalSignedWidth
    let waveSignedWidthDerivative =
      0.72 * cos(firstAngle) * phaseSignedWidthDerivative
      - 0.28 * 0.65 * cos(secondAngle) * phaseSignedWidthDerivative
    return (
      envelope: envelope,
      envelopeDerivative: envelopeDerivative,
      wave: wave,
      waveAxialDerivative: waveAxialDerivative,
      waveSignedWidthDerivative: waveSignedWidthDerivative
    )
  }
}
