import simd

enum CrowBodyContourRegion: UInt8, CaseIterable {
  case dorsal
  case flank
  case ventral
}

struct CrowBodyContourShingle: Equatable {
  let region: CrowBodyContourRegion
  let surfaceFeatherClass: UInt32
  let radialIndex: Int
  let axialIndex: Int
  let rootThetaRadians: Float
  let tipThetaRadians: Float
  let rootSurfaceOffset: SIMD3<Float>
  let tipSurfaceOffset: SIMD3<Float>
  let tipSurfaceNormal: SIMD3<Float>
  let rootOffset: SIMD3<Float>
  let tipOffset: SIMD3<Float>
  let referenceLengthMeters: Float
  let planeNormal: SIMD3<Float>
  let rootWidthMeters: Float
  let maximumWidthMeters: Float
  let camberMeters: Float
  let transverseCamberRatio: Float
  let pennaceousStartFraction: Float
  let vaneAsymmetry: Float
  let edgeRippleAmplitude: Float
  let edgeRipplePhase: Float
  let edgeRippleCycles: Float
  let materialVariation: Float
}

/// Dense, imbricated contour coverage over the asymmetric body loft.
///
/// Each root is sampled from the same loft that owns the visible trunk. Width
/// follows local circumferential spacing and every feather extends beyond the
/// following axial root, creating a roof-tile shell instead of isolated leaves.
enum CrowBodyContourShingles {
  // Presentation density is deliberately sized for future-device compute:
  // enough independent vanes that the standing body reads as plumage rather
  // than a coarse roof-tile proxy at 720p, while every root remains owned by
  // the same anatomical loft.
  static let radialCount = 96
  static let axialCount = 72
  static let shellClearanceMeters: Float = 0.0012

  private static let frontX: Float = 0.110
  private static let backX: Float = -0.160

  static func samples(
    standingPhase: Float? = nil
  ) -> [CrowBodyContourShingle] {
    var result: [CrowBodyContourShingle] = []
    result.reserveCapacity(radialCount * axialCount)
    for radialIndex in 0..<radialCount {
      let theta = 2 * Float.pi * Float(radialIndex) / Float(radialCount)
      let tractPhase = axialCoursePhaseSteps(
        radialIndex: radialIndex,
        theta: theta
      )
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
        let angularStep = 2 * Float.pi / Float(radialCount)
        let rootTheta = theta + angularStep * rootAngularFlowSteps(
          radialIndex: radialIndex,
          axialIndex: axialIndex
        )
        let region = region(for: rootTheta)
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
        let halfAngularSpacing = 0.5 * angularStep
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
        let minimumHalfWidth: Float = 0.0050
        let nominalMaximumWidth = max(
          minimumHalfWidth,
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
        let cycleIdentity = identityVariation(
          radialIndex: radialIndex,
          axialIndex: axialIndex,
          salt: 0xC2B2_AE35
        )
        let materialIdentity = identityVariation(
          radialIndex: radialIndex,
          axialIndex: axialIndex,
          salt: 0x1B56_C4E9
        )
        let crownIdentity = identityVariation(
          radialIndex: radialIndex,
          axialIndex: axialIndex,
          salt: 0x27D4_EB2F
        )
        let tipTheta = rootTheta + tipAngularFlowRadians(
          region: region,
          rootTheta: rootTheta,
          posterior: posterior,
          identity: tipIdentity
        )
        let tipNormal = CrowBodyAnatomy.surfaceNormal(
          atX: tipX,
          theta: tipTheta
        )
        let tipShell = CrowBodyAnatomy.surfacePoint(
          atX: tipX,
          theta: tipTheta
        )
        let referenceRoot = rootShell + shellClearanceMeters * rootNormal
        let referenceTip = tipShell + shellClearanceMeters * tipNormal
        let complianceIdentity = identityVariation(
          radialIndex: radialIndex,
          axialIndex: axialIndex,
          salt: 0xD1B5_4A35
        )
        let tipCompliance = standingPhase.map {
          standingTipComplianceMeters(
            region: region,
            rootTheta: rootTheta,
            posterior: posterior,
            identity: complianceIdentity,
            phase: $0
          )
        } ?? 0
        result.append(
          CrowBodyContourShingle(
            region: region,
            surfaceFeatherClass: surfaceFeatherClass(for: region),
            radialIndex: radialIndex,
            axialIndex: axialIndex,
            rootThetaRadians: rootTheta,
            tipThetaRadians: tipTheta,
            rootSurfaceOffset: rootShell,
            tipSurfaceOffset: tipShell,
            tipSurfaceNormal: tipNormal,
            rootOffset: referenceRoot,
            tipOffset: referenceTip + tipCompliance * tipNormal,
            referenceLengthMeters: simd_distance(referenceRoot, referenceTip),
            planeNormal: normalized(
              rootNormal + tipNormal,
              fallback: rootNormal
            ),
            rootWidthMeters: (0.57 + 0.035 * cos(morphologyPhase)) * maximumWidth,
            maximumWidthMeters: maximumWidth,
            camberMeters: longitudinalCamberScale(
              region: region,
              morphologyPhase: morphologyPhase
            ) * maximumWidth,
            transverseCamberRatio: regionTransverseCamberRatio(region)
              + transverseCamberVariation(region) * crownIdentity,
            pennaceousStartFraction: clamp(
              regionPennaceousStart(region) + 0.020 * tipIdentity,
              lower: 0.34,
              upper: 0.47
            ),
            vaneAsymmetry: 0.045 * vaneIdentity,
            edgeRippleAmplitude: 0.012 + 0.018 * (0.5 + 0.5 * edgeIdentity),
            edgeRipplePhase: Float.pi * (edgeIdentity + 1),
            edgeRippleCycles: 1.20 + 0.80 * (0.5 + 0.5 * cycleIdentity),
            materialVariation: materialIdentity
          )
        )
      }
    }
    return result
  }

  /// Smooth anatomical flow plus finite low-discrepancy course staggering.
  /// The ventral shell receives the strongest breakup because transverse rows
  /// are most visible head-on; the dorsal field retains quieter organization.
  static func axialCoursePhaseSteps(
    radialIndex: Int,
    theta: Float
  ) -> Float {
    let region = region(for: theta)
    let smoothFlow =
      0.40 * sin(2 * theta + 0.61)
      + 0.20 * sin(5 * theta - 0.27)
    return smoothFlow + axialCourseStaggerSteps(
      radialIndex: radialIndex,
      region: region
    )
  }

  static func axialCourseStaggerSteps(
    radialIndex: Int,
    region: CrowBodyContourRegion
  ) -> Float {
    let amplitude: Float
    switch region {
    case .dorsal:
      amplitude = 0.42
    case .flank:
      amplitude = 0.72
    case .ventral:
      amplitude = 0.94
    }
    let goldenPhase = Float(radialIndex) * 0.618_034 + 0.37
    let lowDiscrepancy = goldenPhase - floor(goldenPhase) - 0.5
    let identity = identityVariation(
      radialIndex: radialIndex,
      axialIndex: 0,
      salt: 0x6D2B_79F5
    )
    return amplitude * lowDiscrepancy + 0.075 * identity
  }

  /// A bounded aperiodic phase field prevents the dense shell from resolving
  /// into straight radial lanes. The smooth terms bend each tract across the
  /// body while a smaller stable identity term breaks local lattice cadence.
  /// Keeping the offset below one quarter of a course preserves root order.
  static func rootAngularFlowSteps(
    radialIndex: Int,
    axialIndex: Int
  ) -> Float {
    let radial = Float(radialIndex)
    let axial = Float(axialIndex)
    let primary = sin(radial * 2.399_963 + axial * 1.618_034 + 0.41)
    let secondary = sin(radial * 0.754_878 - axial * 2.414_214 - 0.73)
    let identity = identityVariation(
      radialIndex: radialIndex,
      axialIndex: axialIndex,
      salt: 0x94D0_49BB
    )
    return 0.13 * primary + 0.075 * secondary + 0.035 * identity
  }

  /// Surface-tangent feather flow in anatomical regions. Flank feathers sweep
  /// caudoventrally, while dorsal and ventral midline fields remain primarily
  /// caudal. The endpoint is resampled from the owning loft at this angle.
  static func tipAngularFlowRadians(
    region: CrowBodyContourRegion,
    rootTheta: Float,
    posterior: Float,
    identity: Float
  ) -> Float {
    let strength: Float
    switch region {
    case .dorsal:
      strength = 0.035
    case .flank:
      strength = 0.105
    case .ventral:
      strength = 0.055
    }
    let axialScale = 0.55 + 0.45 * clamp(posterior, lower: 0, upper: 1)
    let caudoventralFlow = -strength * cos(rootTheta) * axialScale
    return caudoventralFlow + 0.010 * min(max(identity, -1), 1)
  }

  /// Quiet-standing vane compliance. Roots remain exactly body seated; only
  /// tips lift or settle along their owning surface normal. Subtracting the
  /// regional rest value makes phase zero and phase one bitwise equivalent.
  static func standingTipComplianceMeters(
    region: CrowBodyContourRegion,
    rootTheta: Float,
    posterior: Float,
    identity: Float,
    phase: Float
  ) -> Float {
    let wrapped = phase - floor(phase)
    guard wrapped > 1e-7 else { return 0 }
    let amplitude: Float
    let regionalDelay: Float
    switch region {
    case .dorsal:
      amplitude = 0.00018
      regionalDelay = 0.15
    case .flank:
      amplitude = 0.00026
      regionalDelay = 0.52
    case .ventral:
      amplitude = 0.00030
      regionalDelay = 0.82
    }
    let identityDelay = 0.12 * min(max(identity, -1), 1)
    let delay = regionalDelay + identityDelay + 0.04 * cos(rootTheta)
    let angle = 2 * Float.pi * wrapped
    let response = sin(angle + delay) - sin(delay)
    let axialScale = 0.72 + 0.28 * clamp(posterior, lower: 0, upper: 1)
    return amplitude * axialScale * response
  }

  static func region(for theta: Float) -> CrowBodyContourRegion {
    let vertical = sin(theta)
    if vertical > 0.36 { return .dorsal }
    if vertical < -0.38 { return .ventral }
    return .flank
  }

  static func surfaceFeatherClass(
    for region: CrowBodyContourRegion
  ) -> UInt32 {
    switch region {
    case .dorsal:
      return 5
    case .flank:
      return 6
    case .ventral:
      return 7
    }
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

  private static func regionTransverseCamberRatio(
    _ region: CrowBodyContourRegion
  ) -> Float {
    switch region {
    case .dorsal: 0.110
    case .flank: 0.030
    case .ventral: 0.035
    }
  }

  private static func transverseCamberVariation(
    _ region: CrowBodyContourRegion
  ) -> Float {
    region == .dorsal ? 0.020 : 0.010
  }

  /// Dorsal vanes need enough individual crown to survive dense imbrication.
  /// The former two-to-three-percent rise merged thousands of contour feathers
  /// into one smooth saddle at high rear camera angles. Flank and ventral
  /// courses retain their quieter established profile.
  private static func longitudinalCamberScale(
    region: CrowBodyContourRegion,
    morphologyPhase: Float
  ) -> Float {
    let variation = 0.5 + 0.5 * sin(morphologyPhase + 1.6)
    switch region {
    case .dorsal:
      return 0.160 + 0.080 * variation
    case .flank, .ventral:
      return 0.022 + 0.009 * variation
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
      * sin(
        2 * Float.pi * feather.edgeRippleCycles * t
          + feather.edgeRipplePhase
      ) * rippleEnvelope
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
