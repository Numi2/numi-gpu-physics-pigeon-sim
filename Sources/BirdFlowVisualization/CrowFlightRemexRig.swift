import simd

/// Estimated visible flight-feather arrangement attached to the existing
/// accepted-state wing surface. This is presentation geometry, not a physical
/// feather, measured crow joint, or an additional aerodynamic authority.
enum CrowFlightRemexRig {
  enum Kind { case primary, secondary }

  struct Feather {
    let kind: Kind
    let ordinal: Int
    let root: SIMD3<Float>
    let tip: SIMD3<Float>
    let normal: SIMD3<Float>
    /// Width of one side of the vane, in metres.
    let halfWidth: Float
  }

  static let primaryCount = 10
  static let secondaryCount = 11

  /// Bilinear point on the live, fixed 33 x 9 surface.
  static func point(
    _ states: [SIMD3<Float>], offset: Int, span: Float, chord: Float
  ) -> SIMD3<Float> {
    let s = min(max(span, 0), 32)
    let c = min(max(chord, 0), 8)
    let s0 = Int(s), c0 = Int(c)
    let s1 = min(s0 + 1, 32), c1 = min(c0 + 1, 8)
    let fs = s - Float(s0), fc = c - Float(c0)
    let a = states[offset + s0 * 9 + c0]
    let b = states[offset + s0 * 9 + c1]
    let d = states[offset + s1 * 9 + c0]
    let e = states[offset + s1 * 9 + c1]
    return (a + (b - a) * fc) * (1 - fs) + (d + (e - d) * fc) * fs
  }

  static func feathers(
    states: [SIMD3<Float>], offset: Int, left: Bool
  ) -> [Feather] {
    precondition(offset >= 0 && offset + 297 <= states.count)
    func at(_ s: Float, _ c: Float) -> SIMD3<Float> {
      point(states, offset: offset, span: s, chord: c)
    }
    func normalized(_ v: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
      let length = simd_length(v)
      return length > 1e-7 && length.isFinite ? v / length : fallback
    }
    var result: [Feather] = []
    result.reserveCapacity(primaryCount + secondaryCount)
    // Trailing arm feathers, ordered from body to wrist.
    for index in 0..<secondaryCount {
      let f = Float(index) / Float(secondaryCount - 1)
      let span = 11 + 8.5 * f
      let root = at(span, 1.5)
      let target = at(span + 1.5, 7.7)
      let direction = normalized(target - root, fallback: SIMD3(-1, 0, 0))
      let spanDirection = normalized(at(span + 2, 2) - at(max(0, span - 2), 2),
        fallback: SIMD3(0, left ? 1 : -1, 0))
      let normal = CrowFlightWingBodyIntegration.covertSurfaceNormal(
        chordDirection: direction, spanDirection: spanDirection, left: left)
      result.append(Feather(
        kind: .secondary, ordinal: index, root: root,
        tip: target,
        normal: normal, halfWidth: 0.014 - 0.0015 * f))
    }
    // The hand feathers fan progressively outward beyond the wrist rather
    // than all pointing parallel to the outer boundary.
    for index in 0..<primaryCount {
      let f = Float(index) / Float(primaryCount - 1)
      let rootSpan = 19 + 4.5 * f
      let root = at(rootSpan, 1.4 - 0.5 * f)
      let target = at(20.5 + 10.5 * f, 7.6 - 4 * f)
      let fallback = SIMD3<Float>(0, left ? 1 : -1, 0)
      let direction = normalized(target - root, fallback: fallback)
      let spanDirection = normalized(at(min(rootSpan + 3, 32), 1)
        - at(max(rootSpan - 3, 0), 1), fallback: fallback)
      let normal = CrowFlightWingBodyIntegration.covertSurfaceNormal(
        chordDirection: direction, spanDirection: spanDirection, left: left)
      result.append(Feather(
        kind: .primary, ordinal: index, root: root,
        tip: target + direction * (0.012 + 0.030 * f),
        normal: normal, halfWidth: 0.014 - 0.0025 * f))
    }
    return result
  }
}
