import Testing
import simd

@testable import BirdFlowVisualization

@Test("throat bridge breaks the cervical pectoral collar only at full resolution")
func throatBridgeBreaksCervicalPectoralCollarAtFullResolution() {
  let samples = CrowThroatBridgeFeathers.samples()
  let morphology = CrowThroatBridgeFeathers.morphologySamples()
  #expect(samples == CrowThroatBridgeFeathers.samples())
  #expect(morphology.count == samples.count)
  #expect(
    samples == morphology.map {
      CrowThroatBridgeFeathers.feather(morphology: $0, neckPose: nil)
    }
  )
  #expect(Set(morphology.map(\.neckCoupling)).count == 4)
  #expect(morphology.map(\.neckCoupling).min() == 0.34)
  #expect(morphology.map(\.neckCoupling).max() == 0.76)
  #expect(
    samples.count
      == 2 * CrowThroatBridgeFeathers.rowCount * CrowThroatBridgeFeathers.columnCount
  )
  #expect(samples.count == 88)
  #expect(CrowThroatBridgeFeathers.surfaceFeatherClass == 17)
  #expect(CrowThroatBridgeFeathers.rootWidthRatio > 0.80)
  #expect(CrowThroatBridgeFeathers.rootWidthRatio < 0.85)
  #expect(CrowThroatBridgeFeathers.visibleRootEnvelopeRatio == 0.70)
  #expect(CrowThroatBridgeFeathers.pennaceousStartFraction == 0)
  #expect(samples.allSatisfy { $0.surfaceFeatherClass == 17 })
  let courseStaggers = (0..<CrowThroatBridgeFeathers.rowCount).map {
    CrowThroatBridgeFeathers.courseStaggerMeters(row: $0)
  }
  #expect(courseStaggers.first == 0 && courseStaggers.last == 0)
  #expect(Set(courseStaggers).count == CrowThroatBridgeFeathers.rowCount - 1)
  #expect(abs(courseStaggers.min()! + 0.0022) < 1e-7)
  #expect(abs(courseStaggers.max()! - 0.00275) < 1e-7)
  #expect(
    zip(courseStaggers, courseStaggers.dropFirst()).allSatisfy {
      abs($0 - $1) > 0.0005
    }
  )
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
    let columnFraction = Float(sample.column)
      / Float(CrowThroatBridgeFeathers.columnCount - 1)
    let expectedRootX = 0.149 - 0.029 * columnFraction
      - CrowThroatBridgeFeathers.courseStaggerMeters(row: sample.row)
    #expect(abs(sample.rootSurfaceOffset.x - expectedRootX) < 1e-6)
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

  for row in 0..<CrowThroatBridgeFeathers.rowCount {
    for column in 0..<CrowThroatBridgeFeathers.columnCount {
      let left = samples.first {
        $0.side < 0 && $0.row == row && $0.column == column
      }!
      let right = samples.first {
        $0.side > 0 && $0.row == row && $0.column == column
      }!
      #expect(abs(left.rootOffset.x - right.rootOffset.x) < 1e-7)
      #expect(abs(left.rootOffset.y + right.rootOffset.y) < 1e-7)
      #expect(abs(left.rootOffset.z - right.rootOffset.z) < 1e-7)
      #expect(abs(left.tipOffset.x - right.tipOffset.x) < 1e-7)
      #expect(abs(left.tipOffset.y + right.tipOffset.y) < 1e-7)
      #expect(abs(left.tipOffset.z - right.tipOffset.z) < 1e-7)
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
