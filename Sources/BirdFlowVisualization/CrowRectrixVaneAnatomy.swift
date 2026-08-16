import BirdFlowMetal
import Foundation

/// Packed topology carried with every persistent feather into the geometry pass.
///
/// The low bytes retain the existing class/side contract. The high bytes add
/// stable order and count so a vane can resolve its anatomical counterpart
/// without depending on transient buffer position or a process-random hash.
enum CrowPersistentFeatherIdentity {
  static func packed(
    feather: BirdRealityFeather,
    order: Int,
    count: Int
  ) -> UInt32 {
    classCode(feather.featherClass)
      | (sideCode(feather.side) << 8)
      | (UInt32(min(max(order, 0), 255)) << 16)
      | (UInt32(min(max(count, 1), 255)) << 24)
  }

  static func classCode(_ featherClass: BirdRealityFeatherClass) -> UInt32 {
    switch featherClass {
    case .primary: return 1
    case .secondary: return 2
    case .tail: return 3
    case .covert: return 4
    case .contour: return 5
    }
  }

  static func sideCode(_ side: BirdRealitySide) -> UInt32 {
    switch side {
    case .center: return 0
    case .left: return 1
    case .right: return 2
    }
  }
}

struct CrowRectrixVaneProfile: Equatable {
  let radialFraction: Float
  let outerSignedWidth: Float
  let maximumWidthScale: Float
  let camberLengthScale: Float
  let vaneAsymmetry: Float
  let camberSkew: Float
  let crownRatio: Float
}

/// Estimated identity-specific surface profile for the six bilateral rectrix
/// pairs. Counterparts share morphology, while successive lateral pairs become
/// gently narrower, flatter, and more asymmetric. These are presentation
/// estimates and do not alter retained length, stable ID, or solver geometry.
enum CrowRectrixVaneAnatomy {
  static func profile(order: Int, count: Int) -> CrowRectrixVaneProfile {
    let safeCount = max(count, 1)
    let fraction =
      Float(min(max(order, 0), safeCount - 1))
      / Float(max(safeCount - 1, 1))
    let centered = 2 * fraction - 1
    let radialFraction = abs(centered)
    let side: Float = centered >= 0 ? 1 : -1
    return CrowRectrixVaneProfile(
      radialFraction: radialFraction,
      outerSignedWidth: -side,
      maximumWidthScale: 1.025 - 0.055 * radialFraction,
      camberLengthScale: 0.034 - 0.007 * radialFraction,
      vaneAsymmetry: 0.025 + 0.045 * radialFraction,
      camberSkew: -0.050 + 0.100 * radialFraction,
      crownRatio: 0.105 + 0.020 * (1 - radialFraction)
    )
  }

  static func profile(packedIdentity: UInt32) -> CrowRectrixVaneProfile? {
    guard packedIdentity & 255 == 3 else { return nil }
    return profile(
      order: Int((packedIdentity >> 16) & 255),
      count: Int((packedIdentity >> 24) & 255)
    )
  }

  static func maximumWidthMeters(
    assetWidthMeters: Float,
    featherClass: BirdRealityFeatherClass,
    order: Int,
    count: Int
  ) -> Float {
    guard featherClass == .tail else { return assetWidthMeters }
    return assetWidthMeters * profile(order: order, count: count).maximumWidthScale
  }

  static func camberMeters(
    lengthMeters: Float,
    featherClass: BirdRealityFeatherClass,
    order: Int,
    count: Int
  ) -> Float {
    if featherClass == .tail {
      return lengthMeters * profile(order: order, count: count).camberLengthScale
    }
    let scale: Float
    switch featherClass {
    case .primary: scale = 0.045
    case .secondary: scale = 0.040
    case .covert: scale = 0.025
    case .contour: scale = 0.020
    case .tail: preconditionFailure("tail handled above")
    }
    return lengthMeters * scale
  }

  static func widthEnvelope(axial rawAxial: Float) -> Float {
    let axial = min(max(rawAxial, 0), 1)
    let body = 0.32 + 0.68 * pow(max(sin(Float.pi * axial), 0), 0.58)
    return body * (1 - 0.985 * pow(axial, 3.2))
  }

  static func halfWidthMeters(
    maximumWidthMeters: Float,
    axial: Float,
    signedWidth: Float,
    profile: CrowRectrixVaneProfile
  ) -> Float {
    let base = maximumWidthMeters * (0.55 + 0.45 * axial) * widthEnvelope(axial: axial)
    let sideScale = 1 - profile.vaneAsymmetry * signedWidth * profile.outerSignedWidth
    return base * sideScale
      * edgeModulation(
        axial: axial,
        signedWidth: signedWidth,
        profile: profile
      )
  }

  /// Bounded paired irregularity along the exposed rectrix vane margins.
  ///
  /// The two sides of a feather receive different phases, while bilateral
  /// counterparts mirror because `outerSignedWidth` reverses with side. The
  /// envelope vanishes at shaft and tip, preserving both attachment and the
  /// locked closed-tail length.
  static func edgeModulation(
    axial rawAxial: Float,
    signedWidth: Float,
    profile: CrowRectrixVaneProfile
  ) -> Float {
    let terms = edgeTerms(
      axial: rawAxial,
      signedWidth: signedWidth,
      profile: profile
    )
    return 1 + terms.amplitude * terms.envelope * terms.wave
  }

  static func edgeModulationAxialDerivative(
    axial rawAxial: Float,
    signedWidth: Float,
    profile: CrowRectrixVaneProfile
  ) -> Float {
    let terms = edgeTerms(
      axial: rawAxial,
      signedWidth: signedWidth,
      profile: profile
    )
    return terms.amplitude
      * (terms.envelopeDerivative * terms.wave
        + terms.envelope * terms.waveAxialDerivative)
  }

  static func edgeModulationSignedWidthDerivative(
    axial rawAxial: Float,
    signedWidth: Float,
    profile: CrowRectrixVaneProfile
  ) -> Float {
    let terms = edgeTerms(
      axial: rawAxial,
      signedWidth: signedWidth,
      profile: profile
    )
    return terms.amplitude * terms.envelope * terms.waveSignedWidthDerivative
  }

  static func camberEnvelope(
    axial rawAxial: Float,
    profile: CrowRectrixVaneProfile
  ) -> Float {
    let axial = min(max(rawAxial, 0), 1)
    return sin(Float.pi * axial) * (1 + profile.camberSkew * (2 * axial - 1))
  }

  private static func edgeTerms(
    axial rawAxial: Float,
    signedWidth: Float,
    profile: CrowRectrixVaneProfile
  ) -> (
    amplitude: Float,
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
    let distalBias = 0.35 + 0.65 * axial
    let envelope = sinePower * distalBias
    let safeSine = max(sine, 1e-6)
    let envelopeDerivative =
      0.9 * pow(safeSine, -0.1) * Float.pi * cosine * distalBias
      + 0.65 * sinePower
    let phase =
      0.55 + 3.2 * profile.radialFraction
      + 0.45 * signedWidth * profile.outerSignedWidth
    let firstAngle = 10 * Float.pi * axial + phase
    let secondAngle = 22 * Float.pi * axial - 0.7 * phase
    let wave = 0.68 * sin(firstAngle) + 0.32 * sin(secondAngle)
    let waveAxialDerivative =
      0.68 * 10 * Float.pi * cos(firstAngle)
      + 0.32 * 22 * Float.pi * cos(secondAngle)
    let phaseSignedWidthDerivative = 0.45 * profile.outerSignedWidth
    let waveSignedWidthDerivative =
      0.68 * cos(firstAngle) * phaseSignedWidthDerivative
      - 0.32 * 0.7 * cos(secondAngle) * phaseSignedWidthDerivative
    return (
      amplitude: 0.018 + 0.008 * profile.radialFraction,
      envelope: envelope,
      envelopeDerivative: envelopeDerivative,
      wave: wave,
      waveAxialDerivative: waveAxialDerivative,
      waveSignedWidthDerivative: waveSignedWidthDerivative
    )
  }
}
