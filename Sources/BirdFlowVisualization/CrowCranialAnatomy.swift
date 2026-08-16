import simd

/// Estimated longitudinal sections for the visible head-and-nape envelope.
///
/// A single ellipsoid makes the cranium read as a detached sphere. This loft
/// instead overlaps the body neck at the nape, carries a raised crown over the
/// orbit, and narrows into the bill base. Values are species-informed artistic
/// proportions, not a reconstruction of an individual bird.
struct CrowCranialLoftRing: Equatable {
  let axialFraction: Float
  let verticalFraction: Float
  let halfWidthFraction: Float
  let dorsalRadiusFraction: Float
  let ventralRadiusFraction: Float
}

enum CrowCranialAnatomy {
  static let renderSubdivisionsPerInterval = 4
  static let showcaseCenterOffsetMeters = SIMD3<Float>(0.158, 0, 0.052)
  static let showcaseRadiusScale = SIMD3<Float>(0.80, 0.76, 0.76)

  static let loftRings: [CrowCranialLoftRing] = [
    .init(
      axialFraction: -1.05,
      verticalFraction: -0.06,
      halfWidthFraction: 0.52,
      dorsalRadiusFraction: 0.55,
      ventralRadiusFraction: 0.48
    ),
    .init(
      axialFraction: -0.72,
      verticalFraction: 0.02,
      halfWidthFraction: 0.78,
      dorsalRadiusFraction: 0.84,
      ventralRadiusFraction: 0.73
    ),
    .init(
      axialFraction: -0.32,
      verticalFraction: 0.10,
      halfWidthFraction: 0.98,
      dorsalRadiusFraction: 1.04,
      ventralRadiusFraction: 0.96
    ),
    .init(
      axialFraction: 0.10,
      verticalFraction: 0.10,
      halfWidthFraction: 1.00,
      dorsalRadiusFraction: 1.02,
      ventralRadiusFraction: 0.97
    ),
    .init(
      axialFraction: 0.52,
      verticalFraction: 0.04,
      halfWidthFraction: 0.88,
      dorsalRadiusFraction: 0.89,
      ventralRadiusFraction: 0.88
    ),
    .init(
      axialFraction: 0.82,
      verticalFraction: -0.08,
      halfWidthFraction: 0.65,
      dorsalRadiusFraction: 0.70,
      ventralRadiusFraction: 0.70
    ),
    .init(
      axialFraction: 1.02,
      verticalFraction: -0.18,
      halfWidthFraction: 0.25,
      dorsalRadiusFraction: 0.32,
      ventralRadiusFraction: 0.38
    ),
  ]

  static func sampledLoftRings(
    subdivisionsPerInterval: Int = renderSubdivisionsPerInterval
  ) -> [CrowCranialLoftRing] {
    precondition(subdivisionsPerInterval > 0)
    guard loftRings.count > 1 else { return loftRings }
    var result: [CrowCranialLoftRing] = []
    result.reserveCapacity(
      (loftRings.count - 1) * subdivisionsPerInterval + 1
    )
    for interval in 0..<(loftRings.count - 1) {
      let first = loftRings[max(interval - 1, 0)]
      let start = loftRings[interval]
      let end = loftRings[interval + 1]
      let last = loftRings[min(interval + 2, loftRings.count - 1)]
      for subdivision in 0..<subdivisionsPerInterval {
        let t = Float(subdivision) / Float(subdivisionsPerInterval)
        result.append(
          CrowCranialLoftRing(
            axialFraction: mix(start.axialFraction, end.axialFraction, t),
            verticalFraction: catmullRom(
              first.verticalFraction,
              start.verticalFraction,
              end.verticalFraction,
              last.verticalFraction,
              t
            ),
            halfWidthFraction: max(
              0.05,
              catmullRom(
                first.halfWidthFraction,
                start.halfWidthFraction,
                end.halfWidthFraction,
                last.halfWidthFraction,
                t
              )
            ),
            dorsalRadiusFraction: max(
              0.05,
              catmullRom(
                first.dorsalRadiusFraction,
                start.dorsalRadiusFraction,
                end.dorsalRadiusFraction,
                last.dorsalRadiusFraction,
                t
              )
            ),
            ventralRadiusFraction: max(
              0.05,
              catmullRom(
                first.ventralRadiusFraction,
                start.ventralRadiusFraction,
                end.ventralRadiusFraction,
                last.ventralRadiusFraction,
                t
              )
            )
          )
        )
      }
    }
    result.append(loftRings.last!)
    return result
  }

  static func vertices(
    center: SIMD3<Float>,
    radii: SIMD3<Float>,
    breathingScale: Float,
    color: SIMD4<Float>
  ) -> [ColoredVertex] {
    let effectiveRadii = radii * SIMD3<Float>(breathingScale, 1, breathingScale)
    let segments = 48
    let rings = sampledLoftRings()
    var positions: [SIMD3<Float>] = []
    positions.reserveCapacity(rings.count * segments)
    for ring in rings {
      for segment in 0..<segments {
        let theta = 2 * Float.pi * Float(segment) / Float(segments)
        positions.append(
          surfacePoint(
            center: center,
            effectiveRadii: effectiveRadii,
            ring: ring,
            theta: theta
          )
        )
      }
    }

    var normals = [SIMD3<Float>](repeating: .zero, count: positions.count)
    var triangles: [SIMD3<Int>] = []
    triangles.reserveCapacity((rings.count - 1) * segments * 2)
    for ring in 0..<(rings.count - 1) {
      for segment in 0..<segments {
        let next = (segment + 1) % segments
        let a = ring * segments + segment
        let b = (ring + 1) * segments + segment
        let c = (ring + 1) * segments + next
        let d = ring * segments + next
        triangles.append(SIMD3<Int>(a, b, c))
        triangles.append(SIMD3<Int>(a, c, d))
      }
    }
    for triangle in triangles {
      let weighted = simd_cross(
        positions[triangle.y] - positions[triangle.x],
        positions[triangle.z] - positions[triangle.x]
      )
      normals[triangle.x] += weighted
      normals[triangle.y] += weighted
      normals[triangle.z] += weighted
    }

    var result: [ColoredVertex] = []
    result.reserveCapacity(triangles.count * 3)
    for triangle in triangles {
      for index in [triangle.x, triangle.y, triangle.z] {
        let magnitude = simd_length(normals[index])
        let normal =
          magnitude > 1e-8
          ? normals[index] / magnitude
          : SIMD3<Float>(0, 0, 1)
        result.append(
          ColoredVertex(
            position: SIMD4<Float>(positions[index], 1),
            normal: SIMD4<Float>(normal, 0),
            color: color
          )
        )
      }
    }
    return result
  }

  static func surfacePoint(
    center: SIMD3<Float>,
    effectiveRadii: SIMD3<Float>,
    ring: CrowCranialLoftRing,
    theta: Float
  ) -> SIMD3<Float> {
    let sine = sin(theta)
    let verticalFraction =
      sine >= 0 ? ring.dorsalRadiusFraction : ring.ventralRadiusFraction
    return center
      + SIMD3<Float>(
        effectiveRadii.x * ring.axialFraction,
        effectiveRadii.y * ring.halfWidthFraction * cos(theta),
        effectiveRadii.z
          * (ring.verticalFraction + verticalFraction * sine)
      )
  }

  private static func mix(_ first: Float, _ second: Float, _ t: Float) -> Float {
    first + t * (second - first)
  }

  private static func catmullRom(
    _ first: Float,
    _ start: Float,
    _ end: Float,
    _ last: Float,
    _ t: Float
  ) -> Float {
    let t2 = t * t
    let t3 = t2 * t
    return 0.5
      * (2 * start
        + (-first + end) * t
        + (2 * first - 5 * start + 4 * end - last) * t2
        + (-first + 3 * start - 3 * end + last) * t3)
  }
}
