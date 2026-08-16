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
}

/// Estimated femoral tract joining pelvic contour plumage to the crural tract.
///
/// Roots follow the same asymmetric loft as the visible trunk, then overlap
/// the dorsal/outer upper thigh. This deliberately changes only presentation
/// geometry: hip, hock, ankle, and planted digital contacts remain untouched.
enum CrowFemoralPlumage {
  static let rowCount = 9
  static let courseCount = 12
  static let shellClearanceMeters: Float = 0.0009

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
        let theta = -1.20 + 0.70 * rowFraction
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
        let stagger: Float =
          row.isMultiple(of: 2)
          ? 0
          : 0.0028
        let rootX = -0.048 + 0.040 * courseFraction - stagger
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
          0.045 + 0.145 * courseFraction
          + (row.isMultiple(of: 2) ? 0 : 0.008)
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
        let maximumWidth = min(0.0082, max(0.0043, 0.22 * length))
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
            rootWidthMeters: 0.52 * maximumWidth,
            maximumWidthMeters: maximumWidth * (1 + 0.04 * shapeIdentity),
            camberMeters: (0.00085 + 0.00030 * courseFraction)
              * (1 + 0.08 * rootIdentity)
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
            camberMeters: 0.0012 + 0.0004 * courseFraction
          )
        )
      }
    }
    return result
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
