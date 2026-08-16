import Testing
import simd

@testable import BirdFlowVisualization

@Test("crow crural plumage overlaps the leg and crosses the hock boundary")
func crowCruralPlumageOverlapsLegAndCrossesHockBoundary() {
  let hip = SIMD3<Float>(-0.025, 0.035, -0.060)
  let hock = SIMD3<Float>(-0.014, 0.040, -0.111)
  let axis = simd_normalize(hock - hip)
  let legLength = simd_distance(hip, hock)
  let samples = CrowLegPlumage.samples(hip: hip, hock: hock)
  #expect(samples.count == CrowLegPlumage.radialCount * CrowLegPlumage.stationCount)

  for radialIndex in 0..<CrowLegPlumage.radialCount {
    let row =
      samples
      .filter { $0.radialIndex == radialIndex }
      .sorted { $0.stationIndex < $1.stationIndex }
    #expect(row.count == CrowLegPlumage.stationCount)
    for pair in zip(row, row.dropFirst()) {
      let rootSpacing = simd_dot(pair.1.root - pair.0.root, axis)
      let featherLength = simd_dot(pair.0.tip - pair.0.root, axis)
      #expect(rootSpacing > 0)
      #expect(rootSpacing < featherLength)
    }
  }

  let distalProjection = samples.map { simd_dot($0.tip - hip, axis) }.max()!
  #expect(distalProjection > legLength + 0.003)
  #expect(distalProjection < legLength + 0.007)
  #expect(
    samples.allSatisfy {
      simd_dot($0.tip - $0.root, axis) > 0
        && $0.maximumWidthMeters > $0.rootWidthMeters
        && abs(simd_length($0.planeNormal) - 1) < 1e-5
    }
  )
}

@Test("crow crural plumage retains circumferential overlap")
func crowCruralPlumageRetainsCircumferentialOverlap() {
  let samples = CrowLegPlumage.samples(
    hip: SIMD3<Float>(-0.025, 0.035, -0.060),
    hock: SIMD3<Float>(-0.014, 0.040, -0.111)
  )
  for sample in samples {
    let nextRadial = (sample.radialIndex + 1) % CrowLegPlumage.radialCount
    let neighbor =
      samples
      .filter { $0.radialIndex == nextRadial }
      .min { simd_distance($0.root, sample.root) < simd_distance($1.root, sample.root) }!
    #expect(
      simd_distance(sample.root, neighbor.root)
        < sample.maximumWidthMeters + neighbor.maximumWidthMeters
    )
  }
}
