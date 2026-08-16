import simd

enum CrowFeatherMesostructureKind: UInt8, CaseIterable {
  case rachis
  case edgeBarbGroup
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
  static let bodyContourEdgeDetailThresholdPixels: Float = 96

  static func segments(
    for feather: CrowBodyContourShingle,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    guard
      feather.referenceLengthMeters * projectedPixelsPerMeter
        >= bodyContourEdgeDetailThresholdPixels
    else { return [] }
    return segments(
      frame: Frame(feather: feather),
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
  }

  static func segments(
    for feather: CrowBodyFeatherTractSample,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    segments(
      frame: Frame(feather: feather),
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
  }

  static func segments(
    for feather: CrowVentralFeatherTractSample,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    segments(
      frame: Frame(feather: feather),
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
  }

  static func segments(
    for feather: CrowCaudalCovertCollarSample,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    segments(
      frame: Frame(feather: feather),
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
  }

  private static func segments(
    frame: Frame,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    let tessellation = CrowFeatherCoverageLOD.tessellation(
      lengthMeters: frame.referenceLengthMeters,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      baseAxialSections: 7
    )
    guard tessellation.rachisSections > 0 else { return [] }

    var result: [CrowFeatherMesostructureSegment] = []
    result.reserveCapacity(
      tessellation.rachisSections
        + 2 * tessellation.edgeBarbPairs
        * (1 + tessellation.barbulesPerBarb)
        + (tessellation.edgeBarbPairs > 0 ? 5 : 0)
    )
    appendRachis(
      sections: tessellation.rachisSections,
      frame: frame,
      to: &result
    )
    appendBarbs(
      pairCount: tessellation.barbPairs,
      edgePairCount: tessellation.edgeBarbPairs,
      barbulesPerBarb: tessellation.barbulesPerBarb,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      frame: frame,
      to: &result
    )
    return result
  }

  private struct Frame {
    let root: SIMD3<Float>
    let tip: SIMD3<Float>
    let referenceLengthMeters: Float
    let direction: SIMD3<Float>
    let normal: SIMD3<Float>
    let widthAxis: SIMD3<Float>
    let rootWidthMeters: Float
    let maximumWidthMeters: Float
    let camberMeters: Float
    let rootEnvelopeRatio: Float
    let pennaceousStartFraction: Float
    let vaneAsymmetry: Float
    let edgeRippleAmplitude: Float
    let edgeRipplePhase: Float
    let edgeRippleCycles: Float
    let identityFirst: Int
    let identitySecond: Int

    init(feather: CrowBodyContourShingle) {
      root = feather.rootOffset
      tip = feather.tipOffset
      referenceLengthMeters = feather.referenceLengthMeters
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
      rootWidthMeters = feather.rootWidthMeters
      maximumWidthMeters = feather.maximumWidthMeters
      camberMeters = feather.camberMeters
      rootEnvelopeRatio = 0.32
      pennaceousStartFraction = feather.pennaceousStartFraction
      vaneAsymmetry = feather.vaneAsymmetry
      edgeRippleAmplitude = feather.edgeRippleAmplitude
      edgeRipplePhase = feather.edgeRipplePhase
      edgeRippleCycles = feather.edgeRippleCycles
      identityFirst = feather.radialIndex
      identitySecond = feather.axialIndex
    }

    init(feather: CrowBodyFeatherTractSample) {
      root = feather.rootOffset
      tip = feather.tipOffset
      referenceLengthMeters = simd_distance(feather.rootOffset, feather.tipOffset)
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
      rootWidthMeters = feather.rootWidthMeters
      maximumWidthMeters = feather.maximumWidthMeters
      camberMeters = feather.camberMeters
      rootEnvelopeRatio = feather.rootEnvelopeRatio
      pennaceousStartFraction = feather.pennaceousStartFraction
      vaneAsymmetry = feather.vaneAsymmetry
      edgeRippleAmplitude = feather.edgeRippleAmplitude
      edgeRipplePhase = feather.edgeRipplePhase
      edgeRippleCycles = feather.edgeRippleCycles
      identityFirst = feather.row + 31 * Int(feather.region.rawValue)
      identitySecond = feather.column + (feather.side < 0 ? 97 : 0)
    }

    init(feather: CrowVentralFeatherTractSample) {
      root = feather.rootOffset
      tip = feather.tipOffset
      referenceLengthMeters = simd_distance(feather.rootOffset, feather.tipOffset)
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
      rootWidthMeters = feather.rootWidthMeters
      maximumWidthMeters = feather.maximumWidthMeters
      camberMeters = feather.camberMeters
      rootEnvelopeRatio = feather.rootEnvelopeRatio
      pennaceousStartFraction = feather.pennaceousStartFraction
      vaneAsymmetry = feather.vaneAsymmetry
      edgeRippleAmplitude = feather.edgeRippleAmplitude
      edgeRipplePhase = feather.edgeRipplePhase
      edgeRippleCycles = feather.edgeRippleCycles
      identityFirst = feather.row + 41 * Int(feather.region.rawValue)
      identitySecond = feather.column + (feather.side < 0 ? 131 : 0)
    }

    init(feather: CrowCaudalCovertCollarSample) {
      root = feather.rootOffset
      tip = feather.tipOffset
      referenceLengthMeters = simd_distance(feather.rootOffset, feather.tipOffset)
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
      rootWidthMeters = feather.rootWidthMeters
      maximumWidthMeters = feather.maximumWidthMeters
      camberMeters = feather.camberMeters
      rootEnvelopeRatio = feather.rootEnvelopeRatio
      pennaceousStartFraction = 0
      vaneAsymmetry = feather.vaneAsymmetry
      edgeRippleAmplitude = feather.edgeRippleAmplitude
      edgeRipplePhase = feather.edgeRipplePhase
      edgeRippleCycles = feather.edgeRippleCycles
      identityFirst = feather.rank
      identitySecond = feather.row
    }

    func center(at axial: Float) -> SIMD3<Float> {
      let t = clamp(axial)
      return root
        + (tip - root) * t
        + normal * (camberMeters * sin(Float.pi * t) + 0.00012)
    }

    func halfWidth(at axial: Float, signedWidth: Float = 0) -> Float {
      let t = clamp(axial)
      let bodyEnvelope = rootEnvelopeRatio
        + (1 - rootEnvelopeRatio) * pow(max(sin(Float.pi * t), 0), 0.58)
      let tipTaper = 1 - 0.985 * pow(t, 3.2)
      let rippleEnvelope = pow(max(sin(Float.pi * t), 0), 2)
      let edgeRipple =
        1
        + edgeRippleAmplitude
        * sin(2 * Float.pi * edgeRippleCycles * t + edgeRipplePhase)
        * rippleEnvelope
      let sideScale = 1 + vaneAsymmetry * min(max(signedWidth, -1), 1)
      return
        (rootWidthMeters * (1 - t) + maximumWidthMeters * t)
        * bodyEnvelope * tipTaper * edgeRipple * sideScale
    }

    func pennaceousAxial(at localFraction: Float) -> Float {
      pennaceousStartFraction
        + (1 - pennaceousStartFraction) * clamp(localFraction)
    }
  }

  private static func appendRachis(
    sections: Int,
    frame: Frame,
    to result: inout [CrowFeatherMesostructureSegment]
  ) {
    for section in 0..<sections {
      let first = frame.pennaceousAxial(
        at: Float(section) / Float(sections)
      )
      let second = frame.pennaceousAxial(
        at: Float(section + 1) / Float(sections)
      )
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
    edgePairCount: Int,
    barbulesPerBarb: Int,
    projectedPixelsPerMeter: Float,
    frame: Frame,
    to result: inout [CrowFeatherMesostructureSegment]
  ) {
    guard edgePairCount > 0 else { return }
    let coarseEdgeOnly = pairCount == 0
    let safePixelsPerMeter = max(projectedPixelsPerMeter, 1)
    let aggregateRadius = min(0.00020, max(0.000035, 0.30 / safePixelsPerMeter))
    let baseExtension = min(0.0012, max(0.00050, 1.10 / safePixelsPerMeter))
    for pair in 0..<edgePairCount {
      let localAxial = 0.10 + 0.77 * Float(pair + 1) / Float(edgePairCount + 1)
      let axial = frame.pennaceousAxial(at: localAxial)
      let reachAxial = frame.pennaceousAxial(
        at: min(0.94, localAxial + 0.035 + 0.020 * localAxial)
      )
      for side: Float in [-1, 1] {
        let identity = sin(
          Float(frame.identityFirst + 1) * 12.9898
            + Float(frame.identitySecond + 1) * 78.233
            + Float(pair + 1) * 37.719
            + side * 1.371
        )
        let start =
          frame.center(at: axial)
          + side * frame.widthAxis * frame.halfWidth(at: axial, signedWidth: side)
            * (coarseEdgeOnly ? 0.72 : 0)
          + frame.normal * (coarseEdgeOnly ? 0.00010 : 0.00005)
        let edgeExtension = baseExtension * (0.86 + 0.14 * identity)
        let end =
          frame.center(at: reachAxial)
          + side * frame.widthAxis
            * (frame.halfWidth(at: reachAxial, signedWidth: side) + edgeExtension)
          + frame.normal * (coarseEdgeOnly ? 0.00018 : 0.00008)
        result.append(
          CrowFeatherMesostructureSegment(
            kind: coarseEdgeOnly ? .edgeBarbGroup : .barb,
            start: start,
            end: end,
            startRadiusMeters: coarseEdgeOnly ? aggregateRadius : 0.000050,
            endRadiusMeters: coarseEdgeOnly ? 0.58 * aggregateRadius : 0.000018
          )
        )
        if !coarseEdgeOnly {
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
    appendTerminalBarbGroups(
      radius: aggregateRadius,
      extensionMeters: baseExtension,
      frame: frame,
      to: &result
    )
  }

  /// Five overlapping terminal bundles break the single geometric point of
  /// the closed vane. Their roots remain on the vane and their tips extend by
  /// less than a millimetre at showcase coverage; they are a raster-scale
  /// aggregate, not a claim that individual barbs are resolved.
  private static func appendTerminalBarbGroups(
    radius: Float,
    extensionMeters: Float,
    frame: Frame,
    to result: inout [CrowFeatherMesostructureSegment]
  ) {
    let rootAxial: Float = 0.88
    let rootHalfWidth = frame.halfWidth(at: rootAxial)
    for lane: Float in [-1, -0.5, 0, 0.5, 1] {
      let root =
        frame.center(at: rootAxial)
        + lane * frame.widthAxis * rootHalfWidth * 0.42
        + frame.normal * 0.00012
      let laneIdentity = sin(
        Float(frame.identityFirst + 1) * 17.117
          + Float(frame.identitySecond + 1) * 43.731
          + lane * 2.913
      )
      let tip =
        frame.tip
        + frame.direction * extensionMeters * (0.82 + 0.12 * laneIdentity)
        + lane * frame.widthAxis * 0.18 * rootHalfWidth
        + frame.normal * 0.00020
      result.append(
        CrowFeatherMesostructureSegment(
          kind: .edgeBarbGroup,
          start: root,
          end: tip,
          startRadiusMeters: 0.88 * radius,
          endRadiusMeters: 0.50 * radius
        )
      )
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
