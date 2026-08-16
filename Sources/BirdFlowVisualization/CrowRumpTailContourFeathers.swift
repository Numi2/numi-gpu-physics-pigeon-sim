import simd

struct CrowRumpTailContourFeatherSample: Equatable {
  let row: Int
  let column: Int
  let rootSurfaceOffset: SIMD3<Float>
  let rootOffset: SIMD3<Float>
  let tipSurfaceOffset: SIMD3<Float>
  let tipOffset: SIMD3<Float>
  let planeNormal: SIMD3<Float>
  let rootWidthMeters: Float
  let maximumWidthMeters: Float
  let camberMeters: Float
  let vaneAsymmetry: Float
  let edgeRippleAmplitude: Float
  let edgeRipplePhase: Float
  let edgeRippleCycles: Float
  let rootEnvelopeRatio: Float
  let materialVariation: Float
  let surfaceFeatherClass: UInt32
}

/// Imbricated contour vanes over the rump-to-rectrix underplumage volume.
///
/// The tapered tube remains a dark, gap-closing optical underlayer. These
/// surface-following feathers keep that fallback from reading as exposed skin:
/// successive rows overlap axially while each circumferential course overlaps
/// its neighbours, and their roots and tips remain outside the same tube.
enum CrowRumpTailContourFeathers {
  static let rowCount = 5
  static let columnCount = 24
  static let shellClearanceMeters: Float = 0.0007
  static let rootEnvelopeRatio: Float = 0.58

  static func visibleSamples(
    projectedPixelsPerMeter: Float
  ) -> [CrowRumpTailContourFeatherSample] {
    guard projectedPixelsPerMeter >= 1_400 else { return [] }
    return samples()
  }

  static func samples() -> [CrowRumpTailContourFeatherSample] {
    let segment = CrowRumpTailUnderlayer.segment()
    let axis = normalized(
      segment.endOffset - segment.startOffset,
      fallback: SIMD3<Float>(-1, 0, 0)
    )
    let lateral = SIMD3<Float>(0, 1, 0)
    let vertical = normalized(
      simd_cross(lateral, axis),
      fallback: SIMD3<Float>(0, 0, 1)
    )
    var result: [CrowRumpTailContourFeatherSample] = []
    result.reserveCapacity(rowCount * columnCount)
    for row in 0..<rowCount {
      let rootFraction = 0.05 + 0.13 * Float(row)
      let tipFraction = rootFraction + 0.29
      let phase = Float(row % 2) * Float.pi / Float(columnCount)
      for column in 0..<columnCount {
        let identity = row * columnCount + column
        let theta = phase + 2 * Float.pi * Float(column) / Float(columnCount)
        let radial = cos(theta) * lateral + sin(theta) * vertical
        let shapeIdentity = identityVariation(row: identity, salt: 0x9E37_79B9)
        let materialIdentity = identityVariation(row: identity, salt: 0x85EB_CA6B)
        let vaneIdentity = identityVariation(row: identity, salt: 0xC2B2_AE35)
        let edgeIdentity = identityVariation(row: identity, salt: 0xB529_7A4D)
        let rootRadius = mix(
          segment.startRadiusMeters,
          segment.endRadiusMeters,
          rootFraction
        )
        let tipRadius = mix(
          segment.startRadiusMeters,
          segment.endRadiusMeters,
          tipFraction
        )
        let rootSurface =
          mix(segment.startOffset, segment.endOffset, rootFraction)
          + rootRadius * radial
        let tipSurface =
          mix(segment.startOffset, segment.endOffset, tipFraction)
          + tipRadius * radial
        let root = rootSurface + shellClearanceMeters * radial
        let tip = tipSurface + shellClearanceMeters * radial
        let spacing = 2 * rootRadius * sin(Float.pi / Float(columnCount))
        let maximumWidth = min(0.0042, 0.62 * spacing)
          * (1 + 0.035 * shapeIdentity)
        result.append(
          CrowRumpTailContourFeatherSample(
            row: row,
            column: column,
            rootSurfaceOffset: rootSurface,
            rootOffset: root,
            tipSurfaceOffset: tipSurface,
            tipOffset: tip,
            planeNormal: radial,
            rootWidthMeters: 0.62 * maximumWidth,
            maximumWidthMeters: maximumWidth,
            camberMeters: 0.00065 * (1 + 0.10 * shapeIdentity),
            vaneAsymmetry: 0.025 * vaneIdentity,
            edgeRippleAmplitude: 0.005 + 0.007 * (0.5 + 0.5 * edgeIdentity),
            edgeRipplePhase: Float.pi * (edgeIdentity + 1),
            edgeRippleCycles: 1.25 + 0.50 * (0.5 + 0.5 * shapeIdentity),
            rootEnvelopeRatio: rootEnvelopeRatio,
            materialVariation: materialIdentity,
            surfaceFeatherClass: simd_dot(radial, vertical) >= 0 ? 5 : 7
          )
        )
      }
    }
    return result
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-8 ? value / length : fallback
  }

  private static func mix(_ first: Float, _ second: Float, _ blend: Float) -> Float {
    first + blend * (second - first)
  }

  private static func mix(
    _ first: SIMD3<Float>,
    _ second: SIMD3<Float>,
    _ blend: Float
  ) -> SIMD3<Float> {
    first + blend * (second - first)
  }

  private static func identityVariation(row: Int, salt: UInt32) -> Float {
    var value = UInt32(truncatingIfNeeded: row) &* 0x9E37_79B9
    value ^= salt
    value ^= value >> 16
    value &*= 0x7FEB_352D
    value ^= value >> 15
    value &*= 0x846C_A68B
    value ^= value >> 16
    return 2 * Float(value & 0x00FF_FFFF) / Float(0x00FF_FFFF) - 1
  }
}
