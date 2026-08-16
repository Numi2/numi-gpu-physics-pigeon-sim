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
