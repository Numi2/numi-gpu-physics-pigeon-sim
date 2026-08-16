import simd

struct CrowBodyContourUnderlayerSegment: Equatable {
  let start: SIMD3<Float>
  let end: SIMD3<Float>
  let startRadiusMeters: Float
  let endRadiusMeters: Float
}

/// Plumulaceous barb geometry below the exposed pennaceous body shell.
///
/// The underlayer is retained as real geometry for future close output, but is
/// omitted while its owning feather is too small on the final image to resolve.
enum CrowBodyContourUnderlayer {
  static func segments(
    for feather: CrowBodyContourShingle,
    projectedPixelsPerMeter: Float
  ) -> [CrowBodyContourUnderlayerSegment] {
    let projectedLength =
      feather.referenceLengthMeters * projectedPixelsPerMeter
    let pairCount: Int
    if projectedLength >= 480 {
      pairCount = 10
    } else if projectedLength >= 240 {
      pairCount = 7
    } else if projectedLength >= 120 {
      pairCount = 4
    } else {
      return []
    }

    let direction = normalized(
      feather.tipOffset - feather.rootOffset,
      fallback: SIMD3<Float>(-1, 0, 0)
    )
    let normal = normalized(
      feather.planeNormal - direction * simd_dot(feather.planeNormal, direction),
      fallback: feather.planeNormal
    )
    let widthAxis = normalized(
      simd_cross(normal, direction),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    let finalAxial = max(0.16, feather.pennaceousStartFraction - 0.055)
    var result: [CrowBodyContourUnderlayerSegment] = []
    result.reserveCapacity(2 * pairCount)
    for pair in 0..<pairCount {
      let phase = Float(pair + 1) / Float(pairCount + 1)
      let axial = mix(0.08, finalAxial, phase)
      let reachAxial = min(
        feather.pennaceousStartFraction - 0.018,
        axial + 0.050 + 0.018 * phase
      )
      let start = CrowBodyContourShingles.centerlinePoint(for: feather, at: axial)
      let reach = CrowBodyContourShingles.centerlinePoint(for: feather, at: reachAxial)
      let halfWidth = CrowBodyContourShingles.vaneHalfWidth(
        for: feather,
        at: reachAxial
      )
      for side: Float in [-1, 1] {
        result.append(
          CrowBodyContourUnderlayerSegment(
            start: start,
            end: reach + side * widthAxis * (0.56 * halfWidth)
              + normal * (0.00030 + 0.00022 * phase),
            startRadiusMeters: 0.000035,
            endRadiusMeters: 0.000009
          )
        )
      }
    }
    return result
  }

  private static func mix(_ first: Float, _ second: Float, _ blend: Float) -> Float {
    first + blend * (second - first)
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-9 ? value / length : fallback
  }
}
