import Foundation
import simd

/// Estimated axial envelope used by the presentation mesh.
///
/// The profile is intentionally asymmetric in Z: a crow's dorsal mantle and
/// ventral breast/keel do not form the rotationally symmetric egg produced by
/// an ellipsoid. The final three rings form a closed cervical sleeve whose cap
/// sits inside the cranial loft, avoiding a visible flat body cap at the neck.
/// These are artistic, species-informed dimensions, not measured joint centers
/// or a same-specimen reconstruction.
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
    .init(x: 0.142, z: 0.050, halfWidth: 0.034, dorsalRadius: 0.037, ventralRadius: 0.031),
    .init(x: 0.150, z: 0.052, halfWidth: 0.032, dorsalRadius: 0.040, ventralRadius: 0.032),
    .init(x: 0.162, z: 0.055, halfWidth: 0.0295, dorsalRadius: 0.0335, ventralRadius: 0.028),
    .init(x: 0.174, z: 0.056, halfWidth: 0.024, dorsalRadius: 0.026, ventralRadius: 0.022),
    .init(x: 0.184, z: 0.055, halfWidth: 0.014, dorsalRadius: 0.016, ventralRadius: 0.013),
  ]

  static let sternumRingIndex = 5
  static let shoulderRingIndex = 6
  static let neckRingRange = 7...9
  static let visibleAnteriorRingIndex = 11
  static let cervicalSleeveRingRange = 12...14

  static func verticalRadius(
    for sine: Float,
    ring: CrowBodyLoftRing
  ) -> Float {
    sine >= 0 ? ring.dorsalRadius : ring.ventralRadius
  }

  static func interpolatedRing(atX x: Float) -> CrowBodyLoftRing {
    guard let first = loftRings.first, let last = loftRings.last else {
      preconditionFailure("crow body loft requires at least one ring")
    }
    if x <= first.x { return first }
    if x >= last.x { return last }
    for index in 0..<(loftRings.count - 1) {
      let lower = loftRings[index]
      let upper = loftRings[index + 1]
      guard x <= upper.x else { continue }
      let blend = (x - lower.x) / (upper.x - lower.x)
      return CrowBodyLoftRing(
        x: x,
        z: mix(lower.z, upper.z, blend),
        halfWidth: mix(lower.halfWidth, upper.halfWidth, blend),
        dorsalRadius: mix(lower.dorsalRadius, upper.dorsalRadius, blend),
        ventralRadius: mix(lower.ventralRadius, upper.ventralRadius, blend)
      )
    }
    return last
  }

  static func surfacePoint(
    ring: CrowBodyLoftRing,
    theta: Float
  ) -> SIMD3<Float> {
    let sine = sin(theta)
    let cosine = cos(theta)
    let verticalRadius = verticalRadius(for: sine, ring: ring)
    let verticalExponent: Float = sine >= 0 ? 1.12 : 0.84
    let verticalFraction = copySign(
      pow(abs(sine), verticalExponent),
      sine
    )
    return SIMD3<Float>(
      ring.x,
      cosine * ring.halfWidth * lateralScale(for: sine, ring: ring),
      ring.z + verticalFraction * verticalRadius
    )
  }

  static func surfacePoint(
    atX x: Float,
    theta: Float
  ) -> SIMD3<Float> {
    surfacePoint(ring: interpolatedRing(atX: x), theta: theta)
  }

  static func surfaceNormal(
    atX x: Float,
    theta: Float
  ) -> SIMD3<Float> {
    let axialStep: Float = 0.0005
    let angularStep: Float = 0.002
    let firstX = loftRings.first!.x
    let lastX = loftRings.last!.x
    let axialTangent =
      surfacePoint(atX: min(lastX, x + axialStep), theta: theta)
      - surfacePoint(atX: max(firstX, x - axialStep), theta: theta)
    let angularTangent =
      surfacePoint(atX: x, theta: theta + angularStep)
      - surfacePoint(atX: x, theta: theta - angularStep)
    let normal = simd_cross(angularTangent, axialTangent)
    let length = simd_length(normal)
    return length > 1e-10
      ? normal / length
      : SIMD3<Float>(0, cos(theta), sin(theta))
  }

  private static func lateralScale(
    for sine: Float,
    ring: CrowBodyLoftRing
  ) -> Float {
    let shoulderWeight = clamp(1 - abs(ring.x - 0.030) / 0.120)
    let pelvicWeight = clamp((-ring.x - 0.035) / 0.130)
    let upperFlankWeight = clamp(1 - abs(sine - 0.30) / 0.70)
    let lowerFlankWeight = clamp(1 - abs(sine + 0.45) / 0.55)
    return max(
      0.68,
      1 + 0.10 * shoulderWeight * upperFlankWeight
        - (0.18 + 0.08 * pelvicWeight) * lowerFlankWeight
    )
  }

  private static func clamp(_ value: Float) -> Float {
    min(max(value, 0), 1)
  }

  private static func copySign(_ magnitude: Float, _ sign: Float) -> Float {
    sign < 0 ? -magnitude : magnitude
  }

  private static func mix(_ first: Float, _ second: Float, _ blend: Float) -> Float {
    first + blend * (second - first)
  }
}
