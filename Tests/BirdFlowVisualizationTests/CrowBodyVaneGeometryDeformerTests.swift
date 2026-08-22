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
  #expect(MemoryLayout<CrowBodyVaneGeometryUniforms>.stride == 16)
  #expect(MemoryLayout<CrowBodyVaneSelectionUniforms>.stride == 32)
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
  #expect(frames.allSatisfy { deformer.activeRecordCount(for: $0) == 3_212 })

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
      #expect(arguments.instanceCount == UInt32(expectedIdentities.count))
      #expect(arguments.vertexCount == UInt32(topology.verticesPerInstance))
    }
  }
}

extension SIMD4 where Scalar == Float {
  fileprivate var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}
