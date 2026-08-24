import Metal

/// Records the live closure boundary between the estimated surface-mask path
/// and a future acceleration-structure path. It deliberately does not enable
/// ray visibility: capability is necessary, while identity/AOV parity and an
/// explicit curve build are still required before it can own radiance.
struct CrowPlumageRayVisibilityCapability: Codable, Equatable {
  let surfaceVisibilityAuthority: String
  let explicitCurveVisibilityAuthority: String
  let computeRayTracingSupported: Bool
  let renderRayTracingSupported: Bool
  let experimentalRayVisibilityEnabled: Bool
  let enablementGate: String

  static func current(on device: MTLDevice) -> Self {
    Self(
      surfaceVisibilityAuthority:
        "analytic-discontinuity-ray-regular-cross-section-estimate",
      explicitCurveVisibilityAuthority: "raster-depth-resolved-explicit-curves",
      computeRayTracingSupported: device.supportsRaytracing,
      renderRayTracingSupported: device.supportsRaytracingFromRender,
      experimentalRayVisibilityEnabled: false,
      enablementGate:
        "explicit-curve-acceleration-structure-and-AOV-parity-required"
    )
  }

  /// Ray hardware is only an eligibility signal. The current renderer has no
  /// acceleration structure and must retain the analytic/raster authorities.
  var isEligibleForFutureRayPrototype: Bool {
    computeRayTracingSupported && !experimentalRayVisibilityEnabled
  }
}
