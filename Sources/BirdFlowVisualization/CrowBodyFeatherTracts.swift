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
  let headCoupling: Float
}

enum CrowBodyFeatherTracts {
  static let cervicalRowCount = 11
  static let cervicalColumnCount = 7
  static let mantleRowCount = 3
  static let mantleColumnCount = 8
  static let scapularRowCount = 4
  static let scapularColumnCount = 9

  static func visibleSamples(
    neckPose: CrowStandingNeckPose? = nil,
    projectedPixelsPerMeter: Float
  ) -> [CrowBodyFeatherTractSample] {
    let complete = samples(neckPose: neckPose)
    if projectedPixelsPerMeter >= 1_400 { return complete }
    if projectedPixelsPerMeter >= 900 {
      return complete.filter {
        $0.region != .cervical || ($0.row + $0.column).isMultiple(of: 2)
      }
    }
    return complete.filter {
      $0.region != .cervical
        || ($0.row.isMultiple(of: 2) && $0.column.isMultiple(of: 2))
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
              maximumWidthMeters:
                (0.00545 - 0.0006 * axial)
                * (1 + 0.020 * sin(Float(row) * 2.07 + Float(column) * 1.31)),
              camberMeters:
                0.0010
                * (1 + 0.06 * sin(Float(row) * 1.49 - Float(column) * 2.11)),
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
          let axial = Float(column) / Float(mantleColumnCount - 1)
          let stagger: Float = row.isMultiple(of: 2) ? 0 : 0.007
          let root = SIMD3<Float>(
            0.074 - 0.154 * axial - stagger,
            side * (0.018 + 0.023 * rowFraction),
            0.056 - 0.010 * rowFraction - 0.010 * axial
          )
          let length = 0.032 + 0.014 * axial + 0.004 * rowFraction
          let tip =
            root
            + SIMD3<Float>(
              -length,
              side * 0.0015 * (1 - rowFraction),
              -0.003 - 0.003 * axial
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
                SIMD3<Float>(0.08, side * (0.30 + 0.30 * rowFraction), 1),
                fallback: SIMD3<Float>(0, 0, 1)
              ),
              rootWidthMeters: 0.0048,
              maximumWidthMeters: 0.0085 + 0.0015 * rowFraction,
              camberMeters: 0.0018 + 0.0004 * rowFraction,
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
          let axial = Float(column) / Float(scapularColumnCount - 1)
          let stagger: Float = row.isMultiple(of: 2) ? 0 : 0.006
          let root = SIMD3<Float>(
            0.080 - 0.164 * axial - stagger,
            side * (0.041 + 0.024 * rowFraction),
            0.048 - 0.025 * rowFraction - 0.009 * axial
          )
          let length = 0.036 + 0.018 * axial + 0.006 * rowFraction
          let tip =
            root
            + SIMD3<Float>(
              -length,
              -side * (0.001 + 0.002 * rowFraction),
              -0.004 - 0.004 * rowFraction
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
                  side * (0.55 + 0.35 * rowFraction),
                  0.82 - 0.30 * rowFraction
                ),
                fallback: SIMD3<Float>(0, side, 0)
              ),
              rootWidthMeters: 0.0055,
              maximumWidthMeters: 0.0105 + 0.002 * rowFraction,
              camberMeters: 0.0022 + 0.0007 * rowFraction,
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
}
