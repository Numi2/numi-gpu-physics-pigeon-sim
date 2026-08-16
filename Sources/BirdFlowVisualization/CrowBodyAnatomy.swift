import simd

/// Estimated axial envelope used by the presentation mesh.
///
/// The profile is intentionally asymmetric in Z: a crow's dorsal mantle and
/// ventral breast/keel do not form the rotationally symmetric egg produced by
/// an ellipsoid. These are artistic, species-informed dimensions, not measured
/// joint centers or a same-specimen reconstruction.
struct CrowBodyLoftRing: Equatable {
  let x: Float
  let z: Float
  let halfWidth: Float
  let dorsalRadius: Float
  let ventralRadius: Float
}

enum CrowBodyAnatomy {
  static let loftRings: [CrowBodyLoftRing] = [
    .init(x: -0.182, z: -0.003, halfWidth: 0.010, dorsalRadius: 0.014, ventralRadius: 0.012),
    .init(x: -0.158, z: -0.006, halfWidth: 0.029, dorsalRadius: 0.034, ventralRadius: 0.031),
    .init(x: -0.121, z: -0.009, halfWidth: 0.047, dorsalRadius: 0.048, ventralRadius: 0.047),
    .init(x: -0.078, z: -0.009, halfWidth: 0.058, dorsalRadius: 0.054, ventralRadius: 0.058),
    .init(x: -0.032, z: -0.005, halfWidth: 0.063, dorsalRadius: 0.057, ventralRadius: 0.066),
    .init(x: 0.014, z: 0.003, halfWidth: 0.065, dorsalRadius: 0.059, ventralRadius: 0.071),
    .init(x: 0.055, z: 0.014, halfWidth: 0.063, dorsalRadius: 0.060, ventralRadius: 0.063),
    .init(x: 0.094, z: 0.026, halfWidth: 0.055, dorsalRadius: 0.055, ventralRadius: 0.052),
    .init(x: 0.128, z: 0.036, halfWidth: 0.046, dorsalRadius: 0.049, ventralRadius: 0.043),
    .init(x: 0.157, z: 0.041, halfWidth: 0.035, dorsalRadius: 0.039, ventralRadius: 0.033),
    .init(x: 0.181, z: 0.039, halfWidth: 0.022, dorsalRadius: 0.027, ventralRadius: 0.023),
  ]

  static let sternumRingIndex = 5
  static let shoulderRingIndex = 6
  static let neckRingRange = 8...10

  static func verticalRadius(
    for sine: Float,
    ring: CrowBodyLoftRing
  ) -> Float {
    sine >= 0 ? ring.dorsalRadius : ring.ventralRadius
  }
}
