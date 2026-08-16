import simd

struct CrowFoldedWingCovertSample: Equatable {
  let side: Float
  let row: Int
  let column: Int
  let rootSurfaceOffset: SIMD3<Float>
  let rootOffset: SIMD3<Float>
  let tipOffset: SIMD3<Float>
  let planeNormal: SIMD3<Float>
  let rootWidthMeters: Float
  let maximumWidthMeters: Float
  let camberMeters: Float
}

/// An imbricated folded-wing shell seated on the same loft as the trunk.
///
/// The former rectangular root grid was only plausible from the release
/// three-quarter view. Sampling the actual body envelope closes the scapular
/// and axillary seams from arbitrary cameras while retaining explicit feather
/// identities that can move to mesh shaders on future hardware.
enum CrowFoldedWingCoverts {
  static let rowCount = 5
  static let columnCount = 13
  static let shellClearanceMeters: Float = 0.0012

  static func samples() -> [CrowFoldedWingCovertSample] {
    var result: [CrowFoldedWingCovertSample] = []
    result.reserveCapacity(2 * rowCount * columnCount)
    for side: Float in [-1, 1] {
      for row in 0..<rowCount {
        let rowFraction = Float(row) / Float(rowCount - 1)
        let theta = 0.92 - 0.98 * rowFraction
        for column in 0..<columnCount {
          let axial = Float(column) / Float(columnCount - 1)
          let stagger: Float = row.isMultiple(of: 2) ? 0 : 0.0045
          let rootX = 0.092 - 0.224 * axial - stagger
          let rootSurface = mirroredSurfacePoint(
            x: rootX,
            theta: theta,
            side: side
          )
          let rootNormal = mirroredSurfaceNormal(
            x: rootX,
            theta: theta,
            side: side
          )
          let clearance = shellClearanceMeters + 0.00025 * rowFraction
          let root = rootSurface + clearance * rootNormal
          let nominalLength = 0.038 + 0.044 * axial + 0.007 * rowFraction
          let tipX = rootX - nominalLength
          let tipTheta = theta - 0.055 - 0.025 * axial
          let clampedTipX = max(tipX, CrowBodyAnatomy.loftRings.first!.x)
          let tipSurface = mirroredSurfacePoint(
            x: clampedTipX,
            theta: tipTheta,
            side: side
          )
          let tipNormal = mirroredSurfaceNormal(
            x: clampedTipX,
            theta: tipTheta,
            side: side
          )
          var tip = tipSurface + clearance * tipNormal
          if tipX < clampedTipX {
            tip += SIMD3<Float>(tipX - clampedTipX, 0, 0.16 * (tipX - clampedTipX))
          }
          let localWidth = max(
            0.0085,
            0.88 * circumferentialSpacing(x: rootX, theta: theta)
          )
          result.append(
            CrowFoldedWingCovertSample(
              side: side,
              row: row,
              column: column,
              rootSurfaceOffset: rootSurface,
              rootOffset: root,
              tipOffset: tip,
              planeNormal: normalized(rootNormal + tipNormal, fallback: rootNormal),
              rootWidthMeters: 0.58 * localWidth,
              maximumWidthMeters: localWidth * (1 + 0.10 * axial),
              camberMeters: 0.0018 + 0.0007 * rowFraction
            )
          )
        }
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

  private static func circumferentialSpacing(x: Float, theta: Float) -> Float {
    let halfStep = 0.5 * Float.pi / Float(rowCount + 2)
    return simd_distance(
      CrowBodyAnatomy.surfacePoint(atX: x, theta: theta - halfStep),
      CrowBodyAnatomy.surfacePoint(atX: x, theta: theta + halfStep)
    )
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-8 ? value / length : fallback
  }
}
