import simd

struct CrowBodyContourShingle: Equatable {
  let radialIndex: Int
  let axialIndex: Int
  let rootSurfaceOffset: SIMD3<Float>
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
      let stagger: Float = radialIndex.isMultiple(of: 2) ? 0 : 0.5
      for axialIndex in 0..<axialCount {
        let axial =
          (Float(axialIndex) + stagger) / Float(axialCount)
        let rootX = mix(frontX, backX, axial)
        let rootRing = CrowBodyAnatomy.interpolatedRing(atX: rootX)
        let rootNormal = CrowBodyAnatomy.surfaceNormal(
          atX: rootX,
          theta: theta
        )
        let rootShell = CrowBodyAnatomy.surfacePoint(
          ring: rootRing,
          theta: theta
        )
        let halfAngularSpacing = Float.pi / Float(radialCount)
        let circumferentialSpacing = simd_distance(
          CrowBodyAnatomy.surfacePoint(
            ring: rootRing,
            theta: theta - halfAngularSpacing
          ),
          CrowBodyAnatomy.surfacePoint(
            ring: rootRing,
            theta: theta + halfAngularSpacing
          )
        )
        let maximumWidth = max(0.0042, 0.86 * circumferentialSpacing)
        let posterior = max(0, min(1, (frontX - rootX) / (frontX - backX)))
        let length = 0.028 + 0.010 * posterior
        let tipX = max(rootX - length, CrowBodyAnatomy.loftRings.first!.x)
        let tipNormal = CrowBodyAnatomy.surfaceNormal(
          atX: tipX,
          theta: theta
        )
        let tipShell = CrowBodyAnatomy.surfacePoint(
          atX: tipX,
          theta: theta
        )
        result.append(
          CrowBodyContourShingle(
            radialIndex: radialIndex,
            axialIndex: axialIndex,
            rootSurfaceOffset: rootShell,
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
}
