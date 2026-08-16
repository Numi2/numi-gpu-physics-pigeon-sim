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
