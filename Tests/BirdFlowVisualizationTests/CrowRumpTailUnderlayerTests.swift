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

@Test("folded wing-tail underplumage is bilateral and releases before articulation")
func foldedWingTailUnderplumageIsBilateralAndReleasesBeforeArticulation() {
  let left = CrowRumpTailUnderlayer.foldedWingTailSegment(left: true)
  let right = CrowRumpTailUnderlayer.foldedWingTailSegment(left: false)
  #expect(left.startOffset == right.startOffset)
  #expect(left.endOffset.x == right.endOffset.x)
  #expect(left.endOffset.y == -right.endOffset.y)
  #expect(left.endOffset.z == right.endOffset.z)
  #expect(left.startRadiusMeters == right.startRadiusMeters)
  #expect(left.endRadiusMeters == right.endRadiusMeters)
  #expect(left.startRadiusMeters == left.endRadiusMeters)
  #expect(left.startRadiusMeters == 0.008)
  #expect(abs(left.endOffset.y - 0.047) < 1e-7)
  #expect(abs(left.endOffset.z + 0.031) < 1e-7)
  #expect(left.endOffset.x < CrowRumpTailUnderlayer.segment().endOffset.x)
  #expect(
    CrowRumpTailUnderlayer.foldedWingTailWeight(presentationPhase: 0) == 1
  )
  #expect(
    CrowRumpTailUnderlayer.foldedWingTailWeight(presentationPhase: 0.125) == 1
  )
  #expect(
    abs(
      CrowRumpTailUnderlayer.foldedWingTailWeight(presentationPhase: 0.25) - 0.5
    ) < 1e-6
  )
  #expect(
    CrowRumpTailUnderlayer.foldedWingTailWeight(presentationPhase: 0.375) == 0
  )
  #expect(
    CrowRumpTailUnderlayer.foldedWingTailWeight(presentationPhase: 1) == 0
  )
}
