import simd

struct CrowThroatBridgeFeather: Equatable {
  let side: Float
  let row: Int
  let column: Int
  let neckCoupling: Float
  let rootSurfaceOffset: SIMD3<Float>
  let rootOffset: SIMD3<Float>
  let tipOffset: SIMD3<Float>
  let planeNormal: SIMD3<Float>
  let rootWidthMeters: Float
  let maximumWidthMeters: Float
  let camberMeters: Float
  let materialVariation: Float
}

/// Interdigitated throat feathers crossing the cervical/pectoral boundary.
///
/// These feathers are rooted on the anterior body loft and receive a graded
/// fraction of the quiet neck transform. The anterior course follows the head
/// more than the posterior course, preventing either a rigid collar or a crack
/// when the simulated crow makes millimetric standing motions.
enum CrowThroatBridgeFeathers {
  static let rowCount = 9
  static let columnCount = 4
  static let shellClearanceMeters: Float = 0.0007

  static func visibleSamples(
    neckPose: CrowStandingNeckPose? = nil,
    projectedPixelsPerMeter: Float
  ) -> [CrowThroatBridgeFeather] {
    guard projectedPixelsPerMeter >= 1_400 else { return [] }
    return samples(neckPose: neckPose)
  }

  static func samples(
    neckPose: CrowStandingNeckPose? = nil
  ) -> [CrowThroatBridgeFeather] {
    var result: [CrowThroatBridgeFeather] = []
    result.reserveCapacity(2 * rowCount * columnCount)
    for side: Float in [-1, 1] {
      for row in 0..<rowCount {
        let baseRowFraction = Float(row) / Float(rowCount - 1)
        for column in 0..<columnCount {
          let columnFraction = Float(column) / Float(columnCount - 1)
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
          let theta = -1.52 + 1.02 * rowFraction
          let rowStagger: Float = row.isMultiple(of: 2) ? 0 : 0.0022
          let rootX = 0.149 - 0.029 * columnFraction - rowStagger
          let rootSurface = mirroredSurfacePoint(x: rootX, theta: theta, side: side)
          let rootNormal = mirroredSurfaceNormal(x: rootX, theta: theta, side: side)
          let unposedRoot = rootSurface + shellClearanceMeters * rootNormal
          let length =
            (0.026 + 0.006 * columnFraction + 0.002 * rowFraction)
            * (1 + 0.055 * shapeIdentity)
          let tipX = rootX - length
          let tipTheta = theta - 0.025 + 0.010 * rootIdentity
          let tipSurface = mirroredSurfacePoint(x: tipX, theta: tipTheta, side: side)
          let tipNormal = mirroredSurfaceNormal(x: tipX, theta: tipTheta, side: side)
          let unposedTip = tipSurface + shellClearanceMeters * tipNormal
          let neckCoupling = 0.76 - 0.42 * columnFraction
          let halfAngularStep = 0.5 * 1.02 / Float(rowCount - 1)
          let circumferentialSpacing = simd_distance(
            mirroredSurfacePoint(
              x: rootX,
              theta: theta - halfAngularStep,
              side: side
            ),
            mirroredSurfacePoint(
              x: rootX,
              theta: theta + halfAngularStep,
              side: side
            )
          )
          let maximumWidth =
            max(0.0044, 0.88 * circumferentialSpacing)
            * (1 + 0.045 * shapeIdentity)
          let unposedPlaneNormal = normalized(
            0.80 * rootNormal + 0.20 * tipNormal,
            fallback: rootNormal
          )
          result.append(
            CrowThroatBridgeFeather(
              side: side,
              row: row,
              column: column,
              neckCoupling: neckCoupling,
              rootSurfaceOffset:
                neckPose?.transform(offset: rootSurface, coupling: neckCoupling)
                ?? rootSurface,
              rootOffset:
                neckPose?.transform(offset: unposedRoot, coupling: neckCoupling)
                ?? unposedRoot,
              tipOffset:
                neckPose?.transform(offset: unposedTip, coupling: neckCoupling)
                ?? unposedTip,
              planeNormal:
                neckPose?.rotated(unposedPlaneNormal, coupling: neckCoupling)
                ?? unposedPlaneNormal,
              rootWidthMeters: 0.58 * maximumWidth,
              maximumWidthMeters: maximumWidth,
              camberMeters: (0.0010 + 0.0003 * columnFraction)
                * (1 + 0.08 * rootIdentity),
              materialVariation: materialIdentity
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
