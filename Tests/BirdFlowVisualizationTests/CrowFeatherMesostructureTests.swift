import Testing
import simd

@testable import BirdFlowVisualization

@Test("body feather mesostructure resolves a nested anatomical hierarchy")
func bodyFeatherMesostructureResolvesHierarchy() {
  let feather = CrowBodyContourShingles.samples()[117]
  let length = simd_distance(feather.rootOffset, feather.tipOffset)
  let silhouette = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: 12 / length
  )
  let vane = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: 48 / length
  )
  let barbs = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: 180 / length
  )
  let barbules = CrowFeatherMesostructure.segments(
    for: feather,
    projectedPixelsPerMeter: 520 / length
  )

  #expect(silhouette.isEmpty)
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
  #expect(silhouette.count < vane.count && vane.count < barbs.count)
  #expect(barbs.count < barbules.count)
}

@Test("body feather edge groups attach inside the vane and cross its hard outline")
func bodyFeatherEdgeGroupsCrossClosedVaneOutline() {
  for feather in CrowBodyContourShingles.samples() {
    let length = simd_distance(feather.rootOffset, feather.tipOffset)
    let segments = CrowFeatherMesostructure.segments(
      for: feather,
      projectedPixelsPerMeter: 48 / length
    ).filter { $0.kind == .edgeBarbGroup }
    #expect(segments.count == 25)

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
        let signedSide: Float = simd_dot(segment.end - feather.rootOffset, widthAxis) < 0
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
