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
    .init(x: -0.190, z: 0.000, halfWidth: 0.009, dorsalRadius: 0.011, ventralRadius: 0.010),
    .init(x: -0.165, z: -0.002, halfWidth: 0.027, dorsalRadius: 0.029, ventralRadius: 0.027),
    .init(x: -0.130, z: -0.006, halfWidth: 0.043, dorsalRadius: 0.041, ventralRadius: 0.043),
    .init(x: -0.090, z: -0.007, halfWidth: 0.054, dorsalRadius: 0.049, ventralRadius: 0.054),
    .init(x: -0.045, z: -0.003, halfWidth: 0.060, dorsalRadius: 0.053, ventralRadius: 0.060),
    .init(x: 0.000, z: 0.006, halfWidth: 0.061, dorsalRadius: 0.054, ventralRadius: 0.063),
    .init(x: 0.044, z: 0.018, halfWidth: 0.059, dorsalRadius: 0.054, ventralRadius: 0.057),
    .init(x: 0.083, z: 0.029, halfWidth: 0.052, dorsalRadius: 0.050, ventralRadius: 0.048),
    .init(x: 0.105, z: 0.038, halfWidth: 0.042, dorsalRadius: 0.042, ventralRadius: 0.039),
    .init(x: 0.125, z: 0.045, halfWidth: 0.036, dorsalRadius: 0.038, ventralRadius: 0.035),
    .init(x: 0.142, z: 0.050, halfWidth: 0.029, dorsalRadius: 0.032, ventralRadius: 0.029),
    .init(x: 0.150, z: 0.052, halfWidth: 0.022, dorsalRadius: 0.026, ventralRadius: 0.023),
  ]

  static let sternumRingIndex = 5
  static let shoulderRingIndex = 6
  static let neckRingRange = 7...9

  static func verticalRadius(
    for sine: Float,
    ring: CrowBodyLoftRing
  ) -> Float {
    sine >= 0 ? ring.dorsalRadius : ring.ventralRadius
  }
}
