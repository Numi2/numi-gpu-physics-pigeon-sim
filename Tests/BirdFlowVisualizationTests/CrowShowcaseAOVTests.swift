import Testing

@testable import BirdFlowVisualization

@Test("silhouette hole audit distinguishes enclosed and exterior background")
func silhouetteHoleAuditDistinguishesEnclosedAndExteriorBackground() {
  let width = 7
  let height = 7
  var closed = [Bool](repeating: false, count: width * height)
  for y in 1...5 {
    for x in 1...5 where x == 1 || x == 5 || y == 1 || y == 5 {
      closed[y * width + x] = true
    }
  }
  let classCodes = closed.map { $0 ? UInt8(2) : UInt8(0) }
  let enclosed = CrowShowcaseFrame.silhouetteHoles(
    birdMask: closed,
    featherClassCodes: classCodes,
    width: width,
    height: height
  )
  #expect(enclosed.pixelCount == 9)
  #expect(enclosed.componentCount == 1)
  #expect(enclosed.largestComponentPixelCount == 9)
  #expect(enclosed.minimumX == 2 && enclosed.maximumX == 4)
  #expect(enclosed.minimumY == 2 && enclosed.maximumY == 4)
  #expect(enclosed.centroidX == 3 && enclosed.centroidY == 3)
  #expect(enclosed.adjacentFeatherClassMask == 1 << 2)
  #expect(enclosed.expectedLowerBodyAperturePixelCount == 0)

  var open = closed
  open[1 * width + 3] = false
  #expect(
    CrowShowcaseFrame.silhouetteHoles(
      birdMask: open,
      width: width,
      height: height
    ) == .zero
  )
}

@Test("silhouette audit separates the planted inter-leg aperture from body slits")
func silhouetteAuditSeparatesPlantedInterLegApertureFromBodySlits() {
  let width = 16
  let height = 18
  var bird = [Bool](repeating: false, count: width * height)
  for y in 1...16 {
    for x in 1...14 {
      bird[y * width + x] = true
    }
  }
  for y in 9...14 {
    for x in 7...8 {
      bird[y * width + x] = false
    }
  }
  for x in 3...5 {
    bird[15 * width + x] = false
  }
  let surfaceClasses = [UInt8](repeating: 0, count: bird.count)
  let audit = CrowShowcaseFrame.silhouetteHoles(
    birdMask: bird,
    featherClassCodes: surfaceClasses,
    width: width,
    height: height
  )
  #expect(audit.pixelCount == 0)
  #expect(audit.componentCount == 0)
  #expect(audit.expectedLowerBodyAperturePixelCount == 15)
  #expect(audit.expectedLowerBodyApertureComponentCount == 2)
  #expect(audit.largestExpectedLowerBodyAperturePixelCount == 12)

  var legClasses = surfaceClasses
  for y in 9...14 {
    legClasses[y * width + 6] = 7
    legClasses[y * width + 9] = 7
  }
  let featherBounded = CrowShowcaseFrame.silhouetteHoles(
    birdMask: bird,
    featherClassCodes: legClasses,
    width: width,
    height: height
  )
  #expect(featherBounded.pixelCount == 0)
  #expect(featherBounded.expectedLowerBodyAperturePixelCount == 15)
  #expect(featherBounded.expectedLowerBodyApertureComponentCount == 2)

  let dorsalWidth = 24
  let dorsalHeight = 18
  var dorsalBird = [Bool](repeating: false, count: dorsalWidth * dorsalHeight)
  for y in 1...16 {
    for x in 1...22 {
      dorsalBird[y * dorsalWidth + x] = true
    }
  }
  for y in 9...14 {
    for x in 8...15 {
      dorsalBird[y * dorsalWidth + x] = false
    }
  }
  var dorsalClasses = [UInt8](repeating: 0, count: dorsalBird.count)
  for y in 9...14 {
    dorsalClasses[y * dorsalWidth + 7] = 7
    dorsalClasses[y * dorsalWidth + 16] = 7
  }
  let dorsalAudit = CrowShowcaseFrame.silhouetteHoles(
    birdMask: dorsalBird,
    featherClassCodes: dorsalClasses,
    width: dorsalWidth,
    height: dorsalHeight
  )
  #expect(dorsalAudit.pixelCount == 0)
  #expect(dorsalAudit.expectedLowerBodyAperturePixelCount == 48)
  #expect(dorsalAudit.expectedLowerBodyApertureComponentCount == 1)

  let dorsalBodyOnlyAudit = CrowShowcaseFrame.silhouetteHoles(
    birdMask: dorsalBird,
    featherClassCodes: [UInt8](repeating: 0, count: dorsalBird.count),
    width: dorsalWidth,
    height: dorsalHeight
  )
  #expect(dorsalBodyOnlyAudit.pixelCount == 48)
  #expect(dorsalBodyOnlyAudit.expectedLowerBodyAperturePixelCount == 0)

  var elevatedPedalBird = dorsalBird
  for x in 3...5 {
    elevatedPedalBird[11 * dorsalWidth + x] = false
  }
  var elevatedPedalClasses = dorsalClasses
  for x in 3...5 {
    elevatedPedalClasses[10 * dorsalWidth + x] = 7
    elevatedPedalClasses[12 * dorsalWidth + x] = 7
  }
  let elevatedPedalAudit = CrowShowcaseFrame.silhouetteHoles(
    birdMask: elevatedPedalBird,
    featherClassCodes: elevatedPedalClasses,
    width: dorsalWidth,
    height: dorsalHeight
  )
  #expect(elevatedPedalAudit.pixelCount == 0)
  #expect(elevatedPedalAudit.expectedLowerBodyAperturePixelCount == 51)
  #expect(elevatedPedalAudit.expectedLowerBodyApertureComponentCount == 2)

  bird[5 * width + 7] = false
  let withSlit = CrowShowcaseFrame.silhouetteHoles(
    birdMask: bird,
    featherClassCodes: surfaceClasses,
    width: width,
    height: height
  )
  #expect(withSlit.pixelCount == 1)
  #expect(withSlit.componentCount == 1)
  #expect(withSlit.expectedLowerBodyAperturePixelCount == 15)
}

@Test("silhouette audit preserves retracted pedal space across wing coverts")
func silhouetteAuditPreservesRetractedPedalSpaceAcrossWingCoverts() {
  let width = 12
  let height = 14
  var bird = [Bool](repeating: false, count: width * height)
  for y in 1...12 {
    for x in 1...10 {
      bird[y * width + x] = true
    }
  }
  for y in 7...9 {
    for x in 5...6 {
      bird[y * width + x] = false
    }
  }
  var classes = [UInt8](repeating: 0, count: bird.count)
  for x in 5...6 {
    classes[6 * width + x] = 4
    classes[10 * width + x] = 7
  }
  let unclassified = CrowShowcaseFrame.silhouetteHoles(
    birdMask: bird,
    featherClassCodes: classes,
    width: width,
    height: height
  )
  #expect(unclassified.pixelCount == 6)
  #expect(unclassified.expectedLowerBodyAperturePixelCount == 0)

  for y in 7...9 {
    classes[y * width + 4] = UInt8(CrowFootAnatomy.surfaceIdentityClassCode)
    classes[y * width + 7] = UInt8(CrowFootAnatomy.surfaceIdentityClassCode)
  }
  let classified = CrowShowcaseFrame.silhouetteHoles(
    birdMask: bird,
    featherClassCodes: classes,
    width: width,
    height: height
  )
  #expect(classified.pixelCount == 0)
  #expect(classified.componentCount == 0)
  #expect(classified.expectedLowerBodyAperturePixelCount == 6)
  #expect(classified.expectedLowerBodyApertureComponentCount == 1)
}
