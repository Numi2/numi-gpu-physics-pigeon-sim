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
  #expect(cervical.count == 50)
  #expect(mantle.count == 48)
  #expect(scapular.count == 72)

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
}

@Test("quiet head motion bends the cervical tract without moving the mantle")
func quietHeadMotionBendsOnlyCervicalTract() {
  let headOffset = SIMD3<Float>(0.0015, -0.0024, 0.0017)
  let reference = CrowBodyFeatherTracts.samples()
  let moved = CrowBodyFeatherTracts.samples(headOffset: headOffset)
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
  #expect(cranialDisplacement < simd_length(headOffset))
}
