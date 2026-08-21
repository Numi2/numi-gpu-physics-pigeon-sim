import Testing

@testable import BirdFlowVisualization

@Test("trailing covert ranks overlap without weakening the accepted envelope")
func trailingCovertRanksOverlapWithoutWeakeningEnvelope() {
  #expect(CrowTrailingCovertRanks.proximalSurfaceFeatherClass == 14)
  #expect(CrowTrailingCovertRanks.distalSurfaceFeatherClass == 15)
  #expect(CrowTrailingCovertRanks.proximalRange == .init(start: 0, end: 0.72))
  #expect(CrowTrailingCovertRanks.distalRange == .init(start: 0.34, end: 1))
  #expect(CrowTrailingCovertRanks.visibleRankWidthScale == 0.98)
  for step in 0...1_000 {
    let fraction = Float(step) / 1_000
    let proximal = CrowTrailingCovertRanks.coverageWeight(
      rank: .proximal,
      axialFraction: fraction
    )
    let distal = CrowTrailingCovertRanks.coverageWeight(
      rank: .distal,
      axialFraction: fraction
    )
    #expect(proximal >= 0 && proximal <= 1)
    #expect(distal >= 0 && distal <= 1)
    #expect(max(proximal, distal) == 1)
    let offset = CrowTrailingCovertRanks.normalOffsetMeters(
      rank: .distal,
      axialFraction: fraction
    )
    #expect(offset >= CrowTrailingCovertRanks.rankSurfaceClearanceMeters)
    #expect(
      offset
        <= CrowTrailingCovertRanks.rankSurfaceClearanceMeters
        + CrowTrailingCovertRanks.maximumLayerSeparationMeters
    )
    if fraction >= CrowTrailingCovertRanks.proximalRange.end {
      #expect(offset == CrowTrailingCovertRanks.rankSurfaceClearanceMeters)
    }
  }
  #expect(
    CrowTrailingCovertRanks.normalOffsetMeters(
      rank: .proximal,
      axialFraction: 0.5
    ) == CrowTrailingCovertRanks.rankSurfaceClearanceMeters
  )
  #expect(CrowTrailingCovertRanks.deploymentWeight(transitionProgress: 0) == 0)
  #expect(
    CrowTrailingCovertRanks.deploymentWeight(transitionProgress: 0.25) == 0
  )
  #expect(
    CrowTrailingCovertRanks.deploymentWeight(transitionProgress: 0.85) == 1
  )
  #expect(CrowTrailingCovertRanks.deploymentWeight(transitionProgress: 1) == 1)
  #expect(
    abs(
      CrowTrailingCovertRanks.deploymentWeight(transitionProgress: 0.55)
        - 0.5
    ) < 0.0001
  )
}

@Test("trailing covert retained templates map local coordinates to rank intervals")
func trailingCovertRetainedTemplateIntervals() {
  for rank in CrowTrailingCovertRanks.Rank.allCases {
    let range = CrowTrailingCovertRanks.range(for: rank)
    let featherClass =
      rank == .proximal
      ? CrowTrailingCovertRanks.proximalSurfaceFeatherClass
      : CrowTrailingCovertRanks.distalSurfaceFeatherClass
    #expect(
      CrowCovertVaneAnatomy.geometryAxialFraction(
        localAxialFraction: 0,
        featherClass: featherClass
      ) == range.start
    )
    #expect(
      CrowCovertVaneAnatomy.geometryAxialFraction(
        localAxialFraction: 1,
        featherClass: featherClass
      ) == range.end
    )
    for local: Float in stride(from: 0, through: 1, by: 0.025) {
      let global = CrowTrailingCovertRanks.globalAxialFraction(
        rank: rank,
        localAxialFraction: local
      )
      #expect((range.start...range.end).contains(global))
      #expect(
        CrowCovertVaneAnatomy.rankCoverageScale(
          localAxialFraction: local,
          featherClass: featherClass
        )
          == CrowTrailingCovertRanks.coverageWeight(
            rank: rank,
            axialFraction: global
          )
      )
    }
  }
}
