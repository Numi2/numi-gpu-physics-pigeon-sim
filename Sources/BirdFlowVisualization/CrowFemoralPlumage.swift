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
  static let rowCount = 13
  static let courseCount = 16
  static let shellClearanceMeters: Float = 0.0009
  static let visibleRootEnvelopeRatio: Float = 0.74
  static let surfaceFeatherClass: UInt32 = 7

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
        let targetFraction =
          0.035 + 0.195 * courseFraction
          + 0.008 * sin(2.35 * Float(row) + 0.61)
        let targetRadius =
          (0.0142 - 0.0011 * courseFraction)
          * (1 + 0.025 * rootIdentity)
        let bridgeTarget =
          mix(hip, hock, targetFraction) + targetRadius * radial
        let bridgeVector = bridgeTarget - root
        let bridgeDistance = simd_length(bridgeVector)
        let length =
          min(0.0285, max(0.018, 0.56 * bridgeDistance))
          * (1 + 0.10 * shapeIdentity)
        let direction = normalized(
          bridgeVector + 0.20 * bridgeDistance * legAxis,
          fallback: legAxis
        )
        let tip = root + length * direction
        let maximumWidth = min(0.0076, max(0.0041, 0.235 * length))
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
            rootWidthMeters: 0.68 * maximumWidth,
            maximumWidthMeters: maximumWidth * (1 + 0.04 * shapeIdentity),
            camberMeters: (0.00085 + 0.00030 * courseFraction)
              * (1 + 0.08 * rootIdentity),
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
        let tip = mix(hip, hock, tipFraction) + tipRadius * radial
        let length = simd_distance(root, tip)
        let maximumWidth = min(0.011, max(0.006, 0.30 * length))
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

  /// Signed non-repeating course offsets interdigitate the pelvic roots
  /// without forming the zipper-like alternating seam visible from below.
  static func courseStaggerMeters(row: Int) -> Float {
    0.00245 * sin(2.399_963 * Float(row) + 0.37)
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
