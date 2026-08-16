import simd

struct CrowUndertailCovertSample: Equatable {
  let row: Int
  let column: Int
  let rootSurfaceOffset: SIMD3<Float>
  let rootOffset: SIMD3<Float>
  let tipOffset: SIMD3<Float>
  let planeNormal: SIMD3<Float>
  let rootWidthMeters: Float
  let maximumWidthMeters: Float
  let camberMeters: Float
  let materialVariation: Float
}

/// Imbricated undertail coverts spanning the pelvic loft to rectrix roots.
///
/// The rectrices remain owned by the live standing feather deformation. This
/// body-seated shell covers only their otherwise exposed root fan, converging
/// from the broader ventral pelvis onto identity-matched rectrix centerlines.
enum CrowUndertailCoverts {
  static let rowCount = 13
  static let columnCount = 7
  static let shellClearanceMeters: Float = 0.00075

  static func visibleSamples(
    projectedPixelsPerMeter: Float
  ) -> [CrowUndertailCovertSample] {
    guard projectedPixelsPerMeter >= 1_400 else { return [] }
    return samples()
  }

  static func samples() -> [CrowUndertailCovertSample] {
    var result: [CrowUndertailCovertSample] = []
    result.reserveCapacity(rowCount * columnCount)
    let thetaStart = -2.12 as Float
    let thetaSpan = 1.10 as Float
    for row in 0..<rowCount {
      let baseRowFraction = Float(row) / Float(rowCount - 1)
      let tail = CrowClosedTailAnatomy.pose(fraction: baseRowFraction)
      for column in 0..<columnCount {
        let axial = Float(column) / Float(columnCount - 1)
        let rootIdentity = identityVariation(
          row: row,
          column: column,
          salt: 0x9E37_79B9
        )
        let shapeIdentity = identityVariation(
          row: row,
          column: column,
          salt: 0x85EB_CA6B
        )
        let materialIdentity = identityVariation(
          row: row,
          column: column,
          salt: 0xC2B2_AE35
        )
        let rowStep = 1 / Float(rowCount - 1)
        let rowFraction = min(
          1,
          max(
            0,
            baseRowFraction
              + (row == 0 || row == rowCount - 1
                ? 0 : 0.10 * rowStep * rootIdentity)
          )
        )
        let theta = thetaStart + thetaSpan * rowFraction
        let stagger: Float = row.isMultiple(of: 2) || column == 0 ? 0 : 0.0038
        let rootX = -0.058 - 0.100 * axial - stagger
        let rootSurface = CrowBodyAnatomy.surfacePoint(atX: rootX, theta: theta)
        let rootNormal = CrowBodyAnatomy.surfaceNormal(atX: rootX, theta: theta)
        let root = rootSurface + shellClearanceMeters * rootNormal
        let rectrixOverlap = 0.018 + 0.012 * axial
        let target = tail.rootOffset + rectrixOverlap * tail.direction
        let towardTarget = normalized(target - root, fallback: tail.direction)
        let length =
          (0.032 + 0.014 * axial + 0.002 * (1 - abs(2 * rowFraction - 1)))
          * (1 + 0.055 * shapeIdentity)
        let tip = root + length * towardTarget
        let halfAngularStep = 0.5 * thetaSpan / Float(rowCount - 1)
        let circumferentialSpacing = simd_distance(
          CrowBodyAnatomy.surfacePoint(
            atX: rootX,
            theta: theta - halfAngularStep
          ),
          CrowBodyAnatomy.surfacePoint(
            atX: rootX,
            theta: theta + halfAngularStep
          )
        )
        let maximumWidth =
          max(0.0048, 0.88 * circumferentialSpacing)
          * (1 + 0.045 * shapeIdentity)
        result.append(
          CrowUndertailCovertSample(
            row: row,
            column: column,
            rootSurfaceOffset: rootSurface,
            rootOffset: root,
            tipOffset: tip,
            planeNormal: normalized(
              0.84 * rootNormal + 0.16 * tail.normal,
              fallback: rootNormal
            ),
            rootWidthMeters: 0.58 * maximumWidth,
            maximumWidthMeters: maximumWidth,
            camberMeters: (0.0011 + 0.0005 * axial)
              * (1 + 0.08 * rootIdentity),
            materialVariation: materialIdentity
          )
        )
      }
    }
    return result
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
    column: Int,
    salt: UInt32
  ) -> Float {
    var value = UInt32(truncatingIfNeeded: row) &* 0x9E37_79B9
    value ^= UInt32(truncatingIfNeeded: column) &* 0x85EB_CA6B
    value ^= salt
    value ^= value >> 16
    value &*= 0x7FEB_352D
    value ^= value >> 15
    value &*= 0x846C_A68B
    value ^= value >> 16
    return 2 * Float(value & 0x00FF_FFFF) / Float(0x00FF_FFFF) - 1
  }
}
