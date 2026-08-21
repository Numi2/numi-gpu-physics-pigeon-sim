import Testing

@testable import BirdFlowVisualization

@Test("live covert profiles cover every bilateral root with bounded identity variation")
func liveCovertProfilesCoverEveryBilateralRootWithBoundedIdentityVariation() {
  var profiles: [CrowCovertVaneProfile] = []
  for (featherClass, count) in [(UInt32(12), 81), (UInt32(13), 27)] {
    for order in 0..<count {
      let left = CrowCovertVaneAnatomy.profile(
        featherClass: featherClass,
        sideCode: 1,
        order: order,
        count: count
      )!
      let right = CrowCovertVaneAnatomy.profile(
        featherClass: featherClass,
        sideCode: 2,
        order: order,
        count: count
      )!
      profiles.append(contentsOf: [left, right])

      #expect(left.featherClass == right.featherClass)
      #expect(abs(left.spanFraction - right.spanFraction) < 1e-7)
      #expect(abs(left.courseFraction - right.courseFraction) < 1e-7)
      #expect(abs(left.exposedSignedWidth + right.exposedSignedWidth) < 1e-7)
      #expect(abs(left.vaneAsymmetry - right.vaneAsymmetry) < 1e-7)
      #expect(abs(left.camberSkew - right.camberSkew) < 1e-7)
      #expect(abs(left.crownRatio - right.crownRatio) < 1e-7)
      #expect(abs(left.rootWidthRatio - right.rootWidthRatio) < 1e-7)
      #expect(abs(left.edgeAmplitude - right.edgeAmplitude) < 1e-7)
      #expect(abs(left.edgePhase - right.edgePhase) < 1e-7)
      #expect(abs(left.firstEdgeCycles - right.firstEdgeCycles) < 1e-7)
      #expect(abs(left.secondEdgeCycles - right.secondEdgeCycles) < 1e-7)
    }
  }

  #expect(profiles.count == 216)
  #expect(profiles.filter { $0.featherClass == 12 }.count == 162)
  #expect(profiles.filter { $0.featherClass == 13 }.count == 54)
  #expect(Set(profiles.filter { $0.featherClass == 12 }.map(\.courseFraction)).count == 3)
  #expect(Set(profiles.filter { $0.featherClass == 13 }.map(\.courseFraction)) == [1])
  #expect(profiles.allSatisfy { (0...1).contains($0.spanFraction) })
  #expect(profiles.allSatisfy { (0.012...0.028).contains($0.vaneAsymmetry) })
  #expect(profiles.allSatisfy { (-0.045...0.025).contains($0.camberSkew) })
  #expect(profiles.allSatisfy { (0.037...0.056).contains($0.crownRatio) })
  #expect(profiles.allSatisfy { (0.585...0.620).contains($0.rootWidthRatio) })
  #expect(profiles.allSatisfy { (0.007...0.013).contains($0.edgeAmplitude) })
  #expect(CrowCovertVaneAnatomy.profile(featherClass: 1, sideCode: 1, order: 0, count: 10) == nil)
}

@Test("covert edge structure is bounded, mirrored, and analytically differentiable")
func covertEdgeStructureIsBoundedMirroredAndAnalyticallyDifferentiable() {
  var minimumModulation: Float = 1
  var maximumModulation: Float = 1
  for (featherClass, count) in [(UInt32(12), 81), (UInt32(13), 27)] {
    for order in 0..<count {
      let left = CrowCovertVaneAnatomy.profile(
        featherClass: featherClass,
        sideCode: 1,
        order: order,
        count: count
      )!
      let right = CrowCovertVaneAnatomy.profile(
        featherClass: featherClass,
        sideCode: 2,
        order: order,
        count: count
      )!
      for signedWidth: Float in [-1, -0.5, 0.5, 1] {
        #expect(
          abs(CrowCovertVaneAnatomy.edgeModulation(
            axial: 0,
            signedWidth: signedWidth,
            profile: left
          ) - 1) < 1e-7
        )
        #expect(
          abs(CrowCovertVaneAnatomy.edgeModulation(
            axial: 1,
            signedWidth: signedWidth,
            profile: left
          ) - 1) < 1e-6
        )

        for axial: Float in stride(from: 0.04, through: 0.96, by: 0.04) {
          let modulation = CrowCovertVaneAnatomy.edgeModulation(
            axial: axial,
            signedWidth: signedWidth,
            profile: left
          )
          minimumModulation = min(minimumModulation, modulation)
          maximumModulation = max(maximumModulation, modulation)
          #expect(modulation > 0.985 && modulation < 1.015)
          let mirrored = CrowCovertVaneAnatomy.edgeModulation(
            axial: axial,
            signedWidth: -signedWidth,
            profile: right
          )
          #expect(abs(modulation - mirrored) < 1e-6)

          let epsilon: Float = 1e-4
          let axialFiniteDifference =
            (CrowCovertVaneAnatomy.edgeModulation(
              axial: axial + epsilon,
              signedWidth: signedWidth,
              profile: left
            ) - CrowCovertVaneAnatomy.edgeModulation(
              axial: axial - epsilon,
              signedWidth: signedWidth,
              profile: left
            )) / (2 * epsilon)
          let axialAnalytic = CrowCovertVaneAnatomy.edgeModulationAxialDerivative(
            axial: axial,
            signedWidth: signedWidth,
            profile: left
          )
          #expect(abs(axialFiniteDifference - axialAnalytic) < 0.003)

          let widthFiniteDifference =
            (CrowCovertVaneAnatomy.edgeModulation(
              axial: axial,
              signedWidth: signedWidth + epsilon,
              profile: left
            ) - CrowCovertVaneAnatomy.edgeModulation(
              axial: axial,
              signedWidth: signedWidth - epsilon,
              profile: left
            )) / (2 * epsilon)
          let widthAnalytic = CrowCovertVaneAnatomy.edgeModulationSignedWidthDerivative(
            axial: axial,
            signedWidth: signedWidth,
            profile: left
          )
          #expect(abs(widthFiniteDifference - widthAnalytic) < 0.001)
        }
      }
    }
  }
  #expect(maximumModulation - minimumModulation > 0.016)
}
