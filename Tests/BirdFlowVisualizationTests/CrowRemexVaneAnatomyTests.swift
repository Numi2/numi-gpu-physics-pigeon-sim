import BirdFlowMetal
import Testing

@testable import BirdFlowVisualization

@Test("primary and secondary vane profiles are class-specific bilateral mirrors")
func primaryAndSecondaryVaneProfilesAreClassSpecificBilateralMirrors() {
  let primaryProfiles = (0..<10).map {
    CrowRemexVaneAnatomy.profile(
      featherClass: 1,
      sideCode: 1,
      order: $0,
      count: 10
    )!
  }
  let secondaryProfiles = (0..<11).map {
    CrowRemexVaneAnatomy.profile(
      featherClass: 2,
      sideCode: 1,
      order: $0,
      count: 11
    )!
  }
  #expect(primaryProfiles.last!.vaneAsymmetry > 2 * secondaryProfiles.last!.vaneAsymmetry)
  #expect(primaryProfiles.first!.camberLengthScale < secondaryProfiles.first!.camberLengthScale)
  #expect(primaryProfiles.last!.crownRatio < secondaryProfiles.last!.crownRatio)
  #expect(primaryProfiles.first!.maximumWidthScale > primaryProfiles.last!.maximumWidthScale)
  #expect(secondaryProfiles.first!.maximumWidthScale > secondaryProfiles.last!.maximumWidthScale)

  for (featherClass, count) in [(UInt32(1), 10), (UInt32(2), 11)] {
    for order in 0..<count {
      let left = CrowRemexVaneAnatomy.profile(
        featherClass: featherClass,
        sideCode: 1,
        order: order,
        count: count
      )!
      let right = CrowRemexVaneAnatomy.profile(
        featherClass: featherClass,
        sideCode: 2,
        order: order,
        count: count
      )!
      #expect(left.featherClass == right.featherClass)
      #expect(abs(left.seriesFraction - right.seriesFraction) < 1e-7)
      #expect(abs(left.dorsalSignedWidth + right.dorsalSignedWidth) < 1e-7)
      #expect(abs(left.maximumWidthScale - right.maximumWidthScale) < 1e-7)
      #expect(abs(left.camberLengthScale - right.camberLengthScale) < 1e-7)
      #expect(abs(left.vaneAsymmetry - right.vaneAsymmetry) < 1e-7)
      #expect(abs(left.camberSkew - right.camberSkew) < 1e-7)
      #expect(abs(left.crownRatio - right.crownRatio) < 1e-7)
    }
  }

  let firstPrimaryWidth = CrowRectrixVaneAnatomy.maximumWidthMeters(
    assetWidthMeters: 0.020,
    featherClass: .primary,
    order: 0,
    count: 10
  )
  let lastPrimaryWidth = CrowRectrixVaneAnatomy.maximumWidthMeters(
    assetWidthMeters: 0.015,
    featherClass: .primary,
    order: 9,
    count: 10
  )
  #expect(firstPrimaryWidth > 0.020)
  #expect(abs(lastPrimaryWidth - 0.023_76) < 1e-6)
  #expect(
    CrowRemexVaneAnatomy.posteriorPrimaryOverlapMaximumWidthScale == 1.60
  )
  let posteriorPrimaryOverlapScales = (0..<10).map {
    CrowRemexVaneAnatomy.posteriorPrimaryOverlapWidthScale(
      featherClass: .primary,
      order: $0,
      count: 10
    )
  }
  #expect(posteriorPrimaryOverlapScales[7] == 1)
  #expect(abs(posteriorPrimaryOverlapScales[8] - 1.266_666_7) < 1e-6)
  #expect(abs(posteriorPrimaryOverlapScales[9] - 1.60) < 1e-6)
  #expect(
    CrowRemexVaneAnatomy.posteriorPrimaryOverlapWidthScale(
      featherClass: .secondary,
      order: 10,
      count: 11
    ) == 1
  )
  #expect(
    CrowRemexVaneAnatomy.posteriorSecondaryOverlapMaximumWidthScale == 1.35
  )
  let posteriorSecondaryOverlapScales = (0..<11).map {
    CrowRemexVaneAnatomy.posteriorSecondaryOverlapWidthScale(
      featherClass: .secondary,
      order: $0,
      count: 11
    )
  }
  #expect(posteriorSecondaryOverlapScales[8] == 1)
  #expect(abs(posteriorSecondaryOverlapScales[9] - 1.175) < 1e-6)
  #expect(posteriorSecondaryOverlapScales[10] == 1.35)
  #expect(
    CrowRemexVaneAnatomy.posteriorSecondaryOverlapWidthScale(
      featherClass: .primary,
      order: 9,
      count: 10
    ) == 1
  )
  let lastSecondaryWidth = CrowRectrixVaneAnatomy.maximumWidthMeters(
    assetWidthMeters: 0.020,
    featherClass: .secondary,
    order: 10,
    count: 11
  )
  #expect(abs(lastSecondaryWidth - 0.027_081) < 1e-6)
  let firstPrimaryCamber = CrowRectrixVaneAnatomy.camberMeters(
    lengthMeters: 0.155,
    featherClass: .primary,
    order: 0,
    count: 10
  )
  let firstSecondaryCamber = CrowRectrixVaneAnatomy.camberMeters(
    lengthMeters: 0.155,
    featherClass: .secondary,
    order: 0,
    count: 11
  )
  #expect(firstSecondaryCamber > firstPrimaryCamber)
}

@Test("remex edge structure is bounded, mirrored, and analytically differentiable")
func remexEdgeStructureIsBoundedMirroredAndAnalyticallyDifferentiable() {
  var minimumModulation: Float = 1
  var maximumModulation: Float = 1
  for (featherClass, count) in [(UInt32(1), 10), (UInt32(2), 11)] {
    for order in 0..<count {
      let left = CrowRemexVaneAnatomy.profile(
        featherClass: featherClass,
        sideCode: 1,
        order: order,
        count: count
      )!
      let right = CrowRemexVaneAnatomy.profile(
        featherClass: featherClass,
        sideCode: 2,
        order: order,
        count: count
      )!
      for signedWidth: Float in [-1, -0.5, 0.5, 1] {
        #expect(
          abs(
            CrowRemexVaneAnatomy.edgeModulation(
              axial: 0,
              signedWidth: signedWidth,
              profile: left
            ) - 1
          ) < 1e-7
        )
        #expect(
          abs(
            CrowRemexVaneAnatomy.edgeModulation(
              axial: 1,
              signedWidth: signedWidth,
              profile: left
            ) - 1
          ) < 1e-6
        )
        for axial: Float in stride(from: 0.04, through: 0.96, by: 0.04) {
          let modulation = CrowRemexVaneAnatomy.edgeModulation(
            axial: axial,
            signedWidth: signedWidth,
            profile: left
          )
          minimumModulation = min(minimumModulation, modulation)
          maximumModulation = max(maximumModulation, modulation)
          #expect(modulation > 0.972 && modulation < 1.028)
          let mirrored = CrowRemexVaneAnatomy.edgeModulation(
            axial: axial,
            signedWidth: -signedWidth,
            profile: right
          )
          #expect(abs(modulation - mirrored) < 1e-6)

          let epsilon: Float = 1e-4
          let axialFiniteDifference =
            (CrowRemexVaneAnatomy.edgeModulation(
              axial: axial + epsilon,
              signedWidth: signedWidth,
              profile: left
            )
              - CrowRemexVaneAnatomy.edgeModulation(
                axial: axial - epsilon,
                signedWidth: signedWidth,
                profile: left
              )) / (2 * epsilon)
          let axialAnalytic = CrowRemexVaneAnatomy.edgeModulationAxialDerivative(
            axial: axial,
            signedWidth: signedWidth,
            profile: left
          )
          #expect(abs(axialFiniteDifference - axialAnalytic) < 0.003)

          let widthFiniteDifference =
            (CrowRemexVaneAnatomy.edgeModulation(
              axial: axial,
              signedWidth: signedWidth + epsilon,
              profile: left
            )
              - CrowRemexVaneAnatomy.edgeModulation(
                axial: axial,
                signedWidth: signedWidth - epsilon,
                profile: left
              )) / (2 * epsilon)
          let widthAnalytic =
            CrowRemexVaneAnatomy.edgeModulationSignedWidthDerivative(
              axial: axial,
              signedWidth: signedWidth,
              profile: left
            )
          #expect(abs(widthFiniteDifference - widthAnalytic) < 0.001)
        }
      }
    }
  }
  #expect(maximumModulation - minimumModulation > 0.025)
}
