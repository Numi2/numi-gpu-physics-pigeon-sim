import Testing
import simd

@testable import BirdFlowVisualization

@Test("greater folded coverts bury every persistent remex root and proximal vane")
func greaterFoldedCovertsBuryPersistentRemexRootsAndProximalVanes() {
  let samples = CrowFoldedFlightCoverts.samples()
  #expect(samples == CrowFoldedFlightCoverts.samples())
  #expect(samples.count == 42)
  #expect(CrowFoldedFlightCoverts.visibleSamples(projectedPixelsPerMeter: 1_000).isEmpty)
  #expect(
    CrowFoldedFlightCoverts.visibleSamples(projectedPixelsPerMeter: 1_600).count
      == samples.count
  )
  #expect(samples.map(\.materialVariation).min()! < -0.85)
  #expect(samples.map(\.materialVariation).max()! > 0.85)

  for sample in samples {
    #expect(sample.featherClass == 1 || sample.featherClass == 2)
    #expect(sample.order >= 0 && sample.order < sample.count)
    #expect(sample.tipOffset.x < sample.rootOffset.x)
    #expect(sample.maximumWidthMeters > sample.rootWidthMeters)
    #expect(sample.maximumWidthMeters > 0.012 && sample.maximumWidthMeters < 0.020)
    #expect(abs(simd_length(sample.flightDirection) - 1) < 1e-6)
    #expect(abs(simd_length(sample.planeNormal) - 1) < 1e-6)
    let covertLength = simd_distance(sample.rootOffset, sample.tipOffset)
    #expect(covertLength > 0.045 && covertLength < 0.095)
    #expect(covertLength > 2.5 * sample.maximumWidthMeters)

    let proximal =
      sample.flightRootOffset
      + 0.22 * sample.flightLengthMeters * sample.flightDirection
    #expect(
      distance(
        from: sample.flightRootOffset,
        toSegmentFrom: sample.rootOffset,
        through: sample.tipOffset
      ) < sample.maximumWidthMeters
    )
    #expect(
      distance(
        from: proximal,
        toSegmentFrom: sample.rootOffset,
        through: sample.tipOffset
      ) < sample.maximumWidthMeters
    )
  }

  for side: Float in [-1, 1] {
    let posteriorPrimary = samples.first {
      $0.side == side
        && $0.featherClass == 1
        && $0.order == CrowFoldedFlightCoverts.primaryCount - 1
    }!
    let lateralTailRoot = CrowClosedTailAnatomy.pose(fraction: side < 0 ? 0 : 1)
      .rootOffset
    #expect(posteriorPrimary.tipOffset.x < lateralTailRoot.x - 0.012)
  }
}

@Test("greater folded covert identities mirror and overlap along each remex course")
func greaterFoldedCovertIdentitiesMirrorAndOverlapAlongRemexCourses() {
  let samples = CrowFoldedFlightCoverts.samples()
  let left = samples.filter { $0.side == 1 }
  let right = samples.filter { $0.side == -1 }
  #expect(left.count == right.count)
  for pair in zip(left, right) {
    #expect(pair.0.featherClass == pair.1.featherClass)
    #expect(pair.0.order == pair.1.order)
    #expect(pair.0.count == pair.1.count)
    #expect(abs(pair.0.rootOffset.x - pair.1.rootOffset.x) < 1e-7)
    #expect(abs(pair.0.rootOffset.y + pair.1.rootOffset.y) < 1e-7)
    #expect(abs(pair.0.rootOffset.z - pair.1.rootOffset.z) < 1e-7)
    #expect(abs(pair.0.tipOffset.x - pair.1.tipOffset.x) < 1e-7)
    #expect(abs(pair.0.tipOffset.y + pair.1.tipOffset.y) < 1e-7)
    #expect(abs(pair.0.tipOffset.z - pair.1.tipOffset.z) < 1e-7)
  }

  for side: Float in [-1, 1] {
    for featherClass: UInt32 in [1, 2] {
      let course =
        samples
        .filter { $0.side == side && $0.featherClass == featherClass }
        .sorted { $0.order < $1.order }
      for pair in zip(course, course.dropFirst()) {
        #expect(pair.0.rootOffset.x > pair.1.rootOffset.x)
        #expect(
          distance(
            from: pair.1.flightRootOffset,
            toSegmentFrom: pair.0.rootOffset,
            through: pair.0.tipOffset
          ) < pair.0.maximumWidthMeters + pair.1.maximumWidthMeters
        )
      }
    }
  }
}

private func distance(
  from point: SIMD3<Float>,
  toSegmentFrom start: SIMD3<Float>,
  through end: SIMD3<Float>
) -> Float {
  let segment = end - start
  let denominator = simd_length_squared(segment)
  let fraction =
    denominator > 1e-10
    ? min(max(simd_dot(point - start, segment) / denominator, 0), 1)
    : 0
  return simd_distance(point, start + fraction * segment)
}
