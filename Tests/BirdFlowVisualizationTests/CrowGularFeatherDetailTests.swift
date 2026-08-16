import Testing
import simd

@testable import BirdFlowVisualization

@Test("gular detail resolves throat rachises and paired barb groups only at full density")
func gularDetailResolvesOnlyFullDensityThroatFeathers() {
  let center = SIMD3<Float>(0.164, 0, 0.052)
  let radii = SIMD3<Float>(0.0447, 0.0328, 0.0387)
  let samples = CrowCranialFeatherTracts.samples(
    center: center,
    radii: radii,
    breathingScale: 1
  )
  let throat = samples.first { $0.region == .throat }!
  let cheek = samples.first { $0.region == .cheek }!
  #expect(
    CrowGularFeatherDetail.segments(
      for: throat,
      projectedPixelsPerMeter: 1_000
    ).isEmpty
  )
  #expect(
    CrowGularFeatherDetail.segments(
      for: cheek,
      projectedPixelsPerMeter: 1_600
    ).isEmpty
  )
  let segments = CrowGularFeatherDetail.segments(
    for: throat,
    projectedPixelsPerMeter: 1_600
  )
  #expect(segments.filter { $0.kind == .rachis }.count == 1)
  #expect(
    segments.filter { $0.kind == .edgeBarbGroup }.count
      == 2 * CrowGularFeatherDetail.barbPairCount
  )
  #expect(segments.count == 7)
}

@Test("gular detail remains finite and attached to every throat vane")
func gularDetailRemainsFiniteAndAttachedToEveryThroatVane() {
  let samples = CrowCranialFeatherTracts.samples(
    center: SIMD3<Float>(0.164, 0, 0.052),
    radii: SIMD3<Float>(0.0447, 0.0328, 0.0387),
    breathingScale: 1.01
  ).filter { $0.region == .throat }
  #expect(samples.count == 225)
  for feather in samples {
    let featherLength = simd_distance(feather.root, feather.tip)
    let segments = CrowGularFeatherDetail.segments(
      for: feather,
      projectedPixelsPerMeter: 1_600
    )
    #expect(segments.count == 7)
    #expect(
      segments.allSatisfy {
        $0.start.x.isFinite && $0.start.y.isFinite && $0.start.z.isFinite
          && $0.end.x.isFinite && $0.end.y.isFinite && $0.end.z.isFinite
          && $0.startRadiusMeters > $0.endRadiusMeters
          && $0.endRadiusMeters > 0
          && simd_distance($0.start, $0.end) > 1e-5
          && simd_distance($0.start, feather.root) < featherLength
          && simd_distance($0.end, feather.root) < 1.25 * featherLength
      }
    )
  }
}
