import Testing
import simd

@testable import BirdFlowVisualization

@Test("axillary feathers form a body-seated lining beneath the folded wing")
func axillaryFeathersFormBodySeatedFoldedWingLining() {
  let samples = CrowAxillaryFeatherTracts.samples()
  #expect(samples == CrowAxillaryFeatherTracts.samples())
  #expect(
    samples.count
      == 2 * CrowAxillaryFeatherTracts.rowCount
        * CrowAxillaryFeatherTracts.columnCount
  )
  #expect(samples.count == 392)
  #expect(
    CrowAxillaryFeatherTracts.visibleSamples(
      projectedPixelsPerMeter: 1_000
    ).isEmpty
  )
  #expect(
    CrowAxillaryFeatherTracts.visibleSamples(
      projectedPixelsPerMeter: 1_600
    ).count == samples.count
  )
  #expect(
    samples.allSatisfy {
      $0.surfaceFeatherClass == CrowAxillaryFeatherTracts.surfaceFeatherClass
    }
  )
  #expect(samples.allSatisfy { $0.rootThetaRadians <= -0.08 })
  #expect(samples.allSatisfy { $0.rootThetaRadians >= -0.60 })
  #expect(samples.allSatisfy { $0.tipThetaRadians < $0.rootThetaRadians })
  #expect(samples.allSatisfy { $0.rootSurfaceOffset.x <= 0.074 })
  #expect(samples.allSatisfy { $0.rootSurfaceOffset.x > -0.109 })
  #expect(samples.allSatisfy { $0.maximumWidthMeters > $0.rootWidthMeters })
  #expect(
    samples.allSatisfy {
      simd_distance($0.rootOffset, $0.tipOffset) > $0.maximumWidthMeters
    }
  )
  #expect(
    samples.allSatisfy { abs(simd_length($0.planeNormal) - 1) < 1e-5 }
  )
  #expect(CrowAxillaryFeatherTracts.surfaceFeatherClass == 7)
  #expect(samples.map(\.materialVariation).min()! < -0.90)
  #expect(samples.map(\.materialVariation).max()! > 0.90)
  #expect(samples.map(\.rootEnvelopeRatio).min()! == 0.68)
  #expect(samples.map(\.rootEnvelopeRatio).max()! == 0.74)
  #expect(samples.map(\.pennaceousStartFraction).min()! == 0.18)
  #expect(samples.map(\.pennaceousStartFraction).max()! == 0.23)

  for sample in samples {
    let rowFraction = Float(sample.row)
      / Float(CrowAxillaryFeatherTracts.rowCount - 1)
    let expectedClearance =
      CrowAxillaryFeatherTracts.shellClearanceMeters
      + 0.00018 * rowFraction
    #expect(
      abs(
        simd_distance(sample.rootSurfaceOffset, sample.rootOffset)
          - expectedClearance
      ) < 1e-6
    )
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
    #expect(abs(pair.0.planeNormal.y + pair.1.planeNormal.y) < 1e-7)
  }

  for side: Float in [-1, 1] {
    for column in 0..<CrowAxillaryFeatherTracts.columnCount {
      let course = samples.filter {
        $0.side == side && $0.column == column
      }.sorted { $0.row < $1.row }
      #expect(course.count == CrowAxillaryFeatherTracts.rowCount)
      for pair in zip(course, course.dropFirst()) {
        #expect(
          simd_distance(pair.0.rootOffset, pair.1.rootOffset)
            < pair.0.maximumWidthMeters + pair.1.maximumWidthMeters
        )
      }
    }
    for row in 0..<CrowAxillaryFeatherTracts.rowCount {
      let course = samples.filter {
        $0.side == side && $0.row == row
      }.sorted { $0.column < $1.column }
      #expect(course.count == CrowAxillaryFeatherTracts.columnCount)
      for pair in zip(course, course.dropFirst()) {
        #expect(
          simd_distance(pair.0.rootOffset, pair.1.rootOffset)
            < simd_distance(pair.0.rootOffset, pair.0.tipOffset)
        )
      }
    }
  }

  let outerCovertCourse = CrowFoldedWingCoverts.samples().filter {
    $0.row == CrowFoldedWingCoverts.rowCount - 1
  }
  let axillaryRootCourse = samples.filter { $0.row == 0 }
  #expect(
    axillaryRootCourse.allSatisfy { feather in
      outerCovertCourse
        .filter { $0.side == feather.side }
        .map { simd_distance($0.rootOffset, feather.rootOffset) }
        .min()! < 0.007
    }
  )
}

@Test("axillary vanes resolve shafts and paired barb groups only at full density")
func axillaryVanesResolveFullDensityMesostructure() {
  let samples = CrowAxillaryFeatherTracts.samples()
  for feather in samples {
    #expect(
      CrowAxillaryFeatherDetail.segments(
        for: feather,
        projectedPixelsPerMeter: 1_000
      ).isEmpty
    )
    let segments = CrowAxillaryFeatherDetail.segments(
      for: feather,
      projectedPixelsPerMeter: 1_600
    )
    #expect(segments.count == 1 + 2 * CrowAxillaryFeatherDetail.barbPairCount)
    #expect(segments.filter { $0.kind == .rachis }.count == 1)
    #expect(
      segments.filter { $0.kind == .edgeBarbGroup }.count
        == 2 * CrowAxillaryFeatherDetail.barbPairCount
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
