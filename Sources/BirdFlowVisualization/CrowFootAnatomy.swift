import simd

struct CrowPlantarPad: Equatable {
  let digitNumber: Int
  let jointIndex: Int
  let center: SIMD3<Float>
  let longitudinalRadiusMeters: Float
  let lateralRadiusMeters: Float
  let heightRadiusMeters: Float
}

/// Estimated segmented foot surface for the quiet-standing presentation.
///
/// Each digit follows its explicit phalangeal chain. Flattened plantar pads own
/// support contact while tapered elliptical phalanges arch above them, and a
/// two-segment claw continues the distal tangent. Geometry is species-informed
/// presentation anatomy; it does not claim tendon forces or measured joints.
enum CrowFootAnatomy {
  /// Semantic AOV class for exposed pedal keratin. This is intentionally
  /// separate from body and feather classes so articulated digital negative
  /// space remains distinguishable from a torn plumage shell.
  static let surfaceIdentityClassCode: UInt32 = 11
  static let phalanxRadialSegments = 10
  static let phalanxAxialStations = 3
  static let padLatitudeIntervals = 6
  static let padLongitudeSegments = 12

  static func plantarPads(
    digit: CrowStandingDigitPose,
    supportHeight: Float
  ) -> [CrowPlantarPad] {
    guard digit.nodes.count > 1 else { return [] }
    return digit.nodes.dropFirst().enumerated().map { offset, node in
      let jointIndex = offset + 1
      let distalFraction = Float(jointIndex) / Float(digit.nodes.count - 1)
      let height: Float = 0.00135 - 0.00020 * distalFraction
      return CrowPlantarPad(
        digitNumber: digit.digitNumber,
        jointIndex: jointIndex,
        center: SIMD3<Float>(node.x, node.y, supportHeight + height),
        longitudinalRadiusMeters: 0.0036 - 0.0006 * distalFraction,
        lateralRadiusMeters: 0.0030 - 0.0005 * distalFraction,
        heightRadiusMeters: height
      )
    }
  }

  static func vertices(
    digit: CrowStandingDigitPose,
    supportHeight: Float,
    keratinColor: SIMD4<Float>,
    padColor: SIMD4<Float>,
    clawColor: SIMD4<Float>
  ) -> [ColoredVertex] {
    guard digit.nodes.count > 1 else { return [] }
    var result: [ColoredVertex] = []
    for segmentIndex in 0..<(digit.nodes.count - 1) {
      let baseRadius = digitBaseRadius(digit.digitNumber)
      let proximalRadius = max(
        0.00155,
        baseRadius * (1 - 0.11 * Float(segmentIndex))
      )
      let distalRadius = max(0.00125, 0.82 * proximalRadius)
      var start = digit.nodes[segmentIndex]
      var end = digit.nodes[segmentIndex + 1]
      start.z = max(start.z, supportHeight + 0.68 * proximalRadius)
      end.z = max(end.z, supportHeight + 0.68 * distalRadius)
      appendEllipticalSegment(
        from: start,
        to: end,
        startRadius: proximalRadius,
        endRadius: distalRadius,
        verticalScale: 0.72,
        color: keratinColor,
        radialSegments: phalanxRadialSegments,
        to: &result
      )
    }

    let pads = plantarPads(digit: digit, supportHeight: supportHeight)
    let planarDirection = distalPlanarDirection(digit)
    for pad in pads {
      appendEllipsoid(
        center: pad.center,
        longitudinalDirection: planarDirection,
        longitudinalRadius: pad.longitudinalRadiusMeters,
        lateralRadius: pad.lateralRadiusMeters,
        heightRadius: pad.heightRadiusMeters,
        color: padColor,
        to: &result
      )
    }

    let contactTip = digit.tip
    let clawBase = SIMD3<Float>(
      contactTip.x,
      contactTip.y,
      supportHeight + 0.00125
    )
    let clawKnee = clawBase + 0.0034 * planarDirection + SIMD3<Float>(0, 0, 0.00055)
    let clawTip = clawBase + 0.0072 * planarDirection + SIMD3<Float>(0, 0, -0.00105)
    appendEllipticalSegment(
      from: clawBase,
      to: clawKnee,
      startRadius: 0.00135,
      endRadius: 0.00085,
      verticalScale: 0.78,
      color: clawColor,
      radialSegments: 8,
      to: &result
    )
    appendEllipticalSegment(
      from: clawKnee,
      to: clawTip,
      startRadius: 0.00085,
      endRadius: 0.00018,
      verticalScale: 0.78,
      color: clawColor,
      radialSegments: 8,
      to: &result
    )
    for index in result.indices {
      result[index].parameters.w = Float(surfaceIdentityClassCode)
    }
    return result
  }

  private static func digitBaseRadius(_ digitNumber: Int) -> Float {
    switch digitNumber {
    case 1: return 0.00305
    case 2: return 0.00310
    case 3: return 0.00335
    case 4: return 0.00300
    default: return 0.00300
    }
  }

  private static func distalPlanarDirection(
    _ digit: CrowStandingDigitPose
  ) -> SIMD3<Float> {
    let penultimate = digit.nodes[digit.nodes.count - 2]
    let raw = SIMD3<Float>(digit.tip.x - penultimate.x, digit.tip.y - penultimate.y, 0)
    return normalized(raw, fallback: SIMD3<Float>(1, 0, 0))
  }

  private static func appendEllipticalSegment(
    from start: SIMD3<Float>,
    to end: SIMD3<Float>,
    startRadius: Float,
    endRadius: Float,
    verticalScale: Float,
    color: SIMD4<Float>,
    radialSegments: Int,
    to result: inout [ColoredVertex]
  ) {
    let axis = normalized(end - start, fallback: SIMD3<Float>(1, 0, 0))
    let projectedUp = SIMD3<Float>(0, 0, 1) - axis.z * axis
    let vertical = normalized(projectedUp, fallback: SIMD3<Float>(0, 1, 0))
    let lateral = normalized(
      simd_cross(vertical, axis),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    var positions: [SIMD3<Float>] = []
    positions.reserveCapacity(phalanxAxialStations * radialSegments)
    for stationIndex in 0..<phalanxAxialStations {
      let fraction = Float(stationIndex) / Float(phalanxAxialStations - 1)
      let baseRadius = startRadius + fraction * (endRadius - startRadius)
      let bulgedRadius = baseRadius * (1 + 0.10 * sin(Float.pi * fraction))
      let center = start + fraction * (end - start)
      for radialIndex in 0..<radialSegments {
        let angle = 2 * Float.pi * Float(radialIndex) / Float(radialSegments)
        positions.append(
          center
            + cos(angle) * bulgedRadius * lateral
            + sin(angle) * verticalScale * bulgedRadius * vertical
        )
      }
    }
    appendLoft(
      positions: positions,
      ringCount: phalanxAxialStations,
      radialSegments: radialSegments,
      fallbackNormal: vertical,
      color: color,
      to: &result
    )
  }

  private static func appendEllipsoid(
    center: SIMD3<Float>,
    longitudinalDirection: SIMD3<Float>,
    longitudinalRadius: Float,
    lateralRadius: Float,
    heightRadius: Float,
    color: SIMD4<Float>,
    to result: inout [ColoredVertex]
  ) {
    let longitudinal = normalized(
      SIMD3<Float>(longitudinalDirection.x, longitudinalDirection.y, 0),
      fallback: SIMD3<Float>(1, 0, 0)
    )
    let lateral = SIMD3<Float>(-longitudinal.y, longitudinal.x, 0)
    let vertical = SIMD3<Float>(0, 0, 1)
    for latitudeIndex in 0..<padLatitudeIntervals {
      let firstLatitude =
        -Float.pi / 2 + Float.pi * Float(latitudeIndex) / Float(padLatitudeIntervals)
      let secondLatitude =
        -Float.pi / 2 + Float.pi * Float(latitudeIndex + 1) / Float(padLatitudeIntervals)
      for longitudeIndex in 0..<padLongitudeSegments {
        let firstLongitude =
          2 * Float.pi * Float(longitudeIndex) / Float(padLongitudeSegments)
        let secondLongitude =
          2 * Float.pi * Float(longitudeIndex + 1) / Float(padLongitudeSegments)
        let corners = [
          ellipsoidPoint(
            latitude: firstLatitude,
            longitude: firstLongitude,
            center: center,
            longitudinal: longitudinal,
            lateral: lateral,
            vertical: vertical,
            radii: SIMD3<Float>(longitudinalRadius, lateralRadius, heightRadius)
          ),
          ellipsoidPoint(
            latitude: secondLatitude,
            longitude: firstLongitude,
            center: center,
            longitudinal: longitudinal,
            lateral: lateral,
            vertical: vertical,
            radii: SIMD3<Float>(longitudinalRadius, lateralRadius, heightRadius)
          ),
          ellipsoidPoint(
            latitude: secondLatitude,
            longitude: secondLongitude,
            center: center,
            longitudinal: longitudinal,
            lateral: lateral,
            vertical: vertical,
            radii: SIMD3<Float>(longitudinalRadius, lateralRadius, heightRadius)
          ),
          ellipsoidPoint(
            latitude: firstLatitude,
            longitude: secondLongitude,
            center: center,
            longitudinal: longitudinal,
            lateral: lateral,
            vertical: vertical,
            radii: SIMD3<Float>(longitudinalRadius, lateralRadius, heightRadius)
          ),
        ]
        for index in [0, 1, 2, 0, 2, 3] {
          result.append(
            ColoredVertex(
              position: SIMD4<Float>(corners[index].position, 1),
              normal: SIMD4<Float>(corners[index].normal, 0),
              color: color
            )
          )
        }
      }
    }
  }

  private static func ellipsoidPoint(
    latitude: Float,
    longitude: Float,
    center: SIMD3<Float>,
    longitudinal: SIMD3<Float>,
    lateral: SIMD3<Float>,
    vertical: SIMD3<Float>,
    radii: SIMD3<Float>
  ) -> (position: SIMD3<Float>, normal: SIMD3<Float>) {
    let cosineLatitude = cos(latitude)
    let local = SIMD3<Float>(
      cosineLatitude * cos(longitude),
      cosineLatitude * sin(longitude),
      sin(latitude)
    )
    let position = center
      + radii.x * local.x * longitudinal
      + radii.y * local.y * lateral
      + radii.z * local.z * vertical
    let normal = normalized(
      local.x / radii.x * longitudinal
        + local.y / radii.y * lateral
        + local.z / radii.z * vertical,
      fallback: vertical
    )
    return (position, normal)
  }

  private static func appendLoft(
    positions: [SIMD3<Float>],
    ringCount: Int,
    radialSegments: Int,
    fallbackNormal: SIMD3<Float>,
    color: SIMD4<Float>,
    to result: inout [ColoredVertex]
  ) {
    var normals = [SIMD3<Float>](repeating: .zero, count: positions.count)
    var triangles: [SIMD3<Int>] = []
    triangles.reserveCapacity((ringCount - 1) * radialSegments * 2)
    for ringIndex in 0..<(ringCount - 1) {
      for radialIndex in 0..<radialSegments {
        let next = (radialIndex + 1) % radialSegments
        let a = ringIndex * radialSegments + radialIndex
        let b = (ringIndex + 1) * radialSegments + radialIndex
        let c = (ringIndex + 1) * radialSegments + next
        let d = ringIndex * radialSegments + next
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
    for triangle in triangles {
      for index in [triangle.x, triangle.y, triangle.z] {
        result.append(
          ColoredVertex(
            position: SIMD4<Float>(positions[index], 1),
            normal: SIMD4<Float>(
              normalized(normals[index], fallback: fallbackNormal),
              0
            ),
            color: color
          )
        )
      }
    }
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-10 ? value / length : fallback
  }
}
