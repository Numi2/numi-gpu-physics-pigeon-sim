import Testing
import simd

@testable import BirdFlowVisualization

@Test("closed rectrices overlap in a medial-to-lateral tent")
func closedRectricesOverlapInMedialToLateralTent() {
  let poses = (0..<CrowClosedTailAnatomy.rectrixCount).map {
    CrowClosedTailAnatomy.pose(
      fraction: Float($0) / Float(CrowClosedTailAnatomy.rectrixCount - 1)
    )
  }
  #expect(poses.count == 12)
  #expect(abs(poses.first!.rootOffset.y + 0.006) < 1e-7)
  #expect(abs(poses.last!.rootOffset.y - 0.006) < 1e-7)
  #expect(abs(poses.first!.tipOffset.y + 0.006) < 1e-7)
  #expect(abs(poses.last!.tipOffset.y - 0.006) < 1e-7)

  let rightFromMedial = Array(poses[0...5].reversed())
  let leftFromMedial = Array(poses[6...11])
  for side in [rightFromMedial, leftFromMedial] {
    for pair in zip(side, side.dropFirst()) {
      #expect(pair.0.radialFraction < pair.1.radialFraction)
      #expect(pair.0.rootOffset.z > pair.1.rootOffset.z)
      #expect(pair.0.tipOffset.z > pair.1.tipOffset.z)
    }
  }

  #expect(
    poses.allSatisfy {
      abs(simd_length($0.direction) - 1) < 1e-6
        && abs(simd_length($0.normal) - 1) < 1e-6
        && abs(
          simd_distance($0.rootOffset, $0.tipOffset)
            - CrowClosedTailAnatomy.lengthMeters(
              radialFraction: $0.radialFraction
            )
        ) < 1e-6
    }
  )
  #expect(
    abs(
      simd_distance(poses[5].rootOffset, poses[5].tipOffset)
        - CrowClosedTailAnatomy.rectrixLengthMeters
    ) < 0.0003
  )
  #expect(
    abs(
      simd_distance(poses[0].rootOffset, poses[0].tipOffset)
        - (CrowClosedTailAnatomy.rectrixLengthMeters
          - CrowClosedTailAnatomy.lateralRectrixLengthReductionMeters)
    ) < 1e-6
  )
  #expect(poses[5].normal.y < 0)
  #expect(poses[6].normal.y > 0)
  #expect(abs(poses[5].normal.y + poses[6].normal.y) < 1e-6)
  #expect(poses.map { abs($0.normal.y) }.min()! > 0.05)
  #expect(poses.map { abs($0.normal.y) }.max()! < 0.16)

  let tipDepths = poses.map(\.tipOffset.z)
  let rootDepths = poses.map(\.rootOffset.z)
  let sampledRadialSpan = poses.map(\.radialFraction).max()!
    - poses.map(\.radialFraction).min()!
  let tipDepthSpan = tipDepths.max()! - tipDepths.min()!
  let rootDepthSpan = rootDepths.max()! - rootDepths.min()!
  #expect(
    abs(
      tipDepthSpan
        - CrowClosedTailAnatomy.tipLayerDepthMeters * sampledRadialSpan
    ) < 1e-7
  )
  #expect(
    abs(
      rootDepthSpan
        - CrowClosedTailAnatomy.rootLayerDepthMeters * sampledRadialSpan
    ) < 1e-7
  )
  #expect(rootDepthSpan > tipDepthSpan)
}

@Test("rectrix pairs retain identity-specific asymmetric vane profiles")
func rectrixPairsRetainIdentitySpecificAsymmetricVaneProfiles() {
  let count = CrowClosedTailAnatomy.rectrixCount
  let profiles = (0..<count).map {
    CrowRectrixVaneAnatomy.profile(order: $0, count: count)
  }
  let widths = profiles.map { 0.019 * $0.maximumWidthScale }
  let cambers = profiles.map {
    CrowClosedTailAnatomy.rectrixLengthMeters * $0.camberLengthScale
  }

  #expect(Set(widths).count == 6)
  #expect(Set(cambers).count == 6)
  #expect(widths.max()! - widths.min()! > 0.0009)
  #expect(widths.max()! - widths.min()! < 0.0011)
  #expect(cambers.max()! - cambers.min()! > 0.0009)
  #expect(cambers.max()! - cambers.min()! < 0.0012)

  for pairIndex in 0..<(count / 2) {
    let right = profiles[pairIndex]
    let left = profiles[count - 1 - pairIndex]
    #expect(abs(right.radialFraction - left.radialFraction) < 1e-7)
    #expect(abs(right.maximumWidthScale - left.maximumWidthScale) < 1e-7)
    #expect(abs(right.camberLengthScale - left.camberLengthScale) < 1e-7)
    #expect(abs(right.vaneAsymmetry - left.vaneAsymmetry) < 1e-7)
    #expect(abs(right.outerSignedWidth + left.outerSignedWidth) < 1e-7)

    let maximumWidth = widths[pairIndex]
    let outer = CrowRectrixVaneAnatomy.halfWidthMeters(
      maximumWidthMeters: maximumWidth,
      axial: 0.55,
      signedWidth: right.outerSignedWidth,
      profile: right
    )
    let inner = CrowRectrixVaneAnatomy.halfWidthMeters(
      maximumWidthMeters: maximumWidth,
      axial: 0.55,
      signedWidth: -right.outerSignedWidth,
      profile: right
    )
    #expect(inner > outer)
    #expect((inner - outer) / maximumWidth > 0.03)
    #expect((inner - outer) / maximumWidth < 0.14)
  }

  for profile in profiles {
    #expect(abs(CrowRectrixVaneAnatomy.camberEnvelope(axial: 0, profile: profile)) < 1e-7)
    #expect(abs(CrowRectrixVaneAnatomy.camberEnvelope(axial: 1, profile: profile)) < 1e-6)
    #expect(CrowRectrixVaneAnatomy.camberEnvelope(axial: 0.5, profile: profile) > 0.99)
  }
}

@Test("rectrix terminals retain narrow rounded vanes without shortening the rachis")
func rectrixTerminalsRetainNarrowRoundedVanesWithoutShorteningRachis() {
  let count = CrowClosedTailAnatomy.rectrixCount
  for order in 0..<count {
    let profile = CrowRectrixVaneAnatomy.profile(order: order, count: count)
    let counterpart = CrowRectrixVaneAnatomy.profile(
      order: count - 1 - order,
      count: count
    )
    let terminalEnvelope = CrowRectrixVaneAnatomy.terminalWidthEnvelope(
      axial: 1,
      profile: profile
    )
    #expect(terminalEnvelope >= 0.13 && terminalEnvelope <= 0.215)
    #expect(
      abs(
        terminalEnvelope
          - CrowRectrixVaneAnatomy.terminalWidthEnvelope(
            axial: 1,
            profile: counterpart
          )
      ) < 2e-7
    )
    #expect(
      abs(
        CrowRectrixVaneAnatomy.terminalRoundbackFraction(
          axial: 1,
          signedWidth: 0,
          profile: profile
        )
      ) < 1e-7
    )
    let edgeRoundback = CrowRectrixVaneAnatomy.terminalRoundbackFraction(
      axial: 1,
      signedWidth: 1,
      profile: profile
    )
    #expect(edgeRoundback >= 0.010 && edgeRoundback <= 0.0141)
    #expect(
      abs(
        edgeRoundback
          - CrowRectrixVaneAnatomy.terminalRoundbackFraction(
            axial: 1,
            signedWidth: -1,
            profile: profile
          )
      ) < 1e-7
    )
    #expect(
      CrowRectrixVaneAnatomy.terminalRoundbackFraction(
        axial: CrowRectrixVaneAnatomy.terminalShapeStartAxialFraction,
        signedWidth: 1,
        profile: profile
      ) == 0
    )

    let maximumWidth = 0.019 * profile.maximumWidthScale
    let terminalHalfWidth = CrowRectrixVaneAnatomy.halfWidthMeters(
      maximumWidthMeters: maximumWidth,
      axial: 1,
      signedWidth: 1,
      profile: profile
    )
    #expect(terminalHalfWidth > 0.0022 && terminalHalfWidth < 0.0043)
  }
}

@Test("rectrix terminal handoff is bilateral and limited to sublateral pairs")
func rectrixTerminalHandoffIsBilateralAndLimitedToSublateralPairs() {
  let count = CrowClosedTailAnatomy.rectrixCount
  let widenedOrders = Set([1, 2, 3, 8, 9, 10])
  for order in 0..<count {
    let profile = CrowRectrixVaneAnatomy.profile(order: order, count: count)
    let counterpart = CrowRectrixVaneAnatomy.profile(
      order: count - 1 - order,
      count: count
    )
    let weight = CrowRectrixVaneAnatomy.sublateralTerminalHandoffWeight(
      profile: profile
    )
    #expect(
      abs(
        weight
          - CrowRectrixVaneAnatomy.sublateralTerminalHandoffWeight(
            profile: counterpart
          )
      ) < 2e-7
    )
    if widenedOrders.contains(order) {
      #expect(weight > 0.99)
    } else {
      #expect(weight < 1e-6)
    }
  }
}

@Test("rectrix edge microstructure is paired, bounded, and analytically differentiable")
func rectrixEdgeMicrostructureIsPairedBoundedAndDifferentiable() {
  let count = CrowClosedTailAnatomy.rectrixCount
  var modulationRange: ClosedRange<Float> = 1...1
  for order in 0..<count {
    let profile = CrowRectrixVaneAnatomy.profile(order: order, count: count)
    let counterpart = CrowRectrixVaneAnatomy.profile(
      order: count - 1 - order,
      count: count
    )
    for signedWidth: Float in [-1, -0.5, 0.5, 1] {
      #expect(
        abs(
          CrowRectrixVaneAnatomy.edgeModulation(
            axial: 0,
            signedWidth: signedWidth,
            profile: profile
          ) - 1
        ) < 1e-7
      )
      #expect(
        abs(
          CrowRectrixVaneAnatomy.edgeModulation(
            axial: 1,
            signedWidth: signedWidth,
            profile: profile
          ) - 1
        ) < 1e-6
      )
      for axial: Float in stride(from: 0.04, through: 0.96, by: 0.02) {
        let modulation = CrowRectrixVaneAnatomy.edgeModulation(
          axial: axial,
          signedWidth: signedWidth,
          profile: profile
        )
        modulationRange = ClosedRange(
          uncheckedBounds: (
            min(modulationRange.lowerBound, modulation),
            max(modulationRange.upperBound, modulation)
          )
        )
        #expect(modulation > 0.965 && modulation < 1.035)
        let mirrored = CrowRectrixVaneAnatomy.edgeModulation(
          axial: axial,
          signedWidth: -signedWidth,
          profile: counterpart
        )
        #expect(abs(modulation - mirrored) < 1e-6)

        let epsilon: Float = 1e-4
        let finiteDifference =
          (CrowRectrixVaneAnatomy.edgeModulation(
            axial: axial + epsilon,
            signedWidth: signedWidth,
            profile: profile
          )
            - CrowRectrixVaneAnatomy.edgeModulation(
              axial: axial - epsilon,
              signedWidth: signedWidth,
              profile: profile
            )) / (2 * epsilon)
        let analytic = CrowRectrixVaneAnatomy.edgeModulationAxialDerivative(
          axial: axial,
          signedWidth: signedWidth,
          profile: profile
        )
        #expect(abs(finiteDifference - analytic) < 0.003)
      }
    }
  }
  #expect(modulationRange.upperBound - modulationRange.lowerBound > 0.035)
}

@Test("identity-specific rectrix vanes preserve the closed-tail envelope")
func identitySpecificRectrixVanesPreserveClosedTailEnvelope() {
  let count = CrowClosedTailAnatomy.rectrixCount
  let poses = (0..<count).map {
    CrowClosedTailAnatomy.pose(fraction: Float($0) / Float(count - 1))
  }

  for axial: Float in [0.20, 0.45, 0.70, 0.88] {
    let intervals = poses.enumerated().map { order, pose -> ClosedRange<Float> in
      let profile = CrowRectrixVaneAnatomy.profile(order: order, count: count)
      let maximumWidth = 0.019 * profile.maximumWidthScale
      let camber = CrowClosedTailAnatomy.rectrixLengthMeters * profile.camberLengthScale
      let orthogonalNormal = simd_normalize(
        pose.normal - pose.direction * simd_dot(pose.normal, pose.direction)
      )
      let widthAxis = simd_normalize(simd_cross(orthogonalNormal, pose.direction))
      let center =
        pose.rootOffset
        + pose.direction * (CrowClosedTailAnatomy.rectrixLengthMeters * axial)
        + orthogonalNormal
        * (camber
          * CrowRectrixVaneAnatomy.camberEnvelope(axial: axial, profile: profile))
      let negative =
        center
        - widthAxis
        * CrowRectrixVaneAnatomy.halfWidthMeters(
          maximumWidthMeters: maximumWidth,
          axial: axial,
          signedWidth: -1,
          profile: profile
        )
      let positive =
        center
        + widthAxis
        * CrowRectrixVaneAnatomy.halfWidthMeters(
          maximumWidthMeters: maximumWidth,
          axial: axial,
          signedWidth: 1,
          profile: profile
        )
      return min(negative.y, positive.y)...max(negative.y, positive.y)
    }
    for pair in zip(intervals, intervals.dropFirst()) {
      let overlap =
        min(pair.0.upperBound, pair.1.upperBound)
        - max(pair.0.lowerBound, pair.1.lowerBound)
      #expect(overlap > 0.001)
    }
  }
}
