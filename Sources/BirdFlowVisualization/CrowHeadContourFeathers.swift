import simd

struct CrowHeadContourFeatherSample: Equatable {
  let side: Float
  let row: Int
  let column: Int
  let root: SIMD3<Float>
  let tip: SIMD3<Float>
  let planeNormal: SIMD3<Float>
  let rootWidthMeters: Float
  let maximumWidthMeters: Float
  let camberMeters: Float
  let surfaceFeatherClass: UInt32
}

/// Sparse cranial contour fallback used by the animated wingbeat presentation.
///
/// Keeping these vanes source-owned makes their bilateral geometry, density,
/// and material identity independently testable instead of burying them in
/// renderer assembly code.
enum CrowHeadContourFeathers {
  static let rowCount = 4
  static let columnCount = 5

  static func samples(
    center: SIMD3<Float>,
    radii: SIMD3<Float>
  ) -> [CrowHeadContourFeatherSample] {
    var result: [CrowHeadContourFeatherSample] = []
    result.reserveCapacity(2 * rowCount * columnCount)
    for side: Float in [-1, 1] {
      for row in 0..<rowCount {
        let angle = -0.62 + 1.24 * Float(row) / Float(rowCount - 1)
        for column in 0..<columnCount {
          let fraction = Float(column) / Float(columnCount - 1)
          let root =
            center
            + SIMD3<Float>(
              0.025 - 0.054 * fraction,
              side * radii.y * 0.98 * cos(angle),
              radii.z * 0.78 * sin(angle)
            )
          result.append(
            CrowHeadContourFeatherSample(
              side: side,
              row: row,
              column: column,
              root: root,
              tip: root + SIMD3<Float>(-0.014 - 0.006 * fraction, 0, -0.0015),
              planeNormal: normalized(
                SIMD3<Float>(0.12, side * cos(angle), sin(angle)),
                fallback: SIMD3<Float>(0, side, 0)
              ),
              rootWidthMeters: 0.0024,
              maximumWidthMeters: 0.0041,
              camberMeters: 0.001,
              surfaceFeatherClass: 0
            )
          )
        }
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
}
