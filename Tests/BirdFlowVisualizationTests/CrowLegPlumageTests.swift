import Testing
import simd

@testable import BirdFlowVisualization

@Test("crural morphology is immutable and reconstructs live limb frames")
func cruralMorphologyReconstructsLiveLimbFrames() {
  let negative = CrowLegPlumage.morphologySamples(side: -1)
  let positive = CrowLegPlumage.morphologySamples(side: 1)
  #expect(negative.count == 162)
  #expect(positive.count == 162)
  #expect(negative.allSatisfy { $0.side == -1 })
  #expect(positive.allSatisfy { $0.side == 1 })
  #expect(
    Set(negative.map { SIMD2<Int>($0.radialIndex, $0.stationIndex) }).count
      == 162
  )
  let firstHip = SIMD3<Float>(-0.025, -0.035, -0.060)
  let firstHock = SIMD3<Float>(-0.014, -0.040, -0.111)
  let secondHip = SIMD3<Float>(-0.023, -0.034, -0.058)
  let secondHock = SIMD3<Float>(-0.011, -0.039, -0.109)
  let first = negative.map {
    CrowLegPlumage.feather(morphology: $0, hip: firstHip, hock: firstHock)
  }
  let second = negative.map {
    CrowLegPlumage.feather(morphology: $0, hip: secondHip, hock: secondHock)
  }
  #expect(first == CrowLegPlumage.samples(hip: firstHip, hock: firstHock))
  #expect(second == CrowLegPlumage.samples(hip: secondHip, hock: secondHock))
  #expect(zip(first, second).allSatisfy { $0.radialIndex == $1.radialIndex })
  #expect(zip(first, second).allSatisfy { $0.stationIndex == $1.stationIndex })
  #expect(zip(first, second).contains { simd_distance($0.root, $1.root) > 1e-4 })
}

@Test("crow crural plumage overlaps the leg and crosses the hock boundary")
func crowCruralPlumageOverlapsLegAndCrossesHockBoundary() {
  let hip = SIMD3<Float>(-0.025, 0.035, -0.060)
  let hock = SIMD3<Float>(-0.014, 0.040, -0.111)
  let axis = simd_normalize(hock - hip)
  let legLength = simd_distance(hip, hock)
  let samples = CrowLegPlumage.samples(hip: hip, hock: hock)
  #expect(samples.count == CrowLegPlumage.radialCount * CrowLegPlumage.stationCount)
  #expect(samples.count == 162)
  #expect(CrowLegPlumage.surfaceFeatherClass == 7)
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
    ).count == 162
  )
  #expect(samples.map(\.materialVariation).min()! < -0.90)
  #expect(samples.map(\.materialVariation).max()! > 0.90)
  #expect(samples.map(\.vaneAsymmetry).min()! < -0.040)
  #expect(samples.map(\.vaneAsymmetry).max()! > 0.040)
  #expect(samples.map(\.lateralSweepMeters).min()! < -0.00030)
  #expect(samples.map(\.lateralSweepMeters).max()! > 0.00030)
  #expect(
    samples.allSatisfy {
      abs($0.lateralSweepMeters) < 0.17 * $0.maximumWidthMeters
    }
  )
  #expect(samples.allSatisfy { $0.edgeRippleAmplitude >= 0.012 })
  #expect(samples.allSatisfy { $0.edgeRippleAmplitude <= 0.030 })
  #expect(samples.allSatisfy { $0.edgeRipplePhase >= 0 })
  #expect(samples.allSatisfy { $0.edgeRipplePhase <= 2 * Float.pi })
  #expect(samples.allSatisfy { $0.edgeRippleCycles >= 1.25 })
  #expect(samples.allSatisfy { $0.edgeRippleCycles <= 1.90 })
  #expect(samples.allSatisfy {
    $0.rootEnvelopeRatio == CrowLegPlumage.visibleRootEnvelopeRatio
  })
  let standingCameraPixelsPerMeter = [Float(0.498), Float(0.502)].map {
    CrowFeatherCoverageLOD.projectedPixelsPerMeter(
      viewportHeight: 720,
      cameraDistanceMeters: $0
    )
  }
  #expect(
    samples.allSatisfy { sample in
      Set(
        standingCameraPixelsPerMeter.map {
          CrowFeatherCoverageLOD.tessellation(
            lengthMeters: max(
              simd_distance(sample.root, sample.tip),
              CrowLegPlumage.minimumLODTessellationLengthMeters
            ),
            projectedPixelsPerMeter: $0,
            baseAxialSections: 8
          ).tier
        }
      ).count == 1
    }
  )
  #expect(CrowLegPlumage.proximalUnderlayerRadiusMeters == 0.014)
  #expect(CrowLegPlumage.distalUnderlayerRadiusMeters == 0.0065)
  let firstRootRadius =
    0.975 * CrowLegPlumage.proximalUnderlayerRadiusMeters
    + 0.025 * CrowLegPlumage.distalUnderlayerRadiusMeters
  #expect(
    samples.filter {
      $0.stationIndex == 0 && $0.radialIndex.isMultiple(of: 2)
    }.allSatisfy {
      abs(simd_distance($0.root, mix(hip, hock, 0.025)) - firstRootRadius) < 1e-6
    }
  )
  #expect(samples.allSatisfy { $0.bodyMaterialBlend >= 0.15 })
  #expect(samples.allSatisfy { $0.bodyMaterialBlend <= 0.62 })
  #expect(
    CrowLegPlumage.visibleSamples(
      hip: hip,
      hock: hock,
      projectedPixelsPerMeter: 1_000
    ).allSatisfy {
      $0.materialVariation == 0 && $0.bodyMaterialBlend == 0
    }
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

  for stationIndex in 0..<CrowLegPlumage.stationCount {
    let axialLengths = samples.filter {
      $0.stationIndex == stationIndex
    }.map {
      simd_dot($0.tip - $0.root, axis)
    }
    #expect(axialLengths.max()! - axialLengths.min()! > 0.0022)
  }

  let distalProjection = samples.map { simd_dot($0.tip - hip, axis) }.max()!
  #expect(distalProjection > legLength + 0.003)
  #expect(distalProjection < legLength + 0.007)
  let distalCourseProjections = samples.filter {
    $0.stationIndex == CrowLegPlumage.stationCount - 1
  }.map {
    simd_dot($0.tip - hip, axis)
  }
  #expect(distalCourseProjections.max()! - distalCourseProjections.min()! > 0.003)
  #expect(
    samples.allSatisfy {
      simd_dot($0.tip - $0.root, axis) > 0
        && $0.maximumWidthMeters > $0.rootWidthMeters
        && $0.maximumWidthMeters < 0.0052
        && abs(simd_length($0.planeNormal) - 1) < 1e-5
    }
  )
}

private func mix(
  _ first: SIMD3<Float>,
  _ second: SIMD3<Float>,
  _ blend: Float
) -> SIMD3<Float> {
  first + blend * (second - first)
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

@Test("crural vanes resolve shafts, paired barbs, and terminal bundles")
func crowCruralVanesResolveFullDensityMesostructure() {
  let samples = CrowLegPlumage.samples(
    hip: SIMD3<Float>(-0.025, 0.035, -0.060),
    hock: SIMD3<Float>(-0.014, 0.040, -0.111)
  )
  for feather in samples {
    #expect(
      CrowCruralFeatherDetail.segments(
        for: feather,
        projectedPixelsPerMeter: 1_000
      ).isEmpty
    )
    let segments = CrowCruralFeatherDetail.segments(
      for: feather,
      projectedPixelsPerMeter: 1_600
    )
    #expect(
      segments.count
        == 1 + 2 * CrowCruralFeatherDetail.barbPairCount
          + CrowCruralFeatherDetail.terminalBundleCount
    )
    #expect(segments.filter { $0.kind == .rachis }.count == 1)
    #expect(
      segments.filter { $0.kind == .edgeBarbGroup }.count
        == 2 * CrowCruralFeatherDetail.barbPairCount
          + CrowCruralFeatherDetail.terminalBundleCount
    )
    let featherLength = simd_distance(feather.root, feather.tip)
    #expect(
      segments.allSatisfy {
        $0.start.x.isFinite && $0.start.y.isFinite && $0.start.z.isFinite
          && $0.end.x.isFinite && $0.end.y.isFinite && $0.end.z.isFinite
          && $0.startRadiusMeters > $0.endRadiusMeters
          && $0.endRadiusMeters > 0
          && simd_distance($0.start, $0.end) > 1e-5
          && simd_distance($0.start, feather.root) < featherLength
          && simd_distance($0.end, feather.root) < 1.05 * featherLength
      }
    )
    let terminal = segments.suffix(CrowCruralFeatherDetail.terminalBundleCount)
    #expect(
      terminal.allSatisfy {
        simd_dot($0.end - feather.tip, feather.tip - feather.root) > 0
      }
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
      $0.parameters.w == Float(CrowFootAnatomy.surfaceIdentityClassCode)
    }
  )
  #expect(
    vertices.allSatisfy {
      let normal = SIMD3<Float>($0.normal.x, $0.normal.y, $0.normal.z)
      return normal.x.isFinite && normal.y.isFinite && normal.z.isFinite
        && abs(simd_length(normal) - 1) < 1e-5
    }
  )
}
