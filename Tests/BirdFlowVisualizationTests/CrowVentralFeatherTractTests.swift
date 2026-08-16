import Testing
import simd

@testable import BirdFlowVisualization

@Test("crow ventral tracts cover breast and abdomen without changing coarse output")
func crowVentralTractsCoverBreastAndAbdomenAtFullResolution() {
  let samples = CrowVentralFeatherTracts.samples()
  #expect(samples == CrowVentralFeatherTracts.samples())
  #expect(
    samples.count
      == 2
      * (CrowVentralFeatherTracts.pectoralRowCount
        * CrowVentralFeatherTracts.pectoralColumnCount
        + CrowVentralFeatherTracts.abdominalRowCount
        * CrowVentralFeatherTracts.abdominalColumnCount)
  )
  #expect(samples.count == 584)
  #expect(
    CrowVentralFeatherTracts.visibleSamples(projectedPixelsPerMeter: 1_000).isEmpty
  )
  #expect(
    CrowVentralFeatherTracts.visibleSamples(projectedPixelsPerMeter: 1_600).count
      == samples.count
  )
  #expect(samples.filter { $0.region == .pectoral }.count == 360)
  #expect(samples.filter { $0.region == .abdominal }.count == 224)
  #expect(samples.allSatisfy { $0.surfaceFeatherClass == 7 })
  #expect(
    CrowVentralFeatherTractRegion.allCases.allSatisfy {
      CrowVentralFeatherTracts.surfaceFeatherClass(for: $0) == 7
    }
  )
  #expect(samples.map(\.materialVariation).min()! < -0.90)
  #expect(samples.map(\.materialVariation).max()! > 0.90)

  let anteriorPectoralRoots = samples.filter {
    $0.region == .pectoral && $0.column == 0
  }
  #expect(anteriorPectoralRoots.map(\.rootOffset.x).min()! > 0.149)
  #expect(anteriorPectoralRoots.allSatisfy { $0.pennaceousStartFraction == 0.10 })
  #expect(
    anteriorPectoralRoots.allSatisfy {
      $0.rootWidthMeters / $0.maximumWidthMeters > 0.81
    }
  )
  #expect(
    samples.filter { $0.region == .pectoral && $0.column == 1 }
      .allSatisfy { $0.pennaceousStartFraction == 0.24 }
  )
  #expect(
    samples.filter { $0.region == .pectoral && $0.column >= 2 }
      .allSatisfy { $0.pennaceousStartFraction == 0.34 }
  )
  let cervicalRoots = CrowBodyFeatherTracts.samples().filter {
    $0.region == .cervical
  }
  #expect(
    anteriorPectoralRoots.allSatisfy { pectoral in
      cervicalRoots.map { simd_distance($0.rootOffset, pectoral.rootOffset) }.min()!
        < 0.045
    }
  )

  for sample in samples {
    #expect(
      abs(
        simd_distance(sample.rootOffset, sample.rootSurfaceOffset)
          - CrowVentralFeatherTracts.shellClearanceMeters
      ) < 1e-6
    )
    #expect(sample.tipOffset.x < sample.rootOffset.x)
    #expect(sample.maximumWidthMeters > sample.rootWidthMeters)
    #expect(simd_distance(sample.rootOffset, sample.tipOffset) > sample.maximumWidthMeters)
    #expect(abs(simd_length(sample.planeNormal) - 1) < 1e-5)
    let rootNormal = simd_normalize(sample.rootOffset - sample.rootSurfaceOffset)
    #expect(simd_dot(rootNormal, sample.planeNormal) > 0.96)
  }

  for region in CrowVentralFeatherTractRegion.allCases {
    let regionSamples = samples.filter { $0.region == region }
    let rowCount =
      region == .pectoral
      ? CrowVentralFeatherTracts.pectoralRowCount
      : CrowVentralFeatherTracts.abdominalRowCount
    let columnCount =
      region == .pectoral
      ? CrowVentralFeatherTracts.pectoralColumnCount
      : CrowVentralFeatherTracts.abdominalColumnCount
    for side: Float in [-1, 1] {
      for row in 0..<rowCount {
        let course =
          regionSamples
          .filter { $0.side == side && $0.row == row }
          .sorted { $0.column < $1.column }
        #expect(course.count == columnCount)
        for pair in zip(course, course.dropFirst()) {
          #expect(
            simd_distance(pair.0.rootOffset, pair.1.rootOffset)
              < simd_distance(pair.0.rootOffset, pair.0.tipOffset)
          )
        }
      }
      for column in 0..<columnCount {
        let crossCourse =
          regionSamples
          .filter { $0.side == side && $0.column == column }
          .sorted { $0.row < $1.row }
        #expect(crossCourse.count == rowCount)
        for pair in zip(crossCourse, crossCourse.dropFirst()) {
          #expect(
            simd_distance(pair.0.rootOffset, pair.1.rootOffset)
              < pair.0.maximumWidthMeters + pair.1.maximumWidthMeters
          )
        }
      }
    }
  }
}

@Test("abdominal contour feathers overlap the proximal femoral field")
func abdominalContourFeathersOverlapProximalFemoralField() {
  let bodyCenter = SIMD3<Float>.zero
  let hip = SIMD3<Float>(-0.025, 0.035, -0.060)
  let hock = SIMD3<Float>(-0.014, 0.040, -0.111)
  let abdominal = CrowVentralFeatherTracts.samples().filter {
    $0.region == .abdominal && $0.side == 1
  }
  let femoral = CrowFemoralPlumage.samples(
    bodyCenter: bodyCenter,
    hip: hip,
    hock: hock
  )
  #expect(
    femoral.allSatisfy { feather in
      abdominal.map { simd_distance($0.tipOffset, feather.root) }.min()! < 0.034
    }
  )
}
