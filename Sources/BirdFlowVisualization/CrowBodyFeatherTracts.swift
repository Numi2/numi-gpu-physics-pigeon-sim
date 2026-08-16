import simd

enum CrowBodyFeatherTractRegion: UInt8, CaseIterable {
  case cervical
  case mantle
  case scapular
}

/// One procedural contour feather anchored to the estimated body envelope.
///
/// Roots are arranged in staggered, overlapping tracts rather than spread as
/// an even particle field. `headCoupling` transports the cranial end of the
/// cervical tract with quiet head motion while its shoulder end stays on the
/// trunk, preventing a visible neck seam.
struct CrowBodyFeatherTractSample: Equatable {
  let region: CrowBodyFeatherTractRegion
  let side: Float
  let row: Int
  let column: Int
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
  let materialVariation: Float
  let headCoupling: Float
}

enum CrowBodyFeatherTracts {
  static let cervicalRowCount = 11
  static let cervicalColumnCount = 7
  static let mantleRowCount = 5
  static let mantleColumnCount = 12
  static let scapularRowCount = 7
  static let scapularColumnCount = 14

  static func visibleSamples(
    neckPose: CrowStandingNeckPose? = nil,
    projectedPixelsPerMeter: Float
  ) -> [CrowBodyFeatherTractSample] {
    let complete = samples(neckPose: neckPose)
    if projectedPixelsPerMeter >= 1_400 { return complete }
    if projectedPixelsPerMeter >= 900 {
      return complete.filter {
        ($0.row + $0.column).isMultiple(of: 2)
      }
    }
    return complete.filter {
      $0.row.isMultiple(of: 2) && $0.column.isMultiple(of: 2)
    }
  }

  static func samples(
    neckPose: CrowStandingNeckPose? = nil
  ) -> [CrowBodyFeatherTractSample] {
    var result: [CrowBodyFeatherTractSample] = []
    result.reserveCapacity(
      2
        * (cervicalRowCount * cervicalColumnCount
          + mantleRowCount * mantleColumnCount
          + scapularRowCount * scapularColumnCount)
    )
    appendCervical(neckPose: neckPose, to: &result)
    appendMantle(to: &result)
    appendScapular(to: &result)
    return result
  }

  private static func appendCervical(
    neckPose: CrowStandingNeckPose?,
    to result: inout [CrowBodyFeatherTractSample]
  ) {
    for side: Float in [-1, 1] {
      for row in 0..<cervicalRowCount {
        let rowFraction = Float(row) / Float(cervicalRowCount - 1)
        for column in 0..<cervicalColumnCount {
          let axial = Float(column) / Float(cervicalColumnCount - 1)
          let rowStep = 2.10 / Float(cervicalRowCount - 1)
          let angle =
            -1.05 + 2.10 * rowFraction
            + 0.20 * rowStep * sin(Float(column) * 2.399_963 + side * 0.71)
            + 0.04 * rowStep
            * sin(Float(row) * 1.173 + Float(column) * 0.83 + side * 1.31)
          let coupling = 0.10 + 0.78 * axial
          let vaneIdentity = identityVariation(
            side: side,
            row: row,
            column: column,
            salt: 0x1656_67B1
          )
          let edgeIdentity = identityVariation(
            side: side,
            row: row,
            column: column,
            salt: 0x68E3_1DA4
          )
          let cycleIdentity = identityVariation(
            side: side,
            row: row,
            column: column,
            salt: 0x27D4_EB2F
          )
          let center = SIMD3<Float>(
            0.086 + 0.062 * axial,
            0,
            0.033 + 0.016 * axial
          )
          let halfWidth = 0.046 - 0.015 * axial
          let verticalRadius = 0.046 - 0.013 * axial
          let stagger: Float = row.isMultiple(of: 2) ? 0 : 0.002
          let unposedRoot =
            center
            + SIMD3<Float>(
              -stagger,
              side * halfWidth * cos(angle),
              verticalRadius * sin(angle)
            )
          let length = 0.023 - 0.004 * axial
          let unposedTip =
            unposedRoot
            + SIMD3<Float>(
              -length,
              -side * 0.0015 * sin(Float.pi * axial),
              -0.001 - 0.0025 * max(0, -sin(angle))
            )
          let unposedNormal = normalized(
            SIMD3<Float>(0.10, side * cos(angle), sin(angle)),
            fallback: SIMD3<Float>(0, side, 0)
          )
          let root =
            neckPose?.transform(
              offset: unposedRoot,
              coupling: coupling
            ) ?? unposedRoot
          let tip =
            neckPose?.transform(
              offset: unposedTip,
              coupling: coupling
            ) ?? unposedTip
          let planeNormal =
            neckPose?.rotated(
              unposedNormal,
              coupling: coupling
            ) ?? unposedNormal
          result.append(
            CrowBodyFeatherTractSample(
              region: .cervical,
              side: side,
              row: row,
              column: column,
              rootOffset: root,
              tipOffset: tip,
              planeNormal: planeNormal,
              rootWidthMeters: 0.0030,
              maximumWidthMeters: (0.00545 - 0.0006 * axial)
                * (1 + 0.020 * sin(Float(row) * 2.07 + Float(column) * 1.31)),
              camberMeters:
                0.0010
                * (1 + 0.06 * sin(Float(row) * 1.49 - Float(column) * 2.11)),
              vaneAsymmetry: 0.040 * vaneIdentity,
              edgeRippleAmplitude: 0.010 + 0.016 * (0.5 + 0.5 * edgeIdentity),
              edgeRipplePhase: Float.pi * (edgeIdentity + 1),
              edgeRippleCycles: 1.30 + 0.50 * (0.5 + 0.5 * cycleIdentity),
              materialVariation: identityVariation(
                side: side,
                row: row,
                column: column,
                salt: 0xC2B2_AE35
              ),
              headCoupling: coupling
            )
          )
        }
      }
    }
  }

  private static func appendMantle(
    to result: inout [CrowBodyFeatherTractSample]
  ) {
    for side: Float in [-1, 1] {
      for row in 0..<mantleRowCount {
        let rowFraction = Float(row) / Float(mantleRowCount - 1)
        for column in 0..<mantleColumnCount {
          let baseAxial = Float(column) / Float(mantleColumnCount - 1)
          let rootIdentity = identityVariation(
            side: side,
            row: row,
            column: column,
            salt: 0x9E37_79B9
          )
          let shapeIdentity = identityVariation(
            side: side,
            row: row,
            column: column,
            salt: 0x85EB_CA6B
          )
          let materialIdentity = identityVariation(
            side: side,
            row: row,
            column: column,
            salt: 0xC2B2_AE35
          )
          let edgeIdentity = identityVariation(
            side: side,
            row: row,
            column: column,
            salt: 0x68E3_1DA4
          )
          let cycleIdentity = identityVariation(
            side: side,
            row: row,
            column: column,
            salt: 0x27D4_EB2F
          )
          let axialStep = 1 / Float(mantleColumnCount - 1)
          let axial = min(
            1,
            max(
              0,
              baseAxial
                + (column == 0 || column == mantleColumnCount - 1
                  ? 0 : 0.10 * axialStep * rootIdentity)
            )
          )
          let rowStep = 1 / Float(mantleRowCount - 1)
          let course = min(
            1,
            max(
              0,
              rowFraction
                + (row == 0 || row == mantleRowCount - 1
                  ? 0 : 0.12 * rowStep * shapeIdentity)
            )
          )
          let rowPhase = identityVariation(
            side: side,
            row: row,
            column: 0,
            salt: 0xD3A2_646C
          )
          let staggerFraction: Float =
            (row.isMultiple(of: 2) ? 0 : 0.5) + 0.075 * rowPhase
          let stagger = staggerFraction * 0.154 / Float(mantleColumnCount - 1)
          let root = SIMD3<Float>(
            0.074 - 0.154 * axial - stagger,
            side * (0.018 + 0.023 * course + 0.0007 * rootIdentity),
            0.056 - 0.010 * course - 0.010 * axial + 0.0007 * shapeIdentity
          )
          let length =
            (0.032 + 0.014 * axial + 0.004 * course)
            * (1 + 0.055 * shapeIdentity)
          let tip =
            root
            + SIMD3<Float>(
              -length,
              side * (0.0015 * (1 - course) + 0.0010 * rootIdentity),
              -0.003 - 0.003 * axial + 0.0007 * shapeIdentity
            )
          result.append(
            CrowBodyFeatherTractSample(
              region: .mantle,
              side: side,
              row: row,
              column: column,
              rootOffset: root,
              tipOffset: tip,
              planeNormal: normalized(
                SIMD3<Float>(
                  0.08 + 0.025 * shapeIdentity,
                  side * (0.30 + 0.30 * course + 0.04 * rootIdentity),
                  1
                ),
                fallback: SIMD3<Float>(0, 0, 1)
              ),
              rootWidthMeters: 0.0038 * (1 + 0.035 * rootIdentity),
              maximumWidthMeters: (0.0067 + 0.0012 * course) * (1 + 0.045 * shapeIdentity),
              camberMeters: (0.00155 + 0.00035 * course) * (1 + 0.09 * rootIdentity),
              vaneAsymmetry: 0.052 * shapeIdentity,
              edgeRippleAmplitude: 0.012 + 0.018 * (0.5 + 0.5 * edgeIdentity),
              edgeRipplePhase: Float.pi * (edgeIdentity + 1),
              edgeRippleCycles: 1.35 + 0.65 * (0.5 + 0.5 * cycleIdentity),
              materialVariation: materialIdentity,
              headCoupling: 0
            )
          )
        }
      }
    }
  }

  private static func appendScapular(
    to result: inout [CrowBodyFeatherTractSample]
  ) {
    for side: Float in [-1, 1] {
      for row in 0..<scapularRowCount {
        let rowFraction = Float(row) / Float(scapularRowCount - 1)
        for column in 0..<scapularColumnCount {
          let baseAxial = Float(column) / Float(scapularColumnCount - 1)
          let rootIdentity = identityVariation(
            side: side,
            row: row,
            column: column,
            salt: 0x27D4_EB2F
          )
          let shapeIdentity = identityVariation(
            side: side,
            row: row,
            column: column,
            salt: 0x1656_67B1
          )
          let materialIdentity = identityVariation(
            side: side,
            row: row,
            column: column,
            salt: 0xD3A2_646C
          )
          let edgeIdentity = identityVariation(
            side: side,
            row: row,
            column: column,
            salt: 0x68E3_1DA4
          )
          let cycleIdentity = identityVariation(
            side: side,
            row: row,
            column: column,
            salt: 0xC801_3EA4
          )
          let axialStep = 1 / Float(scapularColumnCount - 1)
          let axial = min(
            1,
            max(
              0,
              baseAxial
                + (column == 0 || column == scapularColumnCount - 1
                  ? 0 : 0.10 * axialStep * rootIdentity)
            )
          )
          let rowStep = 1 / Float(scapularRowCount - 1)
          let course = min(
            1,
            max(
              0,
              rowFraction
                + (row == 0 || row == scapularRowCount - 1
                  ? 0 : 0.13 * rowStep * shapeIdentity)
            )
          )
          let rowPhase = identityVariation(
            side: side,
            row: row,
            column: 0,
            salt: 0x9E37_79B9
          )
          let staggerFraction: Float =
            (row.isMultiple(of: 2) ? 0 : 0.5) + 0.075 * rowPhase
          let stagger = staggerFraction * 0.164 / Float(scapularColumnCount - 1)
          let root = SIMD3<Float>(
            0.080 - 0.164 * axial - stagger,
            side * (0.041 + 0.024 * course + 0.0008 * rootIdentity),
            0.048 - 0.025 * course - 0.009 * axial + 0.0008 * shapeIdentity
          )
          let length =
            (0.036 + 0.018 * axial + 0.006 * course)
            * (1 + 0.06 * shapeIdentity)
          let tip =
            root
            + SIMD3<Float>(
              -length,
              -side * (0.001 + 0.002 * course - 0.0012 * rootIdentity),
              -0.004 - 0.004 * course + 0.0008 * shapeIdentity
            )
          result.append(
            CrowBodyFeatherTractSample(
              region: .scapular,
              side: side,
              row: row,
              column: column,
              rootOffset: root,
              tipOffset: tip,
              planeNormal: normalized(
                SIMD3<Float>(
                  0.10,
                  side * (0.55 + 0.35 * course + 0.05 * rootIdentity),
                  0.82 - 0.30 * course + 0.04 * shapeIdentity
                ),
                fallback: SIMD3<Float>(0, side, 0)
              ),
              rootWidthMeters: 0.0045 * (1 + 0.04 * rootIdentity),
              maximumWidthMeters: (0.0078 + 0.0015 * course) * (1 + 0.05 * shapeIdentity),
              camberMeters: (0.0019 + 0.00055 * course) * (1 + 0.10 * rootIdentity),
              vaneAsymmetry: 0.060 * shapeIdentity,
              edgeRippleAmplitude: 0.014 + 0.020 * (0.5 + 0.5 * edgeIdentity),
              edgeRipplePhase: Float.pi * (edgeIdentity + 1),
              edgeRippleCycles: 1.40 + 0.70 * (0.5 + 0.5 * cycleIdentity),
              materialVariation: materialIdentity,
              headCoupling: 0
            )
          )
        }
      }
    }
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-8 ? value / length : fallback
  }

  private static func identityVariation(
    side: Float,
    row: Int,
    column: Int,
    salt: UInt32
  ) -> Float {
    var value = UInt32(truncatingIfNeeded: row) &* 0x9E37_79B9
    value ^= UInt32(truncatingIfNeeded: column) &* 0x85EB_CA6B
    value ^= side < 0 ? 0xA511_E9B3 : 0x63D8_3595
    value ^= salt
    value ^= value >> 16
    value &*= 0x7FEB_352D
    value ^= value >> 15
    value &*= 0x846C_A68B
    value ^= value >> 16
    return 2 * Float(value & 0x00FF_FFFF) / Float(0x00FF_FFFF) - 1
  }
}
