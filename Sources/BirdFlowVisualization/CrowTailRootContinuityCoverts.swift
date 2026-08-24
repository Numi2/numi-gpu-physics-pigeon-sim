import simd

struct CrowTailRootContinuityCovertSample: Equatable {
  let order: Int
  let tailFraction: Float
  let rootSurfaceOffset: SIMD3<Float>
  let rootOffset: SIMD3<Float>
  let planeNormal: SIMD3<Float>
  let rootWidthMeters: Float
  let maximumWidthMeters: Float
  let camberMeters: Float
  let materialVariation: Float
}

/// Short dorsal coverts that keep the posterior body surface connected to the
/// rectrix-root fan after its folded stack opens. They are an estimated visual
/// continuity layer, not an additional tail or wing surface.
enum CrowTailRootContinuityCoverts {
  static let count = CrowClosedTailAnatomy.rectrixCount
  static let rootSurfaceX: Float = -0.104
  static let rootClearanceMeters: Float = 0.0008
  static let tipClearanceMeters: Float = 0.0012
  static let dorsalArcRadians: Float = 1.06
  /// The dynamic root span changes length through takeoff, but its mesh
  /// topology must remain identical for current/previous temporal frames.
  static let topologyLODReferenceLengthMeters: Float = 0.075

  static func visibleSamples(
    projectedPixelsPerMeter: Float
  ) -> [CrowTailRootContinuityCovertSample] {
    guard projectedPixelsPerMeter >= 1_400 else { return [] }
    return samples()
  }

  static func samples() -> [CrowTailRootContinuityCovertSample] {
    (0..<count).map { order in
      let fraction = Float(order) / Float(max(count - 1, 1))
      let centered = 2 * fraction - 1
      let theta = Float.pi / 2 + centered * dorsalArcRadians / 2
      let surface = CrowBodyAnatomy.surfacePoint(atX: rootSurfaceX, theta: theta)
      let normal = CrowBodyAnatomy.surfaceNormal(atX: rootSurfaceX, theta: theta)
      let material = identityVariation(order: order)
      let central = 1 - abs(centered)
      let maximumWidth = 0.0037 + 0.0010 * central
      return CrowTailRootContinuityCovertSample(
        order: order,
        tailFraction: fraction,
        rootSurfaceOffset: surface,
        rootOffset: surface + rootClearanceMeters * normal,
        planeNormal: normal,
        rootWidthMeters: 0.58 * maximumWidth,
        maximumWidthMeters: maximumWidth,
        camberMeters: 0.0011 + 0.0005 * central,
        materialVariation: material
      )
    }
  }

  static func deploymentWeight(transitionProgress: Float) -> Float {
    CrowTakeoffSequence.liveRectrixDeploymentWeight(
      transitionProgress: transitionProgress
    )
  }

  static func tipOffset(
    for sample: CrowTailRootContinuityCovertSample,
    transitionProgress: Float
  ) -> SIMD3<Float> {
    let target = CrowTakeoffSequence.transitionRectrixPose(
      order: sample.order,
      count: count,
      transitionProgress: transitionProgress
    ).rootOffset + tipClearanceMeters * sample.planeNormal
    let weight = deploymentWeight(transitionProgress: transitionProgress)
    return sample.rootOffset + weight * (target - sample.rootOffset)
  }

  static func resolvedPlaneNormal(
    for sample: CrowTailRootContinuityCovertSample,
    tipOffset: SIMD3<Float>
  ) -> SIMD3<Float> {
    let direction = normalized(
      tipOffset - sample.rootOffset,
      fallback: SIMD3<Float>(-1, 0, 0)
    )
    return normalized(
      sample.planeNormal - direction * simd_dot(sample.planeNormal, direction),
      fallback: sample.planeNormal
    )
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-8 ? value / length : fallback
  }

  private static func identityVariation(order: Int) -> Float {
    var value = UInt32(truncatingIfNeeded: order) &* 0x9E37_79B9
    value ^= value >> 16
    value &*= 0x7FEB_352D
    value ^= value >> 15
    return 2 * Float(value & 0x00FF_FFFF) / Float(0x00FF_FFFF) - 1
  }
}
