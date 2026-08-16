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
  let vaneAsymmetry: Float
  let edgeRippleAmplitude: Float
  let edgeRipplePhase: Float
  let edgeRippleCycles: Float
  let rootEnvelopeRatio: Float
  let pennaceousStartFraction: Float
  let materialVariation: Float
}

/// Imbricated upper-tail coverts joining the dorsal pelvic shell to the
/// rectrix stack. The feathered shell remains visibly layered, while its broad
/// proximal vanes prevent the background from opening through the rump-to-tail
/// insertion at oblique rear views.
enum CrowUppertailCoverts {
  static let rowCount = 27
  static let columnCount = 10
  static let shellClearanceMeters: Float = 0.00078
  static let rectrixDorsalClearanceMeters: Float = 0.016
  static let visibleRootEnvelopeRatio: Float = 0.64
  static let surfaceFeatherClass: UInt32 = 5

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
        let vaneIdentity = identityVariation(
          row: row,
          column: column,
          salt: 0xB529_7A4D
        )
        let edgeIdentity = identityVariation(
          row: row,
          column: column,
          salt: 0x68E3_1DA4
        )
        let cycleIdentity = identityVariation(
          row: row,
          column: column,
          salt: 0x9E37_79B9
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
        let stagger = column == 0 ? 0 : courseStaggerMeters(row: row)
        let rootX = -0.060 - 0.102 * axial - stagger
        let rootSurface = CrowBodyAnatomy.surfacePoint(atX: rootX, theta: theta)
        let rootNormal = CrowBodyAnatomy.surfaceNormal(atX: rootX, theta: theta)
        let root = rootSurface + shellClearanceMeters * rootNormal
        let rectrixOverlap = rectrixOverlapMeters(axialFraction: axial)
        let rectrixOverlapPoint = tail.rootOffset + rectrixOverlap * tail.direction
        let target =
          rectrixOverlapPoint
          + rectrixDorsalClearanceMeters * axial * axial * tail.normal
        let towardTarget = normalized(target - root, fallback: tail.direction)
        let localLength =
          (0.034 + 0.018 * axial + 0.0025 * (1 - abs(2 * rowFraction - 1)))
          * (1 + 0.050 * shapeIdentity)
        // Preserve the established covert length while steering its distal
        // centerline above the rectrix root stack.
        let targetLength =
          simd_distance(root, rectrixOverlapPoint) + 0.0015 * shapeIdentity
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
          * insertionWidthScale(rowFraction: rowFraction, axialFraction: axial)
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
            rootWidthMeters: 0.68 * maximumWidth,
            maximumWidthMeters: maximumWidth,
            camberMeters: (0.0012 + 0.00055 * axial)
              * (1 + 0.075 * rootIdentity),
            vaneAsymmetry: 0.035 * vaneIdentity,
            edgeRippleAmplitude:
              0.008 + 0.012 * (0.5 + 0.5 * edgeIdentity),
            edgeRipplePhase: Float.pi * (edgeIdentity + 1),
            edgeRippleCycles: 1.20 + 0.70 * (0.5 + 0.5 * cycleIdentity),
            rootEnvelopeRatio: visibleRootEnvelopeRatio,
            pennaceousStartFraction: 0,
            materialVariation: materialIdentity
          )
        )
      }
    }
    return result
  }

  static func courseStaggerMeters(row: Int) -> Float {
    0.00285 * sin(2.399_963 * Float(row) + 0.41)
  }

  static func rectrixOverlapMeters(axialFraction: Float) -> Float {
    0.020 + 0.030 * min(max(axialFraction, 0), 1)
  }

  /// Medial posterior coverts broaden over the rectrix insertion where their
  /// tapered tips otherwise reveal the smooth pelvic loft to rear cameras.
  static func insertionWidthScale(
    rowFraction: Float,
    axialFraction: Float
  ) -> Float {
    let medial = smootherstep(
      min(max((1 - abs(2 * rowFraction - 1) - 0.35) / 0.65, 0), 1)
    )
    let posterior = smootherstep(
      min(max((axialFraction - 0.55) / 0.45, 0), 1)
    )
    return 1 + 0.38 * medial * posterior
  }

  private static func smootherstep(_ value: Float) -> Float {
    value * value * value * (value * (value * 6 - 15) + 10)
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
