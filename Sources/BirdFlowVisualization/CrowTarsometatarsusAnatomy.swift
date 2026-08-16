import simd

struct CrowTarsometatarsusStation: Equatable {
  let fraction: Float
  let lateralRadiusMeters: Float
  let foreAftRadiusMeters: Float
}

/// Estimated non-circular surface for the exposed lower leg.
///
/// A crow tarsometatarsus is not a uniformly round rod. This profile retains
/// the selected limb length while tapering between joint expansions, flattening
/// the shaft laterally, and placing discrete scutes only on the anterior arc.
/// It is presentation anatomy, not a specimen reconstruction.
enum CrowTarsometatarsusAnatomy {
  static let radialSegments = 16
  static let scuteCount = 8
  static let scuteArcSegments = 6

  static let stations: [CrowTarsometatarsusStation] = [
    .init(fraction: 0.00, lateralRadiusMeters: 0.0053, foreAftRadiusMeters: 0.0062),
    .init(fraction: 0.14, lateralRadiusMeters: 0.0050, foreAftRadiusMeters: 0.0058),
    .init(fraction: 0.34, lateralRadiusMeters: 0.0045, foreAftRadiusMeters: 0.0052),
    .init(fraction: 0.58, lateralRadiusMeters: 0.0041, foreAftRadiusMeters: 0.0047),
    .init(fraction: 0.80, lateralRadiusMeters: 0.0039, foreAftRadiusMeters: 0.0045),
    .init(fraction: 1.00, lateralRadiusMeters: 0.0043, foreAftRadiusMeters: 0.0050),
  ]

  static func vertices(
    hock: SIMD3<Float>,
    ankle: SIMD3<Float>,
    shaftColor: SIMD4<Float>,
    scuteColor: SIMD4<Float>
  ) -> [ColoredVertex] {
    let frame = localFrame(hock: hock, ankle: ankle)
    var positions: [SIMD3<Float>] = []
    positions.reserveCapacity(stations.count * radialSegments)
    for station in stations {
      let center = mix(hock, ankle, station.fraction)
      for radialIndex in 0..<radialSegments {
        let angle = 2 * Float.pi * Float(radialIndex) / Float(radialSegments)
        positions.append(
          center
            + cos(angle) * station.foreAftRadiusMeters * frame.forward
            + sin(angle) * station.lateralRadiusMeters * frame.lateral
        )
      }
    }

    var normals = [SIMD3<Float>](repeating: .zero, count: positions.count)
    var triangles: [SIMD3<Int>] = []
    triangles.reserveCapacity((stations.count - 1) * radialSegments * 2)
    for stationIndex in 0..<(stations.count - 1) {
      for radialIndex in 0..<radialSegments {
        let next = (radialIndex + 1) % radialSegments
        let a = stationIndex * radialSegments + radialIndex
        let b = (stationIndex + 1) * radialSegments + radialIndex
        let c = (stationIndex + 1) * radialSegments + next
        let d = stationIndex * radialSegments + next
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
    result.reserveCapacity(
      triangles.count * 3 + scuteCount * scuteArcSegments * 6
    )
    for triangle in triangles {
      for index in [triangle.x, triangle.y, triangle.z] {
        result.append(
          ColoredVertex(
            position: SIMD4<Float>(positions[index], 1),
            normal: SIMD4<Float>(
              normalized(normals[index], fallback: frame.forward),
              0
            ),
            color: shaftColor
          )
        )
      }
    }
    appendAnteriorScutes(
      hock: hock,
      ankle: ankle,
      frame: frame,
      color: scuteColor,
      to: &result
    )
    return result
  }

  private static func appendAnteriorScutes(
    hock: SIMD3<Float>,
    ankle: SIMD3<Float>,
    frame: (axis: SIMD3<Float>, forward: SIMD3<Float>, lateral: SIMD3<Float>),
    color: SIMD4<Float>,
    to result: inout [ColoredVertex]
  ) {
    for scuteIndex in 0..<scuteCount {
      let centerFraction = 0.10 + 0.80 * Float(scuteIndex) / Float(scuteCount - 1)
      let halfLengthFraction: Float = 0.038
      let lowerFraction = centerFraction - halfLengthFraction
      let upperFraction = centerFraction + halfLengthFraction
      for arcIndex in 0..<scuteArcSegments {
        let firstAngle = -0.72 + 1.44 * Float(arcIndex) / Float(scuteArcSegments)
        let secondAngle = -0.72 + 1.44 * Float(arcIndex + 1) / Float(scuteArcSegments)
        let lowerFirst = scutePoint(
          fraction: lowerFraction,
          angle: firstAngle,
          hock: hock,
          ankle: ankle,
          frame: frame
        )
        let upperFirst = scutePoint(
          fraction: upperFraction,
          angle: firstAngle,
          hock: hock,
          ankle: ankle,
          frame: frame
        )
        let upperSecond = scutePoint(
          fraction: upperFraction,
          angle: secondAngle,
          hock: hock,
          ankle: ankle,
          frame: frame
        )
        let lowerSecond = scutePoint(
          fraction: lowerFraction,
          angle: secondAngle,
          hock: hock,
          ankle: ankle,
          frame: frame
        )
        let firstNormal = normalized(
          cos(firstAngle) * frame.forward + sin(firstAngle) * frame.lateral,
          fallback: frame.forward
        )
        let secondNormal = normalized(
          cos(secondAngle) * frame.forward + sin(secondAngle) * frame.lateral,
          fallback: frame.forward
        )
        for (point, normal) in [
          (lowerFirst, firstNormal), (upperFirst, firstNormal),
          (upperSecond, secondNormal), (lowerFirst, firstNormal),
          (upperSecond, secondNormal), (lowerSecond, secondNormal),
        ] {
          result.append(
            ColoredVertex(
              position: SIMD4<Float>(point, 1),
              normal: SIMD4<Float>(normal, 0),
              color: color
            )
          )
        }
      }
    }
  }

  private static func scutePoint(
    fraction: Float,
    angle: Float,
    hock: SIMD3<Float>,
    ankle: SIMD3<Float>,
    frame: (axis: SIMD3<Float>, forward: SIMD3<Float>, lateral: SIMD3<Float>)
  ) -> SIMD3<Float> {
    let radii = interpolatedRadii(at: fraction)
    return mix(hock, ankle, fraction)
      + (radii.foreAft + 0.00018) * cos(angle) * frame.forward
      + radii.lateral * sin(angle) * frame.lateral
  }

  private static func interpolatedRadii(
    at fraction: Float
  ) -> (lateral: Float, foreAft: Float) {
    let clamped = min(max(fraction, 0), 1)
    for index in 0..<(stations.count - 1) {
      let start = stations[index]
      let end = stations[index + 1]
      guard clamped <= end.fraction else { continue }
      let blend = (clamped - start.fraction) / (end.fraction - start.fraction)
      return (
        start.lateralRadiusMeters
          + blend * (end.lateralRadiusMeters - start.lateralRadiusMeters),
        start.foreAftRadiusMeters
          + blend * (end.foreAftRadiusMeters - start.foreAftRadiusMeters)
      )
    }
    return (
      stations.last!.lateralRadiusMeters,
      stations.last!.foreAftRadiusMeters
    )
  }

  private static func localFrame(
    hock: SIMD3<Float>,
    ankle: SIMD3<Float>
  ) -> (axis: SIMD3<Float>, forward: SIMD3<Float>, lateral: SIMD3<Float>) {
    let axis = normalized(ankle - hock, fallback: SIMD3<Float>(0, 0, -1))
    let projectedForward = SIMD3<Float>(1, 0, 0) - axis.x * axis
    let forward = normalized(projectedForward, fallback: SIMD3<Float>(1, 0, 0))
    let lateral = normalized(
      simd_cross(forward, axis),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    return (axis, forward, lateral)
  }

  private static func mix(
    _ first: SIMD3<Float>,
    _ second: SIMD3<Float>,
    _ blend: Float
  ) -> SIMD3<Float> {
    first + blend * (second - first)
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-10 ? value / length : fallback
  }
}
