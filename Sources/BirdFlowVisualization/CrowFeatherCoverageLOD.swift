import Foundation

struct CrowFeatherTessellation: Equatable {
  let tier: Int
  let axialSections: Int
  let widthSections: Int
  let rachisSections: Int
  let edgeBarbPairs: Int
  let barbPairs: Int
  let barbulesPerBarb: Int
}

/// Quantized vane and mesostructure budgets driven by final-output coverage.
///
/// The thresholds mirror the persistent asset's render-LOD contract. Using
/// final-output pixels keeps native and temporally reconstructed frames on the
/// same geometry tier. Quantization avoids topology churn under the small
/// standing-camera orbit.
enum CrowFeatherCoverageLOD {
  static let verticalFieldOfViewRadians: Float = 48 * .pi / 180

  static func projectedPixelsPerMeter(
    viewportHeight: Int,
    cameraDistanceMeters: Float
  ) -> Float {
    let safeHeight = Float(max(viewportHeight, 1))
    let safeDistance = max(cameraDistanceMeters, 1e-4)
    return safeHeight
      / (2 * tan(verticalFieldOfViewRadians * 0.5) * safeDistance)
  }

  static func tessellation(
    lengthMeters: Float,
    projectedPixelsPerMeter: Float,
    baseAxialSections: Int
  ) -> CrowFeatherTessellation {
    let projectedLength = max(0, lengthMeters * projectedPixelsPerMeter)
    let base = max(baseAxialSections, 2)
    if projectedLength >= 480 {
      return CrowFeatherTessellation(
        tier: 0,
        axialSections: max(base * 2, 16),
        widthSections: 7,
        rachisSections: 12,
        edgeBarbPairs: 18,
        barbPairs: 18,
        barbulesPerBarb: 3
      )
    }
    if projectedLength >= 120 {
      return CrowFeatherTessellation(
        tier: 1,
        axialSections: max(Int((Float(base) * 1.5).rounded()), 10),
        widthSections: 5,
        rachisSections: 8,
        edgeBarbPairs: 9,
        barbPairs: 9,
        barbulesPerBarb: 0
      )
    }
    if projectedLength >= 24 {
      return CrowFeatherTessellation(
        tier: 2,
        axialSections: max(base, 6),
        widthSections: 3,
        rachisSections: 4,
        edgeBarbPairs: 10,
        barbPairs: 0,
        barbulesPerBarb: 0
      )
    }
    return CrowFeatherTessellation(
      tier: 3,
      axialSections: max(Int((Float(base) * 0.5).rounded()), 2),
      widthSections: 1,
      rachisSections: 0,
      edgeBarbPairs: 0,
      barbPairs: 0,
      barbulesPerBarb: 0
    )
  }
}
