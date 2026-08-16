import simd

enum CrowVentralFeatherTractRegion: UInt8, CaseIterable {
  case pectoral
  case abdominal
}

struct CrowVentralFeatherTractSample: Equatable {
  let region: CrowVentralFeatherTractRegion
  let surfaceFeatherClass: UInt32
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
  let rootEnvelopeRatio: Float
  let pennaceousStartFraction: Float
  let vaneAsymmetry: Float
  let edgeRippleAmplitude: Float
  let edgeRipplePhase: Float
  let edgeRippleCycles: Float
  let materialVariation: Float
}

/// Body-seated ventral pterylae over the breast and abdomen.
///
/// American-crow pterylosis separates the ventral tract into pectoral and
/// abdominal parts. These interdigitated courses sit on the owning body loft
/// and overlap the proximal femoral field; they are an explicit future-compute
/// layer rather than a displacement or texture painted over the trunk.
enum CrowVentralFeatherTracts {
  static let pectoralRowCount = 13
  static let pectoralColumnCount = 24
  static let abdominalRowCount = 10
  static let abdominalColumnCount = 22
  static let shellClearanceMeters: Float = 0.0008

  static func visibleSamples(
    projectedPixelsPerMeter: Float
  ) -> [CrowVentralFeatherTractSample] {
    guard projectedPixelsPerMeter >= 1_400 else { return [] }
    return samples()
  }

  static func samples() -> [CrowVentralFeatherTractSample] {
    var result: [CrowVentralFeatherTractSample] = []
    result.reserveCapacity(
      2
        * (pectoralRowCount * pectoralColumnCount
          + abdominalRowCount * abdominalColumnCount)
    )
    appendRegion(
      .pectoral,
      rowCount: pectoralRowCount,
      columnCount: pectoralColumnCount,
      thetaRange: -1.50...0.12,
      axialRange: -0.030...0.150,
      baseLengthMeters: 0.028,
      to: &result
    )
    appendRegion(
      .abdominal,
      rowCount: abdominalRowCount,
      columnCount: abdominalColumnCount,
      thetaRange: -1.50 ... -0.45,
      axialRange: -0.145...0.008,
      baseLengthMeters: 0.030,
      to: &result
    )
    return result
  }

  private static func appendRegion(
    _ region: CrowVentralFeatherTractRegion,
    rowCount: Int,
    columnCount: Int,
    thetaRange: ClosedRange<Float>,
    axialRange: ClosedRange<Float>,
    baseLengthMeters: Float,
    to result: inout [CrowVentralFeatherTractSample]
  ) {
    let thetaSpan = thetaRange.upperBound - thetaRange.lowerBound
    let axialSpan = axialRange.upperBound - axialRange.lowerBound
    for side: Float in [-1, 1] {
      for row in 0..<rowCount {
        let baseRowFraction = Float(row) / Float(rowCount - 1)
        for column in 0..<columnCount {
          let baseAxial = Float(column) / Float(columnCount - 1)
          let rootIdentity = identityVariation(
            region: region,
            row: row,
            column: column,
            salt: 0x9E37_79B9
          )
          let shapeIdentity = identityVariation(
            region: region,
            row: row,
            column: column,
            salt: 0x85EB_CA6B
          )
          let materialIdentity = identityVariation(
            region: region,
            row: row,
            column: column,
            salt: 0xC2B2_AE35
          )
          let vaneIdentity = identityVariation(
            region: region,
            row: row,
            column: column,
            salt: 0xB529_7A4D
          )
          let edgeIdentity = identityVariation(
            region: region,
            row: row,
            column: column,
            salt: 0x68E3_1DA4
          )
          let cycleIdentity = identityVariation(
            region: region,
            row: row,
            column: column,
            salt: 0xD3A2_646C
          )
          let rowStep = 1 / Float(rowCount - 1)
          let rowFraction = clamp(
            baseRowFraction
              + (row == 0 || row == rowCount - 1
                ? 0
                : rowStep * rootRowFlowSteps(
                  region: region,
                  row: row,
                  column: column
                )),
            lower: 0,
            upper: 1
          )
          let axialStep = 1 / Float(columnCount - 1)
          let axial = clamp(
            baseAxial
              + (column == 0 || column == columnCount - 1
                ? 0 : 0.10 * axialStep * shapeIdentity),
            lower: 0,
            upper: 1
          )
          let theta = thetaRange.lowerBound + thetaSpan * rowFraction
          let stagger: Float =
            row.isMultiple(of: 2) || column == 0
            ? 0
            : 0.48 * axialSpan / Float(columnCount - 1)
          let rootX = axialRange.upperBound - axialSpan * axial - stagger
          let rootSurface = mirroredSurfacePoint(x: rootX, theta: theta, side: side)
          let rootNormal = mirroredSurfaceNormal(x: rootX, theta: theta, side: side)
          let root = rootSurface + shellClearanceMeters * rootNormal
          let length =
            (baseLengthMeters + 0.010 * axial + 0.003 * rowFraction)
            * (1 + 0.055 * shapeIdentity)
          let tipX = max(
            rootX - length,
            CrowBodyAnatomy.loftRings.first!.x
          )
          let tipTheta = theta - 0.030 - 0.015 * axial + 0.009 * rootIdentity
          let tipSurface = mirroredSurfacePoint(x: tipX, theta: tipTheta, side: side)
          let tipNormal = mirroredSurfaceNormal(x: tipX, theta: tipTheta, side: side)
          let tip = tipSurface + shellClearanceMeters * tipNormal
          let halfAngularStep = 0.5 * thetaSpan / Float(rowCount - 1)
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
            max(0.0062, 0.86 * circumferentialSpacing)
            * (1 + 0.045 * shapeIdentity)
          let centerline = normalized(
            tip - root,
            fallback: SIMD3<Float>(-1, 0, 0)
          )
          let basePlaneNormal = normalized(
            0.82 * rootNormal + 0.18 * tipNormal,
            fallback: rootNormal
          )
          let crownAxis = normalized(
            simd_cross(basePlaneNormal, centerline),
            fallback: SIMD3<Float>(0, side, 0)
          )
          let planeNormal = normalized(
            basePlaneNormal
              + side
              * crownRollSlope(
                region: region,
                row: row,
                column: column
              ) * crownAxis,
            fallback: basePlaneNormal
          )
          result.append(
            CrowVentralFeatherTractSample(
              region: region,
              surfaceFeatherClass: surfaceFeatherClass(for: region),
              side: side,
              row: row,
              column: column,
              rootSurfaceOffset: rootSurface,
              rootOffset: root,
              tipOffset: tip,
              planeNormal: planeNormal,
              rootWidthMeters:
                region == .pectoral && column == 0
                ? 0.82 * maximumWidth
                : (region == .pectoral && column == 1
                  ? 0.66 * maximumWidth : 0.54 * maximumWidth),
              maximumWidthMeters: maximumWidth,
              camberMeters: (0.00115 + 0.00045 * axial)
                * (1 + 0.08 * rootIdentity),
              rootEnvelopeRatio:
                region == .pectoral
                ? 0.66 - 0.08 * axial
                : 0.62 - 0.06 * axial,
              pennaceousStartFraction:
                region == .pectoral && column == 0
                ? 0.10
                : (region == .pectoral && column == 1 ? 0.24 : 0.34),
              vaneAsymmetry: 0.045 * vaneIdentity,
              edgeRippleAmplitude:
                0.012 + 0.016 * (0.5 + 0.5 * edgeIdentity),
              edgeRipplePhase: Float.pi * (edgeIdentity + 1),
              edgeRippleCycles: 1.35 + 0.65 * (0.5 + 0.5 * cycleIdentity),
              materialVariation: materialIdentity
            )
          )
        }
      }
    }
  }

  /// Both explicit ventral pterylae continue the short, soft body-contour
  /// material across the breast and abdomen instead of falling back to the
  /// generic feather response between the surrounding ventral shingles.
  static func surfaceFeatherClass(
    for region: CrowVentralFeatherTractRegion
  ) -> UInt32 {
    switch region {
    case .pectoral, .abdominal:
      return 7
    }
  }

  /// Pectoral and abdominal roots follow coherent but non-lattice tract flow.
  /// The bound stays below one quarter row interval so roots cannot reorder.
  static func rootRowFlowSteps(
    region: CrowVentralFeatherTractRegion,
    row: Int,
    column: Int
  ) -> Float {
    let regionPhase: Float = region == .pectoral ? 0.31 : 1.07
    let smooth = 0.15 * sin(
      Float(row) * 1.11 + Float(column) * 0.67 + regionPhase
    )
    let identity = identityVariation(
      region: region,
      row: row,
      column: column,
      salt: 0x27D4_EB2F
    )
    return smooth + 0.070 * identity
  }

  /// Mirrored crown roll varies grazing response without moving either end of
  /// a vane away from its anatomically owned body surface.
  static func crownRollSlope(
    region: CrowVentralFeatherTractRegion,
    row: Int,
    column: Int
  ) -> Float {
    let regionPhase: Float = region == .pectoral ? 0.73 : 1.39
    let smooth = 0.045 * sin(
      Float(row) * 0.83 + Float(column) * 0.51 + regionPhase
    )
    let identity = identityVariation(
      region: region,
      row: row,
      column: column,
      salt: 0x1656_67B1
    )
    return smooth + 0.020 * identity
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

  private static func clamp(
    _ value: Float,
    lower: Float,
    upper: Float
  ) -> Float {
    min(max(value, lower), upper)
  }

  private static func identityVariation(
    region: CrowVentralFeatherTractRegion,
    row: Int,
    column: Int,
    salt: UInt32
  ) -> Float {
    var value = UInt32(truncatingIfNeeded: row) &* 0x9E37_79B9
    value ^= UInt32(truncatingIfNeeded: column) &* 0x85EB_CA6B
    value ^= region == .pectoral ? 0xA511_E9B3 : 0x63D8_3595
    value ^= salt
    value ^= value >> 16
    value &*= 0x7FEB_352D
    value ^= value >> 15
    value &*= 0x846C_A68B
    value ^= value >> 16
    return 2 * Float(value & 0x00FF_FFFF) / Float(0x00FF_FFFF) - 1
  }
}
