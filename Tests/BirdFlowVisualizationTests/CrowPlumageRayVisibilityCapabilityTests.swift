import Metal
import Testing

@testable import BirdFlowVisualization

@Test("plumage ray visibility reports capability without claiming enablement")
func crowPlumageRayVisibilityCapabilityKeepsClosureGate() {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let capability = CrowPlumageRayVisibilityCapability.current(on: device)

  #expect(
    capability.surfaceVisibilityAuthority
      == "analytic-discontinuity-ray-regular-cross-section-estimate"
  )
  #expect(
    capability.explicitCurveVisibilityAuthority
      == "raster-depth-resolved-explicit-curves"
  )
  #expect(capability.computeRayTracingSupported == device.supportsRaytracing)
  #expect(
    capability.renderRayTracingSupported == device.supportsRaytracingFromRender
  )
  #expect(capability.experimentalRayVisibilityEnabled == false)
  #expect(
    capability.enablementGate
      == "explicit-curve-acceleration-structure-and-AOV-parity-required"
  )
  #expect(
    capability.isEligibleForFutureRayPrototype
      == device.supportsRaytracing
  )
}
