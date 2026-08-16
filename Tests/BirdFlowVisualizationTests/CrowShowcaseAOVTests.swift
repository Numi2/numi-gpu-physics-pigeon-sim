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
  let enclosed = CrowShowcaseFrame.silhouetteHoles(
    birdMask: closed,
    width: width,
    height: height
  )
  #expect(enclosed.pixelCount == 9)
  #expect(enclosed.componentCount == 1)
  #expect(enclosed.largestComponentPixelCount == 9)

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
