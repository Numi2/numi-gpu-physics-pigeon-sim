import Testing
import simd

@testable import BirdFlowVisualization

@Test("rump underplumage seats inside pelvis and encloses rectrix roots")
func rumpUnderplumageSeatsInsidePelvisAndEnclosesRectrixRoots() {
  let segment = CrowRumpTailUnderlayer.segment()
  let pelvicRing = CrowBodyAnatomy.interpolatedRing(atX: segment.startOffset.x)
  #expect(abs(segment.startOffset.y) < pelvicRing.halfWidth)
  #expect(abs(segment.startOffset.z - pelvicRing.z) < pelvicRing.ventralRadius)
  #expect(segment.startRadiusMeters < pelvicRing.halfWidth)

  let centerRectrix = CrowClosedTailAnatomy.pose(fraction: 0.5)
  let insertion = centerRectrix.rootOffset + 0.040 * centerRectrix.direction
  #expect(simd_distance(segment.endOffset, insertion) < 0.004)
  #expect(segment.endRadiusMeters > CrowClosedTailAnatomy.lateralSpanMeters)
  #expect(segment.endRadiusMeters < segment.startRadiusMeters)
  #expect(segment.endOffset.x < segment.startOffset.x)
}
