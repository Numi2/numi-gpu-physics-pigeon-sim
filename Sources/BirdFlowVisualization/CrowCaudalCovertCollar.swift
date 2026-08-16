import simd

struct CrowCaudalCovertCollarSample: Equatable {
  let rank: Int
  let row: Int
  let rootSurfaceOffset: SIMD3<Float>
  let rootOffset: SIMD3<Float>
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

/// Staggered caudal covert ranks over the posterior body-loft closure.
///
/// The body, upper-tail, and undertail tracts meet around a small pelvic disk.
/// Long vanes aimed through the axis form an implausible radial star when seen
/// from behind. These shorter ranks instead start on successive body rings and
/// roof-tile toward the rectrix insertion. Their posterior halves overlap in
/// rear projection, replacing the smooth closing disk with explicit feather
/// surfaces while keeping every root seated on the body loft.
enum CrowCaudalCovertCollar {
  static let rankCounts = [28, 20, 12]
  static let sampleCount = rankCounts.reduce(0, +)
  static let capX = CrowBodyAnatomy.loftRings.first!.x
  static let shellClearanceMeters: Float = 0.0008
  static let rootEnvelopeRatio: Float = 0.72

  static func visibleSamples(
    projectedPixelsPerMeter: Float
  ) -> [CrowCaudalCovertCollarSample] {
    guard projectedPixelsPerMeter >= 1_400 else { return [] }
    return samples()
  }

  static func samples() -> [CrowCaudalCovertCollarSample] {
    let rootXs: [Float] = [-0.174, -0.182, -0.187]
    let tipXs: [Float] = [-0.198, -0.201, -0.203]
    let tipRadii: [Float] = [0.0066, 0.0026, 0.00035]
    let rankMaximumWidths: [Float] = [0.0048, 0.0042, 0.0038]
    var result: [CrowCaudalCovertCollarSample] = []
    result.reserveCapacity(sampleCount)

    for rank in rankCounts.indices {
      let count = rankCounts[rank]
      let phase = rank == 0 ? 0 : Float.pi / Float(count)
      let rootRing = CrowBodyAnatomy.interpolatedRing(atX: rootXs[rank])
      for row in 0..<count {
        let identity = result.count
        let theta = phase + 2 * Float.pi * Float(row) / Float(count)
        let shapeIdentity = identityVariation(row: identity, salt: 0x85EB_CA6B)
        let materialIdentity = identityVariation(row: identity, salt: 0xC2B2_AE35)
        let vaneIdentity = identityVariation(row: identity, salt: 0xB529_7A4D)
        let edgeIdentity = identityVariation(row: identity, salt: 0x68E3_1DA4)
        let cycleIdentity = identityVariation(row: identity, salt: 0x1656_67B1)
        let rootSurface = CrowBodyAnatomy.surfacePoint(
          ring: rootRing,
          theta: theta
        )
        let rootNormal = CrowBodyAnatomy.surfaceNormal(
          atX: rootXs[rank],
          theta: theta
        )
        let root = rootSurface + shellClearanceMeters * rootNormal
        let radialUnit = normalized(
          SIMD3<Float>(0, rootSurface.y, rootSurface.z - rootRing.z),
          fallback: SIMD3<Float>(0, cos(theta), sin(theta))
        )
        let targetRadius = tipRadii[rank] * (1 + 0.08 * shapeIdentity)
        let tip =
          SIMD3<Float>(tipXs[rank], 0, CrowBodyAnatomy.loftRings.first!.z)
          + targetRadius * radialUnit
        let halfAngularStep = Float.pi / Float(count)
        let circumferentialSpacing = simd_distance(
          CrowBodyAnatomy.surfacePoint(
            ring: rootRing,
            theta: theta - halfAngularStep
          ),
          CrowBodyAnatomy.surfacePoint(
            ring: rootRing,
            theta: theta + halfAngularStep
          )
        )
        let maximumWidth =
          min(
            rankMaximumWidths[rank],
            max(0.0034, (0.94 + 0.04 * Float(rank)) * circumferentialSpacing)
          ) * (1 + 0.035 * shapeIdentity)
        let planeNormal = normalized(
          SIMD3<Float>(-1, 0.58 * radialUnit.y, 0.58 * radialUnit.z),
          fallback: SIMD3<Float>(-1, 0, 0)
        )
        result.append(
          CrowCaudalCovertCollarSample(
            rank: rank,
            row: row,
            rootSurfaceOffset: rootSurface,
            rootOffset: root,
            tipOffset: tip,
            planeNormal: planeNormal,
            rootWidthMeters: (0.70 + 0.03 * Float(rank)) * maximumWidth,
            maximumWidthMeters: maximumWidth,
            camberMeters: (0.0024 - 0.00055 * Float(rank))
              * (1 + 0.08 * shapeIdentity),
            vaneAsymmetry: 0.025 * vaneIdentity,
            edgeRippleAmplitude: 0.004 + 0.006 * (0.5 + 0.5 * edgeIdentity),
            edgeRipplePhase: Float.pi * (edgeIdentity + 1),
            edgeRippleCycles: 1.20 + 0.55 * (0.5 + 0.5 * cycleIdentity),
            rootEnvelopeRatio: rootEnvelopeRatio,
            materialVariation: materialIdentity,
            surfaceFeatherClass: sin(theta) >= 0 ? 5 : 7
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
