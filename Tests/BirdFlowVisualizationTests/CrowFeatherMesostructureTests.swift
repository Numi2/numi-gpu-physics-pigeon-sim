import Testing
import simd

@testable import BirdFlowVisualization

@Test("body feather mesostructure resolves a nested anatomical hierarchy")
func bodyFeatherMesostructureResolvesHierarchy() {
  let feather = CrowBodyContourShingles.samples().first { $0.region == .dorsal }!
  let length = simd_distance(feather.rootOffset, feather.tipOffset)
  let silhouette = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: 12 / length
  )
  let dorsalVane = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: 48 / length
  )
  let vane = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: (CrowFeatherMesostructure.bodyContourEdgeDetailThresholdPixels + 1)
      / feather.referenceLengthMeters
  )
  let barbs = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: 180 / length
  )
  let barbules = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: 520 / length
  )
  let flank = CrowBodyContourShingles.samples().first { $0.region == .flank }!
  let flankAtDorsalThreshold = CrowFeatherMesostructure.segments(
    for: flank,
    projectedPixelsPerMeter:
      CrowFeatherMesostructure.dorsalBodyContourDetailThresholdPixels
      / flank.referenceLengthMeters
  )

  #expect(silhouette.isEmpty)
  #expect(flankAtDorsalThreshold.isEmpty)
  #expect(dorsalVane.filter { $0.kind == .rachis }.count == 4)
  #expect(dorsalVane.filter { $0.kind == .edgeBarbGroup }.count == 25)
  #expect(vane.filter { $0.kind == .rachis }.count == 4)
  #expect(vane.filter { $0.kind == .edgeBarbGroup }.count == 25)
  #expect(vane.allSatisfy { $0.kind != .barb && $0.kind != .barbule })
  #expect(barbs.filter { $0.kind == .rachis }.count == 8)
  #expect(barbs.filter { $0.kind == .edgeBarbGroup }.count == 5)
  #expect(barbs.filter { $0.kind == .barb }.count == 18)
  #expect(barbs.allSatisfy { $0.kind != .barbule })
  #expect(barbules.filter { $0.kind == .rachis }.count == 12)
  #expect(barbules.filter { $0.kind == .edgeBarbGroup }.count == 5)
  #expect(barbules.filter { $0.kind == .barb }.count == 36)
  #expect(barbules.filter { $0.kind == .barbule }.count == 108)
  #expect(silhouette.count < dorsalVane.count && dorsalVane.count <= vane.count)
  #expect(vane.count < barbs.count)
  #expect(barbs.count < barbules.count)
}

@Test("posterior dorsal contour feathers promote contained interior barbs")
func posteriorDorsalContourFeathersPromoteInteriorBarbs() throws {
  let dorsal = CrowBodyContourShingles.samples().filter { $0.region == .dorsal }
  let anterior = try #require(dorsal.first { $0.axialIndex == 0 })
  let posterior = try #require(
    dorsal.first { $0.axialIndex == CrowBodyContourShingles.axialCount - 1 }
  )
  let anteriorDetail = CrowFeatherMesostructure.segments(
    for: anterior,
    projectedPixelsPerMeter:
      CrowFeatherMesostructure.dorsalBodyContourDetailThresholdPixels
      / anterior.referenceLengthMeters
  )
  let posteriorDetail = CrowFeatherMesostructure.segments(
    for: posterior,
    projectedPixelsPerMeter:
      CrowFeatherMesostructure.dorsalBodyContourDetailThresholdPixels
      / posterior.referenceLengthMeters
  )
  #expect(anteriorDetail.filter { $0.kind == .edgeBarbGroup }.count == 25)
  #expect(anteriorDetail.allSatisfy { $0.kind != .barb })
  #expect(posteriorDetail.filter { $0.kind == .edgeBarbGroup }.count == 5)
  #expect(posteriorDetail.filter { $0.kind == .barb }.count == 20)
  #expect(posteriorDetail.count == anteriorDetail.count)
}

@Test("body feather edge groups attach inside the vane and cross its hard outline")
func bodyFeatherEdgeGroupsCrossClosedVaneOutline() {
  for feather in CrowBodyContourShingles.samples() {
    let length = simd_distance(feather.rootOffset, feather.tipOffset)
    let segments = CrowFeatherMesostructure.segments(
      for: feather,
      projectedPixelsPerMeter: (CrowFeatherMesostructure.bodyContourEdgeDetailThresholdPixels + 1)
        / feather.referenceLengthMeters
    ).filter { $0.kind == .edgeBarbGroup }
    let axial = Float(feather.axialIndex)
      / Float(CrowBodyContourShingles.axialCount - 1)
    let promoted = feather.region == .dorsal
      && axial
        >= CrowFeatherMesostructure.dorsalBodyContourInteriorBarbStartAxialFraction
    #expect(segments.count == (promoted ? 5 : 25))

    let direction = simd_normalize(feather.tipOffset - feather.rootOffset)
    let normal = simd_normalize(
      feather.planeNormal - direction * simd_dot(feather.planeNormal, direction)
    )
    let widthAxis = simd_normalize(simd_cross(normal, direction))
    for segment in segments {
      let rootAxial = simd_dot(segment.start - feather.rootOffset, direction) / length
      let endAxial = simd_dot(segment.end - feather.rootOffset, direction) / length
      let rootLateral = abs(simd_dot(segment.start - feather.rootOffset, widthAxis))
      let rootWidth = CrowBodyContourShingles.vaneHalfWidth(
        for: feather,
        at: rootAxial
      )
      #expect(rootAxial > feather.pennaceousStartFraction && rootAxial < 0.94)
      #expect(rootLateral < 0.82 * rootWidth)
      #expect(endAxial > rootAxial)
      #expect(simd_distance(segment.start, segment.end) < 0.012)

      if endAxial < 0.99 {
        let signedSide: Float =
          simd_dot(segment.end - feather.rootOffset, widthAxis) < 0
          ? -1 : 1
        let endLateral = abs(simd_dot(segment.end - feather.rootOffset, widthAxis))
        let vaneEdge = CrowBodyContourShingles.vaneHalfWidth(
          for: feather,
          at: endAxial,
          signedWidth: signedSide
        )
        #expect(endLateral > vaneEdge)
      }
    }
  }
}

@Test("body feather mesostructure remains finite and attached to its vane")
func bodyFeatherMesostructureRemainsAttached() {
  for feather in CrowBodyContourShingles.samples() {
    let segments = CrowFeatherMesostructure.segments(
      for: feather,
      projectedPixelsPerMeter: 18_000
    )
    #expect(!segments.isEmpty)
    #expect(
      segments.allSatisfy {
        $0.start.x.isFinite && $0.start.y.isFinite && $0.start.z.isFinite
          && $0.end.x.isFinite && $0.end.y.isFinite && $0.end.z.isFinite
          && $0.startRadiusMeters > 0
          && $0.endRadiusMeters > 0
          && simd_distance($0.start, $0.end) > 1e-7
          && simd_distance($0.start, feather.rootOffset)
            < 1.35 * simd_distance(feather.rootOffset, feather.tipOffset)
      }
    )
  }
}

@Test("body tract feathers inherit resolution-scaled rachis and barb detail")
func bodyTractFeathersResolveMesostructure() {
  for feather in CrowBodyFeatherTracts.samples() {
    let length = simd_distance(feather.rootOffset, feather.tipOffset)
    let silhouette = CrowFeatherMesostructure.segments(
      for: feather,
      projectedPixelsPerMeter: 12 / length
    )
    let resolved = CrowFeatherMesostructure.segments(
      for: feather,
      projectedPixelsPerMeter: 48 / length
    )
    #expect(silhouette.isEmpty)
    #expect(resolved.filter { $0.kind == .rachis }.count == 4)
    if feather.region == .humeral || feather.region == .scapular {
      #expect(resolved.filter { $0.kind == .barb }.count == 20)
      #expect(resolved.filter { $0.kind == .edgeBarbGroup }.count == 5)
    } else {
      #expect(resolved.filter { $0.kind == .barb }.isEmpty)
      #expect(resolved.filter { $0.kind == .edgeBarbGroup }.count == 25)
    }
    #expect(
      resolved.allSatisfy {
        $0.start.x.isFinite && $0.start.y.isFinite && $0.start.z.isFinite
          && $0.end.x.isFinite && $0.end.y.isFinite && $0.end.z.isFinite
          && $0.startRadiusMeters > 0
          && $0.endRadiusMeters > 0
          && simd_distance($0.start, $0.end) > 1e-7
          && simd_distance($0.start, feather.rootOffset) < 1.40 * length
      }
    )
  }
}

@Test("body tract detail follows deployment camber without changing inventory")
func bodyTractDetailFollowsDeploymentCamber() throws {
  let feather = try #require(
    CrowBodyFeatherTracts.samples().first {
      $0.region == .mantle
        && $0.column == CrowBodyFeatherTracts.mantleColumnCount - 1
    }
  )
  let length = simd_distance(feather.rootOffset, feather.tipOffset)
  let full = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: 48 / length
  )
  let settled = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: 48 / length,
    camberScale: CrowBodyFeatherTracts.mantleFlightPosteriorCamberScale
  )
  #expect(settled.count == full.count)
  #expect(zip(settled, full).allSatisfy { $0.kind == $1.kind })
  #expect(
    zip(settled, full).contains {
      simd_distance($0.start, $1.start) > 1e-6
        || simd_distance($0.end, $1.end) > 1e-6
    }
  )
}

@Test("body tract detail follows the rendered transverse vane crown")
func bodyTractDetailFollowsRenderedTransverseVaneCrown() throws {
  let feather = try #require(
    CrowBodyFeatherTracts.samples().first {
      $0.region == .scapular
        && $0.row == CrowBodyFeatherTracts.scapularRowCount - 1
    }
  )
  let length = simd_distance(feather.rootOffset, feather.tipOffset)
  let flat = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: 48 / length,
    transverseCamberRatio: 0
  )
  let crowned = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: 48 / length,
    transverseCamberRatio: CrowBodyFeatherTracts.bodyTractTransverseCamberRatio
  )
  #expect(crowned.count == flat.count)
  #expect(zip(crowned, flat).allSatisfy { $0.kind == $1.kind })
  let direction = simd_normalize(feather.tipOffset - feather.rootOffset)
  let normal = simd_normalize(
    feather.planeNormal - direction * simd_dot(feather.planeNormal, direction)
  )
  let normalLifts = zip(crowned, flat).map {
    simd_dot($0.start - $1.start, normal)
  }
  #expect(normalLifts.max()! > 0.00045)
  #expect(normalLifts.min()! >= -1e-7)
}

@Test("promoted shoulder barbs stay inside the vane before terminal tip bundles")
func promotedShoulderBarbsStayInsideVaneBeforeTerminalTipBundles() throws {
  let feather = try #require(
    CrowBodyFeatherTracts.samples().first { $0.region == .scapular }
  )
  let direction = simd_normalize(feather.tipOffset - feather.rootOffset)
  let normal = simd_normalize(
    feather.planeNormal - direction * simd_dot(feather.planeNormal, direction)
  )
  let widthAxis = simd_normalize(simd_cross(normal, direction))
  let length = simd_distance(feather.rootOffset, feather.tipOffset)
  let barbs = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: 48 / length,
    transverseCamberRatio: CrowBodyFeatherTracts.bodyTractTransverseCamberRatio
  )
  let interiorBarbs = barbs.filter { $0.kind == .barb }
  #expect(!interiorBarbs.isEmpty)
  for barb in interiorBarbs {
    let axial = simd_dot(barb.end - feather.rootOffset, direction) / length
    let bodyEnvelope =
      feather.rootEnvelopeRatio
      + (1 - feather.rootEnvelopeRatio)
      * pow(max(sin(Float.pi * axial), 0), 0.58)
    let tipTaper = 1 - 0.985 * pow(axial, 3.2)
    let rippleEnvelope = pow(max(sin(Float.pi * axial), 0), 2)
    let edgeRipple =
      1
      + feather.edgeRippleAmplitude
      * sin(
        2 * Float.pi * feather.edgeRippleCycles * axial
          + feather.edgeRipplePhase
      ) * rippleEnvelope
    let signedSide: Float =
      simd_dot(barb.end - feather.rootOffset, widthAxis) < 0 ? -1 : 1
    let vaneHalfWidth =
      (feather.rootWidthMeters * (1 - axial)
        + feather.maximumWidthMeters * axial)
      * bodyEnvelope * tipTaper * edgeRipple
      * (1 + feather.vaneAsymmetry * signedSide)
    let lateral = abs(simd_dot(barb.end - feather.rootOffset, widthAxis))
    #expect(lateral <= 0.971 * vaneHalfWidth + 1e-7)
  }
  let terminalBundles = barbs.filter { $0.kind == .edgeBarbGroup }
  #expect(terminalBundles.count == 5)
  for bundle in terminalBundles {
    let axial = simd_dot(bundle.end - feather.rootOffset, direction) / length
    let lateral = abs(simd_dot(bundle.end - feather.rootOffset, widthAxis))
    #expect(axial > 1)
    #expect(axial < 1 + 0.0013 / length)
    #expect(lateral <= 0.181 * feather.maximumWidthMeters + 1e-7)
  }
}

@Test("ventral tract feathers resolve rachis and barb detail from their vane envelope")
func ventralTractFeathersResolveMesostructure() {
  for feather in CrowVentralFeatherTracts.samples() {
    let length = simd_distance(feather.rootOffset, feather.tipOffset)
    let silhouette = CrowFeatherMesostructure.segments(
      for: feather,
      projectedPixelsPerMeter: 12 / length
    )
    let resolved = CrowFeatherMesostructure.segments(
      for: feather,
      projectedPixelsPerMeter: 48 / length
    )
    #expect(silhouette.isEmpty)
    #expect(
      resolved.filter { $0.kind == .rachis }.count
        == (CrowVentralFeatherTracts.retainsCrownRachis(feather) ? 8 : 4)
    )
    #expect(resolved.filter { $0.kind == .edgeBarbGroup }.count == 25)
    #expect(
      resolved.allSatisfy {
        $0.start.x.isFinite && $0.start.y.isFinite && $0.start.z.isFinite
          && $0.end.x.isFinite && $0.end.y.isFinite && $0.end.z.isFinite
          && $0.startRadiusMeters > 0
          && $0.endRadiusMeters > 0
          && simd_distance($0.start, $0.end) > 1e-7
          && simd_distance($0.start, feather.rootOffset) < 1.40 * length
      }
    )
  }
}

@Test("ventral tract detail follows its visible transverse crown")
func ventralTractDetailFollowsVisibleTransverseCrown() throws {
  let feather = try #require(
    CrowVentralFeatherTracts.samples().first(
      where: CrowVentralFeatherTracts.retainsCrownRachis
    )
  )
  let length = simd_distance(feather.rootOffset, feather.tipOffset)
  let flat = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: 48 / length,
    transverseCamberRatio: 0
  )
  let crowned = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: 48 / length
  )
  #expect(crowned.count == flat.count + 4)
  #expect(Array(crowned.prefix(flat.count)) == flat)
  let direction = simd_normalize(feather.tipOffset - feather.rootOffset)
  let normal = simd_normalize(
    feather.planeNormal - direction * simd_dot(feather.planeNormal, direction)
  )
  let flatRachis = flat.filter { $0.kind == .rachis }
  let crownRachis = crowned.suffix(4)
  #expect(crownRachis.allSatisfy { $0.kind == .rachis })
  let normalLifts = zip(crownRachis, flatRachis).map {
    simd_dot($0.start - $1.start, normal)
  }
  #expect(normalLifts.max()! > 0.00020)
  #expect(normalLifts.min()! >= -1e-7)
}
