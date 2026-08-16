import simd

struct CrowUppertailCovertSample: Equatable {
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

/// Imbricated upper-tail coverts joining the dorsal pelvic shell to the
/// rectrix stack. The feathered shell remains visibly layered, while its broad
/// proximal vanes prevent the background from opening through the rump-to-tail
/// insertion at oblique rear views.
enum CrowUppertailCoverts {
  static let rowCount = 27
  static let columnCount = 8
  static let shellClearanceMeters: Float = 0.00078

  static func visibleSamples(
    projectedPixelsPerMeter: Float
  ) -> [CrowUppertailCovertSample] {
    guard projectedPixelsPerMeter >= 1_400 else { return [] }
    return samples()
  }

  static func samples() -> [CrowUppertailCovertSample] {
    var result: [CrowUppertailCovertSample] = []
    result.reserveCapacity(rowCount * columnCount)
    let thetaStart = 0.12 as Float
    let thetaSpan = Float.pi - 0.24
    for row in 0..<rowCount {
      let baseRowFraction = Float(row) / Float(rowCount - 1)
      let tail = CrowClosedTailAnatomy.pose(fraction: baseRowFraction)
      for column in 0..<columnCount {
        let axial = Float(column) / Float(columnCount - 1)
        let rootIdentity = identityVariation(
          row: row,
          column: column,
          salt: 0x27D4_EB2F
        )
        let shapeIdentity = identityVariation(
          row: row,
          column: column,
          salt: 0x1656_67B1
        )
        let materialIdentity = identityVariation(
          row: row,
          column: column,
          salt: 0xD3A2_646C
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
        let stagger: Float = row.isMultiple(of: 2) || column == 0 ? 0 : 0.0034
        let rootX = -0.060 - 0.102 * axial - stagger
        let rootSurface = CrowBodyAnatomy.surfacePoint(atX: rootX, theta: theta)
        let rootNormal = CrowBodyAnatomy.surfaceNormal(atX: rootX, theta: theta)
        let root = rootSurface + shellClearanceMeters * rootNormal
        let rectrixOverlap = 0.020 + 0.013 * axial
        let target = tail.rootOffset + rectrixOverlap * tail.direction
        let towardTarget = normalized(target - root, fallback: tail.direction)
        let localLength =
          (0.034 + 0.018 * axial + 0.0025 * (1 - abs(2 * rowFraction - 1)))
          * (1 + 0.050 * shapeIdentity)
        let targetLength = simd_distance(root, target) + 0.0015 * shapeIdentity
        let length = mix(localLength, targetLength, axial * axial * axial)
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
          max(0.0049, 0.94 * circumferentialSpacing)
          * (1 + 0.042 * shapeIdentity)
        result.append(
          CrowUppertailCovertSample(
            row: row,
            column: column,
            rootSurfaceOffset: rootSurface,
            rootOffset: root,
            tipOffset: tip,
            planeNormal: normalized(
              0.86 * rootNormal + 0.14 * tail.normal,
              fallback: rootNormal
            ),
            rootWidthMeters: 0.62 * maximumWidth,
            maximumWidthMeters: maximumWidth,
            camberMeters: (0.0012 + 0.00055 * axial)
              * (1 + 0.075 * rootIdentity),
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

  private static func mix(_ first: Float, _ second: Float, _ blend: Float) -> Float {
    first + blend * (second - first)
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
