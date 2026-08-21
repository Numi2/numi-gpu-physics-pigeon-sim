import simd

/// LOD-selected shafts contained by the topology-bound dorsal covert vanes.
///
/// The centerline uses the same longitudinal camber as the owning vane. Shaft
/// topology is therefore stable for a fixed final-output coverage tier and can
/// later move to the retained GPU feather template without changing anatomy.
enum CrowWingCovertRachisDetail {
  static let initialAxialFraction: Float = 0.04
  static let terminalAxialFraction: Float = 0.965
  static let terminalRadiusScale: Float = 0.16

  static func segments(
    root: SIMD3<Float>,
    tip: SIMD3<Float>,
    planeNormal: SIMD3<Float>,
    camberMeters: Float,
    baseRadiusMeters: Float,
    lodLengthMeters: Float,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    let tessellation = CrowFeatherCoverageLOD.tessellation(
      lengthMeters: lodLengthMeters,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      baseAxialSections: 7
    )
    guard tessellation.rachisSections > 0 else { return [] }
    let normal = normalized(planeNormal, fallback: SIMD3<Float>(0, 0, 1))
    func center(_ fraction: Float) -> SIMD3<Float> {
      root + fraction * (tip - root)
        + normal * (camberMeters * sin(Float.pi * fraction))
    }
    let axialRange = terminalAxialFraction - initialAxialFraction
    return (0..<tessellation.rachisSections).map { section in
      let first = Float(section) / Float(tessellation.rachisSections)
      let second = Float(section + 1) / Float(tessellation.rachisSections)
      let startFraction = initialAxialFraction + axialRange * first
      let endFraction = initialAxialFraction + axialRange * second
      return CrowFeatherMesostructureSegment(
        kind: .rachis,
        start: center(startFraction),
        end: center(endFraction),
        startRadiusMeters: baseRadiusMeters
          * (1 - (1 - terminalRadiusScale) * first),
        endRadiusMeters: baseRadiusMeters
          * (1 - (1 - terminalRadiusScale) * second)
      )
    }
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-12 ? value / length : fallback
  }
}
