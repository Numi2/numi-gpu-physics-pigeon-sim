import Testing
import simd

@testable import BirdFlowVisualization

@Test("undertail coverts form a body-seated shell over rectrix roots")
func undertailCovertsFormBodySeatedRectrixRootShell() {
  let samples = CrowUndertailCoverts.samples()
  #expect(samples == CrowUndertailCoverts.samples())
  #expect(samples.count == CrowUndertailCoverts.rowCount * CrowUndertailCoverts.columnCount)
  #expect(samples.count == 91)
  #expect(CrowUndertailCoverts.visibleSamples(projectedPixelsPerMeter: 1_000).isEmpty)
  #expect(
    CrowUndertailCoverts.visibleSamples(projectedPixelsPerMeter: 1_600).count
      == samples.count
  )
  #expect(samples.map(\.materialVariation).min()! < -0.90)
  #expect(samples.map(\.materialVariation).max()! > 0.90)

  for sample in samples {
    #expect(
      abs(
        simd_distance(sample.rootOffset, sample.rootSurfaceOffset)
          - CrowUndertailCoverts.shellClearanceMeters
      ) < 1e-6
    )
    let length = simd_distance(sample.rootOffset, sample.tipOffset)
    #expect(length > 0.028 && length < 0.052)
    #expect(sample.tipOffset.x < sample.rootOffset.x)
    #expect(sample.maximumWidthMeters > sample.rootWidthMeters)
    #expect(length > sample.maximumWidthMeters)
    #expect(abs(simd_length(sample.planeNormal) - 1) < 1e-5)
  }

  for row in 0..<CrowUndertailCoverts.rowCount {
    let course = samples.filter { $0.row == row }.sorted { $0.column < $1.column }
    #expect(course.count == CrowUndertailCoverts.columnCount)
    for pair in zip(course, course.dropFirst()) {
      #expect(pair.0.rootOffset.x > pair.1.rootOffset.x)
      #expect(
        simd_distance(pair.0.rootOffset, pair.1.rootOffset)
          < simd_distance(pair.0.rootOffset, pair.0.tipOffset)
      )
    }
    let posterior = course.last!
    let tail = CrowClosedTailAnatomy.pose(
      fraction: Float(row) / Float(CrowUndertailCoverts.rowCount - 1)
    )
    let rectrixOverlapPoint = tail.rootOffset + 0.030 * tail.direction
    #expect(simd_distance(posterior.tipOffset, rectrixOverlapPoint) < 0.018)
  }
}

@Test("undertail covert rows overlap across the pelvic shell")
func undertailCovertRowsOverlapAcrossPelvicShell() {
  let samples = CrowUndertailCoverts.samples()
  for column in 0..<CrowUndertailCoverts.columnCount {
    let crossCourse =
      samples.filter { $0.column == column }.sorted { $0.row < $1.row }
    #expect(crossCourse.count == CrowUndertailCoverts.rowCount)
    for pair in zip(crossCourse, crossCourse.dropFirst()) {
      #expect(
        simd_distance(pair.0.rootOffset, pair.1.rootOffset)
          < pair.0.maximumWidthMeters + pair.1.maximumWidthMeters
      )
    }
  }
}
