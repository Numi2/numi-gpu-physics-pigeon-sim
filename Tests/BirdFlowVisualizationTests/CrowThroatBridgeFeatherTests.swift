import Testing
import simd

@testable import BirdFlowVisualization

@Test("throat bridge breaks the cervical pectoral collar only at full resolution")
func throatBridgeBreaksCervicalPectoralCollarAtFullResolution() {
  let samples = CrowThroatBridgeFeathers.samples()
  #expect(samples == CrowThroatBridgeFeathers.samples())
  #expect(
    samples.count
      == 2 * CrowThroatBridgeFeathers.rowCount * CrowThroatBridgeFeathers.columnCount
  )
  #expect(samples.count == 72)
  #expect(
    CrowThroatBridgeFeathers.visibleSamples(projectedPixelsPerMeter: 1_000).isEmpty
  )
  #expect(
    CrowThroatBridgeFeathers.visibleSamples(projectedPixelsPerMeter: 1_600).count
      == samples.count
  )
  #expect(samples.map(\.materialVariation).min()! < -0.90)
  #expect(samples.map(\.materialVariation).max()! > 0.90)

  for sample in samples {
    #expect(
      abs(
        simd_distance(sample.rootOffset, sample.rootSurfaceOffset)
          - CrowThroatBridgeFeathers.shellClearanceMeters
      ) < 1e-6
    )
    #expect(sample.tipOffset.x < sample.rootOffset.x)
    #expect(sample.maximumWidthMeters > sample.rootWidthMeters)
    #expect(simd_distance(sample.rootOffset, sample.tipOffset) > sample.maximumWidthMeters)
    #expect(abs(simd_length(sample.planeNormal) - 1) < 1e-5)
    let rootNormal = simd_normalize(sample.rootOffset - sample.rootSurfaceOffset)
    #expect(simd_dot(rootNormal, sample.planeNormal) > 0.96)
  }

  for side: Float in [-1, 1] {
    for column in 0..<CrowThroatBridgeFeathers.columnCount {
      let course =
        samples
        .filter { $0.side == side && $0.column == column }
        .sorted { $0.row < $1.row }
      #expect(course.count == CrowThroatBridgeFeathers.rowCount)
      for pair in zip(course, course.dropFirst()) {
        #expect(
          simd_distance(pair.0.rootOffset, pair.1.rootOffset)
            < pair.0.maximumWidthMeters + pair.1.maximumWidthMeters
        )
      }
    }
  }

  let pectoral = CrowVentralFeatherTracts.samples().filter {
    $0.region == .pectoral
  }
  let nearestPectoralDistances = samples.map { bridge in
    pectoral.map { simd_distance($0.rootOffset, bridge.tipOffset) }.min()!
  }
  #expect(nearestPectoralDistances.max()! < 0.028)
}

@Test("throat bridge follows quiet neck motion with graded coupling")
func throatBridgeFollowsQuietNeckMotionWithGradedCoupling() {
  let pose = CrowStandingNeckPose(
    translation: SIMD3<Float>(0.0015, -0.0024, 0.0017),
    yawRadians: 0.018,
    pitchRadians: -0.014,
    rollRadians: 0.006
  )
  let reference = CrowThroatBridgeFeathers.samples()
  let moved = CrowThroatBridgeFeathers.samples(neckPose: pose)
  #expect(reference.count == moved.count)
  let pairs = Array(zip(reference, moved))
  #expect(
    pairs.allSatisfy {
      $0.0.row == $0.1.row && $0.0.column == $0.1.column
        && simd_distance($0.0.rootOffset, $0.1.rootOffset) > 0
        && simd_distance($0.0.rootOffset, $0.1.rootOffset) < 0.005
    }
  )
  let anterior = pairs.filter { $0.0.column == 0 }.map {
    simd_distance($0.0.rootOffset, $0.1.rootOffset)
  }
  let posterior = pairs.filter {
    $0.0.column == CrowThroatBridgeFeathers.columnCount - 1
  }.map {
    simd_distance($0.0.rootOffset, $0.1.rootOffset)
  }
  #expect(anterior.min()! > 1.5 * posterior.max()!)
}
