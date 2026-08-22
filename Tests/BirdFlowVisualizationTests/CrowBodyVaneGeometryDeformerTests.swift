import Metal
import Testing
import simd

@testable import BirdFlowVisualization

@Test("body vanes retain compact identity-stable temporal records")
func bodyVanesRetainCompactIdentityStableTemporalRecords() {
  #expect(MemoryLayout<CrowBodyVaneMorphologyGPU>.stride == 128)
  #expect(MemoryLayout<CrowBodyVaneRecordGPU>.stride == 176)
  #expect(MemoryLayout<CrowBodyVanePoseUniforms>.stride == 32)
  #expect(MemoryLayout<CrowBodyVaneNeckTransformGPU>.stride == 48)
  #expect(MemoryLayout<CrowBodyVaneGeometryUniforms>.stride == 32)
  #expect(MemoryLayout<CrowBodyVaneSelectionUniforms>.stride == 32)
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
  #expect(CrowBodyVaneRecords.productionTopologies.count == 7)
  #expect(
    CrowBodyVaneRecords.productionTopologies.map {
      CrowBodyVaneRecords.rachisSections(for: $0)
    } == [0, 0, 4, 4, 8, 8, 12]
  )
  #expect(
    CrowBodyVaneRecords.productionTopologies.map {
      CrowBodyVaneRecords.rachisVerticesPerInstance(for: $0)
    } == [0, 0, 96, 96, 192, 192, 288]
  )
  #expect(
    CrowBodyVaneRecords.productionTopologies.map {
      CrowBodyVaneRecords.detailSegmentCount(for: $0)
    } == [0, 0, 43, 43, 41, 41, 167]
  )
  #expect(
    CrowBodyVaneRecords.productionTopologies.map {
      CrowBodyVaneRecords.detailVerticesPerInstance(for: $0)
    } == [0, 0, 774, 774, 738, 738, 3_006]
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

@Test("Metal procedural body vanes match the Swift geometry oracle")
func metalProceduralBodyVanesMatchSwiftGeometryOracle() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let deformer = try CrowBodyVaneGeometryDeformer(backend: backend)
  let commandBuffer = try #require(backend.queue.makeCommandBuffer())
  let frame = try deformer.encode(
    currentBodyCenter: SIMD3<Float>(0.013, -0.021, 0.034),
    previousBodyCenter: SIMD3<Float>(-0.008, 0.017, -0.025),
    currentNeckPose: CrowStandingNeckPose(
      translation: SIMD3<Float>(0.001, -0.002, 0.0015),
      yawRadians: 0.018,
      pitchRadians: -0.013,
      rollRadians: 0.006
    ),
    previousNeckPose: CrowStandingNeckPose(
      translation: SIMD3<Float>(-0.0005, 0.001, -0.0007),
      yawRadians: -0.011,
      pitchRadians: 0.009,
      rollRadians: -0.004
    ),
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
  #expect(frame.morphologyRecordCount == 3_212)
  #expect(deformer.activeRecordCount(for: frame) == 3_212)
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
    guard batch.rachisVertexCount > 0,
      let recordIndex = records.firstIndex(where: {
        CrowBodyVaneRecords.rachisIsResolved(
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
  #expect(frames.allSatisfy { $0.morphologyRecordCount == 3_212 })
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
  #expect(frames.allSatisfy { $0.poseInputBytes == 1_376 })
  #expect(frames.allSatisfy { $0.retainedPoseCapacityBytes == 4_128 })
  #expect(deformer.retainedIndirectDrawBytes == 1_008)
  #expect(
    frames.allSatisfy {
      $0.retainedDetailSegmentCapacityBytes
        == 3 * 3_212 * 43 * MemoryLayout<CrowBodyDetailSegmentGPU>.stride
    }
  )
  #expect(frames.allSatisfy { $0.detailSegmentBufferAllocationCount == 3 })
  #expect(frames.allSatisfy { deformer.activeRecordCount(for: $0) == 3_212 })
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
    #expect(rachisArguments.vertexCount == UInt32(reused.rachisVertexCount))
    #expect(rachisArguments.vertexStart == 0)
    #expect(rachisArguments.instanceCount == arguments.instanceCount)
    let detailArguments = deformer.drawDetailArguments(for: reused)
    #expect(detailArguments.vertexCount == UInt32(reused.detailVertexCount))
    #expect(detailArguments.vertexStart == 0)
    #expect(detailArguments.instanceCount == arguments.instanceCount)
  }
}

@Test("Metal body vane LOD selection matches the deterministic CPU oracle")
func metalBodyVaneLODSelectionMatchesCPUOracle() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let deformer = try CrowBodyVaneGeometryDeformer(backend: backend)
  for projectedPixelsPerMeter: Float in [800, 1_000, 1_600, 20_000] {
    let allRecords = CrowBodyVaneRecords.temporalRecords(
      currentBodyCenter: .zero,
      previousBodyCenter: .zero,
      currentNeckPose: nil,
      previousNeckPose: nil,
      currentDeployment: 1,
      previousDeployment: 1
    )
    let expected = CrowBodyVaneRecords.groupedRecords(
      currentBodyCenter: .zero,
      previousBodyCenter: .zero,
      currentNeckPose: nil,
      previousNeckPose: nil,
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
      #expect(selectedIdentities == expectedIdentities)
      let arguments = deformer.drawArguments(for: frame.batches[topologyIndex])
      let rachisArguments = deformer.drawRachisArguments(
        for: frame.batches[topologyIndex]
      )
      let detailArguments = deformer.drawDetailArguments(
        for: frame.batches[topologyIndex]
      )
      #expect(arguments.instanceCount == UInt32(expectedIdentities.count))
      #expect(arguments.vertexCount == UInt32(topology.verticesPerInstance))
      #expect(rachisArguments.instanceCount == arguments.instanceCount)
      #expect(
        rachisArguments.vertexCount
          == UInt32(CrowBodyVaneRecords.rachisVerticesPerInstance(for: topology))
      )
      #expect(detailArguments.instanceCount == arguments.instanceCount)
      #expect(
        detailArguments.vertexCount
          == UInt32(CrowBodyVaneRecords.detailVerticesPerInstance(for: topology))
      )
    }
  }
}

extension SIMD4 where Scalar == Float {
  fileprivate var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}
