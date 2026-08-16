import Testing
import simd

@testable import BirdFlowVisualization

@Test("crow body feather tracts overlap the neck and cover both wing roots")
func crowBodyFeatherTractsOverlapNeckAndCoverWingRoots() {
  let samples = CrowBodyFeatherTracts.samples()
  let expectedCount =
    2
    * (CrowBodyFeatherTracts.cervicalRowCount
      * CrowBodyFeatherTracts.cervicalColumnCount
      + CrowBodyFeatherTracts.mantleRowCount
      * CrowBodyFeatherTracts.mantleColumnCount
      + CrowBodyFeatherTracts.scapularRowCount
      * CrowBodyFeatherTracts.scapularColumnCount)
  #expect(samples.count == expectedCount)

  let cervical = samples.filter { $0.region == .cervical }
  let mantle = samples.filter { $0.region == .mantle }
  let scapular = samples.filter { $0.region == .scapular }
  #expect(cervical.count == 182)
  #expect(mantle.count == 252)
  #expect(scapular.count == 400)
  #expect(Set(cervical.map(\.surfaceFeatherClass)) == Set([5, 6]))
  #expect(mantle.allSatisfy { $0.surfaceFeatherClass == 5 })
  #expect(scapular.allSatisfy { $0.surfaceFeatherClass == 6 })
  #expect(samples.allSatisfy { $0.surfaceFeatherClass == 5 || $0.surfaceFeatherClass == 6 })
  #expect(
    CrowBodyFeatherTracts.surfaceFeatherClass(
      for: .cervical,
      cervicalAngle: 0.75
    ) == 5
  )
  #expect(
    CrowBodyFeatherTracts.surfaceFeatherClass(
      for: .cervical,
      cervicalAngle: -0.75
    ) == 6
  )

  let mantleLengths = mantle.map { simd_distance($0.rootOffset, $0.tipOffset) }
  let scapularLengths = scapular.map { simd_distance($0.rootOffset, $0.tipOffset) }
  #expect(mantleLengths.min()! > 0.023)
  #expect(mantleLengths.max()! < 0.041)
  #expect(scapularLengths.min()! > 0.026)
  #expect(scapularLengths.max()! < 0.049)

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
  #expect(Set(samples.map(\.edgeRipplePhase)).count > samples.count / 2)

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

  for region in [CrowBodyFeatherTractRegion.mantle, .scapular] {
    let regionSamples = samples.filter { $0.region == region }
    let rowCount =
      region == .mantle
      ? CrowBodyFeatherTracts.mantleRowCount
      : CrowBodyFeatherTracts.scapularRowCount
    let columnCount =
      region == .mantle
      ? CrowBodyFeatherTracts.mantleColumnCount
      : CrowBodyFeatherTracts.scapularColumnCount
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
      for pair in zip(phases, phases.dropFirst()) {
        #expect(abs(pair.0 - pair.1) > 0.44)
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
          let axialSpan: Float = region == .mantle ? 0.154 : 0.164
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
  #expect(low.filter { $0.region == .cervical }.count == 56)
  #expect(medium.filter { $0.region == .cervical }.count == 92)
  #expect(full.filter { $0.region == .cervical }.count == 182)
  #expect(low.filter { $0.region == .mantle }.count == 72)
  #expect(medium.filter { $0.region == .mantle }.count == 126)
  #expect(full.filter { $0.region == .mantle }.count == 252)
  #expect(low.filter { $0.region == .scapular }.count == 100)
  #expect(medium.filter { $0.region == .scapular }.count == 200)
  #expect(full.filter { $0.region == .scapular }.count == 400)
  #expect(low.count == 228)
  #expect(medium.count == 418)
  #expect(full.count == 834)
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
