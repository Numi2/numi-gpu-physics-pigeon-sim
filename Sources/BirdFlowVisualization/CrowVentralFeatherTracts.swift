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
  let lodReferenceLengthMeters: Float
  let planeNormal: SIMD3<Float>
  let rootWidthMeters: Float
  let maximumWidthMeters: Float
  let camberMeters: Float
  let lateralSweepMeters: Float
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
  static let pectoralRowCount = 18
  static let pectoralColumnCount = 24
  static let abdominalRowCount = 10
  static let abdominalColumnCount = 22
  static let shellClearanceMeters: Float = 0.0008
  static let transverseCamberRatio: Float = 0.07
  static let retainedRachisTransverseCamberRatio: Float = 0.07

  /// Only interior body-surface records receive a second crown rachis. Boundary
  /// rows and terminal axial courses retain the continuity shaft alone so a
  /// detail curve cannot become a new silhouette owner.
  static func retainsCrownRachis(
    _ feather: CrowVentralFeatherTractSample
  ) -> Bool {
    let rowCount = feather.region == .pectoral
      ? pectoralRowCount : abdominalRowCount
    let columnCount = feather.region == .pectoral
      ? pectoralColumnCount : abdominalColumnCount
    return feather.row >= 2 && feather.row < rowCount - 2
      && feather.column >= 2 && feather.column < columnCount - 2
  }

  static func visibleSamples(
    projectedPixelsPerMeter: Float
  ) -> [CrowVentralFeatherTractSample] {
    guard projectedPixelsPerMeter >= 1_400 else { return [] }
    return samples()
  }

  /// Breaks a mechanically uniform breast crown without changing the tract's
  /// average depth. The same stable value drives the visible vane and retained
  /// rachis, and remains bounded below the previously qualified `0.10` crown.
  static func transverseCamberScale(
    for feather: CrowVentralFeatherTractSample
  ) -> Float {
    let regionPhase: Float = feather.region == .pectoral ? 0.43 : 1.19
    let coherent = 0.12 * sin(
      Float(feather.row) * 0.83 + Float(feather.column) * 0.47
        + regionPhase + 0.31 * feather.side
    )
    let identity = 0.10 * identityVariation(
      region: feather.region,
      row: feather.row,
      column: feather.column,
      salt: 0xD1B5_4A35
    )
    return clamp(1 + coherent + identity, lower: 0.78, upper: 1.22)
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
          let lengthIdentity = identityVariation(
            region: region,
            row: row,
            column: column,
            salt: 0x7E95_761E
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
            column == 0
            ? 0
            : axialStaggerFraction(region: region, row: row)
              * axialSpan / Float(columnCount - 1)
          let rootX = axialRange.upperBound - axialSpan * axial - stagger
          let rootSurface = mirroredSurfacePoint(x: rootX, theta: theta, side: side)
          let rootNormal = mirroredSurfaceNormal(x: rootX, theta: theta, side: side)
          let root = rootSurface + shellClearanceMeters * rootNormal
          let length =
            (baseLengthMeters + 0.010 * axial + 0.003 * rowFraction)
            * (1 + 0.070 * shapeIdentity + 0.035 * lengthIdentity)
          let referenceTipX = max(
            rootX - length,
            CrowBodyAnatomy.loftRings.first!.x
          )
          let referenceTipTheta = theta - 0.030 - 0.015 * axial
            + 0.009 * rootIdentity
          let referenceTipSurface = mirroredSurfacePoint(
            x: referenceTipX,
            theta: referenceTipTheta,
            side: side
          )
          let referenceTipNormal = mirroredSurfaceNormal(
            x: referenceTipX,
            theta: referenceTipTheta,
            side: side
          )
          let referenceTip = referenceTipSurface
            + shellClearanceMeters * referenceTipNormal
          let terminalAxialOffset = terminalAxialOffsetMeters(
            region: region,
            side: side,
            row: row,
            column: column,
            columnCount: columnCount
          )
          let tipX = max(
            rootX - length + terminalAxialOffset,
            CrowBodyAnatomy.loftRings.first!.x
          )
          let terminalThetaOffset = terminalThetaOffsetRadians(
            region: region,
            side: side,
            row: row,
            column: column,
            columnCount: columnCount
          )
          let tipTheta = theta - 0.030 - 0.015 * axial
            + 0.009 * rootIdentity + terminalThetaOffset
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
          let minimumHalfWidth: Float = region == .pectoral ? 0.0044 : 0.0052
          let maximumWidth =
            max(minimumHalfWidth, 0.88 * circumferentialSpacing)
            * (1 + 0.055 * shapeIdentity)
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
              lodReferenceLengthMeters: simd_distance(root, referenceTip),
              planeNormal: planeNormal,
              rootWidthMeters:
                region == .pectoral && column == 0
                ? 0.82 * maximumWidth
                : (region == .pectoral && column == 1
                  ? 0.66 * maximumWidth : 0.54 * maximumWidth),
              maximumWidthMeters: maximumWidth,
              camberMeters: (0.00095 + 0.00035 * axial)
                * (1 + 0.08 * rootIdentity),
              lateralSweepMeters:
                0.00036 * sin(
                  Float(row) * 0.93 + Float(column) * 1.33
                    + (region == .pectoral ? 0.27 : 1.11)
                )
                + 0.00116 * vaneIdentity,
              rootEnvelopeRatio:
                region == .pectoral
                ? 0.60 - 0.07 * axial
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

  /// Distributes successive ventral courses across the full axial interval.
  /// A low-discrepancy phase avoids the two broad sheets produced by even/odd
  /// staggering while column zero remains a shared neck-to-breast insertion.
  static func axialStaggerFraction(
    region: CrowVentralFeatherTractRegion,
    row: Int
  ) -> Float {
    let regionOffset: Float = region == .pectoral ? 0.00 : 0.39
    let identity = identityVariation(
      region: region,
      row: row,
      column: 0,
      salt: 0xC801_3EA4
    )
    let unwrapped =
      Float(row) * 0.618_033_988_75 + regionOffset + 0.018 * identity
    return unwrapped - unwrapped.rounded(.down)
  }

  /// Dephases the surface-bound tips that remain coherent after follicle-flow,
  /// crown, and optical variation. Two irrational row/column increments and a
  /// side-specific offset prevent a frontal course from closing into a
  /// bilateral ring; the resulting axial and angular offsets remain below
  /// half one pectoral row interval and do not move any follicle.
  static func terminalFlowPhase(
    region: CrowVentralFeatherTractRegion,
    side: Float,
    row: Int,
    column: Int
  ) -> Float {
    let regionOffset: Float = region == .pectoral ? 0.07 : 0.41
    let sideOffset: Float = side < 0 ? 0.173 : 0.619
    let identity = identityVariation(
      region: region,
      row: row,
      column: column,
      salt: side < 0 ? 0xA24B_AED4 : 0x9FB2_1C65
    )
    let unwrapped = Float(row) * 0.381_966_011_25
      + Float(column) * 0.236_067_977_50
      + regionOffset + sideOffset + 0.018 * identity
    return unwrapped - unwrapped.rounded(.down)
  }

  static func terminalAxialOffsetMeters(
    region: CrowVentralFeatherTractRegion,
    side: Float,
    row: Int,
    column: Int,
    columnCount: Int
  ) -> Float {
    0.0038
      * terminalFlowEnvelope(column: column, columnCount: columnCount)
      * (terminalFlowPhase(
        region: region,
        side: side,
        row: row,
        column: column
      ) - 0.5)
  }

  static func terminalThetaOffsetRadians(
    region: CrowVentralFeatherTractRegion,
    side: Float,
    row: Int,
    column: Int,
    columnCount: Int
  ) -> Float {
    0.028
      * terminalFlowEnvelope(column: column, columnCount: columnCount)
      * (terminalFlowPhase(
        region: region,
        side: side,
        row: row,
        column: column
      ) - 0.5)
  }

  private static func terminalFlowEnvelope(
    column: Int,
    columnCount: Int
  ) -> Float {
    let boundedCount = max(columnCount, 2)
    let boundedColumn = min(max(column, 0), boundedCount - 1)
    let axial = Float(boundedColumn) / Float(boundedCount - 1)
    return 0.55 + 0.45 * sin(Float.pi * axial)
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
