import Testing
import simd

@testable import BirdFlowVisualization

@Test("dorsal tail-root coverts stay follicle-seated and deploy with rectrix roots")
func tailRootContinuityCovertsDeployWithRectrixRoots() {
  let samples = CrowTailRootContinuityCoverts.samples()
  #expect(samples == CrowTailRootContinuityCoverts.samples())
  #expect(samples.count == CrowClosedTailAnatomy.rectrixCount)
  #expect(
    CrowTailRootContinuityCoverts.topologyLODReferenceLengthMeters > 0.070
  )
  #expect(
    CrowTailRootContinuityCoverts.visibleSamples(projectedPixelsPerMeter: 1_000)
      .isEmpty
  )
  #expect(
    CrowTailRootContinuityCoverts.visibleSamples(projectedPixelsPerMeter: 1_600)
      == samples
  )
  #expect(
    CrowTailRootContinuityCoverts.deploymentWeight(transitionProgress: 0) == 0
  )
  #expect(
    CrowTailRootContinuityCoverts.deploymentWeight(transitionProgress: 1) == 1
  )

  for sample in samples {
    let foldedTip = CrowTailRootContinuityCoverts.tipOffset(
      for: sample,
      transitionProgress: 0
    )
    let deployedTip = CrowTailRootContinuityCoverts.tipOffset(
      for: sample,
      transitionProgress: 1
    )
    let expected = CrowTakeoffSequence.flightRectrixPose(
      order: sample.order,
      count: CrowClosedTailAnatomy.rectrixCount
    ).rootOffset + CrowTailRootContinuityCoverts.tipClearanceMeters
      * sample.planeNormal
    #expect(foldedTip == sample.rootOffset)
    #expect(simd_distance(deployedTip, expected) < 1e-7)
    #expect(sample.rootOffset.x > CrowBodyAnatomy.loftRings.first!.x)
    #expect(simd_length(deployedTip - sample.rootOffset) > 0.015)
    let normal = CrowTailRootContinuityCoverts.resolvedPlaneNormal(
      for: sample,
      tipOffset: deployedTip
    )
    let direction = simd_normalize(deployedTip - sample.rootOffset)
    #expect(abs(simd_dot(normal, direction)) < 1e-5)
    #expect(abs(simd_length(normal) - 1) < 1e-5)
  }
}
