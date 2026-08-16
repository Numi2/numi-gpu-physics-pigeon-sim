import Testing
import simd

@testable import BirdFlowVisualization

@Test("crow cranial contour tracts remain attached and regionally bounded")
func crowCranialContourTractsRemainAttachedAndRegionallyBounded() {
  let center = SIMD3<Float>(0.164, 0, 0.052)
  let radii = SIMD3<Float>(0.0447, 0.0328, 0.0387)
  let samples = CrowCranialFeatherTracts.samples(
    center: center,
    radii: radii,
    breathingScale: 1.01
  )
  #expect(samples.count == 54)
  #expect(samples.filter { $0.region == .nape }.count == 18)
  #expect(samples.filter { $0.region == .crown }.count == 15)
  #expect(samples.filter { $0.region == .cheek }.count == 12)
  #expect(samples.filter { $0.region == .throat }.count == 9)
  #expect(samples.filter { $0.region == .nape }.allSatisfy { $0.root.x < center.x })
  #expect(samples.allSatisfy { $0.root.x < center.x + 0.030 })
  #expect(
    samples.allSatisfy {
      let length = simd_distance($0.root, $0.tip)
      return length > $0.maximumWidthMeters
        && $0.maximumWidthMeters > $0.rootWidthMeters
        && abs(simd_length($0.planeNormal) - 1) < 1e-5
    }
  )

  let breathingSamples = CrowCranialFeatherTracts.samples(
    center: center,
    radii: radii,
    breathingScale: 1.02
  )
  #expect(breathingSamples.count == samples.count)
  #expect(
    zip(samples, breathingSamples).allSatisfy {
      simd_distance($0.root, $1.root) > 0
        && simd_distance($0.root, $1.root) < 0.001
    }
  )

  let low = CrowCranialFeatherTracts.visibleSamples(
    center: center,
    radii: radii,
    breathingScale: 1,
    projectedPixelsPerMeter: 800
  )
  let medium = CrowCranialFeatherTracts.visibleSamples(
    center: center,
    radii: radii,
    breathingScale: 1,
    projectedPixelsPerMeter: 1_400
  )
  let full = CrowCranialFeatherTracts.visibleSamples(
    center: center,
    radii: radii,
    breathingScale: 1,
    projectedPixelsPerMeter: 2_000
  )
  #expect(low.count == 27)
  #expect(medium.count == 36)
  #expect(full.count == 54)
  for region in CrowCranialFeatherRegion.allCases {
    #expect(low.contains { $0.region == region })
    #expect(medium.contains { $0.region == region })
  }
}
