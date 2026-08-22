import simd

enum CrowFeatherMesostructureKind: UInt8, CaseIterable {
  case rachis
  case edgeBarbGroup
  case barb
  case barbule
  case plumulaceousBarb
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
  static let dorsalBodyContourDetailThresholdPixels: Float = 48
  static let dorsalBodyContourInteriorBarbStartAxialFraction: Float = 0.45
  static let shoulderInteriorBarbThresholdPixels: Float = 40
  static let bodyTractResolvedRachisWidthThresholdPixels: Float = 24
  static let bodyTractBarbStationJitterFractionOfSpacing: Float = 0.18
  static let bodyTractTerminalRootAxialJitter: Float = 0.022

  static func segments(
    for feather: CrowBodyContourShingle,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    let threshold =
      feather.region == .dorsal
      ? dorsalBodyContourDetailThresholdPixels
      : bodyContourEdgeDetailThresholdPixels
    guard
      feather.referenceLengthMeters * projectedPixelsPerMeter
        >= threshold
    else { return [] }
    let axial = Float(feather.axialIndex)
      / Float(CrowBodyContourShingles.axialCount - 1)
    let promoteInteriorBarbs =
      feather.region == .dorsal
      && axial >= dorsalBodyContourInteriorBarbStartAxialFraction
      && feather.referenceLengthMeters * projectedPixelsPerMeter
        >= dorsalBodyContourDetailThresholdPixels
    return segments(
      frame: Frame(feather: feather),
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      promoteInteriorBarbs: promoteInteriorBarbs
    )
  }

  static func segments(
    for feather: CrowBodyFeatherTractSample,
    projectedPixelsPerMeter: Float,
    camberScale: Float = 1,
    transverseCamberRatio: Float? = nil
  ) -> [CrowFeatherMesostructureSegment] {
    let resolvedTransverseCamberRatio =
      transverseCamberRatio
      ?? CrowBodyFeatherTracts.transverseCamberRatio(
        region: feather.region,
        row: feather.row,
        transitionProgress: 0
      )
    var resolved = segments(
      frame: Frame(
        feather: feather,
        camberScale: camberScale,
        transverseCamberRatio: resolvedTransverseCamberRatio
      ),
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      containPromotedInteriorBarbs: true,
      barbStationJitterFractionOfSpacing:
        bodyTractBarbStationJitterFractionOfSpacing,
      terminalRootAxialJitter: bodyTractTerminalRootAxialJitter,
      promoteInteriorBarbs: (feather.region == .humeral || feather.region == .scapular)
        && simd_distance(feather.rootOffset, feather.tipOffset)
          * projectedPixelsPerMeter >= shoulderInteriorBarbThresholdPixels
    )
    if !resolved.isEmpty {
      appendBodyPlumulaceousBarbs(
        frame: Frame(
          feather: feather,
          camberScale: camberScale,
          transverseCamberRatio: resolvedTransverseCamberRatio
        ),
        to: &resolved
      )
    }
    let projectedVaneWidth = 2 * feather.maximumWidthMeters
      * projectedPixelsPerMeter
    guard
      projectedVaneWidth
        < bodyTractResolvedRachisWidthThresholdPixels
    else { return resolved }
    return resolved.filter { $0.kind != .rachis }
  }

  static func segments(
    for feather: CrowVentralFeatherTractSample,
    projectedPixelsPerMeter: Float,
    transverseCamberRatio: Float? = nil
  ) -> [CrowFeatherMesostructureSegment] {
    let resolvedTransverseCamberRatio = transverseCamberRatio
      ?? (CrowVentralFeatherTracts.retainsCrownRachis(feather)
        ? CrowVentralFeatherTracts.retainedRachisTransverseCamberRatio
          * CrowVentralFeatherTracts.transverseCamberScale(for: feather)
        : 0)
    // Preserve a subvane continuity shaft as a deterministic occluded oracle;
    // eligible interior feathers add a second shaft on the visible crown.
    let continuity = segments(
      frame: Frame(
        feather: feather,
        transverseCamberRatio: 0
      ),
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
    guard resolvedTransverseCamberRatio > 0 else { return continuity }
    let crownRachis = segments(
      frame: Frame(
        feather: feather,
        transverseCamberRatio: resolvedTransverseCamberRatio
      ),
      projectedPixelsPerMeter: projectedPixelsPerMeter
    ).filter { $0.kind == .rachis }
    return continuity + crownRachis
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

  static func segments(
    for feather: CrowRumpTailContourFeatherSample,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    segments(
      frame: Frame(feather: feather),
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
  }

  static func segments(
    for feather: CrowFemoralPlumageFeather,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    segments(
      frame: Frame(feather: feather),
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      lodLengthMeters: CrowFemoralPlumage.topologyLODReferenceLengthMeters
    )
  }

  private static func segments(
    frame: Frame,
    projectedPixelsPerMeter: Float,
    lodLengthMeters: Float? = nil,
    containPromotedInteriorBarbs: Bool = false,
    barbStationJitterFractionOfSpacing: Float = 0,
    terminalRootAxialJitter: Float = 0,
    promoteInteriorBarbs: Bool = false
  ) -> [CrowFeatherMesostructureSegment] {
    let tessellation = CrowFeatherCoverageLOD.tessellation(
      lengthMeters: lodLengthMeters ?? frame.referenceLengthMeters,
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
      pairCount: promoteInteriorBarbs
        ? max(tessellation.barbPairs, tessellation.edgeBarbPairs)
        : tessellation.barbPairs,
      edgePairCount: tessellation.edgeBarbPairs,
      barbulesPerBarb: tessellation.barbulesPerBarb,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      containPromotedInteriorBarbs: containPromotedInteriorBarbs,
      stationJitterFractionOfSpacing: barbStationJitterFractionOfSpacing,
      terminalRootAxialJitter: terminalRootAxialJitter,
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
    let lateralSweepMeters: Float
    let transverseCamberRatio: Float
    let barbTransverseCamberRatio: Float
    let rootEnvelopeRatio: Float
    let terminalWidthRatio: Float
    let distalTaperExponent: Float
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
      lateralSweepMeters = feather.lateralSweepMeters
      transverseCamberRatio = 0
      barbTransverseCamberRatio = 0
      rootEnvelopeRatio = 0.32
      terminalWidthRatio = 0.015
      distalTaperExponent = 3.2
      pennaceousStartFraction = feather.pennaceousStartFraction
      vaneAsymmetry = feather.vaneAsymmetry
      edgeRippleAmplitude = feather.edgeRippleAmplitude
      edgeRipplePhase = feather.edgeRipplePhase
      edgeRippleCycles = feather.edgeRippleCycles
      identityFirst = feather.radialIndex
      identitySecond = feather.axialIndex
    }

    init(
      feather: CrowBodyFeatherTractSample,
      camberScale: Float = 1,
      transverseCamberRatio: Float
    ) {
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
      camberMeters = feather.camberMeters * camberScale
      lateralSweepMeters = feather.lateralSweepMeters
      self.transverseCamberRatio = transverseCamberRatio
      barbTransverseCamberRatio = transverseCamberRatio
      rootEnvelopeRatio = feather.rootEnvelopeRatio
      terminalWidthRatio = feather.terminalWidthRatio
      distalTaperExponent = feather.distalTaperExponent
      pennaceousStartFraction = feather.pennaceousStartFraction
      vaneAsymmetry = feather.vaneAsymmetry
      edgeRippleAmplitude = feather.edgeRippleAmplitude
      edgeRipplePhase = feather.edgeRipplePhase
      edgeRippleCycles = feather.edgeRippleCycles
      identityFirst = feather.row + 31 * Int(feather.region.rawValue)
      identitySecond = feather.column + (feather.side < 0 ? 97 : 0)
    }

    init(
      feather: CrowVentralFeatherTractSample,
      transverseCamberRatio: Float
    ) {
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
      lateralSweepMeters = feather.lateralSweepMeters
      self.transverseCamberRatio = transverseCamberRatio
      barbTransverseCamberRatio = 0
      rootEnvelopeRatio = feather.rootEnvelopeRatio
      terminalWidthRatio = 0.015
      distalTaperExponent = 3.2
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
      lateralSweepMeters = 0
      transverseCamberRatio = 0
      barbTransverseCamberRatio = 0
      rootEnvelopeRatio = feather.rootEnvelopeRatio
      terminalWidthRatio = 0.015
      distalTaperExponent = 3.2
      pennaceousStartFraction = 0
      vaneAsymmetry = feather.vaneAsymmetry
      edgeRippleAmplitude = feather.edgeRippleAmplitude
      edgeRipplePhase = feather.edgeRipplePhase
      edgeRippleCycles = feather.edgeRippleCycles
      identityFirst = feather.rank
      identitySecond = feather.row
    }

    init(feather: CrowRumpTailContourFeatherSample) {
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
      lateralSweepMeters = 0
      transverseCamberRatio = 0
      barbTransverseCamberRatio = 0
      rootEnvelopeRatio = feather.rootEnvelopeRatio
      terminalWidthRatio = 0.015
      distalTaperExponent = 3.2
      pennaceousStartFraction = 0
      vaneAsymmetry = feather.vaneAsymmetry
      edgeRippleAmplitude = feather.edgeRippleAmplitude
      edgeRipplePhase = feather.edgeRipplePhase
      edgeRippleCycles = feather.edgeRippleCycles
      identityFirst = feather.row
      identitySecond = feather.column
    }

    init(feather: CrowFemoralPlumageFeather) {
      root = feather.root
      tip = feather.tip
      referenceLengthMeters = simd_distance(feather.root, feather.tip)
      direction = normalized(
        feather.tip - feather.root,
        fallback: SIMD3<Float>(0, 0, -1)
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
      lateralSweepMeters = feather.lateralSweepMeters
      transverseCamberRatio = 0
      barbTransverseCamberRatio = 0
      rootEnvelopeRatio = feather.rootEnvelopeRatio
      terminalWidthRatio = 0.015
      distalTaperExponent = 3.2
      pennaceousStartFraction = feather.pennaceousStartFraction
      vaneAsymmetry = feather.vaneAsymmetry
      edgeRippleAmplitude = feather.edgeRippleAmplitude
      edgeRipplePhase = feather.edgeRipplePhase
      edgeRippleCycles = feather.edgeRippleCycles
      identityFirst = feather.row
      identitySecond = feather.course
    }

    func center(at axial: Float) -> SIMD3<Float> {
      center(at: axial, transverseCamberRatio: transverseCamberRatio)
    }

    func barbCenter(at axial: Float) -> SIMD3<Float> {
      center(at: axial, transverseCamberRatio: barbTransverseCamberRatio)
    }

    private func center(
      at axial: Float,
      transverseCamberRatio: Float
    ) -> SIMD3<Float> {
      let t = clamp(axial)
      return root
        + (tip - root) * t
        + widthAxis * (lateralSweepMeters * sin(Float.pi * t))
        + normal
        * (camberMeters * sin(Float.pi * t)
          + transverseCamberRatio * halfWidth(at: t)
          + 0.00012)
    }

    func halfWidth(at axial: Float, signedWidth: Float = 0) -> Float {
      let t = clamp(axial)
      let bodyEnvelope =
        rootEnvelopeRatio
        + (1 - rootEnvelopeRatio) * pow(max(sin(Float.pi * t), 0), 0.58)
      let tipTaper = 1
        - (1 - terminalWidthRatio) * pow(t, distalTaperExponent)
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
    containPromotedInteriorBarbs: Bool,
    stationJitterFractionOfSpacing: Float,
    terminalRootAxialJitter: Float,
    frame: Frame,
    to result: inout [CrowFeatherMesostructureSegment]
  ) {
    guard edgePairCount > 0 else { return }
    let coarseEdgeOnly = pairCount == 0
    let containInteriorDetail = containPromotedInteriorBarbs && !coarseEdgeOnly
    let safePixelsPerMeter = max(projectedPixelsPerMeter, 1)
    let aggregateRadius = min(0.00020, max(0.000035, 0.30 / safePixelsPerMeter))
    let baseExtension = min(0.0012, max(0.00050, 1.10 / safePixelsPerMeter))
    let stationSpacing = 0.77 / Float(edgePairCount + 1)
    let boundedStationJitter = min(
      max(stationJitterFractionOfSpacing, 0),
      0.49
    )
    for pair in 0..<edgePairCount {
      let featherPhase =
        Float(frame.identityFirst + 1) * Float(19.193)
        + Float(frame.identitySecond + 1) * Float(47.117)
      let stationPhase = Float(pair + 1) * Float(11.731)
      let stationIdentity = sin(featherPhase + stationPhase)
      let localAxial =
        0.10 + stationSpacing * Float(pair + 1)
        + boundedStationJitter * stationSpacing * stationIdentity
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
          frame.barbCenter(at: axial)
          + side * frame.widthAxis * frame.halfWidth(at: axial, signedWidth: side)
          * (coarseEdgeOnly ? 0.72 : 0)
          + frame.normal * (coarseEdgeOnly ? 0.00010 : 0.00005)
        let edgeExtension = baseExtension * (0.86 + 0.14 * identity)
        let reachHalfWidth = frame.halfWidth(
          at: reachAxial,
          signedWidth: side
        )
        let lateralReach = containInteriorDetail
          ? 0.97 * reachHalfWidth
          : reachHalfWidth + edgeExtension
        let end =
          frame.barbCenter(at: reachAxial)
          + side * frame.widthAxis
          * lateralReach
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
      rootAxialJitter: terminalRootAxialJitter,
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
    rootAxialJitter: Float,
    frame: Frame,
    to result: inout [CrowFeatherMesostructureSegment]
  ) {
    let boundedRootAxialJitter = min(max(rootAxialJitter, 0), 0.04)
    let tipReferenceHalfWidth = frame.halfWidth(at: 0.88)
    for lane: Float in [-1, -0.5, 0, 0.5, 1] {
      let featherPhase =
        Float(frame.identityFirst + 1) * Float(23.417)
        + Float(frame.identitySecond + 1) * Float(51.193)
      let lanePhase = lane * Float(5.173)
      let rootIdentity = sin(featherPhase + lanePhase)
      let rootAxial = 0.88 + boundedRootAxialJitter * rootIdentity
      let rootHalfWidth = frame.halfWidth(at: rootAxial)
      let root =
        frame.barbCenter(at: rootAxial)
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
        + lane * frame.widthAxis * 0.18 * tipReferenceHalfWidth
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

  /// Three bilateral, piecewise-curved basal barb pairs provide a dark,
  /// compliant-looking underlayer when neighboring body vanes separate.
  /// Their density and reach are renderer estimates; every node remains well
  /// inside the accepted vane envelope and therefore cannot alter its outline.
  private static func appendBodyPlumulaceousBarbs(
    frame: Frame,
    to result: inout [CrowFeatherMesostructureSegment]
  ) {
    for pair in 0..<3 {
      for side: Float in [-1, 1] {
        let identity = sin(
          Float(frame.identityFirst + 1) * 15.317
            + Float(frame.identitySecond + 1) * 39.173
            + Float(pair + 1) * 7.139
            + side * 1.913
        )
        let startAxial = 0.045 + 0.025 * Float(pair) + 0.008 * identity
        let endAxial = 0.235 + 0.035 * Float(pair) + 0.012 * identity
        let reach = 0.44 + 0.06 * identity
        var previous = bodyPlumulaceousNode(
          frame: frame,
          side: side,
          startAxial: startAxial,
          endAxial: endAxial,
          reach: reach,
          identity: identity,
          fraction: 0
        )
        for section in 0..<3 {
          let firstFraction = Float(section) / 3
          let secondFraction = Float(section + 1) / 3
          let next = bodyPlumulaceousNode(
            frame: frame,
            side: side,
            startAxial: startAxial,
            endAxial: endAxial,
            reach: reach,
            identity: identity,
            fraction: secondFraction
          )
          result.append(
            CrowFeatherMesostructureSegment(
              kind: .plumulaceousBarb,
              start: previous,
              end: next,
              startRadiusMeters: mix(0.000032, 0.000008, firstFraction),
              endRadiusMeters: mix(0.000032, 0.000008, secondFraction)
            )
          )
          previous = next
        }
      }
    }
  }

  private static func bodyPlumulaceousNode(
    frame: Frame,
    side: Float,
    startAxial: Float,
    endAxial: Float,
    reach: Float,
    identity: Float,
    fraction: Float
  ) -> SIMD3<Float> {
    let axial = mix(startAxial, endAxial, fraction)
    let lateral = 0.04 + reach * pow(fraction, 0.78)
    let inset = -0.00025 + 0.00018 * fraction
      + 0.00008 * sin(.pi * fraction) * (0.60 + 0.40 * identity)
    return frame.center(at: axial)
      + side * frame.widthAxis * frame.halfWidth(at: axial, signedWidth: side)
        * lateral
      + frame.normal * inset
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
