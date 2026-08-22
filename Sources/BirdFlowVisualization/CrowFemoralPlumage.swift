import simd

struct CrowFemoralPlumageFeather: Equatable {
  let side: Float
  let row: Int
  let course: Int
  let rootSurface: SIMD3<Float>
  let root: SIMD3<Float>
  let tip: SIMD3<Float>
  let planeNormal: SIMD3<Float>
  let rootWidthMeters: Float
  let maximumWidthMeters: Float
  let camberMeters: Float
  let lateralSweepMeters: Float
  let vaneAsymmetry: Float
  let edgeRippleAmplitude: Float
  let edgeRipplePhase: Float
  let edgeRippleCycles: Float
  let rootEnvelopeRatio: Float
  let pennaceousStartFraction: Float
  let materialVariation: Float
  let bodyMaterialBlend: Float
}

/// Estimated femoral tract joining pelvic contour plumage to the crural tract.
///
/// Roots follow the same asymmetric loft as the visible trunk, then overlap
/// the dorsal/outer upper thigh. This deliberately changes only presentation
/// geometry: hip, hock, ankle, and planted digital contacts remain untouched.
enum CrowFemoralPlumage {
  // Keep the close-view field denser than the coarse seven-by-five fallback:
  // the smaller angular and longitudinal pitch lets neighboring flexible
  // vanes remain interleaved as the planted body sways over either leg.
  static let rowCount = 15
  static let courseCount = 18
  static let shellClearanceMeters: Float = 0.0009
  static let visibleRootEnvelopeRatio: Float = 0.74
  static let surfaceFeatherClass: UInt32 = 7
  /// Keeps the distal femoral vane course overlapped with the abdominal shell
  /// as the upper thigh begins retracting during takeoff. The bounded length
  /// changes presentation plumage only; hip and leg kinematics stay intact.
  static let bridgeLengthScale: Float = 0.68
  static let nominalMaximumLengthMeters: Float = 0.034
  /// Stable representative length for both standing and takeoff tessellation.
  /// Pose-dependent root-to-tip distance must not change temporal topology.
  static let topologyLODReferenceLengthMeters: Float = 0.035
  static let pelvicAxillaryHandoffMaximumWidthScale: Float = 1.35
  /// A bounded mid-course expansion roofs the camera-visible femoral insertion
  /// without adding a new row, moving roots, or changing leg articulation.
  static let insertionSeamMaximumWidthScale: Float = 1.36
  static let insertionSeamMaximumLengthScale: Float = 1.06
  static let coarseInsertionSeamMaximumWidthScale: Float = 1.52

  static func visibleSamples(
    bodyCenter: SIMD3<Float>,
    hip: SIMD3<Float>,
    hock: SIMD3<Float>,
    projectedPixelsPerMeter: Float
  ) -> [CrowFemoralPlumageFeather] {
    if projectedPixelsPerMeter >= 1_400 {
      return samples(bodyCenter: bodyCenter, hip: hip, hock: hock)
    }
    return coarseSamples(bodyCenter: bodyCenter, hip: hip, hock: hock)
  }

  static func samples(
    bodyCenter: SIMD3<Float>,
    hip: SIMD3<Float>,
    hock: SIMD3<Float>
  ) -> [CrowFemoralPlumageFeather] {
    let side: Float = hip.y >= bodyCenter.y ? 1 : -1
    let legAxis = normalized(hock - hip, fallback: SIMD3<Float>(0, 0, -1))
    var result: [CrowFemoralPlumageFeather] = []
    result.reserveCapacity(rowCount * courseCount)
    for row in 0..<rowCount {
      let baseRowFraction = Float(row) / Float(rowCount - 1)
      for course in 0..<courseCount {
        let rootIdentity = identityVariation(
          row: row,
          course: course,
          salt: 0x9E37_79B9
        )
        let shapeIdentity = identityVariation(
          row: row,
          course: course,
          salt: 0x85EB_CA6B
        )
        let materialIdentity = identityVariation(
          row: row,
          course: course,
          salt: 0xC2B2_AE35
        )
        let vaneIdentity = identityVariation(
          row: row,
          course: course,
          salt: 0xB529_7A4D
        )
        let edgeIdentity = identityVariation(
          row: row,
          course: course,
          salt: 0x68E3_1DA4
        )
        let cycleIdentity = identityVariation(
          row: row,
          course: course,
          salt: 0xD3A2_646C
        )
        let sweepIdentity = identityVariation(
          row: row,
          course: course,
          salt: 0xA511_E9B3
        )
        let liftIdentity = identityVariation(
          row: row,
          course: course,
          salt: 0x63D8_35F1
        )
        let rowStep = 1 / Float(rowCount - 1)
        let rowFraction = min(
          1,
          max(
            0,
            baseRowFraction
              + (row == 0 || row == rowCount - 1
                ? 0 : 0.11 * rowStep * rootIdentity)
          )
        )
        let theta = -1.36 + 0.98 * rowFraction
        let baseCourseFraction = Float(course) / Float(courseCount - 1)
        let courseStep = 1 / Float(courseCount - 1)
        let courseFraction = min(
          1,
          max(
            0,
            baseCourseFraction
              + (course == 0 || course == courseCount - 1
                ? 0 : 0.10 * courseStep * shapeIdentity)
          )
        )
        let stagger = courseStaggerMeters(row: row)
        let rootX = -0.068 + 0.068 * courseFraction - stagger
        let localSurface = mirroredSurfacePoint(
          x: rootX,
          theta: theta,
          side: side
        )
        let localNormal = mirroredSurfaceNormal(
          x: rootX,
          theta: theta,
          side: side
        )
        let rootSurface = bodyCenter + localSurface
        let root = rootSurface + shellClearanceMeters * localNormal
        let rootRelativeToHip = rootSurface - hip
        let radial = normalized(
          rootRelativeToHip
            - legAxis * simd_dot(rootRelativeToHip, legAxis),
          fallback: SIMD3<Float>(0, side, 0)
        )
        let tangential = normalized(
          simd_cross(legAxis, radial),
          fallback: SIMD3<Float>(1, 0, 0)
        )
        let targetFraction =
          0.035 + 0.195 * courseFraction
          + 0.008 * sin(2.35 * Float(row) + 0.61)
        let targetRadius =
          (0.0142 - 0.0011 * courseFraction)
          * (1 + 0.025 * rootIdentity)
        let breakupScale = anteriorGularHandoffBreakupScale(
          row: row,
          course: course
        )
        // Submillimetre lift and signed sweep keep neighboring tips from
        // collapsing into one conical cuff at presentation resolution. Roots
        // and the broad vane envelopes remain seated on the body shell.
        let tipRadialLift =
          (0.00025 + 0.00065 * (0.5 + 0.5 * liftIdentity))
          * (0.35 + 0.65 * courseFraction)
          * breakupScale
        let tipTangentialSweep = side * (
          0.00075 * sweepIdentity
            + 0.00035 * sin(1.71 * Float(row) + 0.83 * Float(course))
        ) * breakupScale
        let bridgeTarget =
          mix(hip, hock, targetFraction)
          + (targetRadius + tipRadialLift) * radial
          + tipTangentialSweep * tangential
        let bridgeVector = bridgeTarget - root
        let bridgeDistance = simd_length(bridgeVector)
        let length = min(
          nominalMaximumLengthMeters,
          max(0.018, bridgeLengthScale * bridgeDistance)
        )
          * (1 + 0.10 * shapeIdentity)
          * insertionSeamLengthScale(row: row, course: course)
        let direction = normalized(
          bridgeVector + 0.20 * bridgeDistance * legAxis,
          fallback: legAxis
        )
        let tip = root + length * direction
        let maximumWidth = min(0.0076, max(0.0041, 0.235 * length))
          * pelvicAxillaryHandoffWidthScale(row: row, course: course)
          * insertionSeamWidthScale(row: row, course: course)
        let lateralSweep = maximumWidth * (
          0.10 * sweepIdentity
            + 0.035 * sin(2.17 * Float(row) + 0.59 * Float(course))
        ) * breakupScale
        result.append(
          CrowFemoralPlumageFeather(
            side: side,
            row: row,
            course: course,
            rootSurface: rootSurface,
            root: root,
            tip: tip,
            planeNormal: normalized(
              0.85 * localNormal + 0.15 * radial,
              fallback: localNormal
            ),
            rootWidthMeters: rootWidthRatio(courseFraction: courseFraction)
              * maximumWidth,
            maximumWidthMeters: maximumWidth * (1 + 0.04 * shapeIdentity),
            camberMeters: (0.00085 + 0.00030 * courseFraction)
              * (1 + 0.08 * rootIdentity),
            lateralSweepMeters: lateralSweep,
            vaneAsymmetry: 0.040 * vaneIdentity,
            edgeRippleAmplitude:
              0.010 + 0.014 * (0.5 + 0.5 * edgeIdentity),
            edgeRipplePhase: Float.pi * (edgeIdentity + 1),
            edgeRippleCycles: 1.20 + 0.70 * (0.5 + 0.5 * cycleIdentity),
            rootEnvelopeRatio: visibleRootEnvelopeRatio,
            pennaceousStartFraction: 0,
            materialVariation: materialIdentity,
            bodyMaterialBlend: 0.88 - 0.28 * courseFraction
          )
        )
      }
    }
    return result
  }

  /// Broadens the compact posterior femoral field that roofs the pelvic side
  /// of the live axillary junction. The bilateral field leaves hip, hock,
  /// feather roots, and vane lengths unchanged.
  static func pelvicAxillaryHandoffWidthScale(
    row: Int,
    course: Int
  ) -> Float {
    let weight =
      max(0, 1 - abs(Float(row) - 8) / 2)
      * max(0, 1 - Float(course) / 2)
    return 1 + (pelvicAxillaryHandoffMaximumWidthScale - 1) * weight
  }

  /// Smooth-edged plateau over the exact rows and courses adjacent to the
  /// lower-body insertion seam in the temporal identity AOV. Rows 7...10 and
  /// courses 8...9 receive the full expansion; rows 6 and 11 taper it out.
  static func insertionSeamWidthScale(row: Int, course: Int) -> Float {
    let weight = insertionSeamWeight(row: row, course: course)
    return 1 + (insertionSeamMaximumWidthScale - 1) * weight
  }

  static func insertionSeamLengthScale(row: Int, course: Int) -> Float {
    let weight = insertionSeamWeight(row: row, course: course)
    return 1 + (insertionSeamMaximumLengthScale - 1) * weight
  }

  private static func insertionSeamWeight(row: Int, course: Int) -> Float {
    let rowDistance = abs(Float(row) - 8.5)
    let rowWeight = max(0, min(1, 1 - (rowDistance - 1.5) / 2))
    let courseDistance = abs(Float(course) - 8.5)
    let courseWeight = max(0, min(1, 1 - (courseDistance - 0.5)))
    return rowWeight * courseWeight
  }

  private static func coarseSamples(
    bodyCenter: SIMD3<Float>,
    hip: SIMD3<Float>,
    hock: SIMD3<Float>
  ) -> [CrowFemoralPlumageFeather] {
    let coarseRowCount = 5
    let coarseCourseCount = 7
    let side: Float = hip.y >= bodyCenter.y ? 1 : -1
    let legAxis = normalized(hock - hip, fallback: SIMD3<Float>(0, 0, -1))
    var result: [CrowFemoralPlumageFeather] = []
    result.reserveCapacity(coarseRowCount * coarseCourseCount)
    for row in 0..<coarseRowCount {
      let theta = -1.18 + 0.17 * Float(row)
      for course in 0..<coarseCourseCount {
        let courseFraction = Float(course) / Float(coarseCourseCount - 1)
        let stagger: Float = row.isMultiple(of: 2) ? 0 : 0.004
        let rootX = -0.070 + 0.075 * courseFraction - stagger
        let localSurface = mirroredSurfacePoint(x: rootX, theta: theta, side: side)
        let localNormal = mirroredSurfaceNormal(x: rootX, theta: theta, side: side)
        let rootSurface = bodyCenter + localSurface
        let root = rootSurface + shellClearanceMeters * localNormal
        let rootRelativeToHip = rootSurface - hip
        let radial = normalized(
          rootRelativeToHip
            - legAxis * simd_dot(rootRelativeToHip, legAxis),
          fallback: SIMD3<Float>(0, side, 0)
        )
        let tipFraction =
          0.105 + 0.165 * courseFraction
          + (row.isMultiple(of: 2) ? 0 : 0.012)
        let tipRadius = 0.0132 - 0.0015 * courseFraction
        let unscaledTip = mix(hip, hock, tipFraction) + tipRadius * radial
        let tip = root + coarseInsertionSeamLengthScale(row: row, course: course)
          * (unscaledTip - root)
        let length = simd_distance(root, tip)
        let maximumWidth = min(0.011, max(0.006, 0.30 * length))
          * coarseInsertionSeamWidthScale(row: row, course: course)
        result.append(
          CrowFemoralPlumageFeather(
            side: side,
            row: row,
            course: course,
            rootSurface: rootSurface,
            root: root,
            tip: tip,
            planeNormal: normalized(localNormal + radial, fallback: localNormal),
            rootWidthMeters: 0.56 * maximumWidth,
            maximumWidthMeters: maximumWidth,
            camberMeters: 0.0012 + 0.0004 * courseFraction,
            lateralSweepMeters: 0,
            vaneAsymmetry: 0,
            edgeRippleAmplitude: 0,
            edgeRipplePhase: 0,
            edgeRippleCycles: 0,
            rootEnvelopeRatio: 0.58,
            pennaceousStartFraction: 0,
            materialVariation: 0,
            bodyMaterialBlend: 0
          )
        )
      }
    }
    return result
  }

  /// The five-by-seven distance LOD retains the same visible insertion roof as
  /// the dense tract. Its anterior lateral course contains the exact owners
  /// adjacent to the rear-quarter pelvic slit; the neighboring rows taper the
  /// expansion instead of creating a broad cuff around the upper leg.
  static func coarseInsertionSeamWidthScale(row: Int, course: Int) -> Float {
    1 + (coarseInsertionSeamMaximumWidthScale - 1)
      * coarseInsertionSeamWeight(row: row, course: course)
  }

  static func coarseInsertionSeamLengthScale(row: Int, course: Int) -> Float {
    1 + (insertionSeamMaximumLengthScale - 1)
      * coarseInsertionSeamWeight(row: row, course: course)
  }

  private static func coarseInsertionSeamWeight(row: Int, course: Int) -> Float {
    guard course == 6 else { return 0 }
    return switch row {
    case 1, 2: 1
    case 0, 3: 0.5
    default: 0
    }
  }

  /// Signed non-repeating course offsets interdigitate the pelvic roots
  /// without forming the zipper-like alternating seam visible from below.
  static func courseStaggerMeters(row: Int) -> Float {
    0.00245 * sin(2.399_963 * Float(row) + 0.37)
  }

  /// The anterior courses at rows 5...6 roof the body/gular projection during
  /// takeoff. Keep these four boundary vanes seated while neighboring femoral
  /// feathers retain their non-repeating lift and centerline curvature.
  static func anteriorGularHandoffBreakupScale(row: Int, course: Int) -> Float {
    row >= 5 && row <= 6 && course >= 16 ? 0 : 1
  }

  /// Broad downy bases at the anterior femoral boundary keep the tract seated
  /// beneath the abdominal shell while leaving the pennaceous tip silhouette
  /// and maximum vane width unchanged.
  static func rootWidthRatio(courseFraction: Float) -> Float {
    let bounded = min(max(courseFraction, 0), 1)
    return 0.68 + 0.08 * bounded * bounded
  }

  private static func mirroredSurfacePoint(
    x: Float,
    theta: Float,
    side: Float
  ) -> SIMD3<Float> {
    let point = CrowBodyAnatomy.surfacePoint(atX: x, theta: theta)
    return SIMD3<Float>(point.x, side * point.y, point.z)
  }

  private static func mirroredSurfaceNormal(
    x: Float,
    theta: Float,
    side: Float
  ) -> SIMD3<Float> {
    let normal = CrowBodyAnatomy.surfaceNormal(atX: x, theta: theta)
    return SIMD3<Float>(normal.x, side * normal.y, normal.z)
  }

  private static func mix(
    _ first: SIMD3<Float>,
    _ second: SIMD3<Float>,
    _ blend: Float
  ) -> SIMD3<Float> {
    first + blend * (second - first)
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-8 ? value / length : fallback
  }

  private static func identityVariation(
    row: Int,
    course: Int,
    salt: UInt32
  ) -> Float {
    var value = UInt32(truncatingIfNeeded: row) &* 0x9E37_79B9
    value ^= UInt32(truncatingIfNeeded: course) &* 0x85EB_CA6B
    value ^= salt
    value ^= value >> 16
    value &*= 0x7FEB_352D
    value ^= value >> 15
    value &*= 0x846C_A68B
    value ^= value >> 16
    return 2 * Float(value & 0x00FF_FFFF) / Float(0x00FF_FFFF) - 1
  }
}
