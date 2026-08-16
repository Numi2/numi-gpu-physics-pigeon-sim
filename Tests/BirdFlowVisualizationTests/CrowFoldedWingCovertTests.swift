import Testing
import simd

@testable import BirdFlowVisualization

@Test("folded wing coverts form a symmetric body-seated shell")
func foldedWingCovertsFormSymmetricBodySeatedShell() {
  let samples = CrowFoldedWingCoverts.samples()
  #expect(samples == CrowFoldedWingCoverts.samples())
  #expect(
    samples.count
      == 2 * CrowFoldedWingCoverts.rowCount * CrowFoldedWingCoverts.columnCount
  )
  #expect(samples.count == 360)
  #expect(CrowFoldedWingCoverts.surfaceFeatherClass == 4)
  #expect(CrowFoldedWingCoverts.outerCourseWidthScale(row: 0) == 1)
  #expect(
    CrowFoldedWingCoverts.outerCourseWidthScale(
      row: CrowFoldedWingCoverts.rowCount - 1
    ) == 1.30
  )
  #expect(
    CrowFoldedWingCoverts.visibleSamples(projectedPixelsPerMeter: 800).count
      == 130
  )
  #expect(
    CrowFoldedWingCoverts.visibleSamples(projectedPixelsPerMeter: 1_000).count
      == 130
  )
  #expect(
    CrowFoldedWingCoverts.visibleSamples(projectedPixelsPerMeter: 1_600).count
      == 360
  )
  #expect(samples.map(\.materialVariation).min()! < -0.90)
  #expect(samples.map(\.materialVariation).max()! > 0.90)
  #expect(samples.map(\.maximumWidthMeters).max()! < 0.024)
  let courseStaggers = (0..<CrowFoldedWingCoverts.rowCount).map {
    CrowFoldedWingCoverts.courseStaggerFraction(row: $0)
  }
  #expect(courseStaggers.first == 0)
  #expect(courseStaggers.allSatisfy { $0 >= 0 && $0 < 0.73 })
  #expect(Set(courseStaggers.map { Int(($0 * 10_000).rounded()) }).count == 9)
  #expect(courseStaggers.max()! - courseStaggers.min()! > 0.71)
  #expect(
    zip(courseStaggers, courseStaggers.dropFirst()).allSatisfy {
      abs($0 - $1) > 0.399
    }
  )
  #expect(
    CrowFoldedWingCoverts.visibleSamples(projectedPixelsPerMeter: 1_000)
      .allSatisfy { $0.materialVariation == 0 }
  )

  for sample in samples {
    #expect(
      abs(
        simd_distance(sample.rootOffset, sample.rootSurfaceOffset)
          - CrowFoldedWingCoverts.shellClearanceMeters
          - 0.00025
          * Float(sample.row) / Float(CrowFoldedWingCoverts.rowCount - 1)
      ) < 1e-5
    )
    #expect(sample.tipOffset.x < sample.rootOffset.x)
    #expect(sample.maximumWidthMeters > sample.rootWidthMeters)
    #expect(simd_distance(sample.rootOffset, sample.tipOffset) > sample.maximumWidthMeters)
    #expect(abs(simd_length(sample.planeNormal) - 1) < 1e-5)
  }

  let left = samples.filter { $0.side == 1 }
  let right = samples.filter { $0.side == -1 }
  #expect(left.count == right.count)
  for pair in zip(left, right) {
    #expect(pair.0.row == pair.1.row)
    #expect(pair.0.column == pair.1.column)
    #expect(abs(pair.0.rootOffset.x - pair.1.rootOffset.x) < 1e-7)
    #expect(abs(pair.0.rootOffset.y + pair.1.rootOffset.y) < 1e-7)
    #expect(abs(pair.0.rootOffset.z - pair.1.rootOffset.z) < 1e-7)
    #expect(abs(pair.0.tipOffset.y + pair.1.tipOffset.y) < 1e-7)
  }

  for side: Float in [-1, 1] {
    for column in 0..<CrowFoldedWingCoverts.columnCount {
      let course =
        samples
        .filter { $0.side == side && $0.column == column }
        .sorted { $0.row < $1.row }
      #expect(course.count == CrowFoldedWingCoverts.rowCount)
      for pair in zip(course, course.dropFirst()) {
        #expect(
          simd_distance(pair.0.rootOffset, pair.1.rootOffset)
            < pair.0.maximumWidthMeters + pair.1.maximumWidthMeters
        )
        #expect(abs(pair.0.rootOffset.x - pair.1.rootOffset.x) > 0.003)
      }
    }
    for row in 0..<CrowFoldedWingCoverts.rowCount {
      let course =
        samples
        .filter { $0.side == side && $0.row == row }
        .sorted { $0.column < $1.column }
      for pair in zip(course, course.dropFirst()) {
        #expect(
          simd_distance(pair.0.rootOffset, pair.1.rootOffset)
            < simd_distance(pair.0.rootOffset, pair.0.tipOffset)
        )
      }
      let lengths = course.map { simd_distance($0.rootOffset, $0.tipOffset) }
      #expect(lengths.max()! - lengths.min()! > 0.025)
    }
  }
}
