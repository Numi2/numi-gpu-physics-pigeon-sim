import Testing
import simd

@testable import BirdFlowVisualization

@Test("showcase-scale shoulder vanes resolve interior barb bundles")
func showcaseScaleShoulderVanesResolveInteriorBarbBundles() throws {
  let sample = try #require(
    CrowBodyFeatherTracts.samples().first {
      $0.region == .scapular && $0.side == 1
    }
  )
  let length = simd_distance(sample.rootOffset, sample.tipOffset)
  let below = CrowFeatherMesostructure.segments(
    for: sample,
    projectedPixelsPerMeter: (CrowFeatherMesostructure.shoulderInteriorBarbThresholdPixels - 1)
      / length
  )
  let promoted = CrowFeatherMesostructure.segments(
    for: sample,
    projectedPixelsPerMeter:
      CrowFeatherMesostructure.shoulderInteriorBarbThresholdPixels / length
  )
  #expect(below.contains { $0.kind == .edgeBarbGroup })
  #expect(!below.contains { $0.kind == .barb })
  #expect(promoted.contains { $0.kind == .barb })
  #expect(
    promoted.filter { $0.kind == .edgeBarbGroup }.count
      < below.filter { $0.kind == .edgeBarbGroup }.count
  )
  #expect(promoted.count == below.count)
}

@Test("crow body feather tracts overlap the neck and cover both wing roots")
func crowBodyFeatherTractsOverlapNeckAndCoverWingRoots() {
  let samples = CrowBodyFeatherTracts.samples()
  let expectedCount =
    2
    * (CrowBodyFeatherTracts.cervicalRowCount
      * CrowBodyFeatherTracts.cervicalColumnCount
      + CrowBodyFeatherTracts.mantleRowCount
      * CrowBodyFeatherTracts.mantleColumnCount
      + CrowBodyFeatherTracts.humeralRowCount
      * CrowBodyFeatherTracts.humeralColumnCount
      + CrowBodyFeatherTracts.scapularRowCount
      * CrowBodyFeatherTracts.scapularColumnCount)
  #expect(samples.count == expectedCount)

  let cervical = samples.filter { $0.region == .cervical }
  let mantle = samples.filter { $0.region == .mantle }
  let humeral = samples.filter { $0.region == .humeral }
  let scapular = samples.filter { $0.region == .scapular }
  #expect(cervical.count == 480)
  #expect(mantle.count == 960)
  #expect(humeral.count == 300)
  #expect(scapular.count == 1_056)
  #expect(Set(cervical.map(\.surfaceFeatherClass)) == Set([5, 6]))
  #expect(mantle.allSatisfy { $0.surfaceFeatherClass == 5 })
  #expect(humeral.allSatisfy { $0.surfaceFeatherClass == 6 })
  #expect(scapular.allSatisfy { $0.surfaceFeatherClass == 6 })
  #expect(samples.allSatisfy { $0.surfaceFeatherClass == 5 || $0.surfaceFeatherClass == 6 })
  #expect(
    CrowBodyFeatherTracts.surfaceFeatherClass(
      for: .cervical,
      cervicalAngle: 0.75
    ) == 5
  )

  #expect(CrowBodyFeatherTracts.cervicalMaximumAngleRadians > 1.50)
  for side: Float in [-1, 1] {
    for column in 0..<CrowBodyFeatherTracts.cervicalColumnCount {
      let dorsalRoot = CrowBodyFeatherTracts.cervicalRootSurface(
        side: side,
        row: CrowBodyFeatherTracts.cervicalRowCount - 1,
        column: column
      )
      #expect(abs(dorsalRoot.y) < 0.0035)
      #expect(dorsalRoot.z > 0.075)
    }
  }
  #expect(
    CrowBodyFeatherTracts.surfaceFeatherClass(
      for: .cervical,
      cervicalAngle: -0.75
    ) == 6
  )

  let mantleLengths = mantle.map { simd_distance($0.rootOffset, $0.tipOffset) }
  let scapularLengths = scapular.map { simd_distance($0.rootOffset, $0.tipOffset) }
  #expect(mantleLengths.min()! > 0.023)
  #expect(mantleLengths.max()! < 0.046)
  #expect(CrowBodyFeatherTracts.mantlePosteriorLengthAdditionMeters(axial: -1) == 0)
  #expect(CrowBodyFeatherTracts.mantlePosteriorLengthAdditionMeters(axial: 0) == 0)
  #expect(
    abs(CrowBodyFeatherTracts.mantlePosteriorLengthAdditionMeters(axial: 0.5) - 0.001)
      < 1e-7
  )
  #expect(
    CrowBodyFeatherTracts.mantlePosteriorLengthAdditionMeters(axial: 1) == 0.004
  )
  #expect(
    CrowBodyFeatherTracts.mantlePosteriorLengthAdditionMeters(axial: 2) == 0.004
  )
  #expect(
    mantle.allSatisfy {
      2 * $0.maximumWidthMeters
        / simd_distance($0.rootOffset, $0.tipOffset) < 0.43
    }
  )
  #expect(scapularLengths.min()! > 0.026)
  #expect(scapularLengths.max()! < 0.053)
  #expect(CrowBodyFeatherTracts.scapularOuterLengthAdditionMeters(course: -1) == 0)
  #expect(CrowBodyFeatherTracts.scapularOuterLengthAdditionMeters(course: 0) == 0)
  #expect(
    abs(CrowBodyFeatherTracts.scapularOuterLengthAdditionMeters(course: 0.5) - 0.001)
      < 1e-7
  )
  #expect(CrowBodyFeatherTracts.scapularOuterLengthAdditionMeters(course: 1) == 0.004)
  #expect(CrowBodyFeatherTracts.scapularOuterLengthAdditionMeters(course: 2) == 0.004)
  #expect(
    scapular.allSatisfy {
      2 * $0.maximumWidthMeters
        / simd_distance($0.rootOffset, $0.tipOffset) < 0.47
    }
  )
  #expect(scapular.map(\.maximumWidthMeters).max()! < 0.0063)

  for side: Float in [-1, 1] {
    let wingRoot = SIMD3<Float>(0.015, side * 0.067, 0.038)
    let nearestScapularRoot =
      scapular
      .filter { $0.side == side }
      .map { simd_distance($0.rootOffset, wingRoot) }
      .min()!
    #expect(nearestScapularRoot < 0.018)
  }

  for side: Float in [-1, 1] {
    for column in 0..<CrowBodyFeatherTracts.cervicalColumnCount {
      let course =
        cervical
        .filter { $0.side == side && $0.column == column }
        .sorted { $0.row < $1.row }
      for pair in zip(course, course.dropFirst()) {
        #expect(
          simd_distance(pair.0.rootOffset, pair.1.rootOffset)
            < pair.0.maximumWidthMeters + pair.1.maximumWidthMeters
        )
      }
    }
  }

  for side: Float in [-1, 1] {
    for row in 0..<CrowBodyFeatherTracts.cervicalRowCount {
      let ordered =
        cervical
        .filter { $0.side == side && $0.row == row }
        .sorted { $0.column < $1.column }
      #expect(ordered.count == CrowBodyFeatherTracts.cervicalColumnCount)
      for pair in zip(ordered, ordered.dropFirst()) {
        let rootSpacing = simd_distance(pair.0.rootOffset, pair.1.rootOffset)
        let precedingLength = simd_distance(pair.0.rootOffset, pair.0.tipOffset)
        #expect(rootSpacing < precedingLength)
      }
    }
  }

  #expect(
    samples.allSatisfy {
      $0.maximumWidthMeters > $0.rootWidthMeters
        && simd_distance($0.rootOffset, $0.tipOffset) > $0.maximumWidthMeters
        && abs(simd_length($0.planeNormal) - 1) < 1e-5
    }
  )
  #expect(samples.map(\.materialVariation).min()! < -0.90)
  #expect(samples.map(\.materialVariation).max()! > 0.90)
  #expect(samples.map(\.vaneAsymmetry).min()! < -0.050)
  #expect(samples.map(\.vaneAsymmetry).max()! > 0.050)
  #expect(samples.map(\.edgeRippleAmplitude).min()! >= 0.010)
  #expect(samples.map(\.edgeRippleAmplitude).max()! <= 0.0341)
  #expect(samples.map(\.edgeRippleCycles).min()! >= 1.30)
  #expect(samples.map(\.edgeRippleCycles).max()! <= 2.101)
  for region in CrowBodyFeatherTractRegion.allCases {
    let regionSamples = samples.filter { $0.region == region }
    #expect(
      Set(regionSamples.map(\.edgeRipplePhase)).count
        > 9 * regionSamples.count / 10
    )
  }
  #expect(cervical.map(\.rootEnvelopeRatio).min()! >= 0.48)
  #expect(cervical.map(\.rootEnvelopeRatio).max()! <= 0.551)
  #expect(
    cervical.map(\.rootEnvelopeRatio).max()!
      - cervical.map(\.rootEnvelopeRatio).min()! > 0.068
  )
  #expect(mantle.map(\.rootEnvelopeRatio).min()! >= 0.56)
  #expect(mantle.map(\.rootEnvelopeRatio).max()! <= 0.621)
  #expect(humeral.map(\.rootEnvelopeRatio).min()! >= 0.64)
  #expect(humeral.map(\.rootEnvelopeRatio).max()! <= 0.681)
  #expect(scapular.map(\.rootEnvelopeRatio).min()! >= 0.59)
  #expect(scapular.map(\.rootEnvelopeRatio).max()! <= 0.641)
  #expect(samples.allSatisfy { $0.pennaceousStartFraction == 0 })

  for side: Float in [-1, 1] {
    for row in 0..<CrowBodyFeatherTracts.cervicalRowCount {
      for column in 0..<CrowBodyFeatherTracts.cervicalColumnCount {
        let feather = cervical.first {
          $0.side == side && $0.row == row && $0.column == column
        }!
        let surface = CrowBodyFeatherTracts.cervicalRootSurface(
          side: side,
          row: row,
          column: column
        )
        let normal = CrowBodyFeatherTracts.cervicalRootNormal(
          side: side,
          row: row,
          column: column
        )
        let offset = feather.rootOffset - surface
        #expect(
          abs(simd_length(offset) - CrowBodyFeatherTracts.cervicalShellClearanceMeters)
            < 1e-6
        )
        #expect(simd_dot(offset, normal) > 0)
      }
    }
  }

  let cervicalPhases = (0..<CrowBodyFeatherTracts.cervicalRowCount).map {
    CrowBodyFeatherTracts.cervicalCoursePhase(row: $0)
  }
  #expect(Set(cervicalPhases).count == CrowBodyFeatherTracts.cervicalRowCount)
  #expect(cervicalPhases.min() == 0)
  #expect(cervicalPhases.max()! > 0.94)
  #expect(
    zip(cervicalPhases, cervicalPhases.dropFirst()).allSatisfy {
      abs($0 - $1) > 0.43
    }
  )
  let cervicalInteriorStaggers = (0..<CrowBodyFeatherTracts.cervicalRowCount).map {
    CrowBodyFeatherTracts.cervicalAxialStaggerMeters(row: $0, column: 5)
  }
  #expect(cervicalInteriorStaggers.min()! <= -0.00196)
  #expect(cervicalInteriorStaggers.max()! > 0.00180)
  #expect(
    (0..<CrowBodyFeatherTracts.cervicalRowCount).allSatisfy {
      CrowBodyFeatherTracts.cervicalAxialStaggerMeters(row: $0, column: 0) == 0
        && CrowBodyFeatherTracts.cervicalAxialStaggerMeters(
          row: $0,
          column: CrowBodyFeatherTracts.cervicalColumnCount - 1
        ) == 0
    }
  )
  #expect(
    cervical.map(\.rootWidthMeters).max()!
      - cervical.map(\.rootWidthMeters).min()! > 0.00028
  )

  for side: Float in [-1, 1] {
    let sideMantle = mantle.filter { $0.side == side }
    let sideScapular = scapular.filter { $0.side == side }
    let sideHumeral = humeral.filter { $0.side == side }
    for feather in sideHumeral {
      #expect(
        sideMantle.map { simd_distance($0.rootOffset, feather.rootOffset) }.min()!
          < 0.012
      )
      #expect(
        sideScapular.map { simd_distance($0.rootOffset, feather.rootOffset) }.min()!
          < 0.012
      )
    }
    for row in 0..<CrowBodyFeatherTracts.humeralRowCount {
      let course =
        sideHumeral
        .filter { $0.row == row }
        .sorted { $0.column < $1.column }
      #expect(course.count == CrowBodyFeatherTracts.humeralColumnCount)
      for pair in zip(course, course.dropFirst()) {
        #expect(
          simd_distance(pair.0.rootOffset, pair.1.rootOffset)
            < simd_distance(pair.0.rootOffset, pair.0.tipOffset)
        )
      }
    }
    for column in 0..<CrowBodyFeatherTracts.humeralColumnCount {
      let crossCourse =
        sideHumeral
        .filter { $0.column == column }
        .sorted { $0.row < $1.row }
      for pair in zip(crossCourse, crossCourse.dropFirst()) {
        #expect(
          simd_distance(pair.0.rootOffset, pair.1.rootOffset)
            < pair.0.maximumWidthMeters + pair.1.maximumWidthMeters
        )
      }
    }
  }

  for region in [CrowBodyFeatherTractRegion.mantle, .humeral, .scapular] {
    let regionSamples = samples.filter { $0.region == region }
    let rowCount: Int
    let columnCount: Int
    let axialSpan: Float
    switch region {
    case .mantle:
      rowCount = CrowBodyFeatherTracts.mantleRowCount
      columnCount = CrowBodyFeatherTracts.mantleColumnCount
      axialSpan = 0.154
    case .humeral:
      rowCount = CrowBodyFeatherTracts.humeralRowCount
      columnCount = CrowBodyFeatherTracts.humeralColumnCount
      axialSpan = 0.160
    case .scapular:
      rowCount = CrowBodyFeatherTracts.scapularRowCount
      columnCount = CrowBodyFeatherTracts.scapularColumnCount
      axialSpan = 0.164
    case .cervical:
      preconditionFailure("cervical tract has a separate fixed-boundary phase contract")
    }
    for side: Float in [-1, 1] {
      let phases = (0..<rowCount).map {
        CrowBodyFeatherTracts.tractStaggerFraction(
          region: region,
          side: side,
          row: $0
        )
      }
      let quantizedPhases = Set(phases.map { Int(($0 * 1_000).rounded()) })
      #expect(quantizedPhases.count == rowCount)
      if region == .humeral {
        #expect(phases.max()! - phases.min()! > 0.60)
      } else {
        #expect(phases.min()! < 0.12)
        #expect(phases.max()! > 0.88)
      }
      for pair in zip(phases, phases.dropFirst()) {
        let linearDistance = abs(pair.0 - pair.1)
        let circularDistance = min(linearDistance, 1 - linearDistance)
        #expect(circularDistance > 0.30)
      }
      for column in 0..<columnCount {
        let course =
          regionSamples
          .filter { $0.side == side && $0.column == column }
          .sorted { $0.row < $1.row }
        #expect(course.count == rowCount)
        for pair in zip(course, course.dropFirst()) {
          #expect(
            simd_distance(pair.0.rootOffset, pair.1.rootOffset)
              < pair.0.maximumWidthMeters + pair.1.maximumWidthMeters
          )
          let axialSpacing = axialSpan / Float(columnCount - 1)
          #expect(
            abs(pair.0.rootOffset.x - pair.1.rootOffset.x)
              > 0.25 * axialSpacing
          )
        }
      }
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
    }
  }

  let low = CrowBodyFeatherTracts.visibleSamples(projectedPixelsPerMeter: 800)
  let medium = CrowBodyFeatherTracts.visibleSamples(projectedPixelsPerMeter: 1_000)
  let full = CrowBodyFeatherTracts.visibleSamples(projectedPixelsPerMeter: 1_600)
  #expect(low.filter { $0.region == .cervical }.count == 240)
  #expect(medium.filter { $0.region == .cervical }.count == 240)
  #expect(full.filter { $0.region == .cervical }.count == 480)
  #expect(low.filter { $0.region == .mantle }.count == 240)
  #expect(medium.filter { $0.region == .mantle }.count == 480)
  #expect(full.filter { $0.region == .mantle }.count == 960)
  #expect(low.filter { $0.region == .humeral }.count == 90)
  #expect(medium.filter { $0.region == .humeral }.count == 150)
  #expect(full.filter { $0.region == .humeral }.count == 300)
  #expect(low.filter { $0.region == .scapular }.count == 264)
  #expect(medium.filter { $0.region == .scapular }.count == 528)
  #expect(full.filter { $0.region == .scapular }.count == 1_056)
  #expect(low.count == 834)
  #expect(medium.count == 1_398)
  #expect(full.count == 2_796)
}

@Test("quiet head motion bends the cervical tract without moving the mantle")
func quietHeadMotionBendsOnlyCervicalTract() {
  let neckPose = CrowStandingNeckPose(
    translation: SIMD3<Float>(0.0015, -0.0024, 0.0017),
    yawRadians: 0.018,
    pitchRadians: -0.014,
    rollRadians: 0.006
  )
  let reference = CrowBodyFeatherTracts.samples()
  let moved = CrowBodyFeatherTracts.samples(neckPose: neckPose)
  #expect(reference.count == moved.count)

  let paired = Array(zip(reference, moved))
  #expect(
    paired
      .filter { $0.0.region != .cervical }
      .allSatisfy { simd_distance($0.0.rootOffset, $0.1.rootOffset) < 1e-8 }
  )

  let cervicalPairs = paired.filter { $0.0.region == .cervical }
  let shoulderDisplacement =
    cervicalPairs
    .filter { $0.0.column == 0 }
    .map { simd_distance($0.0.rootOffset, $0.1.rootOffset) }
    .max()!
  let cranialDisplacement =
    cervicalPairs
    .filter { $0.0.column == CrowBodyFeatherTracts.cervicalColumnCount - 1 }
    .map { simd_distance($0.0.rootOffset, $0.1.rootOffset) }
    .min()!
  #expect(shoulderDisplacement > 0)
  #expect(cranialDisplacement > 6 * shoulderDisplacement)
  #expect(cranialDisplacement < 0.006)
}
