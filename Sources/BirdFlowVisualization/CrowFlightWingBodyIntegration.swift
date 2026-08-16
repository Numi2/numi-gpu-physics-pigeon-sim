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
  static let covertChordIndices = [0, 3, 4, 5, 6]

  /// Samples every fixed wing-topology station from the body-seated root to
  /// the last station with a two-step surface target. Dense, stable courses
  /// avoid hiding sparse-plumage slots with implausibly broad vanes.
  static var covertSpanIndices: [Int] {
    Array(0...(spanCount - 3))
  }

  /// Axillary coverts overlap most strongly where the wing is body-seated,
  /// then recover the established vane width before free articulation.
  static func covertAttachmentOverlapScale(spanIndex: Int) -> Float {
    let progress = clamp(Float(spanIndex) / Float(attachmentSpanCount))
    return 1 + 0.28 * (1 - smootherstep(progress))
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

  private static func clamp(_ value: Float) -> Float {
    min(max(value, 0), 1)
  }

  private static func mix(_ first: Float, _ second: Float, _ blend: Float) -> Float {
    first + blend * (second - first)
  }
}
