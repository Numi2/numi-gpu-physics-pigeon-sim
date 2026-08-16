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
  #expect(vane.count == 4)
  #expect(vane.allSatisfy { $0.kind == .rachis })
  #expect(barbs.filter { $0.kind == .rachis }.count == 8)
  #expect(barbs.filter { $0.kind == .barb }.count == 18)
  #expect(barbs.allSatisfy { $0.kind != .barbule })
  #expect(barbules.filter { $0.kind == .rachis }.count == 12)
  #expect(barbules.filter { $0.kind == .barb }.count == 36)
  #expect(barbules.filter { $0.kind == .barbule }.count == 108)
  #expect(silhouette.count < vane.count && vane.count < barbs.count)
  #expect(barbs.count < barbules.count)
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
