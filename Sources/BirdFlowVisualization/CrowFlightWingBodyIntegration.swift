import simd

/// Presentation-only retarget from the measured-derived wing scaffold into the
/// estimated crow torso.
///
/// The source scaffold's nominal root collapses behind the pelvis. A rigid
/// shoulder translation alone would still leave a point hinge, so the first
/// span stations are lofted onto a broad scapular-to-flank attachment curve.
/// Flap rotation ramps in outside that attached envelope, keeping the root on
/// the body while preserving the distal reference topology.
enum CrowFlightWingBodyIntegration {
  static let chordCount = 9
  static let spanCount = 33
  static let attachmentSpanCount = 14
  static let articulationSpanCount = 12
  static let covertCourseOverlapScale: Float = 1.24
  static let covertAttachmentMaximumOverlapScale: Float = 1.68
  static let covertDistalMaximumChordExtension: Float = 0.70
  static let covertDistalAnteriorMaximumChordExtension: Float = 0.50
  static let covertProximalMaximumChordExtension: Float = 1.60
  static let covertCaudalSecondaryHandoffMaximumWidthScale: Float = 1.40
  static let covertCaudalSecondaryHandoffMaximumVaneAsymmetry: Float = 0.45
  static let covertFoldedSecondaryHandoffMaximumWidthScale: Float = 1.70
  static let covertFoldedSecondaryHandoffReleaseStartPhase: Float = 0.25
  static let covertFoldedSecondaryHandoffReleaseEndPhase: Float = 7 / 24
  static let covertFoldedShellHandoffMaximumWidthScale: Float = 1.40
  static let covertFoldedShellHandoffStartPhase: Float = 0.30
  static let covertFoldedShellHandoffPeakPhase: Float = 0.375
  static let covertFoldedShellHandoffEndPhase: Float = 0.46
  static let covertAbdominalHandoffMaximumWidthScale: Float = 1.35
  static let covertDistalTrailingMaximumWidthScale: Float = 1.25
  static let covertDistalTrailingBodyHandoffMaximumWidthScale: Float = 1.10
  static let covertDistalTrailingBodyHandoffStartPhase: Float = 0.20
  static let covertDistalTrailingBodyHandoffPeakPhase: Float = 0.25
  static let covertDistalTrailingBodyHandoffEndPhase: Float = 0.375
  static let covertProximalTailHandoffMaximumWidthScale: Float = 1.35
  static let covertVentralBodyHandoffMaximumWidthScale: Float = 1.35
  static let rectrixWingHandoffMaximumWidthScale: Float = 1.40
  static let covertAbdominalHandoffMaximumNormalLiftMeters: Float = 0.001
  static let covertChordIndices = [0, 3, 4, 5, 6]
  static let underwingCovertChordIndices = [1, 3, 5, 6]
  static let underwingCovertSurfaceFeatherClass: UInt32 = 12
  static let underwingPrimaryCovertSurfaceFeatherClass: UInt32 = 13
  static let underwingCovertRootClearanceMeters: Float = 0.0001
  static let underwingCovertTipClearanceMeters: Float = 0.00015
  static let underwingCovertDeploymentStartProgress: Float = 0.01
  static let underwingCovertDeploymentEndProgress: Float = 0.20
  static let axillaryUnderlayerRootChordIndex = 6
  static let axillaryUnderlayerTipChordIndex = 8
  static let terminalAxillaryHandoffSpanIndex = 0
  static let dorsalFoldedWingHandoffChordIndex = 6
  static let dorsalFoldedWingHandoffSpanIndices = [21, 29]
  static let dorsalFoldedWingHandoffBodyAxialIndex = 61
  static let dorsalFoldedWingHandoffLeftBodyRadialIndex = 19
  static let dorsalFoldedWingHandoffRightBodyRadialIndex = 29
  static let dorsalFoldedWingHandoffReleaseStartPhase: Float = 0.28
  static let dorsalFoldedWingHandoffReleaseEndPhase: Float = 0.42

  /// Nine body-seated stations bound the continuous axillary covert bed. Its
  /// eight topology intervals close projection slots without widening or
  /// lengthening the exposed dorsal course.
  static var axillaryUnderlayerSpanIndices: [Int] {
    Array(0...8)
  }

  /// Samples every fixed wing-topology station from the body-seated root to
  /// the last station with a two-step surface target. Dense, stable courses
  /// avoid hiding sparse-plumage slots with implausibly broad vanes.
  static var covertSpanIndices: [Int] {
    Array(0...(spanCount - 3))
  }

  /// Keeps the ventral tract two topology stations inside every wing boundary.
  /// Its feather vanes can break up the reverse-side scaffold without becoming
  /// a new leading, trailing, root, or tip silhouette.
  static var underwingCovertSpanIndices: [Int] {
    Array(2...(spanCount - 5))
  }

  /// Deploys the reverse-face vanes after the folded hold. Width and clearance
  /// collapse to zero without deleting vertices, preserving temporal identity.
  static func underwingCovertDeploymentWeight(
    transitionProgress: Float
  ) -> Float {
    let progress = clamp(
      (transitionProgress - underwingCovertDeploymentStartProgress)
        / (underwingCovertDeploymentEndProgress
          - underwingCovertDeploymentStartProgress)
    )
    return smootherstep(progress)
  }

  /// Passerine primary coverts are relatively short; the caudal course seals
  /// remex bases without extending to the established trailing-wing outline.
  static func underwingCovertChordTargetScale(chordIndex: Int) -> Float {
    chordIndex == 6 ? 0.64 : 0.86
  }

  static func underwingCovertCourseWidthScale(chordIndex: Int) -> Float {
    chordIndex == 6 ? 0.82 : 1
  }

  static func underwingCovertClassCode(chordIndex: Int) -> UInt32 {
    chordIndex == 6
      ? underwingPrimaryCovertSurfaceFeatherClass
      : underwingCovertSurfaceFeatherClass
  }

  static func dorsalFoldedWingHandoffBodyRadialIndex(left: Bool) -> Int {
    left
      ? dorsalFoldedWingHandoffLeftBodyRadialIndex
      : dorsalFoldedWingHandoffRightBodyRadialIndex
  }

  /// Keeps the compact dorsal handoff seated through early deployment, then
  /// collapses it smoothly onto its two live wing stations before the wing is
  /// freely articulated. The fixed topology remains present at zero area.
  static func dorsalFoldedWingHandoffWeight(
    presentationPhase: Float
  ) -> Float {
    let release = clamp(
      (presentationPhase - dorsalFoldedWingHandoffReleaseStartPhase)
        / (dorsalFoldedWingHandoffReleaseEndPhase
          - dorsalFoldedWingHandoffReleaseStartPhase)
    )
    return 1 - release * release * (3 - 2 * release)
  }

  /// Axillary coverts overlap most strongly where the wing is body-seated,
  /// closing the rear-quarter root course before recovering the established
  /// vane width ahead of free articulation.
  static func covertAttachmentOverlapScale(spanIndex: Int) -> Float {
    let progress = clamp(Float(spanIndex) / Float(attachmentSpanCount))
    return 1
      + (covertAttachmentMaximumOverlapScale - 1)
        * (1 - smootherstep(progress))
  }

  /// Distal trailing coverts project across the marginal scaffold boundary
  /// and overlap the outer rectrix course in the high rear-quarter view. The
  /// correction adds length along the sampled chord instead of making every
  /// exposed vane implausibly broad.
  static func covertDistalChordExtension(spanIndex: Int) -> Float {
    let firstDistalStation = spanCount - 10
    let lastCovertStation = spanCount - 3
    let progress = clamp(
      Float(spanIndex - firstDistalStation)
        / Float(lastCovertStation - firstDistalStation)
    )
    return covertDistalMaximumChordExtension * smootherstep(progress)
  }

  /// Leading and middle distal coverts carry slightly beyond the generic
  /// surface target so their tapered tips overlap the marginal wing scaffold.
  /// Other courses retain their established chord length.
  static func covertDistalAnteriorChordExtension(
    chordIndex: Int,
    spanIndex: Int
  ) -> Float {
    guard chordIndex == 0 || chordIndex == 3 else { return 0 }
    let firstDistalStation = spanCount - 10
    let lastCovertStation = spanCount - 3
    let progress = clamp(
      Float(spanIndex - firstDistalStation)
        / Float(lastCovertStation - firstDistalStation)
    )
    return covertDistalAnteriorMaximumChordExtension * smootherstep(progress)
  }

  /// Broadens the penultimate live covert course across the caudal secondary
  /// handoff while the retained folded remex is still visible. The compact
  /// field fades out before free distal articulation and leaves other courses
  /// untouched.
  static func covertCaudalSecondaryHandoffWidthScale(
    chordIndex: Int,
    spanIndex: Int
  ) -> Float {
    return 1
      + (covertCaudalSecondaryHandoffMaximumWidthScale - 1)
        * covertCaudalSecondaryHandoffWeight(
          chordIndex: chordIndex,
          spanIndex: spanIndex
        )
  }

  /// Directs the added vane area toward the retained secondary instead of
  /// widening both exposed edges equally. Bilateral signs mirror the shape.
  static func covertCaudalSecondaryHandoffVaneAsymmetry(
    chordIndex: Int,
    spanIndex: Int,
    left: Bool
  ) -> Float {
    return (left ? 1 : -1)
      * covertCaudalSecondaryHandoffMaximumVaneAsymmetry
      * covertCaudalSecondaryHandoffWeight(
        chordIndex: chordIndex,
        spanIndex: spanIndex
      )
  }

  /// Adds folded-phase overlap where the two live trailing covert courses meet
  /// the retained secondary fan. The compact mid-wing field returns exactly to
  /// the established width before free articulation.
  static func covertFoldedSecondaryHandoffWidthScale(
    chordIndex: Int,
    spanIndex: Int,
    presentationPhase: Float
  ) -> Float {
    guard chordIndex == 5 || chordIndex == 6 else { return 1 }
    let distance = abs(Float(spanIndex) - 16)
    guard distance < 5 else { return 1 }
    let spanWeight = smootherstep(1 - distance / 5)
    let release = clamp(
      (presentationPhase - covertFoldedSecondaryHandoffReleaseStartPhase)
        / (covertFoldedSecondaryHandoffReleaseEndPhase
          - covertFoldedSecondaryHandoffReleaseStartPhase)
    )
    let phaseWeight = 1 - release * release * (3 - 2 * release)
    return 1
      + (covertFoldedSecondaryHandoffMaximumWidthScale - 1)
        * spanWeight * phaseWeight
  }

  /// Carries the proximal live trailing-covert course beneath the last
  /// body-seated folded coverts while the wing crosses their posterior shell.
  /// The compact root field recovers before free articulation without moving
  /// roots or tips.
  static func covertFoldedShellHandoffWidthScale(
    chordIndex: Int,
    spanIndex: Int,
    presentationPhase: Float
  ) -> Float {
    guard chordIndex == 6 else { return 1 }
    let proximalWeight = max(0, 1 - Float(spanIndex) / 2)
    let spanWeight = smootherstep(proximalWeight)
    guard spanWeight > 0 else { return 1 }
    let rise = smootherstep(
      clamp(
        (presentationPhase - covertFoldedShellHandoffStartPhase)
          / (covertFoldedShellHandoffPeakPhase
            - covertFoldedShellHandoffStartPhase)
      )
    )
    let release = 1 - smootherstep(
      clamp(
        (presentationPhase - covertFoldedShellHandoffPeakPhase)
          / (covertFoldedShellHandoffEndPhase
            - covertFoldedShellHandoffPeakPhase)
      )
    )
    return 1
      + (covertFoldedShellHandoffMaximumWidthScale - 1)
        * spanWeight * rise * release
  }

  /// Proximal trailing coverts bridge the body-seated scaffold boundary, then
  /// recover their established chord length before free articulation.
  static func covertProximalChordExtension(spanIndex: Int) -> Float {
    let lastProximalStation = 8
    let progress = clamp(Float(spanIndex) / Float(lastProximalStation))
    return covertProximalMaximumChordExtension * (1 - smootherstep(progress))
  }

  /// Staggers visible vane tips while every root remains on its exact live
  /// topology station. Course phases are interleaved rather than alternating.
  static func covertTipSpanFraction(chordIndex: Int, spanIndex: Int) -> Float {
    let coursePhase: Float
    switch chordIndex {
    case 0: coursePhase = -0.040
    case 3: coursePhase = 0.025
    case 4: coursePhase = -0.015
    case 5: coursePhase = 0.045
    case 6: coursePhase = 0
    default: coursePhase = 0
    }
    return 0.34 + coursePhase
      + 0.012 * covertIdentityVariation(
        chordIndex: chordIndex,
        spanIndex: spanIndex,
        salt: 0x9E37_79B9
      )
  }

  static func covertWidthScale(chordIndex: Int, spanIndex: Int) -> Float {
    1.03 + 0.025 * covertIdentityVariation(
      chordIndex: chordIndex,
      spanIndex: spanIndex,
      salt: 0x85EB_CA6B
    )
  }

  /// Short, interleaved ventral tips remain inside the convex topology cell:
  /// the chord and span weights always sum to less than one.
  static func underwingCovertTipSpanFraction(
    chordIndex: Int,
    spanIndex: Int
  ) -> Float {
    let coursePhase: Float
    switch chordIndex {
    case 1: coursePhase = -0.012
    case 3: coursePhase = 0.010
    case 5: coursePhase = -0.002
    case 6: coursePhase = 0.016
    default: coursePhase = 0
    }
    return 0.10 + coursePhase
      + 0.010 * covertIdentityVariation(
        chordIndex: chordIndex,
        spanIndex: spanIndex,
        salt: 0xD3A2_646C
      )
  }

  static func underwingCovertWidthScale(
    chordIndex: Int,
    spanIndex: Int
  ) -> Float {
    0.94 + 0.055 * covertIdentityVariation(
      chordIndex: chordIndex,
      spanIndex: spanIndex,
      salt: 0xA24B_AED4
    )
  }

  static func underwingCovertCamberScale(
    chordIndex: Int,
    spanIndex: Int
  ) -> Float {
    0.90 + 0.075 * covertIdentityVariation(
      chordIndex: chordIndex,
      spanIndex: spanIndex,
      salt: 0x9FB2_1C65
    )
  }

  static func underwingCovertMaterialVariation(
    chordIndex: Int,
    spanIndex: Int
  ) -> Float {
    covertIdentityVariation(
      chordIndex: chordIndex,
      spanIndex: spanIndex,
      salt: 0xC13F_A9A9
    )
  }

  static func underwingCovertEdgeVariation(
    chordIndex: Int,
    spanIndex: Int
  ) -> Float {
    covertIdentityVariation(
      chordIndex: chordIndex,
      spanIndex: spanIndex,
      salt: 0x91E1_0DA5
    )
  }

  /// Broadens only the body-seated trailing covert centered on span five,
  /// fading symmetrically into its neighbors without moving any root or tip.
  static func covertAbdominalHandoffWidthScale(
    chordIndex: Int,
    spanIndex: Int
  ) -> Float {
    guard chordIndex == 6 else { return 1 }
    let distance = abs(spanIndex - 5)
    guard distance < 2 else { return 1 }
    let weight = 1 - Float(distance) / 2
    return 1
      + (covertAbdominalHandoffMaximumWidthScale - 1) * smootherstep(weight)
  }

  /// Lifts the seated span-five trailing covert by at most one millimetre so
  /// its body-facing edge remains in front of the abdominal tract through the
  /// transition. The symmetric fade leaves spans three and seven unchanged.
  static func covertAbdominalHandoffNormalLift(
    chordIndex: Int,
    spanIndex: Int
  ) -> Float {
    guard chordIndex == 6 else { return 0 }
    let distance = abs(spanIndex - 5)
    guard distance < 2 else { return 0 }
    let weight = 1 - Float(distance) / 2
    return covertAbdominalHandoffMaximumNormalLiftMeters * smootherstep(weight)
  }

  /// Slightly broadens the two outer trailing coverts whose tapered vane
  /// edges meet the live marginal scaffold during early transition. The
  /// compact field leaves spans 27 and 30 at their established width.
  static func covertDistalTrailingWidthScale(
    chordIndex: Int,
    spanIndex: Int
  ) -> Float {
    let weight = covertDistalTrailingWeight(
      chordIndex: chordIndex,
      spanIndex: spanIndex
    )
    return 1
      + (covertDistalTrailingMaximumWidthScale - 1) * weight
  }

  /// Adds a small symmetric overlap to the same two trailing shingles during
  /// their initial deployment. Both vane edges remain present, and roots, tips,
  /// chord length, and the established free-flight shape are unchanged.
  static func covertDistalTrailingBodyHandoffWidthScale(
    chordIndex: Int,
    spanIndex: Int,
    presentationPhase: Float
  ) -> Float {
    return 1
      + (covertDistalTrailingBodyHandoffMaximumWidthScale - 1)
      * covertDistalTrailingWeight(
        chordIndex: chordIndex,
        spanIndex: spanIndex
      )
      * covertDistalTrailingBodyHandoffTransitionWeight(
        presentationPhase: presentationPhase
      )
  }

  /// Smoothly limits the added overlap to initial wing deployment. The
  /// folded hold and later free wing remain on their established silhouettes.
  static func covertDistalTrailingBodyHandoffTransitionWeight(
    presentationPhase: Float
  ) -> Float {
    let rise = smootherstep(
      clamp(
        (presentationPhase - covertDistalTrailingBodyHandoffStartPhase)
          / (covertDistalTrailingBodyHandoffPeakPhase
            - covertDistalTrailingBodyHandoffStartPhase)
      )
    )
    let release = 1 - smootherstep(
      clamp(
        (presentationPhase - covertDistalTrailingBodyHandoffPeakPhase)
          / (covertDistalTrailingBodyHandoffEndPhase
            - covertDistalTrailingBodyHandoffPeakPhase)
      )
    )
    return rise * release
  }

  /// Broadens only the first two body-seated trailing coverts beneath the
  /// posterior primary-to-outer-rectrix junction. The field recovers before
  /// articulation, preserving the exposed wing and tail silhouettes.
  static func covertProximalTailHandoffWidthScale(
    chordIndex: Int,
    spanIndex: Int
  ) -> Float {
    guard chordIndex == 6, spanIndex >= 0, spanIndex < 2 else { return 1 }
    let weight = 1 - Float(spanIndex) / 2
    return 1
      + (covertProximalTailHandoffMaximumWidthScale - 1) * weight
  }

  /// Broadens the paired leading coverts that meet the ventral/femoral shell
  /// through the late stroke. The compact midspan field leaves chord length,
  /// roots, and the exposed leading-edge silhouette unchanged.
  static func covertVentralBodyHandoffWidthScale(
    chordIndex: Int,
    spanIndex: Int
  ) -> Float {
    guard chordIndex == 0 else { return 1 }
    let distance = abs(Float(spanIndex) - 13.5)
    guard distance < 2.5 else { return 1 }
    let weight = 1 - distance / 2.5
    return 1
      + (covertVentralBodyHandoffMaximumWidthScale - 1) * weight
  }

  /// Broadens the paired sublateral rectrices where the live tail meets the
  /// distal trailing covert course. The bilateral compact field preserves
  /// the established roots, tips, central tail stack, and outer silhouette.
  static func rectrixWingHandoffWidthScale(order: Int, count: Int) -> Float {
    guard count >= 4, order >= 0, order < count else { return 1 }
    let position = Float(order)
    let distance = min(
      abs(position - 1.5),
      abs(position - (Float(count) - 2.5))
    )
    guard distance < 1.5 else { return 1 }
    let weight = 1 - distance / 1.5
    return 1 + (rectrixWingHandoffMaximumWidthScale - 1) * weight
  }

  static func covertCamberScale(chordIndex: Int, spanIndex: Int) -> Float {
    1 + 0.10 * covertIdentityVariation(
      chordIndex: chordIndex,
      spanIndex: spanIndex,
      salt: 0xC2B2_AE35
    )
  }

  static func covertMaterialVariation(chordIndex: Int, spanIndex: Int) -> Float {
    covertIdentityVariation(
      chordIndex: chordIndex,
      spanIndex: spanIndex,
      salt: 0x27D4_EB2F
    )
  }

  static func covertEdgeVariation(chordIndex: Int, spanIndex: Int) -> Float {
    covertIdentityVariation(
      chordIndex: chordIndex,
      spanIndex: spanIndex,
      salt: 0x1656_67B1
    )
  }

  static func axillaryUnderlayerTipSpanFraction(spanIndex: Int) -> Float {
    0.34 + 0.018 * covertIdentityVariation(
      chordIndex: axillaryUnderlayerRootChordIndex,
      spanIndex: spanIndex,
      salt: 0x7E95_761E
    )
  }

  /// Resolves the anatomical dorsal side from fixed topology orientation.
  /// World Z is intentionally absent: a reversing wing must not swap the
  /// feather shell to its opposite physical face.
  static func covertSurfaceNormal(
    chordDirection: SIMD3<Float>,
    spanDirection: SIMD3<Float>,
    left: Bool
  ) -> SIMD3<Float> {
    let orientation: Float = left ? 1 : -1
    let cross = orientation * simd_cross(chordDirection, spanDirection)
    let fallback = SIMD3<Float>(0, 0, -1)
    let length = simd_length(cross)
    return length > 1e-8 ? cross / length : fallback
  }

  /// The underwing tract is locked to the physical reverse face even when a
  /// stroke crosses world-horizontal and the wing's world-space Z reverses.
  static func underwingCovertSurfaceNormal(
    chordDirection: SIMD3<Float>,
    spanDirection: SIMD3<Float>,
    left: Bool
  ) -> SIMD3<Float> {
    -covertSurfaceNormal(
      chordDirection: chordDirection,
      spanDirection: spanDirection,
      left: left
    )
  }

  static func bodyRoot(chordIndex: Int, left: Bool) -> SIMD3<Float> {
    precondition((0..<chordCount).contains(chordIndex))
    let fraction = Float(chordIndex) / Float(chordCount - 1)
    let x = mix(0.082, -0.118, fraction)
    let theta = mix(0.40, 0.30, fraction)
    let surface = CrowBodyAnatomy.surfacePoint(atX: x, theta: theta)
    let normal = CrowBodyAnatomy.surfaceNormal(atX: x, theta: theta)
    let seated = surface + normal * 0.0015
    return SIMD3<Float>(seated.x, left ? abs(seated.y) : -abs(seated.y), seated.z)
  }

  static func integratedPoint(
    referencePoint: SIMD3<Float>,
    sourceRoot: SIMD3<Float>,
    sourceLeadingRoot: SIMD3<Float>,
    spanIndex: Int,
    chordIndex: Int,
    left: Bool,
    phase: Float
  ) -> SIMD3<Float> {
    precondition((0..<spanCount).contains(spanIndex))
    precondition((0..<chordCount).contains(chordIndex))

    let shoulder = bodyRoot(chordIndex: 0, left: left)
    let commonShift = shoulder - sourceLeadingRoot
    let translated = referencePoint + commonShift
    let translatedSourceRoot = sourceRoot + commonShift

    let attachmentProgress = clamp(
      Float(spanIndex) / Float(attachmentSpanCount)
    )
    let attachmentWeight = 1 - smootherstep(attachmentProgress)
    let rooted = translated
      + attachmentWeight
        * (bodyRoot(chordIndex: chordIndex, left: left) - translatedSourceRoot)

    let articulationProgress = clamp(
      Float(spanIndex) / Float(articulationSpanCount)
    )
    let articulationWeight = smootherstep(articulationProgress)
    let wrappedPhase = phase - floor(phase)
    let side: Float = left ? 1 : -1
    let flapAngle = side * 0.54 * cos(2 * Float.pi * wrappedPhase)
      * articulationWeight
    return shoulder + rotateX(rooted - shoulder, angle: flapAngle)
  }

  private static func rotateX(_ point: SIMD3<Float>, angle: Float) -> SIMD3<Float> {
    let cosine = cos(angle)
    let sine = sin(angle)
    return SIMD3<Float>(
      point.x,
      cosine * point.y - sine * point.z,
      sine * point.y + cosine * point.z
    )
  }

  private static func smootherstep(_ value: Float) -> Float {
    value * value * value * (value * (value * 6 - 15) + 10)
  }

  private static func covertCaudalSecondaryHandoffWeight(
    chordIndex: Int,
    spanIndex: Int
  ) -> Float {
    guard chordIndex == 5 else { return 0 }
    let distance = abs(Float(spanIndex) - 21.5)
    guard distance < 4.5 else { return 0 }
    return smootherstep(1 - distance / 4.5)
  }

  private static func covertDistalTrailingWeight(
    chordIndex: Int,
    spanIndex: Int
  ) -> Float {
    guard chordIndex == 6 else { return 0 }
    let distance = abs(Float(spanIndex) - 28.5)
    guard distance < 1.5 else { return 0 }
    return smootherstep(1 - distance / 1.5)
  }

  private static func clamp(_ value: Float) -> Float {
    min(max(value, 0), 1)
  }

  private static func mix(_ first: Float, _ second: Float, _ blend: Float) -> Float {
    first + blend * (second - first)
  }

  private static func covertIdentityVariation(
    chordIndex: Int,
    spanIndex: Int,
    salt: UInt32
  ) -> Float {
    var value = UInt32(truncatingIfNeeded: chordIndex) &* 0x9E37_79B9
    value ^= UInt32(truncatingIfNeeded: spanIndex) &* 0x85EB_CA6B
    value ^= salt
    value ^= value >> 16
    value &*= 0x7FEB_352D
    value ^= value >> 15
    value &*= 0x846C_A68B
    value ^= value >> 16
    return 2 * Float(value & 0x00FF_FFFF) / Float(0x00FF_FFFF) - 1
  }
}
