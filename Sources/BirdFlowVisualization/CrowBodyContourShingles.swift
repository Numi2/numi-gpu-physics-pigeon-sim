import simd

enum CrowBodyContourRegion: UInt8, CaseIterable {
  case dorsal
  case flank
  case ventral
}

struct CrowBodyContourShingle: Equatable {
  let region: CrowBodyContourRegion
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
      let region = region(for: theta)
      let tractPhase = axialTractPhase(theta: theta)
      for axialIndex in 0..<axialCount {
        let morphologyPhase = Float(axialIndex) * 2.399_963 + theta * 3.17
        let localPhase =
          0.10 * sin(morphologyPhase)
          + 0.045 * sin(Float(axialIndex) * 1.173 - theta * 7.0)
        let axial = clamp(
          (Float(axialIndex) + tractPhase + localPhase) / Float(axialCount),
          lower: 0.012,
          upper: 0.988
        )
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
        let widthVariation = 1 + 0.075 * sin(morphologyPhase + 0.83)
        let maximumWidth = max(
          0.0042,
          regionWidthScale(region) * widthVariation * 0.86 * circumferentialSpacing
        )
        let posterior = max(0, min(1, (frontX - rootX) / (frontX - backX)))
        let lengthVariation = 0.0018 * sin(morphologyPhase - 0.51)
        let length =
          regionLength(region)
          + 0.010 * posterior
          + lengthVariation
        let tipX = max(rootX - length, CrowBodyAnatomy.loftRings.first!.x)
        let tipTheta = theta - 0.038 * cos(theta) * (0.35 + 0.65 * posterior)
        let tipNormal = CrowBodyAnatomy.surfaceNormal(
          atX: tipX,
          theta: tipTheta
        )
        let tipShell = CrowBodyAnatomy.surfacePoint(
          atX: tipX,
          theta: tipTheta
        )
        result.append(
          CrowBodyContourShingle(
            region: region,
            radialIndex: radialIndex,
            axialIndex: axialIndex,
            rootSurfaceOffset: rootShell,
            rootOffset: rootShell + shellClearanceMeters * rootNormal,
            tipOffset: tipShell + shellClearanceMeters * tipNormal,
            planeNormal: normalized(
              rootNormal + tipNormal,
              fallback: rootNormal
            ),
            rootWidthMeters: (0.57 + 0.035 * cos(morphologyPhase)) * maximumWidth,
            maximumWidthMeters: maximumWidth,
            camberMeters:
              (0.022 + 0.009 * (0.5 + 0.5 * sin(morphologyPhase + 1.6)))
              * maximumWidth
          )
        )
      }
    }
    return result
  }

  /// A periodic, low-frequency phase field makes neighbouring feather tracts
  /// interdigitate without turning the body into aligned transverse hoops.
  private static func axialTractPhase(theta: Float) -> Float {
    0.34
      + 0.22 * sin(2 * theta + 0.61)
      + 0.12 * sin(5 * theta - 0.27)
  }

  private static func region(for theta: Float) -> CrowBodyContourRegion {
    let vertical = sin(theta)
    if vertical > 0.36 { return .dorsal }
    if vertical < -0.38 { return .ventral }
    return .flank
  }

  private static func regionLength(_ region: CrowBodyContourRegion) -> Float {
    switch region {
    case .dorsal: 0.030
    case .flank: 0.028
    case .ventral: 0.026
    }
  }

  private static func regionWidthScale(_ region: CrowBodyContourRegion) -> Float {
    switch region {
    case .dorsal: 0.94
    case .flank: 1.0
    case .ventral: 1.06
    }
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

  private static func clamp(_ value: Float, lower: Float, upper: Float) -> Float {
    min(max(value, lower), upper)
  }
}
