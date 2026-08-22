import Metal
import Testing
import simd

@testable import BirdFlowVisualization

@Test("body vanes retain compact identity-stable temporal records")
func bodyVanesRetainCompactIdentityStableTemporalRecords() {
  #expect(MemoryLayout<CrowBodyVaneRecordGPU>.stride == 176)
  #expect(MemoryLayout<CrowBodyVaneGeometryUniforms>.stride == 16)
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
    currentNeckPose: nil,
    previousNeckPose: nil,
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
  #expect(frame.recordCount == 3_212)
  #expect(frame.expandedVertexCount > 0)

  for batch in frame.batches {
    let records = records(in: batch)
    let vertices = deformer.vertices(for: batch)
    for recordIndex in Set([0, max(0, records.count - 1)]) {
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
        #expect(simd_distance(gpu.position.xyz, current) < 4e-7)
        #expect(simd_distance(gpu.previousPosition.xyz, previous) < 4e-7)
        // The terminal chord is deliberately narrow; fast-math normalization
        // remains within 0.06 degrees of the FP32 Swift oracle there.
        #expect(simd_distance(gpu.normal.xyz, normal) < 1e-3)
        #expect(gpu.identity == record.identity)
        #expect(gpu.color == record.color)
      }
    }
  }
}

@Test("body vane production storage is triple buffered and indirect")
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
  #expect(batchCount > 0)
  #expect(frames.map(\.slot) == [0, 1, 2, 0])
  #expect(frames[0].recordBufferAllocationCount == batchCount)
  #expect(frames[1].recordBufferAllocationCount == batchCount * 2)
  #expect(frames[2].recordBufferAllocationCount == batchCount * 3)
  #expect(frames[3].recordBufferAllocationCount == batchCount * 3)
  #expect(frames.allSatisfy { $0.recordCount == 3_212 })
  #expect(
    frames.allSatisfy {
      $0.recordBytes == $0.recordCount
        * MemoryLayout<CrowBodyVaneRecordGPU>.stride
    }
  )
  #expect(frames.allSatisfy { $0.recordCapacityBytes >= $0.recordBytes })

  for index in 0..<batchCount {
    let first = frames[0].batches[index]
    let reused = frames[3].batches[index]
    #expect(first.topology == reused.topology)
    #expect(first.recordBuffer === reused.recordBuffer)
    #expect(first.indirectDrawBuffer === reused.indirectDrawBuffer)
    let arguments = reused.indirectDrawBuffer.contents().bindMemory(
      to: DrawPrimitivesIndirectArguments.self,
      capacity: 1
    ).pointee
    #expect(arguments.vertexCount == UInt32(reused.vertexCount))
    #expect(arguments.instanceCount == UInt32(reused.recordCount))
    #expect(arguments.vertexStart == 0)
    #expect(arguments.baseInstance == 0)
  }
}

private func records(
  in batch: CrowBodyVaneGeometryBatchFrame
) -> [CrowBodyVaneRecordGPU] {
  let pointer = batch.recordBuffer.contents().bindMemory(
    to: CrowBodyVaneRecordGPU.self,
    capacity: batch.recordCount
  )
  return Array(UnsafeBufferPointer(start: pointer, count: batch.recordCount))
}

extension SIMD4 where Scalar == Float {
  fileprivate var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}
