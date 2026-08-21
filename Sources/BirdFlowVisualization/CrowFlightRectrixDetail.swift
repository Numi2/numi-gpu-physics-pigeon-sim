import simd

/// LOD-selected shaft geometry for the procedural open-flight rectrices.
/// Segments stay inside the owning vane so added feather detail cannot change
/// the coverage-preserving tail silhouette.
enum CrowFlightRectrixDetail {
  static let terminalAxialFraction: Float = 0.985
  static let camberMeters: Float = 0.006
  static let terminalRadiusScale: Float = 0.18

  static func rachisSegments(
    root: SIMD3<Float>,
    tip: SIMD3<Float>,
    planeNormal: SIMD3<Float>,
    baseRadiusMeters: Float,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    let tessellation = CrowFeatherCoverageLOD.tessellation(
      lengthMeters: simd_distance(root, tip),
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      baseAxialSections: 9
    )
    guard tessellation.rachisSections > 0 else { return [] }
    let normal = normalized(
      planeNormal,
      fallback: SIMD3<Float>(0, 0, 1)
    )
    func center(_ fraction: Float) -> SIMD3<Float> {
      root + fraction * (tip - root)
        + normal * (camberMeters * sin(Float.pi * fraction))
    }
    return (0..<tessellation.rachisSections).map { section in
      let startFraction = terminalAxialFraction * Float(section)
        / Float(tessellation.rachisSections)
      let endFraction = terminalAxialFraction * Float(section + 1)
        / Float(tessellation.rachisSections)
      return CrowFeatherMesostructureSegment(
        kind: .rachis,
        start: center(startFraction),
        end: center(endFraction),
        startRadiusMeters:
          baseRadiusMeters
          * (1 - (1 - terminalRadiusScale) * startFraction),
        endRadiusMeters:
          baseRadiusMeters
          * (1 - (1 - terminalRadiusScale) * endFraction)
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
