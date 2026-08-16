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
  }

  static func camberEnvelope(
    axial rawAxial: Float,
    profile: CrowRectrixVaneProfile
  ) -> Float {
    let axial = min(max(rawAxial, 0), 1)
    return sin(Float.pi * axial) * (1 + profile.camberSkew * (2 * axial - 1))
  }
}
