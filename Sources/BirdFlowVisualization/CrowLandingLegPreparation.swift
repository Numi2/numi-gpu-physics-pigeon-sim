import simd

/// Presentation-only estimate, driven by accepted perch-relative position.
/// It is neither a contact detector nor a change to the flight controller.
enum CrowLandingLegPreparation {
  static func weight(completed: Bool, rootInPerch: SIMD3<Float>) -> Float {
    guard completed, rootInPerch.x.isFinite, rootInPerch.y.isFinite,
      rootInPerch.z.isFinite else { return 0 }
    func smooth(_ x: Float) -> Float {
      let t = min(max(x, 0), 1)
      return t * t * (3 - 2 * t)
    }
    let side = smooth((0.24 - abs(rootInPerch.x)) / 0.13)
    let length = smooth((0.85 - abs(rootInPerch.y)) / 0.13)
    let heightAboveTop = rootInPerch.z - 0.055
    let descent = smooth((0.34 - heightAboveTop) / 0.16)
    return side * length * descent
  }
}
