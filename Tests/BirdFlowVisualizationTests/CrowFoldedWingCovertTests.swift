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
  #expect(samples.count == 1_224)
  #expect(CrowFoldedWingCoverts.surfaceFeatherClass == 4)
  #expect(CrowFoldedWingCoverts.outerCourseWidthScale(row: 0, column: 17) == 1)
  #expect(abs(
    CrowFoldedWingCoverts.outerCourseWidthScale(
      row: CrowFoldedWingCoverts.rowCount - 1,
      column: 0
    ) - 1.30) < 1e-6
  )
  #expect(abs(
    CrowFoldedWingCoverts.outerCourseWidthScale(
      row: CrowFoldedWingCoverts.rowCount - 1,
      column: 17
    ) - 1.45) < 1e-6
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
      == 1_224
  )
  #expect(samples.map(\.materialVariation).min()! < -0.90)
  #expect(samples.map(\.materialVariation).max()! > 0.90)
  #expect(samples.map(\.vaneAsymmetry).min()! < -0.032)
  #expect(samples.map(\.vaneAsymmetry).max()! > 0.032)
  #expect(samples.allSatisfy { $0.edgeRippleAmplitude >= 0.008 })
  #expect(samples.allSatisfy { $0.edgeRippleAmplitude <= 0.020 })
  #expect(samples.allSatisfy { $0.edgeRipplePhase >= 0 })
  #expect(samples.allSatisfy { $0.edgeRipplePhase <= 2 * Float.pi })
  #expect(samples.allSatisfy { $0.edgeRippleCycles >= 1.20 })
  #expect(samples.allSatisfy { $0.edgeRippleCycles <= 1.90 })
  #expect(samples.allSatisfy { $0.pennaceousStartFraction == 0 })
  let axillaryCourse = samples.filter { $0.row == CrowFoldedWingCoverts.rowCount - 1 }
  #expect(axillaryCourse.allSatisfy { $0.rootEnvelopeRatio == 0.74 })
  #expect(axillaryCourse.allSatisfy {
    $0.rootWidthMeters / $0.maximumWidthMeters > 0.42
  })
  #expect(samples.map(\.maximumWidthMeters).max()! < 0.008)
  #expect(
    samples.allSatisfy {
      2 * $0.maximumWidthMeters
        / simd_distance($0.rootOffset, $0.tipOffset) < 0.48
    }
  )
  let courseStaggers = (0..<CrowFoldedWingCoverts.rowCount).map {
    CrowFoldedWingCoverts.courseStaggerFraction(row: $0)
  }
  #expect(courseStaggers.first == 0)
  #expect(courseStaggers.allSatisfy { $0 >= 0 && $0 < 1 })
  #expect(
    Set(courseStaggers.map { Int(($0 * 10_000).rounded()) }).count
      == CrowFoldedWingCoverts.rowCount
  )
  #expect(courseStaggers.max()! - courseStaggers.min()! > 0.94)
  #expect(
    zip(courseStaggers, courseStaggers.dropFirst()).allSatisfy {
      abs($0 - $1) > 0.47
    }
  )
  #expect(
    CrowFoldedWingCoverts.visibleSamples(projectedPixelsPerMeter: 1_000)
      .allSatisfy { $0.materialVariation == 0 }
  )
  let rowFlows = (0..<CrowFoldedWingCoverts.rowCount).flatMap { row in
    (0..<CrowFoldedWingCoverts.columnCount).map {
      CrowFoldedWingCoverts.rootRowFlowSteps(row: row, column: $0)
    }
  }
  let crownRolls = (0..<CrowFoldedWingCoverts.rowCount).flatMap { row in
    (0..<CrowFoldedWingCoverts.columnCount).map {
      CrowFoldedWingCoverts.crownRollSlope(row: row, column: $0)
    }
  }
  #expect(rowFlows.allSatisfy { abs($0) < 0.23 })
  #expect(rowFlows.max()! - rowFlows.min()! > 0.40)
  #expect(Set(rowFlows.map { Int(($0 * 100_000).rounded()) }).count > 330)
  #expect(crownRolls.allSatisfy { abs($0) < 0.081 })
  #expect(crownRolls.max()! - crownRolls.min()! > 0.145)
  #expect(Set(crownRolls.map { Int(($0 * 100_000).rounded()) }).count > 320)

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
    #expect(abs(pair.0.planeNormal.x - pair.1.planeNormal.x) < 1e-7)
    #expect(abs(pair.0.planeNormal.y + pair.1.planeNormal.y) < 1e-7)
    #expect(abs(pair.0.planeNormal.z - pair.1.planeNormal.z) < 1e-7)
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

@Test("folded wing coverts resolve crown-attached shafts and barb groups")
func foldedWingCovertsResolveCrownAttachedMesostructure() {
  let samples = CrowFoldedWingCoverts.samples()
  for feather in samples {
    #expect(
      CrowFoldedWingCovertDetail.segments(
        for: feather,
        projectedPixelsPerMeter: 1_000
      ).isEmpty
    )
    let segments = CrowFoldedWingCovertDetail.segments(
      for: feather,
      projectedPixelsPerMeter: 1_600
    )
    #expect(
      segments.count == 1 + 2 * CrowFoldedWingCovertDetail.barbPairCount
    )
    #expect(segments.filter { $0.kind == .rachis }.count == 1)
    #expect(
      segments.filter { $0.kind == .edgeBarbGroup }.count
        == 2 * CrowFoldedWingCovertDetail.barbPairCount
    )
    let featherLength = simd_distance(feather.rootOffset, feather.tipOffset)
    let direction = (feather.tipOffset - feather.rootOffset) / featherLength
    let normal = simd_normalize(
      feather.planeNormal
        - direction * simd_dot(feather.planeNormal, direction)
    )
    let widthAxis = simd_normalize(simd_cross(normal, direction))
    let rachis = segments.first { $0.kind == .rachis }!
    for (fraction, point) in [(Float(0.12), rachis.start), (0.96, rachis.end)] {
      let centerline =
        feather.rootOffset + fraction * (feather.tipOffset - feather.rootOffset)
      let axialFraction =
        simd_dot(point - feather.rootOffset, direction) / featherLength
      let crownHeight = simd_dot(point - centerline, normal)
      #expect(abs(axialFraction - fraction) < 1e-5)
      #expect(crownHeight > 0.00010)
      #expect(crownHeight < 0.0030)
    }
    let edgeGroups = segments.filter { $0.kind == .edgeBarbGroup }
    for pair in stride(from: 0, to: edgeGroups.count, by: 2) {
      let left = edgeGroups[pair]
      let right = edgeGroups[pair + 1]
      #expect(simd_distance(left.start, right.start) < 1e-7)
      #expect(simd_dot(left.end - feather.rootOffset, widthAxis) < -0.001)
      #expect(simd_dot(right.end - feather.rootOffset, widthAxis) > 0.001)
    }
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
