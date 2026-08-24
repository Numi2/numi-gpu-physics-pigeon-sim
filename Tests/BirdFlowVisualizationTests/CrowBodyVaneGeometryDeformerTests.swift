import Metal
import Testing
import simd

@testable import BirdFlowVisualization

@Test("body vanes retain compact identity-stable temporal records")
func bodyVanesRetainCompactIdentityStableTemporalRecords() {
  #expect(MemoryLayout<CrowBodyVaneMorphologyGPU>.stride == 128)
  #expect(MemoryLayout<CrowBodyVaneRecordGPU>.stride == 176)
  #expect(MemoryLayout<CrowBodyVanePoseUniforms>.stride == 128)
  #expect(MemoryLayout<CrowBodyVaneNeckTransformGPU>.stride == 48)
  #expect(MemoryLayout<CrowBodyVaneGeometryUniforms>.stride == 32)
  #expect(MemoryLayout<CrowBodyVaneSelectionUniforms>.stride == 32)
  #expect(MemoryLayout<CrowCranialVisibilityUniforms>.stride == 208)
  #expect(MemoryLayout<CrowBodyDetailSegmentGPU>.stride == 96)
  let first = CrowBodyVaneRecords.groupedRecords(
    currentBodyCenter: SIMD3<Float>(0.01, -0.02, 0.03),
    previousBodyCenter: SIMD3<Float>(-0.01, 0.02, -0.03),
    currentNeckPose: nil,
    previousNeckPose: nil,
    currentDeployment: 1,
    previousDeployment: 0.4,
    projectedPixelsPerMeter: 1_600
  )
  let replay = CrowBodyVaneRecords.groupedRecords(
    currentBodyCenter: SIMD3<Float>(0.01, -0.02, 0.03),
    previousBodyCenter: SIMD3<Float>(-0.01, 0.02, -0.03),
    currentNeckPose: nil,
    previousNeckPose: nil,
    currentDeployment: 1,
    previousDeployment: 0.4,
    projectedPixelsPerMeter: 1_600
  )
  #expect(first == replay)
  #expect(first.values.reduce(0) { $0 + $1.count } == 3_212)
  let records = first.keys.sorted().flatMap { first[$0] ?? [] }
  #expect(Set(records.map(\.identity)).count == records.count)
  #expect(first.keys.allSatisfy { $0.widthSections == 1 || $0.widthSections >= 5 })
  #expect(first.keys.allSatisfy { $0.verticesPerInstance > 0 })
  #expect(CrowBodyVaneRecords.productionTopologies.count == 11)
  #expect(
    CrowBodyVaneRecords.productionTopologies.map {
      CrowBodyVaneRecords.rachisSections(for: $0)
    } == [0, 0, 4, 4, 8, 8, 12, 4, 8, 4, 4]
  )
  #expect(
    CrowBodyVaneRecords.productionTopologies.map {
      CrowBodyVaneRecords.rachisVerticesPerInstance(for: $0)
    } == [0, 0, 96, 96, 192, 192, 288, 96, 192, 96, 96]
  )
  #expect(
    CrowBodyVaneRecords.productionTopologies.map {
      CrowBodyVaneRecords.detailSegmentCount(for: $0)
    } == [0, 0, 43, 43, 41, 41, 167, 43, 41, 43, 43]
  )
  #expect(
    CrowBodyVaneRecords.productionTopologies.map {
      CrowBodyVaneRecords.detailVerticesPerInstance(for: $0)
    } == [0, 0, 774, 774, 738, 738, 3_006, 774, 738, 774, 774]
  )
  let morphology = CrowBodyVaneRecords.morphologyRecords()
  #expect(morphology.count == 3_212)
  #expect(Set(morphology.map(\.identity)).count == morphology.count)
  #expect(
    CrowBodyVaneRecords.temporalRecords(
      currentBodyCenter: .zero,
      previousBodyCenter: .zero,
      currentNeckPose: nil,
      previousNeckPose: nil,
      currentDeployment: 1,
      previousDeployment: 1
    ).count == 3_212
  )
  let ventralMorphology = CrowBodyVaneRecords.ventralMorphologyRecords()
  #expect(ventralMorphology.count == 1_304)
  #expect(Set(ventralMorphology.map(\.identity)).count == 1_304)
  #expect(
    ventralMorphology.allSatisfy {
      ($0.identity.x & 0xFF00_0000) == 0x0300_0000
    }
  )
  let retainedMorphology = CrowBodyVaneRecords.retainedMorphologyRecords()
  #expect(retainedMorphology.count == 6_179)
  #expect(Set(retainedMorphology.map(\.identity)).count == 6_179)
  let inactiveLimbRecords = CrowBodyVaneRecords.retainedTemporalRecords(
    currentBodyCenter: .zero,
    previousBodyCenter: .zero,
    currentNeckPose: nil,
    previousNeckPose: nil,
    currentDeployment: 0,
    previousDeployment: 0
  )
  #expect(inactiveLimbRecords.count == retainedMorphology.count)
  #expect(inactiveLimbRecords.map(\.identity.x) == retainedMorphology.map(\.identity.x))
  let femoralMorphology = CrowBodyVaneRecords.femoralMorphologyRecords()
  #expect(femoralMorphology.count == 540)
  #expect(Set(femoralMorphology.map(\.identity)).count == 540)
  #expect(
    femoralMorphology.allSatisfy {
      ($0.identity.x & 0xFF00_0000) == 0x0400_0000
    }
  )
  let cruralMorphology = CrowBodyVaneRecords.cruralMorphologyRecords()
  #expect(cruralMorphology.count == 324)
  #expect(Set(cruralMorphology.map(\.identity)).count == 324)
  #expect(
    cruralMorphology.allSatisfy {
      ($0.identity.x & 0xFF00_0000) == 0x0500_0000
    }
  )
  let throatMorphology = CrowBodyVaneRecords.throatBridgeMorphologyRecords()
  #expect(throatMorphology.count == 88)
  #expect(Set(throatMorphology.map(\.identity)).count == 88)
  #expect(
    throatMorphology.allSatisfy {
      ($0.identity.x & 0xFF00_0000) == 0x0600_0000
    }
  )
  let cranialMorphology = CrowBodyVaneRecords.cranialMorphologyRecords()
  #expect(cranialMorphology.count == 711)
  #expect(Set(cranialMorphology.map(\.identity)).count == 711)
  #expect(
    cranialMorphology.allSatisfy {
      ($0.identity.x & 0xFF00_0000) == 0x0700_0000
    }
  )
}

@Test("cranial contour relaxation is deterministic, root-bound, and bounded")
func cranialContourRelaxationIsBounded() {
  let sample = try! #require(CrowCranialFeatherTracts.samples(
    center: SIMD3<Float>(0.158, 0, 0.052),
    radii: SIMD3<Float>(0.0447, 0.0328, 0.0387),
    breathingScale: 1.012
  ).first)
  let root = CrowCranialFeatherTracts.relaxedBladeOffset(
    sample: sample,
    axialFraction: 0,
    signedWidth: 0,
    breathingScale: 1.012
  )
  let first = CrowCranialFeatherTracts.relaxedBladeOffset(
    sample: sample,
    axialFraction: 1,
    signedWidth: 0.75,
    breathingScale: 1.012
  )
  let replay = CrowCranialFeatherTracts.relaxedBladeOffset(
    sample: sample,
    axialFraction: 1,
    signedWidth: 0.75,
    breathingScale: 1.012
  )
  #expect(simd_length(root) < 1e-8)
  #expect(first == replay)
  #expect(simd_length(first) < 0.00045)
}

@Test("retained body contour set is deterministic, root-locked, and bounded")
func retainedBodyContourSetIsBounded() throws {
  let records = CrowBodyVaneRecords.groupedRecords(
    currentBodyCenter: .zero,
    previousBodyCenter: .zero,
    currentNeckPose: nil,
    previousNeckPose: nil,
    currentDeployment: 0,
    previousDeployment: 0,
    projectedPixelsPerMeter: 1_600
  ).values.flatMap { $0 }
  let record = try #require(records.first {
    ($0.identity.x & 0xFF00_0000) == 0x0200_0000
  })
  let normal = SIMD3<Float>(0, 0, 1)
  let widthAxis = SIMD3<Float>(0, 1, 0)
  let root = CrowBodyVaneRecords.bodyTractContourSetOffset(
    record: record, axial: 0, signedWidth: 0, normal: normal, widthAxis: widthAxis
  )
  let first = CrowBodyVaneRecords.bodyTractContourSetOffset(
    record: record, axial: 1, signedWidth: 0.75, normal: normal, widthAxis: widthAxis
  )
  let replay = CrowBodyVaneRecords.bodyTractContourSetOffset(
    record: record, axial: 1, signedWidth: 0.75, normal: normal, widthAxis: widthAxis
  )
  #expect(simd_length(root) < 1e-8)
  #expect(first == replay)
  #expect(simd_length(first) < 0.00036)
}

@Test("retained body detail reproduces the CPU mesostructure hierarchy")
func retainedBodyDetailReproducesCPUMesostructureHierarchy() {
  let samples = CrowBodyFeatherTracts.samples()
  let records = CrowBodyVaneRecords.temporalRecords(
    currentBodyCenter: .zero,
    previousBodyCenter: .zero,
    currentNeckPose: nil,
    previousNeckPose: nil,
    currentDeployment: 0,
    previousDeployment: 0
  )
  for recordIndex in [0, 896, 1_856, 2_156] {
    let sample = samples[recordIndex]
    let record = records[recordIndex]
    for projectedPixelsPerMeter: Float in [3_000, 10_000, 30_000] {
      let topology = CrowBodyVaneRecords.topology(
        for: sample,
        projectedPixelsPerMeter: projectedPixelsPerMeter
      )
      let expected = CrowFeatherMesostructure.segments(
        for: sample,
        projectedPixelsPerMeter: projectedPixelsPerMeter,
        camberScale: 1,
        transverseCamberRatio: CrowBodyFeatherTracts.transverseCamberRatio(
          region: sample.region,
          row: sample.row,
          transitionProgress: 0
        )
      ).filter { $0.kind != .rachis }
      let retained = CrowBodyVaneRecords.detailSegments(
        record: record,
        topology: topology,
        projectedPixelsPerMeter: projectedPixelsPerMeter,
        current: true
      )
      #expect(retained.count == expected.count)
      for (candidate, oracle) in zip(retained, expected) {
        #expect(candidate.kind == oracle.kind)
        #expect(simd_distance(candidate.start, oracle.start) < 2e-6)
        #expect(simd_distance(candidate.end, oracle.end) < 2e-6)
        #expect(abs(candidate.startRadiusMeters - oracle.startRadiusMeters) < 2e-7)
        #expect(abs(candidate.endRadiusMeters - oracle.endRadiusMeters) < 2e-7)
      }
    }
  }
}

@Test("retained body plumulaceous chains stay basal and continuous")
func retainedBodyPlumulaceousChainsStayBasalAndContinuous() {
  let record = CrowBodyVaneRecords.temporalRecords(
    currentBodyCenter: .zero,
    previousBodyCenter: SIMD3<Float>(0.004, -0.003, 0.002),
    currentNeckPose: nil,
    previousNeckPose: nil,
    currentDeployment: 1,
    previousDeployment: 0.4
  )[2_156]
  let topology = CrowBodyVaneTopology(axialSections: 8, widthSections: 5)
  let segments = CrowBodyVaneRecords.detailSegments(
    record: record,
    topology: topology,
    projectedPixelsPerMeter: 3_000,
    current: true
  ).filter { $0.kind == .plumulaceousBarb }

  #expect(segments.count == 18)
  let root = record.currentRootAndRootWidth.xyz
  let tip = record.currentTipAndMaximumWidth.xyz
  let length = simd_distance(root, tip)
  let axis = simd_normalize(tip - root)
  for segment in segments {
    let startAxial = simd_dot(segment.start - root, axis) / length
    let endAxial = simd_dot(segment.end - root, axis) / length
    #expect(startAxial > 0.02 && startAxial < 0.35)
    #expect(endAxial > startAxial && endAxial < 0.35)
    #expect(segment.startRadiusMeters > segment.endRadiusMeters)
    #expect(segment.endRadiusMeters > 0)
  }
  for chainStart in stride(from: 0, to: segments.count, by: 3) {
    #expect(
      simd_distance(
        segments[chainStart].end,
        segments[chainStart + 1].start
      ) < 1e-8
    )
    #expect(
      simd_distance(
        segments[chainStart + 1].end,
        segments[chainStart + 2].start
      ) < 1e-8
    )
  }
}

@Test("Metal future-close body barbules match the retained Swift oracle")
func metalFutureCloseBodyBarbulesMatchRetainedSwiftOracle() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let recordIndex = 2_156
  let currentBodyCenter = SIMD3<Float>(0.011, -0.007, 0.019)
  let previousBodyCenter = SIMD3<Float>(-0.006, 0.004, -0.013)
  let morphology = CrowBodyVaneRecords.morphologyRecords()[recordIndex]
  let temporal = CrowBodyVaneRecords.temporalRecords(
    currentBodyCenter: currentBodyCenter,
    previousBodyCenter: previousBodyCenter,
    currentNeckPose: nil,
    previousNeckPose: nil,
    currentDeployment: 1,
    previousDeployment: 0.35
  )[recordIndex]
  let topology = CrowBodyVaneTopology(axialSections: 16, widthSections: 7)
  let vertexCount = CrowBodyVaneRecords.detailVerticesPerInstance(for: topology)
  let projectedPixelsPerMeter: Float = 30_000

  func sharedBuffer<T>(_ values: [T]) throws -> MTLBuffer {
    let buffer = try backend.buffer(
      length: values.count * MemoryLayout<T>.stride,
      shared: true
    )
    values.withUnsafeBytes { bytes in
      if let baseAddress = bytes.baseAddress {
        buffer.contents().copyMemory(from: baseAddress, byteCount: bytes.count)
      }
    }
    return buffer
  }

  let morphologyBuffer = try sharedBuffer([morphology])
  let poseBuffer = try sharedBuffer([
    CrowBodyVanePoseUniforms(
      currentBodyCenterAndDeployment: SIMD4<Float>(currentBodyCenter, 1),
      previousBodyCenterAndDeployment: SIMD4<Float>(previousBodyCenter, 0.35)
    )
  ])
  let neckBuffer = try sharedBuffer(
    CrowBodyVaneRecords.neckTransforms(current: nil, previous: nil)
  )
  let output = try backend.buffer(
    length: vertexCount * MemoryLayout<CrowFeatherVertexGPU>.stride,
    shared: true
  )
  var uniforms = CrowBodyVaneGeometryUniforms(
    counts: SIMD4<UInt32>(16, 7, 1, UInt32(vertexCount)),
    selection: SIMD4<Float>(projectedPixelsPerMeter, 0, 0, 0)
  )
  let pipeline = try backend.compute("probeCrowBodyDetailVertices")
  let commandBuffer = try #require(backend.queue.makeCommandBuffer())
  let encoder = try #require(commandBuffer.makeComputeCommandEncoder())
  encoder.setBuffer(morphologyBuffer, offset: 0, index: 0)
  encoder.setBytes(
    &uniforms,
    length: MemoryLayout<CrowBodyVaneGeometryUniforms>.stride,
    index: 1
  )
  encoder.setBuffer(output, offset: 0, index: 2)
  encoder.setBuffer(poseBuffer, offset: 0, index: 3)
  encoder.setBuffer(neckBuffer, offset: 0, index: 4)
  backend.dispatch1D(encoder, pipeline: pipeline, count: vertexCount)
  encoder.endEncoding()
  commandBuffer.commit()
  commandBuffer.waitUntilCompleted()
  #expect(commandBuffer.status == .completed)

  let pointer = output.contents().bindMemory(
    to: CrowFeatherVertexGPU.self,
    capacity: vertexCount
  )
  let vertices = UnsafeBufferPointer(start: pointer, count: vertexCount)
  for vertexIndex in [0, 18, 36, 72, vertexCount / 2, vertexCount - 1] {
    let gpu = vertices[vertexIndex]
    let expected = CrowBodyVaneRecords.detailVertex(
      record: temporal,
      topology: topology,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      vertexIndex: vertexIndex
    )
    #expect(simd_distance(gpu.position.xyz, expected.position.xyz) < 2e-6)
    #expect(
      simd_distance(gpu.previousPosition.xyz, expected.previousPosition.xyz)
        < 2e-6
    )
    #expect(simd_distance(gpu.normal.xyz, expected.normal.xyz) < 1e-3)
    #expect(simd_distance(gpu.color.xyz, expected.color.xyz) < 2e-6)
    #expect(gpu.identity == expected.identity)
    #expect(gpu.parameters == expected.parameters)
  }
}

@Test("Metal gular shafts and barb groups match the transformed Swift oracle")
func metalGularDetailMatchesTransformedSwiftOracle() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let morphologies = CrowCranialFeatherTracts.morphologySamples()
  let morphologyIndex = try #require(
    morphologies.firstIndex { $0.region == .throat }
  )
  let morphology = morphologies[morphologyIndex]
  let gpuMorphology = CrowBodyVaneRecords.cranialMorphologyRecords()[
    morphologyIndex
  ]
  let currentBodyCenter = SIMD3<Float>(0.008, -0.004, 0.015)
  let previousBodyCenter = SIMD3<Float>(-0.005, 0.003, -0.009)
  let radii = SIMD3<Float>(0.0447, 0.0328, 0.0387)
  let currentBreathing: Float = 1.009
  let previousBreathing: Float = 0.993
  let currentNeckPose = CrowStandingNeckPose(
    translation: SIMD3<Float>(0.0012, -0.0008, 0.0006),
    yawRadians: 0.017,
    pitchRadians: -0.012,
    rollRadians: 0.005
  )
  let previousNeckPose = CrowStandingNeckPose(
    translation: SIMD3<Float>(-0.0007, 0.0005, -0.0004),
    yawRadians: -0.010,
    pitchRadians: 0.008,
    rollRadians: -0.003
  )

  func sharedBuffer<T>(_ values: [T]) throws -> MTLBuffer {
    let buffer = try backend.buffer(
      length: values.count * MemoryLayout<T>.stride,
      shared: true
    )
    values.withUnsafeBytes { bytes in
      if let baseAddress = bytes.baseAddress {
        buffer.contents().copyMemory(from: baseAddress, byteCount: bytes.count)
      }
    }
    return buffer
  }

  let morphologyBuffer = try sharedBuffer([gpuMorphology])
  let poseBuffer = try sharedBuffer([
    CrowBodyVanePoseUniforms(
      currentBodyCenterAndDeployment: SIMD4<Float>(currentBodyCenter, 1),
      previousBodyCenterAndDeployment: SIMD4<Float>(previousBodyCenter, 1),
      currentCranialRadiiAndBreathing: SIMD4<Float>(radii, currentBreathing),
      previousCranialRadiiAndBreathing: SIMD4<Float>(radii, previousBreathing),
      currentNeckTranslationAndYaw: SIMD4<Float>(
        currentNeckPose.translation,
        currentNeckPose.yawRadians
      ),
      currentNeckPitchRollAndActive: SIMD4<Float>(
        currentNeckPose.pitchRadians,
        currentNeckPose.rollRadians,
        1,
        0
      ),
      previousNeckTranslationAndYaw: SIMD4<Float>(
        previousNeckPose.translation,
        previousNeckPose.yawRadians
      ),
      previousNeckPitchRollAndActive: SIMD4<Float>(
        previousNeckPose.pitchRadians,
        previousNeckPose.rollRadians,
        1,
        0
      )
    )
  ])
  let neckBuffer = try sharedBuffer(
    CrowBodyVaneRecords.neckTransforms(current: nil, previous: nil)
  )
  let segmentCount = 1 + 2 * CrowGularFeatherDetail.barbPairCount
  let output = try backend.buffer(
    length: segmentCount * MemoryLayout<CrowBodyDetailSegmentGPU>.stride,
    shared: true
  )
  let pipeline = try backend.compute("probeCrowGularDetailSegments")
  let commandBuffer = try #require(backend.queue.makeCommandBuffer())
  let encoder = try #require(commandBuffer.makeComputeCommandEncoder())
  encoder.setBuffer(morphologyBuffer, offset: 0, index: 0)
  encoder.setBuffer(output, offset: 0, index: 1)
  encoder.setBuffer(poseBuffer, offset: 0, index: 2)
  encoder.setBuffer(neckBuffer, offset: 0, index: 3)
  backend.dispatch1D(encoder, pipeline: pipeline, count: segmentCount)
  encoder.endEncoding()
  commandBuffer.commit()
  commandBuffer.waitUntilCompleted()
  #expect(commandBuffer.status == .completed)

  let currentFeather = CrowCranialFeatherTracts.feather(
    morphology: morphology,
    center: currentBodyCenter + CrowCranialAnatomy.showcaseCenterOffsetMeters,
    radii: radii,
    breathingScale: currentBreathing
  )
  let previousFeather = CrowCranialFeatherTracts.feather(
    morphology: morphology,
    center: previousBodyCenter + CrowCranialAnatomy.showcaseCenterOffsetMeters,
    radii: radii,
    breathingScale: previousBreathing
  )
  let currentSegments = CrowGularFeatherDetail.segments(
    for: currentFeather,
    projectedPixelsPerMeter: 1_600
  )
  let previousSegments = CrowGularFeatherDetail.segments(
    for: previousFeather,
    projectedPixelsPerMeter: 1_600
  )
  #expect(currentSegments.count == segmentCount)
  #expect(previousSegments.count == segmentCount)
  let pointer = output.contents().bindMemory(
    to: CrowBodyDetailSegmentGPU.self,
    capacity: segmentCount
  )
  for index in 0..<segmentCount {
    let gpu = pointer[index]
    let current = currentSegments[index]
    let previous = previousSegments[index]
    let expectedCurrentStart = CrowHeadNeckBlend.position(
      current.start,
      bodyCenter: currentBodyCenter,
      neckPose: currentNeckPose
    )
    let expectedCurrentEnd = CrowHeadNeckBlend.position(
      current.end,
      bodyCenter: currentBodyCenter,
      neckPose: currentNeckPose
    )
    let expectedPreviousStart = CrowHeadNeckBlend.position(
      previous.start,
      bodyCenter: previousBodyCenter,
      neckPose: previousNeckPose
    )
    let expectedPreviousEnd = CrowHeadNeckBlend.position(
      previous.end,
      bodyCenter: previousBodyCenter,
      neckPose: previousNeckPose
    )
    #expect(
      simd_distance(gpu.currentStartAndRadius.xyz, expectedCurrentStart) < 2e-6
    )
    #expect(
      simd_distance(gpu.currentEndAndRadius.xyz, expectedCurrentEnd) < 2e-6
    )
    #expect(
      simd_distance(gpu.previousStartAndRadius.xyz, expectedPreviousStart)
        < 2e-6
    )
    #expect(
      simd_distance(gpu.previousEndAndRadius.xyz, expectedPreviousEnd) < 2e-6
    )
    #expect(
      abs(gpu.currentStartAndRadius.w - current.startRadiusMeters) < 2e-7
    )
    #expect(
      abs(gpu.currentEndAndRadius.w - current.endRadiusMeters) < 2e-7
    )
    #expect(gpu.currentNormalAndKind.w == Float(current.kind.rawValue))
  }
}

@Test("Metal procedural body vanes match the Swift geometry oracle")
func metalProceduralBodyVanesMatchSwiftGeometryOracle() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let deformer = try CrowBodyVaneGeometryDeformer(backend: backend)
  let commandBuffer = try #require(backend.queue.makeCommandBuffer())
  let currentFemoralPose = CrowFemoralVanePoseSample(
    CrowStandingPose.sample(phase: 0.37)
  )
  let previousFemoralPose = CrowFemoralVanePoseSample(
    CrowStandingPose.sample(phase: 0.31)
  )
  let currentNeckPose = CrowStandingNeckPose(
    translation: SIMD3<Float>(0.001, -0.002, 0.0015),
    yawRadians: 0.018,
    pitchRadians: -0.013,
    rollRadians: 0.006
  )
  let previousNeckPose = CrowStandingNeckPose(
    translation: SIMD3<Float>(-0.0005, 0.001, -0.0007),
    yawRadians: -0.011,
    pitchRadians: 0.009,
    rollRadians: -0.004
  )
  let cranialRadii = SIMD3<Float>(0.0447, 0.0328, 0.0387)
  let currentCranialBreathing: Float = 1.009
  let previousCranialBreathing: Float = 0.994
  let frame = try deformer.encode(
    currentBodyCenter: currentFemoralPose.bodyCenter,
    previousBodyCenter: previousFemoralPose.bodyCenter,
    currentNeckPose: currentNeckPose,
    previousNeckPose: previousNeckPose,
    cranialRadii: cranialRadii,
    currentCranialBreathingScale: currentCranialBreathing,
    previousCranialBreathingScale: previousCranialBreathing,
    currentFemoralPose: currentFemoralPose,
    previousFemoralPose: previousFemoralPose,
    currentDeployment: 1,
    previousDeployment: 0.35,
    projectedPixelsPerMeter: 1_600,
    commandBuffer: commandBuffer,
    auditReadback: true
  )
  commandBuffer.commit()
  commandBuffer.waitUntilCompleted()
  #expect(commandBuffer.status == .completed)
  #expect(frame.auditReadbackReady)
  #expect(frame.morphologyRecordCount == 6_179)
  #expect(deformer.activeRecordCount(for: frame) == 6_179)
  #expect(deformer.activeFemoralRecordCount(for: frame) == 540)
  #expect(deformer.expandedFemoralVertexCount(for: frame) == 68_040)
  #expect(deformer.activeCruralRecordCount(for: frame) == 324)
  #expect(deformer.expandedCruralVertexCount(for: frame) == 46_656)
  #expect(deformer.activeThroatBridgeRecordCount(for: frame) == 88)
  #expect(deformer.expandedThroatBridgeVertexCount(for: frame) == 11_088)
  #expect(deformer.activeCranialRecordCount(for: frame) == 711)
  let expectedCranialVertexCount = CrowCranialFeatherTracts.morphologySamples()
    .reduce(0) { partial, sample in
      let tessellation = CrowFeatherCoverageLOD.tessellation(
        lengthMeters: CrowCranialFeatherTracts.lodReferenceLengthMeters(for: sample),
        projectedPixelsPerMeter: 1_600,
        baseAxialSections: sample.region == .nape ? 6 : 5
      )
      return partial
        + tessellation.axialSections * tessellation.widthSections * 6
    }
  #expect(expectedCranialVertexCount == 35_568)
  #expect(deformer.expandedCranialVertexCount(for: frame) == expectedCranialVertexCount)
  #expect(deformer.expandedVertexCount(for: frame) > 0)

  for batch in frame.batches where batch.auditRecordCount > 0 {
    let records = deformer.auditRecords(for: batch)
    let vertices = deformer.vertices(for: batch)
    for recordIndex in Set([
      0,
      max(0, records.count - 1),
      records.firstIndex { Int($0.morphology.y) == 0 } ?? 0,
    ]) {
      let record = records[recordIndex]
      if (record.identity.x & 0xFF00_0000) == 0x0700_0000 { continue }
      let interestingVertices = Set([
        0,
        batch.vertexCount / 2,
        max(0, batch.vertexCount - 1),
      ])
      for localVertex in interestingVertices {
        let grid = CrowBodyVaneRecords.decodedVertex(
          localVertex,
          topology: batch.topology
        )
        let gpu = vertices[recordIndex * batch.vertexCount + localVertex]
        let current = CrowBodyVaneRecords.point(
          record: record,
          topology: batch.topology,
          current: true,
          axialIndex: grid.axial,
          widthIndex: grid.width
        )
        let previous = CrowBodyVaneRecords.point(
          record: record,
          topology: batch.topology,
          current: false,
          axialIndex: grid.axial,
          widthIndex: grid.width
        )
        let normal = CrowBodyVaneRecords.normal(
          record: record,
          topology: batch.topology,
          axialIndex: grid.axial,
          widthIndex: grid.width
        )
        #expect(simd_distance(gpu.position.xyz, current) < 2e-6)
        #expect(simd_distance(gpu.previousPosition.xyz, previous) < 2e-6)
        // The terminal chord is deliberately narrow; fast-math normalization
        // remains within 0.06 degrees of the FP32 Swift oracle there.
        #expect(simd_distance(gpu.normal.xyz, normal) < 1e-3)
        #expect(gpu.identity == record.identity)
        #expect(gpu.color == record.color)
      }
    }
    if let cranialRecordIndex = records.firstIndex(where: {
      ($0.identity.x & 0xFF00_0000) == 0x0700_0000
    }) {
      let record = records[cranialRecordIndex]
      let inventoryIndex = Int(record.identity.x & 0x00FF_FFFF)
      let morphology = CrowCranialFeatherTracts.morphologySamples()[inventoryIndex]
      let currentSample = CrowCranialFeatherTracts.feather(
        morphology: morphology,
        center: currentFemoralPose.bodyCenter
          + CrowCranialAnatomy.showcaseCenterOffsetMeters,
        radii: cranialRadii,
        breathingScale: currentCranialBreathing
      )
      let previousSample = CrowCranialFeatherTracts.feather(
        morphology: morphology,
        center: previousFemoralPose.bodyCenter
          + CrowCranialAnatomy.showcaseCenterOffsetMeters,
        radii: cranialRadii,
        breathingScale: previousCranialBreathing
      )
      for localVertex in Set([
        0,
        batch.vertexCount / 2,
        max(0, batch.vertexCount - 1),
      ]) {
        let grid = CrowBodyVaneRecords.decodedVertex(
          localVertex,
          topology: batch.topology
        )
        let sourceCurrent = cranialBladePoint(
          sample: currentSample,
          topology: batch.topology,
          axialIndex: grid.axial,
          widthIndex: grid.width,
          breathingScale: currentCranialBreathing
        )
        let sourcePrevious = cranialBladePoint(
          sample: previousSample,
          topology: batch.topology,
          axialIndex: grid.axial,
          widthIndex: grid.width,
          breathingScale: previousCranialBreathing
        )
        let expectedCurrent = CrowHeadNeckBlend.position(
          sourceCurrent,
          bodyCenter: currentFemoralPose.bodyCenter,
          neckPose: currentNeckPose
        )
        let expectedPrevious = CrowHeadNeckBlend.position(
          sourcePrevious,
          bodyCenter: previousFemoralPose.bodyCenter,
          neckPose: previousNeckPose
        )
        let sourceNormal = cranialBladeNormal(
          sample: currentSample,
          topology: batch.topology,
          axialIndex: grid.axial,
          widthIndex: grid.width,
          breathingScale: currentCranialBreathing
        )
        let expectedNormal = CrowHeadNeckBlend.normal(
          sourceNormal,
          position: sourceCurrent,
          bodyCenter: currentFemoralPose.bodyCenter,
          neckPose: currentNeckPose
        )
        let gpu = vertices[cranialRecordIndex * batch.vertexCount + localVertex]
        #expect(simd_distance(gpu.position.xyz, expectedCurrent) < 2e-6)
        #expect(simd_distance(gpu.previousPosition.xyz, expectedPrevious) < 2e-6)
        #expect(simd_distance(gpu.normal.xyz, expectedNormal) < 1e-3)
        #expect(gpu.identity == record.identity)
        #expect(gpu.color == record.color)
      }
    }
    guard batch.rachisVertexCount > 0,
      let recordIndex = records.firstIndex(where: {
        ($0.identity.x & 0xFF00_0000) == 0x0200_0000
          && CrowBodyVaneRecords.rachisIsResolved(
          record: $0,
          projectedPixelsPerMeter: batch.projectedPixelsPerMeter
          )
      })
    else { continue }
    let rachisVertices = deformer.rachisVertices(for: batch)
    for localVertex in Set([
      0,
      batch.rachisVertexCount / 2,
      batch.rachisVertexCount - 1,
    ]) {
      let gpu = rachisVertices[
        recordIndex * batch.rachisVertexCount + localVertex
      ]
      let expected = CrowBodyVaneRecords.rachisVertex(
        record: records[recordIndex],
        topology: batch.topology,
        projectedPixelsPerMeter: batch.projectedPixelsPerMeter,
        vertexIndex: localVertex
      )
      #expect(simd_distance(gpu.position.xyz, expected.position.xyz) < 2e-6)
      #expect(
        simd_distance(gpu.previousPosition.xyz, expected.previousPosition.xyz)
          < 2e-6
      )
      #expect(simd_distance(gpu.normal.xyz, expected.normal.xyz) < 1e-3)
      #expect(simd_distance(gpu.color.xyz, expected.color.xyz) < 2e-6)
      #expect(gpu.identity == expected.identity)
      #expect(gpu.parameters == expected.parameters)
    }
    guard batch.detailVertexCount > 0 else { continue }
    let detailVertices = deformer.detailVertices(for: batch)
    let detailRecordIndex = min(recordIndex, records.count - 1)
    for localVertex in Set([
      0,
      min(17, batch.detailVertexCount - 1),
      batch.detailVertexCount / 2,
      batch.detailVertexCount - 1,
    ]) {
      let gpu = detailVertices[
        detailRecordIndex * batch.detailVertexCount + localVertex
      ]
      let expected = CrowBodyVaneRecords.detailVertex(
        record: records[detailRecordIndex],
        topology: batch.topology,
        projectedPixelsPerMeter: batch.projectedPixelsPerMeter,
        vertexIndex: localVertex
      )
      #expect(simd_distance(gpu.position.xyz, expected.position.xyz) < 2e-6)
      #expect(
        simd_distance(gpu.previousPosition.xyz, expected.previousPosition.xyz)
          < 2e-6
      )
      #expect(simd_distance(gpu.normal.xyz, expected.normal.xyz) < 1e-3)
      #expect(simd_distance(gpu.color.xyz, expected.color.xyz) < 2e-6)
      #expect(gpu.identity == expected.identity)
      #expect(gpu.parameters == expected.parameters)
    }
  }
}

@Test("body vane production retains morphology and triple-buffers pose")
func bodyVaneProductionStorageIsTripleBufferedAndIndirect() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let deformer = try CrowBodyVaneGeometryDeformer(backend: backend)
  var frames: [CrowBodyVaneGeometryFrame] = []
  for index in 0..<4 {
    let commandBuffer = try #require(backend.queue.makeCommandBuffer())
    let frame = try deformer.encode(
      currentBodyCenter: SIMD3<Float>(Float(index) * 0.001, 0, 0),
      previousBodyCenter: SIMD3<Float>(Float(index - 1) * 0.001, 0, 0),
      currentNeckPose: nil,
      previousNeckPose: nil,
      currentDeployment: 1,
      previousDeployment: 1,
      projectedPixelsPerMeter: 1_600,
      commandBuffer: commandBuffer
    )
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    #expect(commandBuffer.status == .completed)
    frames.append(frame)
  }

  let batchCount = frames[0].batches.count
  #expect(batchCount == CrowBodyVaneRecords.productionTopologies.count)
  #expect(frames.map(\.slot) == [0, 1, 2, 0])
  #expect(frames.map(\.morphologyBufferAllocationCount) == [1, 1, 1, 1])
  #expect(frames.allSatisfy { $0.morphologyRecordCount == 6_179 })
  #expect(
    frames.allSatisfy {
      $0.morphologyRecordBytes == $0.morphologyRecordCount
        * MemoryLayout<CrowBodyVaneMorphologyGPU>.stride
    }
  )
  #expect(
    frames.allSatisfy {
      $0.morphologyCapacityBytes == $0.morphologyRecordBytes
    }
  )
  #expect(frames.allSatisfy { $0.poseInputBytes == 1_984 })
  #expect(frames.allSatisfy { $0.retainedPoseCapacityBytes == 5_952 })
  #expect(deformer.retainedIndirectDrawBytes == 1_584)
  #expect(
    frames.allSatisfy {
      $0.retainedDetailSegmentCapacityBytes
        == 3 * 3_212 * 43 * MemoryLayout<CrowBodyDetailSegmentGPU>.stride
    }
  )
  #expect(frames.allSatisfy { $0.detailSegmentBufferAllocationCount == 3 })
  #expect(frames.allSatisfy { deformer.activeRecordCount(for: $0) == 4_604 })
  #expect(frames.allSatisfy { deformer.expandedRachisVertexCount(for: $0) > 0 })
  #expect(frames.allSatisfy { deformer.expandedDetailVertexCount(for: $0) > 0 })

  for index in 0..<batchCount {
    let first = frames[0].batches[index]
    let reused = frames[3].batches[index]
    #expect(first.topology == reused.topology)
    #expect(first.morphologyBuffer === reused.morphologyBuffer)
    #expect(first.poseBuffer === reused.poseBuffer)
    #expect(first.neckTransformBuffer === reused.neckTransformBuffer)
    #expect(first.workBuffer === reused.workBuffer)
    #expect(first.indirectDrawBuffer === reused.indirectDrawBuffer)
    let arguments = deformer.drawArguments(for: reused)
    #expect(arguments.vertexCount == UInt32(reused.vertexCount))
    #expect(arguments.vertexStart == 0)
    #expect(
      arguments.instanceCount
        == deformer.topologyCounts(for: frames[3])[index]
    )
    let rachisArguments = deformer.drawRachisArguments(for: reused)
    let bodyInstanceCount = deformer.selectedRecordIndices(
      for: frames[3],
      topologyIndex: index
    ).count { Int($0) < CrowBodyVaneRecords.bodyMorphologyRecordCount }
    #expect(rachisArguments.vertexCount == UInt32(reused.rachisVertexCount))
    #expect(rachisArguments.vertexStart == 0)
    #expect(rachisArguments.instanceCount == UInt32(bodyInstanceCount))
    let detailArguments = deformer.drawDetailArguments(for: reused)
    #expect(detailArguments.vertexCount == UInt32(reused.detailVertexCount))
    #expect(detailArguments.vertexStart == 0)
    #expect(detailArguments.instanceCount == UInt32(bodyInstanceCount))
  }
}

@Test("Metal retained-family mask separates femoral crural throat and cranial ownership")
func metalRetainedFamilyMaskSeparatesIndependentOwners() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let deformer = try CrowBodyVaneGeometryDeformer(backend: backend)
  let standingPose = CrowStandingPose.sample(phase: 0.27)
  let pose = CrowFemoralVanePoseSample(standingPose)

  func frame(mask: UInt32) throws -> CrowBodyVaneGeometryFrame {
    let commandBuffer = try #require(backend.queue.makeCommandBuffer())
    let frame = try deformer.encode(
      currentBodyCenter: pose.bodyCenter,
      previousBodyCenter: pose.bodyCenter,
      currentNeckPose: standingPose.neckPose,
      previousNeckPose: standingPose.neckPose,
      cranialRadii: SIMD3<Float>(0.0447, 0.0328, 0.0387),
      currentCranialBreathingScale: 1.006,
      previousCranialBreathingScale: 0.997,
      currentFemoralPose: pose,
      previousFemoralPose: pose,
      retainedFamilyMask: mask,
      currentDeployment: 0,
      previousDeployment: 0,
      projectedPixelsPerMeter: 1_600,
      commandBuffer: commandBuffer
    )
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    #expect(commandBuffer.status == .completed)
    return frame
  }

  let femoralOnly = try frame(mask: 0x1)
  #expect(deformer.activeFemoralRecordCount(for: femoralOnly) == 540)
  #expect(deformer.activeCruralRecordCount(for: femoralOnly) == 0)
  #expect(deformer.activeThroatBridgeRecordCount(for: femoralOnly) == 0)
  let cruralOnly = try frame(mask: 0x2)
  #expect(deformer.activeFemoralRecordCount(for: cruralOnly) == 0)
  #expect(deformer.activeCruralRecordCount(for: cruralOnly) == 324)
  #expect(deformer.activeThroatBridgeRecordCount(for: cruralOnly) == 0)
  let throatOnly = try frame(mask: 0x4)
  #expect(deformer.activeFemoralRecordCount(for: throatOnly) == 0)
  #expect(deformer.activeCruralRecordCount(for: throatOnly) == 0)
  #expect(deformer.activeThroatBridgeRecordCount(for: throatOnly) == 88)
  #expect(deformer.activeCranialRecordCount(for: throatOnly) == 0)
  let cranialOnly = try frame(mask: 0x8)
  #expect(deformer.activeFemoralRecordCount(for: cranialOnly) == 0)
  #expect(deformer.activeCruralRecordCount(for: cranialOnly) == 0)
  #expect(deformer.activeThroatBridgeRecordCount(for: cranialOnly) == 0)
  #expect(deformer.activeCranialRecordCount(for: cranialOnly) == 711)
}

@Test("Metal family-7 visibility compacts stable cranial and gular work")
func metalFamilySevenVisibilityCompactsStableCranialAndGularWork() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let deformer = try CrowBodyVaneGeometryDeformer(backend: backend)
  let morphology = CrowBodyVaneRecords.retainedMorphologyRecords()

  func visibility(
    target: SIMD3<Float>,
    previousDepthPyramid: MTLTexture? = nil
  ) throws -> CrowCranialVisibilityFrame {
    let commandBuffer = try #require(backend.queue.makeCommandBuffer())
    let bodyFrame = try deformer.encode(
      currentBodyCenter: .zero,
      previousBodyCenter: .zero,
      currentNeckPose: nil,
      previousNeckPose: nil,
      cranialRadii: SIMD3<Float>(0.0447, 0.0328, 0.0387),
      currentCranialBreathingScale: 1.006,
      previousCranialBreathingScale: 0.997,
      retainedFamilyMask: 0x8,
      currentDeployment: 0,
      previousDeployment: 0,
      projectedPixelsPerMeter: 1_600,
      commandBuffer: commandBuffer
    )
    var camera = CameraState()
    camera.target = target
    camera.distance = 0.50
    camera.yaw = 1.18
    camera.pitch = 0.075
    let viewProjection = camera.uniforms(
      aspect: 16.0 / 9.0,
      ribbonWidth: 0.001
    ).viewProjection
    let compact = try deformer.encodeCranialVisibility(
      for: bodyFrame,
      viewProjection: viewProjection,
      previousViewProjection: viewProjection,
      previousDepthPyramid: previousDepthPyramid,
      occlusionViewport: SIMD2<Int>(128, 72),
      commandBuffer: commandBuffer
    )
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    #expect(commandBuffer.status == .completed)
    return compact
  }

  let visible = try visibility(target: SIMD3<Float>(0.158, 0, 0.052))
  let cranialIndices = deformer.cranialVisibleRecordIndices(for: visible)
  let gularIndices = deformer.gularVisibleRecordIndices(for: visible)
  #expect(!cranialIndices.isEmpty)
  #expect(cranialIndices.count <= CrowBodyVaneRecords.cranialMorphologyRecordCount)
  #expect(Set(cranialIndices).count == cranialIndices.count)
  #expect(
    cranialIndices.allSatisfy {
      Int($0) >= CrowBodyVaneRecords.cranialMorphologyBase
        && (morphology[Int($0)].identity.x & 0xFF00_0000) == 0x0700_0000
    }
  )
  #expect(gularIndices.count <= 225)
  #expect(
    gularIndices.allSatisfy {
      cranialIndices.contains($0) && morphology[Int($0)].identity.w == 10
    }
  )
  let arguments = visible.indirectDrawBuffer.contents().bindMemory(
    to: DrawPrimitivesIndirectArguments.self,
    capacity: 12
  )
  for topologyIndex in 0..<11 {
    let base = Int(arguments[topologyIndex].baseInstance)
    let count = Int(arguments[topologyIndex].instanceCount)
    let selected = cranialIndices[base..<(base + count)]
    #expect(Array(selected) == selected.sorted())
  }
  #expect(deformer.cranialExpandedVertexCount(for: visible) > 0)
  #expect(
    deformer.cranialFrustumVisibleRecordCount(for: visible)
      == deformer.cranialVisibleRecordCount(for: visible)
  )
  #expect(deformer.cranialOcclusionTestedRecordCount(for: visible) == 0)
  #expect(deformer.cranialOcclusionCulledRecordCount(for: visible) == 0)
  #expect(
    deformer.gularFrustumVisibleRecordCount(for: visible)
      == deformer.gularVisibleRecordCount(for: visible)
  )
  #expect(deformer.gularOcclusionTestedRecordCount(for: visible) == 0)
  #expect(deformer.gularOcclusionCulledRecordCount(for: visible) == 0)
  #expect(
    deformer.gularExpandedVertexCount(for: visible)
      == gularIndices.count * (1 + 2 * CrowGularFeatherDetail.barbPairCount) * 18
  )

  let outside = try visibility(target: SIMD3<Float>(100, 100, 100))
  #expect(deformer.cranialVisibleRecordCount(for: outside) == 0)
  #expect(deformer.gularVisibleRecordCount(for: outside) == 0)
  #expect(deformer.cranialExpandedVertexCount(for: outside) == 0)
  #expect(deformer.gularExpandedVertexCount(for: outside) == 0)
}

@Test("previous max depth conservatively culls retained family-7 work")
func previousMaxDepthCullsRetainedFamilySevenWork() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let deformer = try CrowBodyVaneGeometryDeformer(backend: backend)
  let target = SIMD3<Float>(0.158, 0, 0.052)
  let viewport = SIMD2<Int>(128, 72)
  var camera = CameraState()
  camera.target = target
  camera.distance = 0.50
  camera.yaw = 1.18
  camera.pitch = 0.075
  let viewProjection = camera.uniforms(
    aspect: Float(viewport.x) / Float(viewport.y),
    ribbonWidth: 0.001
  ).viewProjection

  func classify(depth: Float?) throws -> CrowCranialVisibilityFrame {
    let commandBuffer = try #require(backend.queue.makeCommandBuffer())
    let bodyFrame = try deformer.encode(
      currentBodyCenter: .zero,
      previousBodyCenter: .zero,
      currentNeckPose: nil,
      previousNeckPose: nil,
      cranialRadii: SIMD3<Float>(0.0447, 0.0328, 0.0387),
      currentCranialBreathingScale: 1.006,
      previousCranialBreathingScale: 0.997,
      retainedFamilyMask: 0x8,
      currentDeployment: 0,
      previousDeployment: 0,
      projectedPixelsPerMeter: 1_600,
      commandBuffer: commandBuffer
    )
    let depthTexture = try depth.map {
      try constantR32Texture(
        device: device,
        width: viewport.x,
        height: viewport.y,
        value: $0
      )
    }
    let compact = try deformer.encodeCranialVisibility(
      for: bodyFrame,
      viewProjection: viewProjection,
      previousViewProjection: viewProjection,
      previousDepthPyramid: depthTexture,
      occlusionViewport: viewport,
      commandBuffer: commandBuffer
    )
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    #expect(commandBuffer.status == .completed)
    return compact
  }

  let historyReset = try classify(depth: nil)
  let background = try classify(depth: 1)
  #expect(
    deformer.cranialFrustumVisibleRecordCount(for: background)
      == deformer.cranialFrustumVisibleRecordCount(for: historyReset)
  )
  #expect(
    deformer.cranialVisibleRecordCount(for: background)
      == deformer.cranialVisibleRecordCount(for: historyReset)
  )
  #expect(
    deformer.cranialOcclusionTestedRecordCount(for: background)
      == deformer.cranialFrustumVisibleRecordCount(for: background)
  )
  #expect(deformer.cranialOcclusionCulledRecordCount(for: background) == 0)
  #expect(
    deformer.cranialVisibleRecordCount(for: background)
      + deformer.cranialOcclusionCulledRecordCount(for: background)
      == deformer.cranialFrustumVisibleRecordCount(for: background)
  )
  #expect(
    deformer.gularOcclusionTestedRecordCount(for: background)
      == deformer.gularFrustumVisibleRecordCount(for: background)
  )
  #expect(deformer.gularOcclusionCulledRecordCount(for: background) == 0)
  #expect(
    deformer.gularVisibleRecordCount(for: background)
      + deformer.gularOcclusionCulledRecordCount(for: background)
      == deformer.gularFrustumVisibleRecordCount(for: background)
  )
  #expect(
    deformer.cranialVisibleRecordIndices(for: background)
      == deformer.cranialVisibleRecordIndices(for: historyReset)
  )

  let occluded = try classify(depth: 0)
  #expect(
    deformer.cranialOcclusionTestedRecordCount(for: occluded)
      == deformer.cranialFrustumVisibleRecordCount(for: occluded)
  )
  #expect(deformer.cranialOcclusionCulledRecordCount(for: occluded) > 0)
  #expect(
    deformer.cranialVisibleRecordCount(for: occluded)
      < deformer.cranialFrustumVisibleRecordCount(for: occluded)
  )
  #expect(
    deformer.cranialVisibleRecordCount(for: occluded)
      + deformer.cranialOcclusionCulledRecordCount(for: occluded)
      == deformer.cranialFrustumVisibleRecordCount(for: occluded)
  )
  #expect(
    deformer.gularOcclusionTestedRecordCount(for: occluded)
      == deformer.gularFrustumVisibleRecordCount(for: occluded)
  )
  #expect(
    deformer.gularOcclusionCulledRecordCount(for: occluded)
      <= deformer.gularFrustumVisibleRecordCount(for: occluded)
  )
  let survivors = deformer.cranialVisibleRecordIndices(for: occluded)
  let gularSurvivors = deformer.gularVisibleRecordIndices(for: occluded)
  #expect(Set(survivors).count == survivors.count)
  #expect(Set(gularSurvivors).count == gularSurvivors.count)
  #expect(gularSurvivors.count == deformer.gularVisibleRecordCount(for: occluded))
  #expect(gularSurvivors.allSatisfy { survivors.contains($0) })
  #expect(
    survivors.allSatisfy {
      deformer.cranialVisibleRecordIndices(for: historyReset).contains($0)
    }
  )
}

@Test("Metal body vane LOD selection matches the deterministic CPU oracle")
func metalBodyVaneLODSelectionMatchesCPUOracle() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let deformer = try CrowBodyVaneGeometryDeformer(backend: backend)
  let currentLimbPose = CrowFemoralVanePoseSample(
    CrowStandingPose.sample(phase: 0.41)
  )
  let previousLimbPose = CrowFemoralVanePoseSample(
    CrowStandingPose.sample(phase: 0.35)
  )
  let cranialRadii = SIMD3<Float>(0.0447, 0.0328, 0.0387)
  for projectedPixelsPerMeter: Float in [800, 1_000, 1_600, 4_000, 20_000] {
    let allRecords = CrowBodyVaneRecords.retainedTemporalRecords(
      currentBodyCenter: .zero,
      previousBodyCenter: .zero,
      currentNeckPose: nil,
      previousNeckPose: nil,
      cranialRadii: cranialRadii,
      currentCranialBreathingScale: 1.01,
      previousCranialBreathingScale: 0.99,
      currentFemoralPose: currentLimbPose,
      previousFemoralPose: previousLimbPose,
      currentDeployment: 1,
      previousDeployment: 1
    )
    let expected = CrowBodyVaneRecords.retainedGroupedRecords(
      currentBodyCenter: .zero,
      previousBodyCenter: .zero,
      currentNeckPose: nil,
      previousNeckPose: nil,
      cranialRadii: cranialRadii,
      currentCranialBreathingScale: 1.01,
      previousCranialBreathingScale: 0.99,
      currentFemoralPose: currentLimbPose,
      previousFemoralPose: previousLimbPose,
      currentDeployment: 1,
      previousDeployment: 1,
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
    let commandBuffer = try #require(backend.queue.makeCommandBuffer())
    let frame = try deformer.encode(
      currentBodyCenter: .zero,
      previousBodyCenter: .zero,
      currentNeckPose: nil,
      previousNeckPose: nil,
      cranialRadii: cranialRadii,
      currentCranialBreathingScale: 1.01,
      previousCranialBreathingScale: 0.99,
      currentFemoralPose: currentLimbPose,
      previousFemoralPose: previousLimbPose,
      currentDeployment: 1,
      previousDeployment: 1,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      commandBuffer: commandBuffer
    )
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    #expect(commandBuffer.status == .completed)
    let expectedCount = expected.values.reduce(0) { $0 + $1.count }
    #expect(deformer.activeRecordCount(for: frame) == expectedCount)
    for (topologyIndex, topology) in CrowBodyVaneRecords.productionTopologies.enumerated() {
      let indices = deformer.selectedRecordIndices(
        for: frame,
        topologyIndex: topologyIndex
      )
      let selectedIdentities = indices.map { allRecords[Int($0)].identity }
      let expectedIdentities = (expected[topology] ?? []).map(\.identity)
      let expectedBodyIdentityCount = expectedIdentities.count {
        ($0.x & 0xFF00_0000) == 0x0200_0000
      }
      let expectedMainVaneIdentityCount = expectedIdentities.count {
        ($0.x & 0xFF00_0000) != 0x0700_0000
      }
      #expect(selectedIdentities == expectedIdentities)
      let arguments = deformer.drawArguments(for: frame.batches[topologyIndex])
      let rachisArguments = deformer.drawRachisArguments(
        for: frame.batches[topologyIndex]
      )
      let detailArguments = deformer.drawDetailArguments(
        for: frame.batches[topologyIndex]
      )
      #expect(arguments.instanceCount == UInt32(expectedMainVaneIdentityCount))
      #expect(arguments.vertexCount == UInt32(topology.verticesPerInstance))
      #expect(rachisArguments.instanceCount == UInt32(expectedBodyIdentityCount))
      #expect(
        rachisArguments.vertexCount
          == UInt32(CrowBodyVaneRecords.rachisVerticesPerInstance(for: topology))
      )
      #expect(detailArguments.instanceCount == UInt32(expectedBodyIdentityCount))
      #expect(
        detailArguments.vertexCount
          == UInt32(CrowBodyVaneRecords.detailVerticesPerInstance(for: topology))
      )
    }
  }
}

private func constantR32Texture(
  device: MTLDevice,
  width: Int,
  height: Int,
  value: Float
) throws -> MTLTexture {
  let descriptor = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .r32Float,
    width: width,
    height: height,
    mipmapped: true
  )
  descriptor.storageMode = .shared
  descriptor.usage = .shaderRead
  let texture = try #require(device.makeTexture(descriptor: descriptor))
  for level in 0..<texture.mipmapLevelCount {
    let levelWidth = max(1, width >> level)
    let levelHeight = max(1, height >> level)
    let values = [Float](
      repeating: value,
      count: levelWidth * levelHeight
    )
    values.withUnsafeBytes { bytes in
      texture.replace(
        region: MTLRegionMake2D(0, 0, levelWidth, levelHeight),
        mipmapLevel: level,
        withBytes: bytes.baseAddress!,
        bytesPerRow: levelWidth * MemoryLayout<Float>.stride
      )
    }
  }
  return texture
}

private func cranialBladePoint(
  sample: CrowCranialFeatherSample,
  topology: CrowBodyVaneTopology,
  axialIndex: Int,
  widthIndex: Int,
  breathingScale: Float
) -> SIMD3<Float> {
  let t = Float(axialIndex) / Float(topology.axialSections)
  let direction = normalizedTest(
    sample.tip - sample.root,
    fallback: SIMD3<Float>(1, 0, 0)
  )
  let normal = normalizedTest(
    sample.planeNormal,
    fallback: SIMD3<Float>(0, 0, 1)
  )
  let widthAxis = normalizedTest(
    simd_cross(normal, direction),
    fallback: SIMD3<Float>(0, 1, 0)
  )
  let bodyEnvelope = 0.32 + 0.68 * pow(max(sin(.pi * t), 0), 0.58)
  let tipTaper = 1 - 0.985 * pow(t, 3.2)
  let width = (
    sample.rootWidthMeters * (1 - t) + sample.maximumWidthMeters * t
  ) * bodyEnvelope * tipTaper
  let center = sample.root + (sample.tip - sample.root) * t
    + normal * (sample.camberMeters * sin(.pi * t))
  let signedWidth = 2 * Float(widthIndex) / Float(topology.widthSections) - 1
  return center + widthAxis * (signedWidth * width)
    + normal * (width * 0.18 * max(0, 1 - signedWidth * signedWidth))
    + CrowCranialFeatherTracts.relaxedBladeOffset(
      sample: sample,
      axialFraction: t,
      signedWidth: signedWidth,
      breathingScale: breathingScale
    )
}

private func cranialBladeNormal(
  sample: CrowCranialFeatherSample,
  topology: CrowBodyVaneTopology,
  axialIndex: Int,
  widthIndex: Int,
  breathingScale: Float
) -> SIMD3<Float> {
  let axialFirst = cranialBladePoint(
    sample: sample,
    topology: topology,
    axialIndex: max(0, axialIndex - 1),
    widthIndex: widthIndex,
    breathingScale: breathingScale
  )
  let axialSecond = cranialBladePoint(
    sample: sample,
    topology: topology,
    axialIndex: min(topology.axialSections, axialIndex + 1),
    widthIndex: widthIndex,
    breathingScale: breathingScale
  )
  let widthFirst = cranialBladePoint(
    sample: sample,
    topology: topology,
    axialIndex: axialIndex,
    widthIndex: max(0, widthIndex - 1),
    breathingScale: breathingScale
  )
  let widthSecond = cranialBladePoint(
    sample: sample,
    topology: topology,
    axialIndex: axialIndex,
    widthIndex: min(topology.widthSections, widthIndex + 1),
    breathingScale: breathingScale
  )
  let supplied = normalizedTest(
    sample.planeNormal,
    fallback: SIMD3<Float>(0, 0, 1)
  )
  var resolved = normalizedTest(
    simd_cross(axialSecond - axialFirst, widthSecond - widthFirst),
    fallback: supplied
  )
  if simd_dot(resolved, supplied) < 0 { resolved = -resolved }
  return resolved
}

private func normalizedTest(
  _ value: SIMD3<Float>,
  fallback: SIMD3<Float>
) -> SIMD3<Float> {
  let length = simd_length(value)
  return length > 1e-12 ? value / length : fallback
}

extension SIMD4 where Scalar == Float {
  fileprivate var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}
