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
  #expect(samples.count == 98)
  #expect(
    CrowLegPlumage.visibleSamples(
      hip: hip,
      hock: hock,
      projectedPixelsPerMeter: 800
    ).count == 50
  )
  #expect(
    CrowLegPlumage.visibleSamples(
      hip: hip,
      hock: hock,
      projectedPixelsPerMeter: 1_000
    ).count == 50
  )
  #expect(
    CrowLegPlumage.visibleSamples(
      hip: hip,
      hock: hock,
      projectedPixelsPerMeter: 1_600
    ).count == 98
  )

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
        && $0.maximumWidthMeters < 0.0052
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

@Test("crow tarsometatarsus tapers elliptically and carries anterior scutes")
func crowTarsometatarsusTapersEllipticallyAndCarriesAnteriorScutes() {
  let stations = CrowTarsometatarsusAnatomy.stations
  #expect(stations.first!.fraction == 0)
  #expect(stations.last!.fraction == 1)
  #expect(zip(stations, stations.dropFirst()).allSatisfy { $0.fraction < $1.fraction })
  #expect(stations.allSatisfy { $0.foreAftRadiusMeters > $0.lateralRadiusMeters })
  let narrowest = stations.min { $0.lateralRadiusMeters < $1.lateralRadiusMeters }!
  #expect(narrowest.fraction > 0.7 && narrowest.fraction < 0.9)
  #expect(stations.first!.lateralRadiusMeters > narrowest.lateralRadiusMeters)
  #expect(stations.last!.lateralRadiusMeters > narrowest.lateralRadiusMeters)

  let hock = SIMD3<Float>(-0.012, 0.040, -0.109)
  let ankle = SIMD3<Float>(0.002, 0.039, -0.164)
  let vertices = CrowTarsometatarsusAnatomy.vertices(
    hock: hock,
    ankle: ankle,
    shaftColor: SIMD4<Float>(0.048, 0.053, 0.061, 0.58),
    scuteColor: SIMD4<Float>(0.052, 0.057, 0.064, 0.62)
  )
  let expectedShaftVertices =
    (stations.count - 1) * CrowTarsometatarsusAnatomy.radialSegments * 6
  let expectedScuteVertices =
    CrowTarsometatarsusAnatomy.scuteCount
    * CrowTarsometatarsusAnatomy.scuteArcSegments * 6
  #expect(vertices.count == expectedShaftVertices + expectedScuteVertices)
  #expect(
    vertices.allSatisfy {
      let normal = SIMD3<Float>($0.normal.x, $0.normal.y, $0.normal.z)
      return normal.x.isFinite && normal.y.isFinite && normal.z.isFinite
        && abs(simd_length(normal) - 1) < 1e-5
    }
  )
}
