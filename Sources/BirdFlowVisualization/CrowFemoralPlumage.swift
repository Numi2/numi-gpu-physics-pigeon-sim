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
  static let rowCount = 5
  static let courseCount = 7
  static let shellClearanceMeters: Float = 0.0009

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
      let theta = -1.18 + 0.17 * Float(row)
      for course in 0..<courseCount {
        let courseFraction = Float(course) / Float(courseCount - 1)
        let stagger: Float = row.isMultiple(of: 2) ? 0 : 0.004
        let rootX = -0.070 + 0.075 * courseFraction - stagger
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
}
