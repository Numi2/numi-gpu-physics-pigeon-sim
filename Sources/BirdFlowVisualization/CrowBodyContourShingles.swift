import simd

struct CrowBodyContourShingle: Equatable {
  let radialIndex: Int
  let axialIndex: Int
  let rootOffset: SIMD3<Float>
  let tipOffset: SIMD3<Float>
  let planeNormal: SIMD3<Float>
  let rootWidthMeters: Float
  let maximumWidthMeters: Float
  let camberMeters: Float
}

/// Dense, imbricated contour coverage over the asymmetric body loft.
///
/// Each root is sampled from the same loft that owns the visible trunk. Width
/// follows local circumferential spacing and every feather extends beyond the
/// following axial root, creating a roof-tile shell instead of isolated leaves.
enum CrowBodyContourShingles {
  static let radialCount = 20
  static let axialCount = 16
  static let shellClearanceMeters: Float = 0.0008

  private static let frontX: Float = 0.110
  private static let backX: Float = -0.160

  static func samples() -> [CrowBodyContourShingle] {
    var result: [CrowBodyContourShingle] = []
    result.reserveCapacity(radialCount * axialCount)
    for radialIndex in 0..<radialCount {
      let theta = 2 * Float.pi * Float(radialIndex) / Float(radialCount)
      let sine = sin(theta)
      let cosine = cos(theta)
      let stagger: Float = radialIndex.isMultiple(of: 2) ? 0 : 0.5
      for axialIndex in 0..<axialCount {
        let axial =
          (Float(axialIndex) + stagger) / Float(axialCount)
        let rootX = mix(frontX, backX, axial)
        let rootRing = CrowBodyAnatomy.interpolatedRing(atX: rootX)
        let rootNormal = surfaceNormal(
          ring: rootRing,
          sine: sine,
          cosine: cosine
        )
        let rootShell = shellPoint(
          ring: rootRing,
          sine: sine,
          cosine: cosine
        )
        let localRadius = sqrt(
          square(rootRing.halfWidth * sine)
            + square(CrowBodyAnatomy.verticalRadius(for: sine, ring: rootRing) * cosine)
        )
        let circumferentialSpacing =
          2 * Float.pi * localRadius / Float(radialCount)
        let maximumWidth = max(0.0042, 0.86 * circumferentialSpacing)
        let posterior = max(0, min(1, (frontX - rootX) / (frontX - backX)))
        let length = 0.028 + 0.010 * posterior
        let tipX = max(rootX - length, CrowBodyAnatomy.loftRings.first!.x)
        let tipRing = CrowBodyAnatomy.interpolatedRing(atX: tipX)
        let tipNormal = surfaceNormal(
          ring: tipRing,
          sine: sine,
          cosine: cosine
        )
        let tipShell = shellPoint(
          ring: tipRing,
          sine: sine,
          cosine: cosine
        )
        result.append(
          CrowBodyContourShingle(
            radialIndex: radialIndex,
            axialIndex: axialIndex,
            rootOffset: rootShell + shellClearanceMeters * rootNormal,
            tipOffset: tipShell + shellClearanceMeters * tipNormal,
            planeNormal: normalized(
              rootNormal + tipNormal,
              fallback: rootNormal
            ),
            rootWidthMeters: 0.60 * maximumWidth,
            maximumWidthMeters: maximumWidth,
            camberMeters: 0.025 * maximumWidth
          )
        )
      }
    }
    return result
  }

  private static func shellPoint(
    ring: CrowBodyLoftRing,
    sine: Float,
    cosine: Float
  ) -> SIMD3<Float> {
    SIMD3<Float>(
      ring.x,
      cosine * ring.halfWidth,
      ring.z + sine * CrowBodyAnatomy.verticalRadius(for: sine, ring: ring)
    )
  }

  private static func surfaceNormal(
    ring: CrowBodyLoftRing,
    sine: Float,
    cosine: Float
  ) -> SIMD3<Float> {
    let verticalRadius = CrowBodyAnatomy.verticalRadius(for: sine, ring: ring)
    return normalized(
      SIMD3<Float>(0, cosine / ring.halfWidth, sine / verticalRadius),
      fallback: SIMD3<Float>(0, cosine, sine)
    )
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-8 ? value / length : fallback
  }

  private static func mix(_ first: Float, _ second: Float, _ blend: Float) -> Float {
    first + blend * (second - first)
  }

  private static func square(_ value: Float) -> Float {
    value * value
  }
}
