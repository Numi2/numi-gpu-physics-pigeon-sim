import simd

enum CrowFeatherMesostructureKind: UInt8, CaseIterable {
  case rachis
  case barb
  case barbule
}

struct CrowFeatherMesostructureSegment: Equatable {
  let kind: CrowFeatherMesostructureKind
  let start: SIMD3<Float>
  let end: SIMD3<Float>
  let startRadiusMeters: Float
  let endRadiusMeters: Float
}

/// Hierarchical feather detail derived from the same root, tip, plane, and
/// envelope that own the visible vane. Final-output coverage controls whether
/// the representation stops at its silhouette, exposes its rachis, resolves
/// paired barbs, or spends close-up compute on interlocking barbules.
enum CrowFeatherMesostructure {
  static func segments(
    for feather: CrowBodyContourShingle,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    let length = simd_distance(feather.rootOffset, feather.tipOffset)
    let tessellation = CrowFeatherCoverageLOD.tessellation(
      lengthMeters: length,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      baseAxialSections: 7
    )
    guard tessellation.rachisSections > 0 else { return [] }

    let frame = Frame(feather: feather)
    var result: [CrowFeatherMesostructureSegment] = []
    result.reserveCapacity(
      tessellation.rachisSections
        + 2 * tessellation.barbPairs
          * (1 + tessellation.barbulesPerBarb)
    )
    appendRachis(
      sections: tessellation.rachisSections,
      frame: frame,
      to: &result
    )
    appendBarbs(
      pairCount: tessellation.barbPairs,
      barbulesPerBarb: tessellation.barbulesPerBarb,
      frame: frame,
      to: &result
    )
    return result
  }

  private struct Frame {
    let feather: CrowBodyContourShingle
    let direction: SIMD3<Float>
    let normal: SIMD3<Float>
    let widthAxis: SIMD3<Float>

    init(feather: CrowBodyContourShingle) {
      self.feather = feather
      direction = normalized(
        feather.tipOffset - feather.rootOffset,
        fallback: SIMD3<Float>(-1, 0, 0)
      )
      normal = normalized(
        feather.planeNormal
          - direction * simd_dot(feather.planeNormal, direction),
        fallback: feather.planeNormal
      )
      widthAxis = normalized(
        simd_cross(normal, direction),
        fallback: SIMD3<Float>(0, 1, 0)
      )
    }

    func center(at axial: Float) -> SIMD3<Float> {
      let t = clamp(axial)
      return feather.rootOffset
        + (feather.tipOffset - feather.rootOffset) * t
        + normal * (feather.camberMeters * sin(Float.pi * t) + 0.00012)
    }

    func halfWidth(at axial: Float) -> Float {
      let t = clamp(axial)
      let bodyEnvelope = 0.32 + 0.68 * pow(max(sin(Float.pi * t), 0), 0.58)
      let tipTaper = 1 - 0.985 * pow(t, 3.2)
      return (
        feather.rootWidthMeters * (1 - t)
          + feather.maximumWidthMeters * t
      ) * bodyEnvelope * tipTaper
    }
  }

  private static func appendRachis(
    sections: Int,
    frame: Frame,
    to result: inout [CrowFeatherMesostructureSegment]
  ) {
    for section in 0..<sections {
      let first = Float(section) / Float(sections)
      let second = Float(section + 1) / Float(sections)
      result.append(
        CrowFeatherMesostructureSegment(
          kind: .rachis,
          start: frame.center(at: first),
          end: frame.center(at: second),
          startRadiusMeters: mix(0.00022, 0.000055, first),
          endRadiusMeters: mix(0.00022, 0.000055, second)
        )
      )
    }
  }

  private static func appendBarbs(
    pairCount: Int,
    barbulesPerBarb: Int,
    frame: Frame,
    to result: inout [CrowFeatherMesostructureSegment]
  ) {
    guard pairCount > 0 else { return }
    for pair in 0..<pairCount {
      let axial = 0.10 + 0.77 * Float(pair + 1) / Float(pairCount + 1)
      let reachAxial = min(0.94, axial + 0.035 + 0.020 * axial)
      let start = frame.center(at: axial)
      for side: Float in [-1, 1] {
        let end =
          frame.center(at: reachAxial)
          + side * frame.widthAxis * frame.halfWidth(at: reachAxial) * 0.94
          + frame.normal * 0.00005
        result.append(
          CrowFeatherMesostructureSegment(
            kind: .barb,
            start: start,
            end: end,
            startRadiusMeters: 0.000050,
            endRadiusMeters: 0.000018
          )
        )
        appendBarbules(
          count: barbulesPerBarb,
          side: side,
          start: start,
          end: end,
          frame: frame,
          to: &result
        )
      }
    }
  }

  private static func appendBarbules(
    count: Int,
    side: Float,
    start: SIMD3<Float>,
    end: SIMD3<Float>,
    frame: Frame,
    to result: inout [CrowFeatherMesostructureSegment]
  ) {
    guard count > 0 else { return }
    let barbDirection = normalized(end - start, fallback: side * frame.widthAxis)
    let barbLength = simd_distance(start, end)
    let barbuleLength = min(0.0014, 0.22 * barbLength)
    for index in 0..<count {
      let fraction = Float(index + 1) / Float(count + 1)
      let root = mix(start, end, fraction)
      let hookDirection = normalized(
        0.82 * frame.direction - 0.24 * side * frame.widthAxis
          + 0.10 * barbDirection,
        fallback: frame.direction
      )
      result.append(
        CrowFeatherMesostructureSegment(
          kind: .barbule,
          start: root,
          end: root + barbuleLength * hookDirection,
          startRadiusMeters: 0.000014,
          endRadiusMeters: 0.000006
        )
      )
    }
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-9 ? value / length : fallback
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

  private static func clamp(_ value: Float) -> Float {
    min(max(value, 0), 1)
  }
}
