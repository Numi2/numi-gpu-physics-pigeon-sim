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
  static let rowCount = 9
  static let columnCount = 20
  static let shellClearanceMeters: Float = 0.0012

  static func visibleSamples(
    projectedPixelsPerMeter: Float
  ) -> [CrowFoldedWingCovertSample] {
    if projectedPixelsPerMeter >= 1_400 { return samples() }
    return coarseSamples()
  }

  static func samples() -> [CrowFoldedWingCovertSample] {
    var result: [CrowFoldedWingCovertSample] = []
    result.reserveCapacity(2 * rowCount * columnCount)
    for side: Float in [-1, 1] {
      for row in 0..<rowCount {
        let baseRowFraction = Float(row) / Float(rowCount - 1)
        for column in 0..<columnCount {
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
          let theta = 0.94 - 1.02 * rowFraction
          let baseAxial = Float(column) / Float(columnCount - 1)
          let axialStep = 1 / Float(columnCount - 1)
          let axial = min(
            1,
            max(
              0,
              baseAxial
                + (column == 0 || column == columnCount - 1
                  ? 0 : 0.09 * axialStep * shapeIdentity)
            )
          )
          let stagger: Float =
            row.isMultiple(of: 2)
            ? 0
            : 0.5 * 0.224 / Float(columnCount - 1)
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
          let nominalLength =
            (0.034 + 0.044 * axial + 0.006 * rowFraction)
            * (1 + 0.055 * shapeIdentity)
          let tipX = rootX - nominalLength
          let tipTheta =
            theta - 0.050 - 0.024 * axial + 0.012 * rootIdentity
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
            0.0062,
            0.78
              * circumferentialSpacing(
                x: rootX,
                theta: theta,
                rowCount: rowCount
              )
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
              rootWidthMeters: 0.52 * localWidth,
              maximumWidthMeters:
                localWidth * (1 + 0.08 * axial) * (1 + 0.04 * shapeIdentity),
              camberMeters: (0.00155 + 0.00055 * rowFraction)
                * (1 + 0.09 * rootIdentity)
            )
          )
        }
      }
    }
    return result
  }

  private static func coarseSamples() -> [CrowFoldedWingCovertSample] {
    let coarseRowCount = 5
    let coarseColumnCount = 13
    var result: [CrowFoldedWingCovertSample] = []
    result.reserveCapacity(2 * coarseRowCount * coarseColumnCount)
    for side: Float in [-1, 1] {
      for row in 0..<coarseRowCount {
        let rowFraction = Float(row) / Float(coarseRowCount - 1)
        let theta = 0.92 - 0.98 * rowFraction
        for column in 0..<coarseColumnCount {
          let axial = Float(column) / Float(coarseColumnCount - 1)
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
            0.88
              * circumferentialSpacing(
                x: rootX,
                theta: theta,
                rowCount: coarseRowCount
              )
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

  private static func circumferentialSpacing(
    x: Float,
    theta: Float,
    rowCount: Int
  ) -> Float {
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
