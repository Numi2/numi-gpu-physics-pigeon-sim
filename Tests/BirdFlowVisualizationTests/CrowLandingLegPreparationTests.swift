import Testing
import simd
@testable import BirdFlowVisualization

@Test("landing preparation follows accepted approach without asserting contact")
func landingLegPreparation() {
  let near = SIMD3<Float>(0.03, 0.5, 0.29)
  #expect(CrowLandingLegPreparation.weight(completed: false, rootInPerch: near) == 0)
  #expect(CrowLandingLegPreparation.weight(completed: true, rootInPerch: SIMD3(0.3, 0.5, 0.23)) == 0)
  #expect(CrowLandingLegPreparation.weight(completed: true, rootInPerch: SIMD3(0, 0.9, 0.23)) == 0)
  #expect(CrowLandingLegPreparation.weight(completed: true, rootInPerch: SIMD3(0, 0, 0.45)) == 0)
  var previous: Float = 0
  for i in 0...160 {
    let z: Float = 0.395 - Float(i) * 0.001
    let weight = CrowLandingLegPreparation.weight(completed: true, rootInPerch: SIMD3(0,0,z))
    #expect(weight >= previous && weight <= 1)
    #expect(weight - previous < 0.02)
    previous = weight
  }
  #expect(previous > 0.99)
  let tucked = CrowTakeoffSequence.standingPose(phase: 1, preserveFlightDigits: true)
  let reached = CrowTakeoffSequence.standingPose(phase: 1, preserveFlightDigits: true,
    preLandingLegExtension: 1)
  #expect(reached.leftFoot.ankle.z < tucked.leftFoot.ankle.z - 0.02)
  #expect(reached.rightFoot.ankle.z < tucked.rightFoot.ankle.z - 0.02)
}
