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
  static let posteriorPrimaryOverlapMaximumWidthScale: Float = 1.80
  static let posteriorSecondaryOverlapMaximumWidthScale: Float = 1.35
  static let terminalPrimaryBroadEdgeMaximumScale: Float = 1.12
  static let terminalPrimaryFoldedJunctionMaximumScale: Float = 1.35
  static let terminalSecondaryFoldedJunctionMaximumScale: Float = 1.28

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

  /// Broadens only the last secondary and its immediate neighbor where the
  /// folded remex stack meets the outer primary, caudal covert course, and
  /// rectrix shell. Length, rachis, camber, and all other vanes are unchanged.
  static func posteriorSecondaryOverlapWidthScale(
    featherClass: BirdRealityFeatherClass,
    order: Int,
    count: Int
  ) -> Float {
    guard featherClass == .secondary else { return 1 }
    let distance = Float(max(count - 1 - order, 0))
    let weight = max(0, 1 - distance / 2)
    return 1 + (posteriorSecondaryOverlapMaximumWidthScale - 1) * weight
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

  /// Adds a short, smooth overlap course along the broad edge of only the
  /// terminal primary. The mirrored dorsal axis selects the corresponding
  /// edge on each wing, while the rachis, opposite vane, and feather tip stay
  /// fixed.
  static func terminalPrimaryBroadEdgeTerms(
    axial rawAxial: Float,
    signedWidth: Float,
    packedIdentity: UInt32
  ) -> (scale: Float, axialDerivative: Float, signedWidthDerivative: Float) {
    let featherClass = packedIdentity & 255
    let order = (packedIdentity >> 16) & 255
    let count = max((packedIdentity >> 24) & 255, 1)
    guard featherClass == 1, order + 1 == count,
      let profile = profile(packedIdentity: packedIdentity)
    else { return (1, 0, 0) }

    let axial = min(max(rawAxial, 0), 1)
    let rise = smoothstepTerms(value: axial, lower: 0.40, upper: 0.50)
    let fall = smoothstepTerms(value: axial, lower: 0.625, upper: 0.725)
    let axialEnvelope = rise.value * (1 - fall.value)
    let axialEnvelopeDerivative =
      rise.derivative * (1 - fall.value) - rise.value * fall.derivative

    let broadEdgeCoordinate = -signedWidth * profile.dorsalSignedWidth
    let edge = smoothstepTerms(value: broadEdgeCoordinate, lower: 0, upper: 1)
    let edgeSignedWidthDerivative = -profile.dorsalSignedWidth * edge.derivative
    let amplitude = terminalPrimaryBroadEdgeMaximumScale - 1
    return (
      scale: 1 + amplitude * axialEnvelope * edge.value,
      axialDerivative: amplitude * axialEnvelopeDerivative * edge.value,
      signedWidthDerivative: amplitude * axialEnvelope * edgeSignedWidthDerivative
    )
  }

  /// Closes the crossing course where the terminal primary's inner vane meets
  /// the terminal secondary's outer vane in the folded stack. Each wing uses
  /// mirrored signed edges, and both feathers retain an unchanged rachis,
  /// opposite edge, base, and tip.
  static func terminalFoldedRemexJunctionTerms(
    axial rawAxial: Float,
    signedWidth: Float,
    packedIdentity: UInt32
  ) -> (scale: Float, axialDerivative: Float, signedWidthDerivative: Float) {
    let featherClass = packedIdentity & 255
    let order = (packedIdentity >> 16) & 255
    let count = max((packedIdentity >> 24) & 255, 1)
    guard (featherClass == 1 || featherClass == 2), order + 1 == count,
      let profile = profile(packedIdentity: packedIdentity)
    else { return (1, 0, 0) }

    let axial = min(max(rawAxial, 0), 1)
    let isPrimary = featherClass == 1
    let rise = smoothstepTerms(
      value: axial,
      lower: isPrimary ? 0.16 : 0.38,
      upper: isPrimary ? 0.25 : 0.50
    )
    let fall = smoothstepTerms(
      value: axial,
      lower: isPrimary ? 0.375 : 0.75,
      upper: isPrimary ? 0.46 : 0.84
    )
    let axialEnvelope = rise.value * (1 - fall.value)
    let axialEnvelopeDerivative =
      rise.derivative * (1 - fall.value) - rise.value * fall.derivative

    let edgeSign: Float = isPrimary ? 1 : -1
    let junctionEdgeCoordinate =
      edgeSign * signedWidth * profile.dorsalSignedWidth
    let edge = smoothstepTerms(value: junctionEdgeCoordinate, lower: 0, upper: 1)
    let edgeSignedWidthDerivative =
      edgeSign * profile.dorsalSignedWidth * edge.derivative
    let maximumScale =
      isPrimary
      ? terminalPrimaryFoldedJunctionMaximumScale
      : terminalSecondaryFoldedJunctionMaximumScale
    let amplitude = maximumScale - 1
    return (
      scale: 1 + amplitude * axialEnvelope * edge.value,
      axialDerivative: amplitude * axialEnvelopeDerivative * edge.value,
      signedWidthDerivative: amplitude * axialEnvelope * edgeSignedWidthDerivative
    )
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

  private static func smoothstepTerms(
    value: Float,
    lower: Float,
    upper: Float
  ) -> (value: Float, derivative: Float) {
    guard value > lower, value < upper else {
      return (value >= upper ? 1 : 0, 0)
    }
    let normalized = (value - lower) / (upper - lower)
    return (
      value: normalized * normalized * (3 - 2 * normalized),
      derivative: 6 * normalized * (1 - normalized) / (upper - lower)
    )
  }
}
