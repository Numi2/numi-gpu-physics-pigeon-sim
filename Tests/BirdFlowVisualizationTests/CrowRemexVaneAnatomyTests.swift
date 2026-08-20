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
  #expect(abs(lastPrimaryWidth - 0.026_73) < 1e-6)
  #expect(
    CrowRemexVaneAnatomy.posteriorPrimaryOverlapMaximumWidthScale == 1.80
  )
  let posteriorPrimaryOverlapScales = (0..<10).map {
    CrowRemexVaneAnatomy.posteriorPrimaryOverlapWidthScale(
      featherClass: .primary,
      order: $0,
      count: 10
    )
  }
  #expect(posteriorPrimaryOverlapScales[7] == 1)
  #expect(abs(posteriorPrimaryOverlapScales[8] - 1.355_555_6) < 1e-6)
  #expect(abs(posteriorPrimaryOverlapScales[9] - 1.80) < 1e-6)
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

@Test("terminal primary broad-edge overlap is local, mirrored, and differentiable")
func terminalPrimaryBroadEdgeOverlapIsLocalMirroredAndDifferentiable() {
  let leftIdentity = UInt32(1) | (UInt32(1) << 8) | (UInt32(9) << 16)
    | (UInt32(10) << 24)
  let rightIdentity = UInt32(1) | (UInt32(2) << 8) | (UInt32(9) << 16)
    | (UInt32(10) << 24)
  let penultimateIdentity = UInt32(1) | (UInt32(1) << 8) | (UInt32(8) << 16)
    | (UInt32(10) << 24)
  let secondaryIdentity = UInt32(2) | (UInt32(1) << 8) | (UInt32(10) << 16)
    | (UInt32(11) << 24)

  #expect(CrowRemexVaneAnatomy.terminalPrimaryBroadEdgeMaximumScale == 1.12)
  for axial: Float in [0, 0.39, 0.73, 1] {
    let terms = CrowRemexVaneAnatomy.terminalPrimaryBroadEdgeTerms(
      axial: axial,
      signedWidth: -1,
      packedIdentity: leftIdentity
    )
    #expect(terms.scale == 1)
    #expect(terms.axialDerivative == 0)
  }
  #expect(
    abs(
      CrowRemexVaneAnatomy.terminalPrimaryBroadEdgeTerms(
        axial: 0.56,
        signedWidth: -1,
        packedIdentity: leftIdentity
      ).scale - 1.12
    ) < 1e-6
  )
  #expect(
    CrowRemexVaneAnatomy.terminalPrimaryBroadEdgeTerms(
      axial: 0.56,
      signedWidth: 1,
      packedIdentity: leftIdentity
    ).scale == 1
  )
  #expect(
    CrowRemexVaneAnatomy.terminalPrimaryBroadEdgeTerms(
      axial: 0.56,
      signedWidth: -1,
      packedIdentity: penultimateIdentity
    ).scale == 1
  )
  #expect(
    CrowRemexVaneAnatomy.terminalPrimaryBroadEdgeTerms(
      axial: 0.56,
      signedWidth: -1,
      packedIdentity: secondaryIdentity
    ).scale == 1
  )

  let epsilon: Float = 1e-4
  for axial: Float in [0.44, 0.56, 0.68] {
    for signedWidth: Float in [-0.8, -0.4] {
      let left = CrowRemexVaneAnatomy.terminalPrimaryBroadEdgeTerms(
        axial: axial,
        signedWidth: signedWidth,
        packedIdentity: leftIdentity
      )
      let mirrored = CrowRemexVaneAnatomy.terminalPrimaryBroadEdgeTerms(
        axial: axial,
        signedWidth: -signedWidth,
        packedIdentity: rightIdentity
      )
      #expect(abs(left.scale - mirrored.scale) < 1e-7)
      #expect(abs(left.axialDerivative - mirrored.axialDerivative) < 1e-7)
      #expect(abs(left.signedWidthDerivative + mirrored.signedWidthDerivative) < 1e-7)

      let axialFiniteDifference =
        (CrowRemexVaneAnatomy.terminalPrimaryBroadEdgeTerms(
          axial: axial + epsilon,
          signedWidth: signedWidth,
          packedIdentity: leftIdentity
        ).scale
          - CrowRemexVaneAnatomy.terminalPrimaryBroadEdgeTerms(
            axial: axial - epsilon,
            signedWidth: signedWidth,
            packedIdentity: leftIdentity
          ).scale) / (2 * epsilon)
      let widthFiniteDifference =
        (CrowRemexVaneAnatomy.terminalPrimaryBroadEdgeTerms(
          axial: axial,
          signedWidth: signedWidth + epsilon,
          packedIdentity: leftIdentity
        ).scale
          - CrowRemexVaneAnatomy.terminalPrimaryBroadEdgeTerms(
            axial: axial,
            signedWidth: signedWidth - epsilon,
            packedIdentity: leftIdentity
          ).scale) / (2 * epsilon)
      #expect(abs(axialFiniteDifference - left.axialDerivative) < 0.002)
      #expect(abs(widthFiniteDifference - left.signedWidthDerivative) < 0.002)
    }
  }
}

@Test("terminal folded remex junction is local, mirrored, and differentiable")
func terminalFoldedRemexJunctionIsLocalMirroredAndDifferentiable() {
  func identity(featherClass: UInt32, side: UInt32, order: UInt32, count: UInt32)
    -> UInt32
  {
    featherClass | (side << 8) | (order << 16) | (count << 24)
  }

  let leftPrimary = identity(featherClass: 1, side: 1, order: 9, count: 10)
  let rightPrimary = identity(featherClass: 1, side: 2, order: 9, count: 10)
  let leftSecondary = identity(featherClass: 2, side: 1, order: 10, count: 11)
  let rightSecondary = identity(featherClass: 2, side: 2, order: 10, count: 11)
  let penultimatePrimary = identity(featherClass: 1, side: 1, order: 8, count: 10)

  #expect(CrowRemexVaneAnatomy.terminalPrimaryFoldedJunctionMaximumScale == 1.35)
  #expect(CrowRemexVaneAnatomy.terminalSecondaryFoldedJunctionMaximumScale == 1.28)
  for axial: Float in [0, 0.15, 0.47, 1] {
    #expect(
      CrowRemexVaneAnatomy.terminalFoldedRemexJunctionTerms(
        axial: axial,
        signedWidth: 1,
        packedIdentity: leftPrimary
      ).scale == 1
    )
  }
  for axial: Float in [0, 0.37, 0.85, 1] {
    #expect(
      CrowRemexVaneAnatomy.terminalFoldedRemexJunctionTerms(
        axial: axial,
        signedWidth: -1,
        packedIdentity: leftSecondary
      ).scale == 1
    )
  }
  #expect(
    abs(
      CrowRemexVaneAnatomy.terminalFoldedRemexJunctionTerms(
        axial: 0.30,
        signedWidth: 1,
        packedIdentity: leftPrimary
      ).scale - 1.35
    ) < 1e-6
  )
  #expect(
    CrowRemexVaneAnatomy.terminalFoldedRemexJunctionTerms(
      axial: 0.30,
      signedWidth: -1,
      packedIdentity: leftPrimary
    ).scale == 1
  )
  #expect(
    abs(
      CrowRemexVaneAnatomy.terminalFoldedRemexJunctionTerms(
        axial: 0.60,
        signedWidth: -1,
        packedIdentity: leftSecondary
      ).scale - 1.28
    ) < 1e-6
  )
  #expect(
    CrowRemexVaneAnatomy.terminalFoldedRemexJunctionTerms(
      axial: 0.60,
      signedWidth: 1,
      packedIdentity: leftSecondary
    ).scale == 1
  )
  #expect(
    CrowRemexVaneAnatomy.terminalFoldedRemexJunctionTerms(
      axial: 0.30,
      signedWidth: 1,
      packedIdentity: penultimatePrimary
    ).scale == 1
  )

  let epsilon: Float = 1e-4
  for (packedIdentity, mirroredIdentity, axialValues, signedWidth) in [
    (leftPrimary, rightPrimary, [Float(0.20), 0.30, 0.42], Float(0.4)),
    (leftSecondary, rightSecondary, [Float(0.44), 0.60, 0.80], Float(-0.4)),
  ] {
    for axial in axialValues {
      let terms = CrowRemexVaneAnatomy.terminalFoldedRemexJunctionTerms(
        axial: axial,
        signedWidth: signedWidth,
        packedIdentity: packedIdentity
      )
      let mirrored = CrowRemexVaneAnatomy.terminalFoldedRemexJunctionTerms(
        axial: axial,
        signedWidth: -signedWidth,
        packedIdentity: mirroredIdentity
      )
      #expect(abs(terms.scale - mirrored.scale) < 1e-7)
      #expect(abs(terms.axialDerivative - mirrored.axialDerivative) < 1e-7)
      #expect(
        abs(terms.signedWidthDerivative + mirrored.signedWidthDerivative) < 1e-7
      )

      let axialFiniteDifference =
        (CrowRemexVaneAnatomy.terminalFoldedRemexJunctionTerms(
          axial: axial + epsilon,
          signedWidth: signedWidth,
          packedIdentity: packedIdentity
        ).scale
          - CrowRemexVaneAnatomy.terminalFoldedRemexJunctionTerms(
            axial: axial - epsilon,
            signedWidth: signedWidth,
            packedIdentity: packedIdentity
          ).scale) / (2 * epsilon)
      let widthFiniteDifference =
        (CrowRemexVaneAnatomy.terminalFoldedRemexJunctionTerms(
          axial: axial,
          signedWidth: signedWidth + epsilon,
          packedIdentity: packedIdentity
        ).scale
          - CrowRemexVaneAnatomy.terminalFoldedRemexJunctionTerms(
            axial: axial,
            signedWidth: signedWidth - epsilon,
            packedIdentity: packedIdentity
          ).scale) / (2 * epsilon)
      #expect(abs(axialFiniteDifference - terms.axialDerivative) < 0.003)
      #expect(abs(widthFiniteDifference - terms.signedWidthDerivative) < 0.003)
    }
  }
}
