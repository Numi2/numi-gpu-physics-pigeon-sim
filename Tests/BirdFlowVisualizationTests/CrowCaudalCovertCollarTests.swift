import Testing
import simd

@testable import BirdFlowVisualization

@Test("caudal covert ranks roof-tile over the smooth posterior loft cap")
func caudalCovertCollarCoversPosteriorLoftCap() {
  let samples = CrowCaudalCovertCollar.samples()
  #expect(samples == CrowCaudalCovertCollar.samples())
  #expect(samples.count == CrowCaudalCovertCollar.sampleCount)
  #expect(
    Dictionary(grouping: samples, by: \.rank).mapValues(\.count)
      == Dictionary(
        uniqueKeysWithValues: CrowCaudalCovertCollar.rankCounts.enumerated().map {
          ($0.offset, $0.element)
        }
      )
  )
  #expect(
    CrowCaudalCovertCollar.visibleSamples(projectedPixelsPerMeter: 1_000).isEmpty
  )
  #expect(
    CrowCaudalCovertCollar.visibleSamples(projectedPixelsPerMeter: 1_600).count
      == samples.count
  )
  #expect(Set(samples.map(\.surfaceFeatherClass)) == Set([5, 7]))
  #expect(samples.map(\.materialVariation).min()! < -0.85)
  #expect(samples.map(\.materialVariation).max()! > 0.85)

  for sample in samples {
    #expect(
      abs(
        simd_distance(sample.rootOffset, sample.rootSurfaceOffset)
          - CrowCaudalCovertCollar.shellClearanceMeters
      ) < 1e-6
    )
    #expect(sample.rootOffset.x > CrowCaudalCovertCollar.capX)
    #expect(sample.tipOffset.x < CrowCaudalCovertCollar.capX)
    #expect(sample.maximumWidthMeters > sample.rootWidthMeters)
    #expect(simd_distance(sample.rootOffset, sample.tipOffset) > 2.5 * sample.maximumWidthMeters)
    #expect(abs(simd_length(sample.planeNormal) - 1) < 1e-5)
    #expect(simd_dot(sample.planeNormal, SIMD3<Float>(-1, 0, 0)) > 0.85)
  }

  for rank in CrowCaudalCovertCollar.rankCounts.indices {
    let ranked = samples.filter { $0.rank == rank }
    #expect(ranked.map(\.row) == Array(0..<ranked.count))
    for row in ranked.indices {
      let next = (row + 1) % ranked.count
      #expect(
        simd_distance(ranked[row].rootSurfaceOffset, ranked[next].rootSurfaceOffset)
          < ranked[row].maximumWidthMeters + ranked[next].maximumWidthMeters
      )
    }
  }

  let meanRootRadiusByRank = CrowCaudalCovertCollar.rankCounts.indices.map { rank in
    let ranked = samples.filter { $0.rank == rank }
    return ranked.map { hypot($0.rootOffset.y, $0.rootOffset.z) }.reduce(0, +)
      / Float(ranked.count)
  }
  let meanTipRadiusByRank = CrowCaudalCovertCollar.rankCounts.indices.map { rank in
    let ranked = samples.filter { $0.rank == rank }
    return ranked.map { hypot($0.tipOffset.y, $0.tipOffset.z) }.reduce(0, +)
      / Float(ranked.count)
  }
  #expect(meanRootRadiusByRank[0] > meanRootRadiusByRank[1])
  #expect(meanRootRadiusByRank[1] > meanRootRadiusByRank[2])
  #expect(meanTipRadiusByRank[0] > meanTipRadiusByRank[1])
  #expect(meanTipRadiusByRank[1] > meanTipRadiusByRank[2])
  #expect(meanTipRadiusByRank[2] < 0.001)
}

@Test("caudal coverts resolve shafts and barbs with output coverage")
func caudalCovertCollarResolvesMesostructure() {
  for sample in CrowCaudalCovertCollar.samples() {
    #expect(
      CrowFeatherMesostructure.segments(
        for: sample,
        projectedPixelsPerMeter: 600
      ).isEmpty
    )
    let resolved = CrowFeatherMesostructure.segments(
      for: sample,
      projectedPixelsPerMeter: 1_600
    )
    #expect(resolved.filter { $0.kind == .rachis }.count == 4)
    #expect(resolved.filter { $0.kind == .edgeBarbGroup }.count == 25)
    #expect(resolved.allSatisfy { simd_distance($0.start, $0.end) > 0 })

    let future = CrowFeatherMesostructure.segments(
      for: sample,
      projectedPixelsPerMeter: 14_000
    )
    #expect(future.contains { $0.kind == .barb })
    #expect(future.count > resolved.count)
  }
}
