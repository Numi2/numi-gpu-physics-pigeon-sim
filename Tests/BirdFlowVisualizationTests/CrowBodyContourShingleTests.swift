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
    #expect(rootXs.max()! - rootXs.min()! > 0.0035)
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
    let interiorSpacings = Array(spacings.dropFirst().dropLast())
    let nominalSpacing = 0.270 / Float(CrowBodyContourShingles.axialCount)
    #expect(interiorSpacings.min()! > 0.35 * nominalSpacing)
    #expect(spacings.max()! - spacings.min()! > 0.0004)
  }

  for axialIndex in 0..<CrowBodyContourShingles.axialCount {
    let angularOffsets = (0..<CrowBodyContourShingles.radialCount).map {
      CrowBodyContourShingles.rootAngularFlowSteps(
        radialIndex: $0,
        axialIndex: axialIndex
      )
    }
    #expect(angularOffsets.allSatisfy { abs($0) < 0.25 })
    #expect(angularOffsets.max()! - angularOffsets.min()! > 0.32)
    let quantized = Set(angularOffsets.map { Int(($0 * 10_000).rounded()) })
    #expect(quantized.count > CrowBodyContourShingles.radialCount * 9 / 10)
    for radialIndex in 0..<CrowBodyContourShingles.radialCount {
      let nextIndex = (radialIndex + 1) % CrowBodyContourShingles.radialCount
      let orderedGapSteps = 1 + angularOffsets[nextIndex] - angularOffsets[radialIndex]
      #expect(orderedGapSteps > 0.50)
      #expect(orderedGapSteps < 1.50)
    }
  }

  for radialIndex in 0..<CrowBodyContourShingles.radialCount {
    let angularOffsets = (0..<CrowBodyContourShingles.axialCount).map {
      CrowBodyContourShingles.rootAngularFlowSteps(
        radialIndex: radialIndex,
        axialIndex: $0
      )
    }
    #expect(angularOffsets.max()! - angularOffsets.min()! > 0.30)
    let deltas = zip(angularOffsets, angularOffsets.dropFirst()).map { $1 - $0 }
    #expect(deltas.contains { $0 > 0.08 })
    #expect(deltas.contains { $0 < -0.08 })
  }
}

@Test("body contour pennaceous tips retain a closed irregular outer shell")
func bodyContourPennaceousTipsRetainClosedOuterShell() {
  let samples = CrowBodyContourShingles.samples()
  let fractions = samples.map(\.pennaceousStartFraction)
  #expect(fractions.min()! >= 0.35)
  #expect(fractions.max()! <= 0.45)
  #expect(fractions.max()! - fractions.min()! > 0.07)

  for feather in samples {
    let start = CrowBodyContourShingles.centerlinePoint(
      for: feather,
      at: feather.pennaceousStartFraction
    )
    let fullLength = simd_distance(feather.rootOffset, feather.tipOffset)
    let hiddenLength = simd_distance(feather.rootOffset, start)
    #expect(hiddenLength > 0.34 * fullLength)
    #expect(hiddenLength < 0.47 * fullLength)
    #expect(
      CrowBodyContourShingles.vaneHalfWidth(
        for: feather,
        at: feather.pennaceousStartFraction
      ) > 0.003
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

  for radialIndex in 0..<CrowBodyContourShingles.radialCount {
    let currentTract = samples.filter { $0.radialIndex == radialIndex }
    let nextTract = samples.filter {
      $0.radialIndex == (radialIndex + 1) % CrowBodyContourShingles.radialCount
    }
    for current in currentTract {
      let currentStart = CrowBodyContourShingles.centerlinePoint(
        for: current,
        at: current.pennaceousStartFraction
      )
      let candidates = nextTract.filter {
        abs($0.axialIndex - current.axialIndex) <= 1
      }
      #expect(
        candidates.contains { next in
          let nextStart = CrowBodyContourShingles.centerlinePoint(
            for: next,
            at: next.pennaceousStartFraction
          )
          func signedWidth(
            feather: CrowBodyContourShingle,
            from start: SIMD3<Float>,
            toward target: SIMD3<Float>
          ) -> Float {
            let direction = simd_normalize(feather.tipOffset - feather.rootOffset)
            let normal = simd_normalize(
              feather.planeNormal
                - direction * simd_dot(feather.planeNormal, direction)
            )
            let widthAxis = simd_normalize(simd_cross(normal, direction))
            return simd_dot(target - start, widthAxis) >= 0 ? 1 : -1
          }
          let currentSignedWidth = signedWidth(
            feather: current,
            from: currentStart,
            toward: nextStart
          )
          let nextSignedWidth = signedWidth(
            feather: next,
            from: nextStart,
            toward: currentStart
          )
          let availableWidth =
            CrowBodyContourShingles.vaneHalfWidth(
              for: current,
              at: current.pennaceousStartFraction,
              signedWidth: currentSignedWidth
            )
            + CrowBodyContourShingles.vaneHalfWidth(
              for: next,
              at: next.pennaceousStartFraction,
              signedWidth: nextSignedWidth
            )
          return simd_distance(currentStart, nextStart) < availableWidth
        }
      )
    }
  }
}

@Test("dorsal contour feathers resolve as narrow interdigitated vanes")
func dorsalContourFeathersResolveAsNarrowInterdigitatedVanes() {
  let dorsal = CrowBodyContourShingles.samples().filter { $0.region == .dorsal }
  #expect(dorsal.count > 200)

  for feather in dorsal {
    let length = simd_distance(feather.rootOffset, feather.tipOffset)
    let fullMaximumWidth = 2 * feather.maximumWidthMeters
    #expect(length / fullMaximumWidth > 2.0)
    #expect(length / fullMaximumWidth < 5.8)
    #expect((1 - feather.pennaceousStartFraction) * length > 0.020)
  }

  let courseMeans = (0..<CrowBodyContourShingles.radialCount).compactMap {
    radialIndex -> Float? in
    let tract = dorsal.filter { $0.radialIndex == radialIndex }
    guard !tract.isEmpty else { return nil }
    return tract.map(\.rootOffset.x).reduce(0, +) / Float(tract.count)
  }
  #expect(courseMeans.count >= 7)
  let adjacentOffsets = zip(courseMeans, courseMeans.dropFirst()).map {
    abs($0 - $1)
  }
  #expect(adjacentOffsets.max()! > 0.0015)
  #expect(adjacentOffsets.filter { $0 > 0.0005 }.count >= courseMeans.count / 2)

  let asymmetries = dorsal.map(\.vaneAsymmetry)
  let rippleAmplitudes = dorsal.map(\.edgeRippleAmplitude)
  let materialVariations = dorsal.map(\.materialVariation)
  #expect(asymmetries.min()! < -0.040)
  #expect(asymmetries.max()! > 0.040)
  #expect(rippleAmplitudes.min()! >= 0.012)
  #expect(rippleAmplitudes.max()! <= 0.0301)
  #expect(materialVariations.min()! < -0.90)
  #expect(materialVariations.max()! > 0.90)

  for feather in dorsal {
    for axial: Float in [feather.pennaceousStartFraction, 0.65, 0.84] {
      let negative = CrowBodyContourShingles.vaneHalfWidth(
        for: feather,
        at: axial,
        signedWidth: -1
      )
      let positive = CrowBodyContourShingles.vaneHalfWidth(
        for: feather,
        at: axial,
        signedWidth: 1
      )
      #expect(negative > 0 && positive > 0)
      #expect(abs(negative - positive) / max(negative, positive) < 0.09)
    }
  }
}
