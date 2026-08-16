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
  let pennaceousStartFraction: Float
  let vaneAsymmetry: Float
  let edgeRippleAmplitude: Float
  let edgeRipplePhase: Float
  let materialVariation: Float
}

/// Dense, imbricated contour coverage over the asymmetric body loft.
///
/// Each root is sampled from the same loft that owns the visible trunk. Width
/// follows local circumferential spacing and every feather extends beyond the
/// following axial root, creating a roof-tile shell instead of isolated leaves.
enum CrowBodyContourShingles {
  static let radialCount = 56
  static let axialCount = 48
  static let shellClearanceMeters: Float = 0.0012

  private static let frontX: Float = 0.110
  private static let backX: Float = -0.160

  static func samples() -> [CrowBodyContourShingle] {
    var result: [CrowBodyContourShingle] = []
    result.reserveCapacity(radialCount * axialCount)
    for radialIndex in 0..<radialCount {
      let theta = 2 * Float.pi * Float(radialIndex) / Float(radialCount)
      let region = region(for: theta)
      let tractIdentity = identityVariation(
        radialIndex: radialIndex,
        axialIndex: 0,
        salt: 0x6D2B_79F5
      )
      let tractPhase = axialTractPhase(theta: theta) + 0.20 * tractIdentity
      for axialIndex in 0..<axialCount {
        let morphologyPhase = Float(axialIndex) * 2.399_963 + theta * 3.17
        let axialIdentity = identityVariation(
          radialIndex: radialIndex,
          axialIndex: axialIndex,
          salt: 0xA341_316C
        )
        let localPhase =
          0.10 * sin(morphologyPhase)
          + 0.045 * sin(Float(axialIndex) * 1.173 - theta * 7.0)
          + 0.13 * axialIdentity
        let axial = clamp(
          (Float(axialIndex) + 1.70 + tractPhase + localPhase)
            / (Float(axialCount) + 2.40),
          lower: 0.012,
          upper: 0.988
        )
        let rootTheta =
          theta + 0.014 * axialIdentity + 0.006 * sin(morphologyPhase + 0.40)
        let rootX = mix(frontX, backX, axial)
        let rootRing = CrowBodyAnatomy.interpolatedRing(atX: rootX)
        let rootNormal = CrowBodyAnatomy.surfaceNormal(
          atX: rootX,
          theta: rootTheta
        )
        let rootShell = CrowBodyAnatomy.surfacePoint(
          ring: rootRing,
          theta: rootTheta
        )
        let halfAngularSpacing = Float.pi / Float(radialCount)
        let circumferentialSpacing = simd_distance(
          CrowBodyAnatomy.surfacePoint(
            ring: rootRing,
            theta: rootTheta - halfAngularSpacing
          ),
          CrowBodyAnatomy.surfacePoint(
            ring: rootRing,
            theta: rootTheta + halfAngularSpacing
          )
        )
        let widthIdentity = identityVariation(
          radialIndex: radialIndex,
          axialIndex: axialIndex,
          salt: 0xC801_3EA4
        )
        let widthVariation =
          1 + 0.075 * sin(morphologyPhase + 0.83) + 0.045 * widthIdentity
        let nominalMaximumWidth = max(
          0.0048,
          regionWidthScale(region) * widthVariation * 1.38 * circumferentialSpacing
        )
        let posterior = max(0, min(1, (frontX - rootX) / (frontX - backX)))
        let lengthIdentity = identityVariation(
          radialIndex: radialIndex,
          axialIndex: axialIndex,
          salt: 0xAD90_777D
        )
        let lengthVariation =
          0.0018 * sin(morphologyPhase - 0.51) + 0.0012 * lengthIdentity
        let length =
          regionLength(region)
          + 0.010 * posterior
          + lengthVariation
        let maximumWidth = min(nominalMaximumWidth, 0.249 * length)
        let tipX = max(rootX - length, CrowBodyAnatomy.loftRings.first!.x)
        let tipIdentity = identityVariation(
          radialIndex: radialIndex,
          axialIndex: axialIndex,
          salt: 0x7E95_761E
        )
        let vaneIdentity = identityVariation(
          radialIndex: radialIndex,
          axialIndex: axialIndex,
          salt: 0xB529_7A4D
        )
        let edgeIdentity = identityVariation(
          radialIndex: radialIndex,
          axialIndex: axialIndex,
          salt: 0x68E3_1DA4
        )
        let materialIdentity = identityVariation(
          radialIndex: radialIndex,
          axialIndex: axialIndex,
          salt: 0x1B56_C4E9
        )
        let tipTheta =
          rootTheta - 0.038 * cos(rootTheta) * (0.35 + 0.65 * posterior)
          + 0.012 * tipIdentity
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
            camberMeters: (0.022 + 0.009 * (0.5 + 0.5 * sin(morphologyPhase + 1.6)))
              * maximumWidth,
            pennaceousStartFraction: clamp(
              regionPennaceousStart(region) + 0.020 * tipIdentity,
              lower: 0.34,
              upper: 0.47
            ),
            vaneAsymmetry: 0.045 * vaneIdentity,
            edgeRippleAmplitude: 0.012 + 0.018 * (0.5 + 0.5 * edgeIdentity),
            edgeRipplePhase: Float.pi * (edgeIdentity + 1),
            materialVariation: materialIdentity
          )
        )
      }
    }
    return result
  }

  /// A periodic, low-frequency phase field makes neighbouring feather tracts
  /// interdigitate without turning the body into aligned transverse hoops.
  private static func axialTractPhase(theta: Float) -> Float {
    0.40 * sin(2 * theta + 0.61)
      + 0.20 * sin(5 * theta - 0.27)
  }

  private static func region(for theta: Float) -> CrowBodyContourRegion {
    let vertical = sin(theta)
    if vertical > 0.36 { return .dorsal }
    if vertical < -0.38 { return .ventral }
    return .flank
  }

  private static func regionLength(_ region: CrowBodyContourRegion) -> Float {
    switch region {
    case .dorsal: 0.040
    case .flank: 0.034
    case .ventral: 0.032
    }
  }

  private static func regionWidthScale(_ region: CrowBodyContourRegion) -> Float {
    switch region {
    case .dorsal: 0.94
    case .flank: 1.0
    case .ventral: 1.06
    }
  }

  private static func regionPennaceousStart(_ region: CrowBodyContourRegion) -> Float {
    switch region {
    case .dorsal: 0.42
    case .flank: 0.40
    case .ventral: 0.38
    }
  }

  static func centerlinePoint(
    for feather: CrowBodyContourShingle,
    at fraction: Float
  ) -> SIMD3<Float> {
    let t = clamp(fraction, lower: 0, upper: 1)
    return feather.rootOffset
      + (feather.tipOffset - feather.rootOffset) * t
      + feather.planeNormal * (feather.camberMeters * sin(Float.pi * t))
  }

  static func vaneHalfWidth(
    for feather: CrowBodyContourShingle,
    at fraction: Float,
    signedWidth: Float = 0
  ) -> Float {
    let t = clamp(fraction, lower: 0, upper: 1)
    let bodyEnvelope = 0.32 + 0.68 * pow(max(sin(Float.pi * t), 0), 0.58)
    let tipTaper = 1 - 0.985 * pow(t, 3.2)
    let rippleEnvelope = pow(max(sin(Float.pi * t), 0), 2)
    let edgeRipple =
      1
      + feather.edgeRippleAmplitude
      * sin(3 * Float.pi * t + feather.edgeRipplePhase) * rippleEnvelope
    let sideScale = 1 + feather.vaneAsymmetry * min(max(signedWidth, -1), 1)
    return
      (feather.rootWidthMeters * (1 - t)
      + feather.maximumWidthMeters * t) * bodyEnvelope * tipTaper
      * edgeRipple * sideScale
  }

  /// Stable identity noise prevents periodic courses without allowing temporal
  /// flicker. It is presentation morphology, not a measured feather sample.
  private static func identityVariation(
    radialIndex: Int,
    axialIndex: Int,
    salt: UInt32
  ) -> Float {
    var value = UInt32(truncatingIfNeeded: radialIndex) &* 0x9E37_79B9
    value ^= UInt32(truncatingIfNeeded: axialIndex) &* 0x85EB_CA6B
    value ^= salt
    value ^= value >> 16
    value &*= 0x7FEB_352D
    value ^= value >> 15
    value &*= 0x846C_A68B
    value ^= value >> 16
    return 2 * Float(value & 0x00FF_FFFF) / Float(0x00FF_FFFF) - 1
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
