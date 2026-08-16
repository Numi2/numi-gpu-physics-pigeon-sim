import simd

/// Continuous standing-pose coupling across the estimated nape and cranium.
///
/// The trunk-facing nape stays attached to the body while the orbit and bill
/// move rigidly with the head. The cubic transition avoids the silhouette kink
/// produced when two overlapping surfaces receive unrelated transforms. These
/// bounds are presentation anatomy, not measured cervical joint locations.
enum CrowHeadNeckBlend {
  static let anchoredAxialOffsetMeters: Float = 0.105
  static let rigidAxialOffsetMeters: Float = 0.156

  static func coupling(axialOffsetMeters: Float) -> Float {
    let span = rigidAxialOffsetMeters - anchoredAxialOffsetMeters
    let linear = min(
      max((axialOffsetMeters - anchoredAxialOffsetMeters) / span, 0),
      1
    )
    return linear * linear * (3 - 2 * linear)
  }

  static func position(
    _ position: SIMD3<Float>,
    bodyCenter: SIMD3<Float>,
    neckPose: CrowStandingNeckPose
  ) -> SIMD3<Float> {
    let blend = coupling(axialOffsetMeters: position.x - bodyCenter.x)
    return bodyCenter
      + neckPose.transform(offset: position - bodyCenter, coupling: blend)
  }

  static func normal(
    _ normal: SIMD3<Float>,
    position: SIMD3<Float>,
    bodyCenter: SIMD3<Float>,
    neckPose: CrowStandingNeckPose
  ) -> SIMD3<Float> {
    // A spatially varying rotation is not a rigid transform: merely rotating
    // the source normal misses the coupling gradient and creates a lighting
    // crease. Push two local surface tangents through the actual deformation
    // and rebuild the normal from the deformed differential.
    let sourceNormal = normalized(normal, fallback: SIMD3<Float>(0, 0, 1))
    let referenceAxis =
      abs(sourceNormal.x) < 0.8
      ? SIMD3<Float>(1, 0, 0)
      : SIMD3<Float>(0, 1, 0)
    let firstTangent = normalized(
      simd_cross(referenceAxis, sourceNormal),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    let secondTangent = simd_cross(sourceNormal, firstTangent)
    let step: Float = 0.0001
    let deformedFirst =
      self.position(
        position + step * firstTangent,
        bodyCenter: bodyCenter,
        neckPose: neckPose
      )
      - self.position(
        position - step * firstTangent,
        bodyCenter: bodyCenter,
        neckPose: neckPose
      )
    let deformedSecond =
      self.position(
        position + step * secondTangent,
        bodyCenter: bodyCenter,
        neckPose: neckPose
      )
      - self.position(
        position - step * secondTangent,
        bodyCenter: bodyCenter,
        neckPose: neckPose
      )
    return normalized(
      simd_cross(deformedFirst, deformedSecond),
      fallback: neckPose.rotated(
        sourceNormal,
        coupling: coupling(axialOffsetMeters: position.x - bodyCenter.x)
      )
    )
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-10 ? value / length : fallback
  }
}
