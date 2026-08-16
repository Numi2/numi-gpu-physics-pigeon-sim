import Testing
import simd

@testable import BirdFlowVisualization

@Test("upper-tail coverts close the dorsal pelvic-to-rectrix shell")
func uppertailCovertsCloseDorsalPelvicToRectrixShell() {
  let samples = CrowUppertailCoverts.samples()
  #expect(samples == CrowUppertailCoverts.samples())
  #expect(samples.count == CrowUppertailCoverts.rowCount * CrowUppertailCoverts.columnCount)
  #expect(samples.count == 270)
  #expect(CrowUppertailCoverts.surfaceFeatherClass == 5)
  #expect(CrowUppertailCoverts.rectrixDorsalClearanceMeters == 0.016)
  #expect(CrowUppertailCoverts.visibleSamples(projectedPixelsPerMeter: 1_000).isEmpty)
  #expect(
    CrowUppertailCoverts.visibleSamples(projectedPixelsPerMeter: 1_600).count
      == samples.count
  )
  #expect(samples.map(\.materialVariation).min()! < -0.90)
  #expect(samples.map(\.materialVariation).max()! > 0.90)
  #expect(samples.map(\.vaneAsymmetry).min()! < -0.032)
  #expect(samples.map(\.vaneAsymmetry).max()! > 0.032)
  #expect(samples.allSatisfy { $0.edgeRippleAmplitude >= 0.008 })
  #expect(samples.allSatisfy { $0.edgeRippleAmplitude <= 0.020 })
  #expect(samples.allSatisfy { $0.rootEnvelopeRatio == 0.64 })
  #expect(samples.allSatisfy { $0.pennaceousStartFraction == 0 })
  let courseStaggers = (0..<CrowUppertailCoverts.rowCount).map {
    CrowUppertailCoverts.courseStaggerMeters(row: $0)
  }
  #expect(courseStaggers.min()! < -0.0027)
  #expect(courseStaggers.max()! > 0.0027)
  #expect(Set(courseStaggers.map { Int(($0 * 1_000_000).rounded()) }).count == 27)
  #expect(
    CrowUppertailCoverts.insertionWidthScale(
      rowFraction: 0.5,
      axialFraction: 1
    ) == 1.38
  )
  #expect(
    abs(
      CrowUppertailCoverts.insertionWidthScale(
        rowFraction: 0,
        axialFraction: 1
      ) - 1.32
    ) < 1e-6
  )
  #expect(
    CrowUppertailCoverts.insertionWidthScale(
      rowFraction: 0.5,
      axialFraction: 0
    ) == 1
  )

  for sample in samples {
    #expect(
      abs(
        simd_distance(sample.rootOffset, sample.rootSurfaceOffset)
          - CrowUppertailCoverts.shellClearanceMeters
      ) < 1e-6
    )
    let length = simd_distance(sample.rootOffset, sample.tipOffset)
    #expect(length > 0.030 && length < 0.110)
    #expect(length < 0.70 * CrowClosedTailAnatomy.rectrixLengthMeters)
    #expect(sample.tipOffset.x < sample.rootOffset.x)
    #expect(sample.maximumWidthMeters > sample.rootWidthMeters)
    #expect(length > sample.maximumWidthMeters)
    #expect(abs(simd_length(sample.planeNormal) - 1) < 1e-5)
    #expect(sample.rootSurfaceOffset.z > -0.005)
  }

  for row in 0..<CrowUppertailCoverts.rowCount {
    let course = samples.filter { $0.row == row }.sorted { $0.column < $1.column }
    #expect(course.count == CrowUppertailCoverts.columnCount)
    for pair in zip(course, course.dropFirst()) {
      #expect(pair.0.rootOffset.x > pair.1.rootOffset.x)
      #expect(
        simd_distance(pair.0.rootOffset, pair.1.rootOffset)
          < simd_distance(pair.0.rootOffset, pair.0.tipOffset)
      )
    }
    let posterior = course.last!
    let tail = CrowClosedTailAnatomy.pose(
      fraction: Float(row) / Float(CrowUppertailCoverts.rowCount - 1)
    )
    let rectrixOverlapPoint = tail.rootOffset
      + CrowUppertailCoverts.rectrixOverlapMeters(axialFraction: 1) * tail.direction
    #expect(simd_distance(posterior.tipOffset, rectrixOverlapPoint) < 0.018)
    #expect(
      simd_dot(posterior.tipOffset - rectrixOverlapPoint, tail.normal) > 0.008
    )
  }
}

@Test("upper-tail coverts resolve shafts and paired barb groups at full density")
func uppertailCovertsResolveFullDensityMesostructure() {
  let samples = CrowUppertailCoverts.samples()
  for feather in samples {
    #expect(
      CrowUppertailCovertDetail.segments(
        for: feather,
        projectedPixelsPerMeter: 1_000
      ).isEmpty
    )
    let segments = CrowUppertailCovertDetail.segments(
      for: feather,
      projectedPixelsPerMeter: 1_600
    )
    #expect(
      segments.count == 1 + 2 * CrowUppertailCovertDetail.barbPairCount
    )
    #expect(segments.filter { $0.kind == .rachis }.count == 1)
    #expect(
      segments.filter { $0.kind == .edgeBarbGroup }.count
        == 2 * CrowUppertailCovertDetail.barbPairCount
    )
    let featherLength = simd_distance(feather.rootOffset, feather.tipOffset)
    #expect(
      segments.allSatisfy {
        $0.start.x.isFinite && $0.start.y.isFinite && $0.start.z.isFinite
          && $0.end.x.isFinite && $0.end.y.isFinite && $0.end.z.isFinite
          && $0.startRadiusMeters > $0.endRadiusMeters
          && $0.endRadiusMeters > 0
          && simd_distance($0.start, $0.end) > 1e-5
          && simd_distance($0.start, feather.rootOffset) < featherLength
          && simd_distance($0.end, feather.rootOffset) < 1.30 * featherLength
      }
    )
  }
}

@Test("upper-tail covert rows overlap across the dorsal pelvic shell")
func uppertailCovertRowsOverlapAcrossDorsalPelvicShell() {
  let samples = CrowUppertailCoverts.samples()
  for column in 0..<CrowUppertailCoverts.columnCount {
    let crossCourse =
      samples.filter { $0.column == column }.sorted { $0.row < $1.row }
    #expect(crossCourse.count == CrowUppertailCoverts.rowCount)
    for pair in zip(crossCourse, crossCourse.dropFirst()) {
      #expect(
        simd_distance(pair.0.rootOffset, pair.1.rootOffset)
          < pair.0.maximumWidthMeters + pair.1.maximumWidthMeters
      )
    }
  }
}
