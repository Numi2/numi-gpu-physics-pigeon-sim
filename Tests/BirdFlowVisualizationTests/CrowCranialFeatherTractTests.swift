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
  #expect(samples.count == 306)
  #expect(samples.filter { $0.region == .nape }.count == 128)
  #expect(samples.filter { $0.region == .crown }.count == 73)
  #expect(samples.filter { $0.region == .cheek }.count == 21)
  #expect(samples.filter { $0.region == .throat }.count == 84)
  #expect(samples.filter { $0.region == .nape }.allSatisfy { $0.root.x < center.x })
  #expect(samples.allSatisfy { $0.root.x < center.x + 0.038 })
  #expect(
    samples.allSatisfy {
      let length = simd_distance($0.root, $0.tip)
      return length > $0.maximumWidthMeters
        && $0.maximumWidthMeters > $0.rootWidthMeters
        && abs(simd_length($0.planeNormal) - 1) < 1e-5
    }
  )

  let rings = CrowCranialFeatherTracts.axialRings
  for sample in samples {
    let ring = rings[sample.axialIndex]
    let theta = sample.thetaRadians
    let surface = CrowCranialAnatomy.surfacePoint(
      center: center,
      effectiveRadii: radii * SIMD3<Float>(1.01, 1, 1.01),
      ring: ring,
      theta: theta
    )
    #expect(abs(simd_distance(sample.root, surface) - 0.00030) < 1e-6)
    #expect(simd_dot(sample.root - surface, sample.planeNormal) > 0.00029)
    if ring.axialFraction > 0.55 {
      #expect(abs(sin(theta)) >= 0.50)
    }
    if ring.axialFraction >= 0.02 && ring.axialFraction <= 0.62 {
      func angularDistance(_ first: Float, _ second: Float) -> Float {
        let difference = abs(first - second).truncatingRemainder(
          dividingBy: 2 * Float.pi
        )
        return min(difference, 2 * Float.pi - difference)
      }
      #expect(
        min(
          angularDistance(theta, 0.28),
          angularDistance(theta, Float.pi - 0.28)
        ) > 0.32
      )
    }
  }

  #expect(samples.map(\.materialVariation).min()! < -0.90)
  #expect(samples.map(\.materialVariation).max()! > 0.90)

  let throatDirections =
    samples
    .filter { $0.region == .throat }
    .map { simd_normalize($0.tip - $0.root) }
  let lateralComponents = throatDirections.map(\.y)
  #expect(lateralComponents.min()! < -0.10)
  #expect(lateralComponents.max()! > 0.10)

  for axialIndex in rings.indices {
    let course =
      samples
      .filter { $0.axialIndex == axialIndex }
      .sorted { $0.angularIndex < $1.angularIndex }
    for pair in zip(course, course.dropFirst())
    where pair.1.angularIndex == pair.0.angularIndex + 1 {
      #expect(
        simd_distance(pair.0.root, pair.1.root)
          < pair.0.maximumWidthMeters + pair.1.maximumWidthMeters
      )
    }
  }

  for axialIndex in 0..<(rings.count - 1) {
    for angularIndex in 0..<CrowCranialFeatherTracts.angularCount {
      guard
        let first = samples.first(where: {
          $0.axialIndex == axialIndex && $0.angularIndex == angularIndex
        }),
        let second = samples.first(where: {
          $0.axialIndex == axialIndex + 1 && $0.angularIndex == angularIndex
        })
      else { continue }
      #expect(simd_distance(first.root, second.root) < simd_distance(first.root, first.tip))
    }
  }

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
    projectedPixelsPerMeter: 1_000
  )
  let full = CrowCranialFeatherTracts.visibleSamples(
    center: center,
    radii: radii,
    breathingScale: 1,
    projectedPixelsPerMeter: 1_600
  )
  #expect(low.count == 82)
  #expect(medium.count == 152)
  #expect(full.count == 306)
  #expect(low.count < medium.count && medium.count < full.count)
  for region in CrowCranialFeatherRegion.allCases {
    #expect(low.contains { $0.region == region })
    #expect(medium.contains { $0.region == region })
  }
}
