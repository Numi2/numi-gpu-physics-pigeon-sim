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
  #expect(samples.count == 1_304)
  #expect(CrowVentralFeatherTracts.transverseCamberRatio == 0.07)
  #expect(CrowVentralFeatherTracts.retainedRachisTransverseCamberRatio == 0.07)
  #expect(samples.filter(CrowVentralFeatherTracts.retainsCrownRachis).count == 776)
  #expect(
    CrowVentralFeatherTracts.visibleSamples(projectedPixelsPerMeter: 1_000).isEmpty
  )
  #expect(
    CrowVentralFeatherTracts.visibleSamples(projectedPixelsPerMeter: 1_600).count
      == samples.count
  )
  #expect(samples.filter { $0.region == .pectoral }.count == 864)
  #expect(samples.filter { $0.region == .abdominal }.count == 440)
  #expect(samples.allSatisfy { $0.surfaceFeatherClass == 7 })
  #expect(
    CrowVentralFeatherTractRegion.allCases.allSatisfy {
      CrowVentralFeatherTracts.surfaceFeatherClass(for: $0) == 7
    }
  )
  #expect(samples.map(\.materialVariation).min()! < -0.90)
  #expect(samples.map(\.materialVariation).max()! > 0.90)
  #expect(samples.map(\.vaneAsymmetry).min()! < -0.043)
  #expect(samples.map(\.vaneAsymmetry).max()! > 0.043)
  #expect(samples.map(\.edgeRippleAmplitude).min()! > 0.0119)
  #expect(samples.map(\.edgeRippleAmplitude).max()! < 0.0281)
  #expect(samples.map(\.edgeRippleAmplitude).max()! > 0.0275)
  #expect(samples.map(\.edgeRippleCycles).min()! > 1.34)
  #expect(samples.map(\.edgeRippleCycles).max()! < 2.01)
  let lateralSweeps = samples.map(\.lateralSweepMeters)
  #expect(lateralSweeps.min()! < -0.00145)
  #expect(lateralSweeps.max()! > 0.00145)
  #expect(lateralSweeps.allSatisfy { abs($0) < 0.00153 })
  #expect(
    Set(lateralSweeps.map { Int(($0 * 1_000_000).rounded()) }).count > 550
  )
  #expect(
    samples.allSatisfy {
      abs($0.lateralSweepMeters) < 0.38 * $0.maximumWidthMeters
    }
  )
  #expect(
    Set(samples.map { Int(($0.edgeRipplePhase * 100_000).rounded()) }).count
      > 510
  )
  let rowFlows = CrowVentralFeatherTractRegion.allCases.flatMap { region in
    let rowCount = region == .pectoral
      ? CrowVentralFeatherTracts.pectoralRowCount
      : CrowVentralFeatherTracts.abdominalRowCount
    let columnCount = region == .pectoral
      ? CrowVentralFeatherTracts.pectoralColumnCount
      : CrowVentralFeatherTracts.abdominalColumnCount
    return (0..<rowCount).flatMap { row in
      (0..<columnCount).map {
        CrowVentralFeatherTracts.rootRowFlowSteps(
          region: region,
          row: row,
          column: $0
        )
      }
    }
  }
  let crownRolls = CrowVentralFeatherTractRegion.allCases.flatMap { region in
    let rowCount = region == .pectoral
      ? CrowVentralFeatherTracts.pectoralRowCount
      : CrowVentralFeatherTracts.abdominalRowCount
    let columnCount = region == .pectoral
      ? CrowVentralFeatherTracts.pectoralColumnCount
      : CrowVentralFeatherTracts.abdominalColumnCount
    return (0..<rowCount).flatMap { row in
      (0..<columnCount).map {
        CrowVentralFeatherTracts.crownRollSlope(
          region: region,
          row: row,
          column: $0
        )
      }
    }
  }
  #expect(rowFlows.allSatisfy { abs($0) < 0.221 })
  #expect(rowFlows.max()! - rowFlows.min()! > 0.40)
  #expect(Set(rowFlows.map { Int(($0 * 100_000).rounded()) }).count > 510)
  #expect(crownRolls.allSatisfy { abs($0) < 0.066 })
  #expect(crownRolls.max()! - crownRolls.min()! > 0.115)
  #expect(Set(crownRolls.map { Int(($0 * 100_000).rounded()) }).count > 510)
  for region in CrowVentralFeatherTractRegion.allCases {
    let rowCount = region == .pectoral
      ? CrowVentralFeatherTracts.pectoralRowCount
      : CrowVentralFeatherTracts.abdominalRowCount
    let phases = (0..<rowCount).map {
      CrowVentralFeatherTracts.axialStaggerFraction(region: region, row: $0)
    }
    #expect(Set(phases.map { Int(($0 * 1_000).rounded()) }).count == rowCount)
    #expect(phases.min()! < 0.15)
    #expect(phases.max()! > 0.85)
    for pair in zip(phases, phases.dropFirst()) {
      let linearDistance = abs(pair.0 - pair.1)
      #expect(min(linearDistance, 1 - linearDistance) > 0.30)
    }
  }
  #expect(samples.map(\.rootEnvelopeRatio).min()! >= 0.53)
  #expect(samples.map(\.rootEnvelopeRatio).max()! <= 0.621)
  let pectoral = samples.filter { $0.region == .pectoral }
  #expect(
    pectoral.allSatisfy {
      2 * $0.maximumWidthMeters
        / simd_distance($0.rootOffset, $0.tipOffset) < 0.40
    }
  )

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

  let negative = samples.filter { $0.side == -1 }
  let positive = samples.filter { $0.side == 1 }
  #expect(negative.count == positive.count)
  for pair in zip(negative, positive) {
    #expect(pair.0.region == pair.1.region)
    #expect(pair.0.row == pair.1.row && pair.0.column == pair.1.column)
    #expect(abs(pair.0.rootOffset.x - pair.1.rootOffset.x) < 1e-7)
    #expect(abs(pair.0.rootOffset.y + pair.1.rootOffset.y) < 1e-7)
    #expect(abs(pair.0.rootOffset.z - pair.1.rootOffset.z) < 1e-7)
    #expect(abs(pair.0.tipOffset.y + pair.1.tipOffset.y) < 1e-7)
    #expect(abs(pair.0.planeNormal.x - pair.1.planeNormal.x) < 1e-7)
    #expect(abs(pair.0.planeNormal.y + pair.1.planeNormal.y) < 1e-7)
    #expect(abs(pair.0.planeNormal.z - pair.1.planeNormal.z) < 1e-7)
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
