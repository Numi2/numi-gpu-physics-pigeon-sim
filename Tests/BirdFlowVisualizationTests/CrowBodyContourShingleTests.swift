import Testing
import simd

@testable import BirdFlowVisualization

@Test("crow body contour shingles overlap around and along the anatomical loft")
func crowBodyContourShinglesOverlapAroundAndAlongLoft() {
  let samples = CrowBodyContourShingles.samples()
  #expect(
    samples.count
      == CrowBodyContourShingles.radialCount * CrowBodyContourShingles.axialCount
  )

  for radialIndex in 0..<CrowBodyContourShingles.radialCount {
    let row =
      samples
      .filter { $0.radialIndex == radialIndex }
      .sorted { $0.axialIndex < $1.axialIndex }
    #expect(row.count == CrowBodyContourShingles.axialCount)
    for pair in zip(row, row.dropFirst()) {
      #expect(pair.0.rootOffset.x > pair.1.rootOffset.x)
      #expect(pair.0.tipOffset.x < pair.1.rootOffset.x)
      #expect(
        simd_distance(pair.0.rootOffset, pair.1.rootOffset)
          < simd_distance(pair.0.rootOffset, pair.0.tipOffset)
      )
    }
  }

  for axialIndex in 0..<CrowBodyContourShingles.axialCount {
    let column = samples.filter { $0.axialIndex == axialIndex }
    #expect(column.count == CrowBodyContourShingles.radialCount)
    for radialIndex in 0..<CrowBodyContourShingles.radialCount {
      let current = column.first { $0.radialIndex == radialIndex }!
      let next = column.first {
        $0.radialIndex == (radialIndex + 1) % CrowBodyContourShingles.radialCount
      }!
      let rootSpacing = simd_distance(current.rootOffset, next.rootOffset)
      #expect(
        rootSpacing
          < current.maximumWidthMeters + next.maximumWidthMeters
      )
    }
  }

  #expect(
    samples.allSatisfy {
      $0.rootWidthMeters > 0
        && $0.maximumWidthMeters > $0.rootWidthMeters
        && abs(simd_length($0.planeNormal) - 1) < 1e-5
        && $0.rootOffset.x.isFinite && $0.rootOffset.y.isFinite
        && $0.rootOffset.z.isFinite
    }
  )
}

@Test("body contour roots follow the asymmetric loft with sub-millimetre clearance")
func bodyContourRootsFollowAsymmetricLoft() {
  let samples = CrowBodyContourShingles.samples()
  for sample in samples {
    let clearance = simd_distance(sample.rootOffset, sample.rootSurfaceOffset)
    #expect(abs(clearance - CrowBodyContourShingles.shellClearanceMeters) < 1e-6)
  }
}

@Test("body contour tracts break transverse rows with bounded deterministic variation")
func bodyContourTractsBreakTransverseRows() {
  let first = CrowBodyContourShingles.samples()
  let second = CrowBodyContourShingles.samples()
  #expect(first == second)
  #expect(Set(first.map(\.region)) == Set(CrowBodyContourRegion.allCases))

  for axialIndex in 0..<CrowBodyContourShingles.axialCount {
    let course = first.filter { $0.axialIndex == axialIndex }
    let rootXs = course.map(\.rootOffset.x)
    #expect(rootXs.max()! - rootXs.min()! > 0.004)
  }

  let lengths = first.map { simd_distance($0.rootOffset, $0.tipOffset) }
  let widths = first.map(\.maximumWidthMeters)
  #expect(lengths.max()! - lengths.min()! > 0.006)
  #expect(widths.max()! - widths.min()! > 0.002)

  for radialIndex in 0..<CrowBodyContourShingles.radialCount {
    let tract =
      first
      .filter { $0.radialIndex == radialIndex }
      .sorted { $0.axialIndex < $1.axialIndex }
    let spacings = zip(tract, tract.dropFirst()).map {
      $0.rootOffset.x - $1.rootOffset.x
    }
    let nominalSpacing = 0.270 / Float(CrowBodyContourShingles.axialCount)
    #expect(spacings.min()! > 0.50 * nominalSpacing)
    #expect(spacings.max()! - spacings.min()! > 0.0004)
  }
}

@Test("body contour pennaceous tips retain a closed irregular outer shell")
func bodyContourPennaceousTipsRetainClosedOuterShell() {
  let samples = CrowBodyContourShingles.samples()
  let fractions = samples.map(\.pennaceousStartFraction)
  #expect(fractions.min()! >= 0.38)
  #expect(fractions.max()! <= 0.51)
  #expect(fractions.max()! - fractions.min()! > 0.06)

  for feather in samples {
    let start = CrowBodyContourShingles.centerlinePoint(
      for: feather,
      at: feather.pennaceousStartFraction
    )
    let fullLength = simd_distance(feather.rootOffset, feather.tipOffset)
    let hiddenLength = simd_distance(feather.rootOffset, start)
    #expect(hiddenLength > 0.36 * fullLength)
    #expect(hiddenLength < 0.54 * fullLength)
    #expect(
      CrowBodyContourShingles.vaneHalfWidth(
        for: feather,
        at: feather.pennaceousStartFraction
      ) > 0.004
    )
  }

  for radialIndex in 0..<CrowBodyContourShingles.radialCount {
    let tract =
      samples
      .filter { $0.radialIndex == radialIndex }
      .sorted { $0.axialIndex < $1.axialIndex }
    for pair in zip(tract, tract.dropFirst()) {
      let followingPennaceousStart = CrowBodyContourShingles.centerlinePoint(
        for: pair.1,
        at: pair.1.pennaceousStartFraction
      )
      #expect(pair.0.tipOffset.x < followingPennaceousStart.x)
    }
  }

  for axialIndex in 0..<CrowBodyContourShingles.axialCount {
    let course = samples.filter { $0.axialIndex == axialIndex }
    for radialIndex in 0..<CrowBodyContourShingles.radialCount {
      let current = course.first { $0.radialIndex == radialIndex }!
      let next = course.first {
        $0.radialIndex == (radialIndex + 1) % CrowBodyContourShingles.radialCount
      }!
      let currentStart = CrowBodyContourShingles.centerlinePoint(
        for: current,
        at: current.pennaceousStartFraction
      )
      let nextStart = CrowBodyContourShingles.centerlinePoint(
        for: next,
        at: next.pennaceousStartFraction
      )
      let availableWidth =
        CrowBodyContourShingles.vaneHalfWidth(
          for: current,
          at: current.pennaceousStartFraction
        )
        + CrowBodyContourShingles.vaneHalfWidth(
          for: next,
          at: next.pennaceousStartFraction
        )
      #expect(simd_distance(currentStart, nextStart) < availableWidth)
    }
  }
}
