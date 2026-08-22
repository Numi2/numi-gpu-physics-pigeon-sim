import Metal
import simd

struct CrowBodyVaneTopology: Hashable, Comparable {
  let axialSections: Int
  let widthSections: Int

  static func < (lhs: Self, rhs: Self) -> Bool {
    (lhs.axialSections, lhs.widthSections)
      < (rhs.axialSections, rhs.widthSections)
  }

  var verticesPerInstance: Int { axialSections * widthSections * 6 }
}

/// One immutable lifetime root for the newly retained body-detail resources.
/// Keeping these Metal existentials out of the already-wide value batch avoids
/// copying their inline containers through the optimized showcase stack.
final class CrowBodyVaneDetailBatchFrame {
  let indirectDrawBufferOffset: Int
  let segmentBuffer: MTLBuffer
  let segmentCapacityPerRecord: Int
  let auditOutputBuffer: MTLBuffer?

  init(
    indirectDrawBufferOffset: Int,
    segmentBuffer: MTLBuffer,
    segmentCapacityPerRecord: Int,
    auditOutputBuffer: MTLBuffer?
  ) {
    self.indirectDrawBufferOffset = indirectDrawBufferOffset
    self.segmentBuffer = segmentBuffer
    self.segmentCapacityPerRecord = segmentCapacityPerRecord
    self.auditOutputBuffer = auditOutputBuffer
  }
}

struct CrowBodyVaneGeometryBatchFrame {
  let topologyIndex: Int
  let topology: CrowBodyVaneTopology
  let projectedPixelsPerMeter: Float
  let morphologyBuffer: MTLBuffer
  let poseBuffer: MTLBuffer
  let neckTransformBuffer: MTLBuffer
  let workBuffer: MTLBuffer
  let indirectDrawBuffer: MTLBuffer
  let indirectDrawBufferOffset: Int
  let rachisIndirectDrawBufferOffset: Int
  let detail: CrowBodyVaneDetailBatchFrame
  let auditRecords: [CrowBodyVaneRecordGPU]
  let auditRecordCount: Int
  let auditOutputBuffer: MTLBuffer?
  let auditRachisOutputBuffer: MTLBuffer?

  var detailIndirectDrawBufferOffset: Int { detail.indirectDrawBufferOffset }
  var detailSegmentBuffer: MTLBuffer { detail.segmentBuffer }
  var detailSegmentCapacityPerRecord: Int {
    detail.segmentCapacityPerRecord
  }
  var auditDetailOutputBuffer: MTLBuffer? { detail.auditOutputBuffer }

  var vertexCount: Int { topology.verticesPerInstance }
  var rachisVertexCount: Int {
    CrowBodyVaneRecords.rachisVerticesPerInstance(for: topology)
  }
  var detailVertexCount: Int {
    CrowBodyVaneRecords.detailVerticesPerInstance(for: topology)
  }
}

final class CrowBodyVaneGeometryFrame {
  let slot: Int
  let batches: [CrowBodyVaneGeometryBatchFrame]
  let morphologyRecordCount: Int
  let morphologyRecordBytes: Int
  let morphologyCapacityBytes: Int
  let poseInputBytes: Int
  let retainedPoseCapacityBytes: Int
  let morphologyBufferAllocationCount: Int
  let retainedDetailSegmentCapacityBytes: Int
  let detailSegmentBufferAllocationCount: Int
  let auditReadbackReady: Bool

  init(
    slot: Int,
    batches: [CrowBodyVaneGeometryBatchFrame],
    morphologyRecordCount: Int,
    morphologyRecordBytes: Int,
    morphologyCapacityBytes: Int,
    poseInputBytes: Int,
    retainedPoseCapacityBytes: Int,
    morphologyBufferAllocationCount: Int,
    retainedDetailSegmentCapacityBytes: Int,
    detailSegmentBufferAllocationCount: Int,
    auditReadbackReady: Bool
  ) {
    self.slot = slot
    self.batches = batches
    self.morphologyRecordCount = morphologyRecordCount
    self.morphologyRecordBytes = morphologyRecordBytes
    self.morphologyCapacityBytes = morphologyCapacityBytes
    self.poseInputBytes = poseInputBytes
    self.retainedPoseCapacityBytes = retainedPoseCapacityBytes
    self.morphologyBufferAllocationCount = morphologyBufferAllocationCount
    self.retainedDetailSegmentCapacityBytes = retainedDetailSegmentCapacityBytes
    self.detailSegmentBufferAllocationCount = detailSegmentBufferAllocationCount
    self.auditReadbackReady = auditReadbackReady
  }
}

/// Live procedural expansion of body contour vanes.
///
/// Production rasterization pulls compact temporal records directly. The
/// compute pipeline invokes the same Metal helper only as a parity oracle.
final class CrowBodyVaneGeometryDeformer {
  private static let bufferedFrameCount = 3

  private let backend: VisualizationBackend
  private let classifyPipeline: MTLComputePipelineState
  private let scanPipeline: MTLComputePipelineState
  private let emitPipeline: MTLComputePipelineState
  private let indirectPipeline: MTLComputePipelineState
  private let detailSegmentPipeline: MTLComputePipelineState
  private let auditPipeline: MTLComputePipelineState
  private let auditRachisPipeline: MTLComputePipelineState
  private let auditDetailPipeline: MTLComputePipelineState
  private let morphologyRecords: [CrowBodyVaneMorphologyGPU]
  private let maximumMorphologyLength: Float
  private let morphologyBuffer: MTLBuffer
  private let poseBuffers: [MTLBuffer]
  private let neckTransformBuffers: [MTLBuffer]
  private let topologyIndexBuffers: [MTLBuffer]
  private let topologyOffsetBuffers: [MTLBuffer]
  private let topologyCountBuffers: [MTLBuffer]
  private let workBuffers: [MTLBuffer]
  private let indirectDrawBuffers: [MTLBuffer]
  private var detailSegmentBuffers: [MTLBuffer]
  private var detailSegmentCapacityPerRecord = 25
  private var nextSlot = 0
  private(set) var morphologyBufferAllocationCount = 1
  private(set) var detailSegmentBufferAllocationCount = bufferedFrameCount

  var retainedMorphologyCapacityBytes: Int {
    morphologyBuffer.length
  }

  var retainedPoseCapacityBytes: Int {
    poseBuffers.reduce(0) { $0 + $1.length }
      + neckTransformBuffers.reduce(0) { $0 + $1.length }
  }

  var retainedIndirectDrawBytes: Int {
    indirectDrawBuffers.reduce(0) { $0 + $1.length }
  }

  var retainedDetailSegmentCapacityBytes: Int {
    detailSegmentBuffers.reduce(0) { $0 + $1.length }
  }

  init(backend: VisualizationBackend) throws {
    self.backend = backend
    classifyPipeline = try backend.compute("classifyCrowBodyVaneRecords")
    scanPipeline = try backend.compute("scanCrowBodyVaneRecords")
    emitPipeline = try backend.compute("emitCrowBodyVaneWork")
    indirectPipeline = try backend.compute("prepareCrowBodyVaneIndirectWork")
    detailSegmentPipeline = try backend.compute("emitCrowBodyDetailSegments")
    auditPipeline = try backend.compute("probeCrowBodyVaneVertices")
    auditRachisPipeline = try backend.compute("probeCrowBodyRachisVertices")
    auditDetailPipeline = try backend.compute("probeCrowBodyDetailVertices")
    let createdMorphologyRecords = CrowBodyVaneRecords.morphologyRecords()
    morphologyRecords = createdMorphologyRecords
    maximumMorphologyLength = createdMorphologyRecords.reduce(.zero) {
      partial, record in
      max(
        partial,
        simd_distance(record.rootAndRootWidth.xyz, record.tipAndMaximumWidth.xyz)
      )
    }
    let maximumRecordCount = createdMorphologyRecords.count
    morphologyBuffer = try Self.sharedBuffer(
      values: morphologyRecords,
      backend: backend
    )
    morphologyBuffer.label = "Immutable body vane morphology inventory"
    poseBuffers = try (0..<Self.bufferedFrameCount).map { slot in
      let buffer = try backend.buffer(
        length: MemoryLayout<CrowBodyVanePoseUniforms>.stride,
        shared: true
      )
      buffer.label = "Body vane pose slot \(slot)"
      return buffer
    }
    neckTransformBuffers = try (0..<Self.bufferedFrameCount).map { slot in
      let buffer = try backend.buffer(
        length: 2 * CrowBodyFeatherTracts.cervicalColumnCount
          * MemoryLayout<CrowBodyVaneNeckTransformGPU>.stride,
        shared: true
      )
      buffer.label = "Body vane neck transforms slot \(slot)"
      return buffer
    }
    topologyIndexBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(
        length: maximumRecordCount * MemoryLayout<UInt32>.stride,
        shared: true
      )
    }
    topologyOffsetBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(
        length: maximumRecordCount * MemoryLayout<UInt32>.stride,
        shared: true
      )
    }
    topologyCountBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(length: 8 * MemoryLayout<UInt32>.stride, shared: true)
    }
    workBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(
        length: maximumRecordCount * MemoryLayout<UInt32>.stride,
        shared: true
      )
    }
    indirectDrawBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(
        length: 3 * CrowBodyVaneRecords.productionTopologies.count
          * MemoryLayout<DrawPrimitivesIndirectArguments>.stride,
        shared: true
      )
    }
    detailSegmentBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(
        length: maximumRecordCount * 25
          * MemoryLayout<CrowBodyDetailSegmentGPU>.stride
      )
    }
  }

  func encode(
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    currentNeckPose: CrowStandingNeckPose?,
    previousNeckPose: CrowStandingNeckPose?,
    currentDeployment: Float,
    previousDeployment: Float,
    projectedPixelsPerMeter: Float,
    commandBuffer: MTLCommandBuffer,
    auditReadback: Bool = false
  ) throws -> CrowBodyVaneGeometryFrame {
    let slot = nextSlot
    nextSlot = (nextSlot + 1) % Self.bufferedFrameCount
    var pose = CrowBodyVanePoseUniforms(
      currentBodyCenterAndDeployment: SIMD4<Float>(
        currentBodyCenter,
        currentDeployment
      ),
      previousBodyCenterAndDeployment: SIMD4<Float>(
        previousBodyCenter,
        previousDeployment
      )
    )
    memcpy(
      poseBuffers[slot].contents(),
      &pose,
      MemoryLayout<CrowBodyVanePoseUniforms>.stride
    )
    let neckTransforms = CrowBodyVaneRecords.neckTransforms(
      current: currentNeckPose,
      previous: previousNeckPose
    )
    neckTransforms.withUnsafeBytes { bytes in
      if let baseAddress = bytes.baseAddress, !bytes.isEmpty {
        memcpy(neckTransformBuffers[slot].contents(), baseAddress, bytes.count)
      }
    }
    let recordCount = morphologyRecords.count
    try ensureDetailSegmentCapacity(
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
    let retainedDetailSegmentCapacity = detailSegmentCapacityPerRecord
    let requiredRecordBytes =
      recordCount
      * MemoryLayout<CrowBodyVaneMorphologyGPU>.stride
    let poseInputBytes = MemoryLayout<CrowBodyVanePoseUniforms>.stride
      + neckTransforms.count
        * MemoryLayout<CrowBodyVaneNeckTransformGPU>.stride
    let auditTemporalRecords =
      auditReadback
      ? CrowBodyVaneRecords.temporalRecords(
        currentBodyCenter: currentBodyCenter,
        previousBodyCenter: previousBodyCenter,
        currentNeckPose: currentNeckPose,
        previousNeckPose: previousNeckPose,
        currentDeployment: currentDeployment,
        previousDeployment: previousDeployment
      )
      : []
    memset(
      topologyCountBuffers[slot].contents(),
      0,
      8 * MemoryLayout<UInt32>.stride
    )
    memset(
      indirectDrawBuffers[slot].contents(),
      0,
      3 * CrowBodyVaneRecords.productionTopologies.count
        * MemoryLayout<DrawPrimitivesIndirectArguments>.stride
    )
    var selection = CrowBodyVaneSelectionUniforms(
      selection: SIMD4<Float>(projectedPixelsPerMeter, 0, 0, 0),
      counts: SIMD4<UInt32>(
        UInt32(recordCount),
        UInt32(CrowBodyVaneRecords.productionTopologies.count),
        UInt32(retainedDetailSegmentCapacity),
        0
      )
    )
    guard let classify = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow body vane selection encoder")
    }
    classify.label = "Classify full body vane inventory"
    classify.setBuffer(morphologyBuffer, offset: 0, index: 0)
    classify.setBuffer(topologyIndexBuffers[slot], offset: 0, index: 1)
    classify.setBytes(
      &selection,
      length: MemoryLayout<CrowBodyVaneSelectionUniforms>.stride,
      index: 2
    )
    backend.dispatch1D(classify, pipeline: classifyPipeline, count: recordCount)
    classify.endEncoding()

    guard let scan = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow body vane selection scan")
    }
    scan.label = "Scan body vane topology selection"
    scan.setBuffer(topologyIndexBuffers[slot], offset: 0, index: 0)
    scan.setBuffer(topologyOffsetBuffers[slot], offset: 0, index: 1)
    scan.setBuffer(topologyCountBuffers[slot], offset: 0, index: 2)
    scan.setBytes(
      &selection,
      length: MemoryLayout<CrowBodyVaneSelectionUniforms>.stride,
      index: 3
    )
    backend.dispatch1D(scan, pipeline: scanPipeline, count: 1)
    scan.endEncoding()

    guard let emit = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow body vane compact work encoder")
    }
    emit.label = "Emit compact body vane topology work"
    emit.setBuffer(topologyIndexBuffers[slot], offset: 0, index: 0)
    emit.setBuffer(topologyOffsetBuffers[slot], offset: 0, index: 1)
    emit.setBuffer(topologyCountBuffers[slot], offset: 0, index: 2)
    emit.setBuffer(workBuffers[slot], offset: 0, index: 3)
    emit.setBytes(
      &selection,
      length: MemoryLayout<CrowBodyVaneSelectionUniforms>.stride,
      index: 4
    )
    backend.dispatch1D(emit, pipeline: emitPipeline, count: recordCount)
    emit.endEncoding()

    guard let prepare = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow body vane indirect-work encoder")
    }
    prepare.label = "Prepare body vane indirect draws"
    prepare.setBuffer(topologyCountBuffers[slot], offset: 0, index: 0)
    prepare.setBuffer(indirectDrawBuffers[slot], offset: 0, index: 1)
    backend.dispatch1D(
      prepare,
      pipeline: indirectPipeline,
      count: CrowBodyVaneRecords.productionTopologies.count
    )
    prepare.endEncoding()

    guard let detailSegments = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow body detail segment encoder")
    }
    detailSegments.label = "Emit compact temporal body barb segments"
    detailSegments.setBuffer(morphologyBuffer, offset: 0, index: 0)
    detailSegments.setBuffer(topologyIndexBuffers[slot], offset: 0, index: 1)
    detailSegments.setBuffer(topologyCountBuffers[slot], offset: 0, index: 2)
    detailSegments.setBuffer(workBuffers[slot], offset: 0, index: 3)
    detailSegments.setBuffer(detailSegmentBuffers[slot], offset: 0, index: 4)
    detailSegments.setBuffer(poseBuffers[slot], offset: 0, index: 5)
    detailSegments.setBuffer(neckTransformBuffers[slot], offset: 0, index: 6)
    detailSegments.setBytes(
      &selection,
      length: MemoryLayout<CrowBodyVaneSelectionUniforms>.stride,
      index: 7
    )
    backend.dispatch1D(
      detailSegments,
      pipeline: detailSegmentPipeline,
      count: recordCount * retainedDetailSegmentCapacity
    )
    detailSegments.endEncoding()

    let auditGroups =
      auditReadback
      ? CrowBodyVaneRecords.groupedMorphologyIndices(
        projectedPixelsPerMeter: projectedPixelsPerMeter
      )
      : [:]
    var batches: [CrowBodyVaneGeometryBatchFrame] = []
    for (topologyIndex, topology) in CrowBodyVaneRecords.productionTopologies.enumerated() {
      let auditIndices = auditGroups[topology] ?? []
      let auditRecords = auditIndices.map { auditTemporalRecords[$0] }
      let auditOutputBuffer: MTLBuffer?
      if auditReadback && !auditRecords.isEmpty {
        let auditMorphologies = auditIndices.map { morphologyRecords[$0] }
        let auditInput = try Self.sharedBuffer(
          values: auditMorphologies,
          backend: backend
        )
        let auditVertexCount = topology.verticesPerInstance * auditRecords.count
        let auditOutput = try backend.buffer(
          length: auditVertexCount * MemoryLayout<CrowFeatherVertexGPU>.stride,
          shared: true
        )
        var uniforms = CrowBodyVaneGeometryUniforms(
          counts: SIMD4<UInt32>(
            UInt32(topology.axialSections),
            UInt32(topology.widthSections),
            UInt32(auditRecords.count),
            UInt32(topology.verticesPerInstance)
          ),
          selection: SIMD4<Float>(projectedPixelsPerMeter, 0, 0, 0)
        )
        guard let audit = commandBuffer.makeComputeCommandEncoder() else {
          throw VisualizationError.pipeline("crow body vane audit encoder")
        }
        audit.label = "Audit procedural body vane geometry"
        audit.setBuffer(auditInput, offset: 0, index: 0)
        audit.setBytes(
          &uniforms,
          length: MemoryLayout<CrowBodyVaneGeometryUniforms>.stride,
          index: 1
        )
        audit.setBuffer(auditOutput, offset: 0, index: 2)
        audit.setBuffer(poseBuffers[slot], offset: 0, index: 3)
        audit.setBuffer(neckTransformBuffers[slot], offset: 0, index: 4)
        backend.dispatch1D(
          audit,
          pipeline: auditPipeline,
          count: auditVertexCount
        )
        audit.endEncoding()
        auditOutputBuffer = auditOutput
      } else {
        auditOutputBuffer = nil
      }
      let auditRachisOutputBuffer: MTLBuffer?
      let auditRachisVertexCount =
        CrowBodyVaneRecords.rachisVerticesPerInstance(for: topology)
        * auditRecords.count
      if auditReadback && auditRachisVertexCount > 0 {
        let auditMorphologies = auditIndices.map { morphologyRecords[$0] }
        let auditInput = try Self.sharedBuffer(
          values: auditMorphologies,
          backend: backend
        )
        let auditOutput = try backend.buffer(
          length: auditRachisVertexCount
            * MemoryLayout<CrowFeatherVertexGPU>.stride,
          shared: true
        )
        var uniforms = CrowBodyVaneGeometryUniforms(
          counts: SIMD4<UInt32>(
            UInt32(topology.axialSections),
            UInt32(topology.widthSections),
            UInt32(auditRecords.count),
            UInt32(
              CrowBodyVaneRecords.rachisVerticesPerInstance(for: topology)
            )
          ),
          selection: SIMD4<Float>(projectedPixelsPerMeter, 0, 0, 0)
        )
        guard let audit = commandBuffer.makeComputeCommandEncoder() else {
          throw VisualizationError.pipeline("crow body rachis audit encoder")
        }
        audit.label = "Audit procedural body rachis geometry"
        audit.setBuffer(auditInput, offset: 0, index: 0)
        audit.setBytes(
          &uniforms,
          length: MemoryLayout<CrowBodyVaneGeometryUniforms>.stride,
          index: 1
        )
        audit.setBuffer(auditOutput, offset: 0, index: 2)
        audit.setBuffer(poseBuffers[slot], offset: 0, index: 3)
        audit.setBuffer(neckTransformBuffers[slot], offset: 0, index: 4)
        backend.dispatch1D(
          audit,
          pipeline: auditRachisPipeline,
          count: auditRachisVertexCount
        )
        audit.endEncoding()
        auditRachisOutputBuffer = auditOutput
      } else {
        auditRachisOutputBuffer = nil
      }
      let auditDetailOutputBuffer: MTLBuffer?
      let auditDetailVertexCount =
        CrowBodyVaneRecords.detailVerticesPerInstance(for: topology)
        * auditRecords.count
      if auditReadback && auditDetailVertexCount > 0 {
        let auditMorphologies = auditIndices.map { morphologyRecords[$0] }
        let auditInput = try Self.sharedBuffer(
          values: auditMorphologies,
          backend: backend
        )
        let auditOutput = try backend.buffer(
          length: auditDetailVertexCount
            * MemoryLayout<CrowFeatherVertexGPU>.stride,
          shared: true
        )
        var uniforms = CrowBodyVaneGeometryUniforms(
          counts: SIMD4<UInt32>(
            UInt32(topology.axialSections),
            UInt32(topology.widthSections),
            UInt32(auditRecords.count),
            UInt32(
              CrowBodyVaneRecords.detailVerticesPerInstance(for: topology)
            )
          ),
          selection: SIMD4<Float>(projectedPixelsPerMeter, 0, 0, 0)
        )
        guard let audit = commandBuffer.makeComputeCommandEncoder() else {
          throw VisualizationError.pipeline("crow body detail audit encoder")
        }
        audit.label = "Audit procedural body barb hierarchy"
        audit.setBuffer(auditInput, offset: 0, index: 0)
        audit.setBytes(
          &uniforms,
          length: MemoryLayout<CrowBodyVaneGeometryUniforms>.stride,
          index: 1
        )
        audit.setBuffer(auditOutput, offset: 0, index: 2)
        audit.setBuffer(poseBuffers[slot], offset: 0, index: 3)
        audit.setBuffer(neckTransformBuffers[slot], offset: 0, index: 4)
        backend.dispatch1D(
          audit,
          pipeline: auditDetailPipeline,
          count: auditDetailVertexCount
        )
        audit.endEncoding()
        auditDetailOutputBuffer = auditOutput
      } else {
        auditDetailOutputBuffer = nil
      }
      batches.append(
        CrowBodyVaneGeometryBatchFrame(
          topologyIndex: topologyIndex,
          topology: topology,
          projectedPixelsPerMeter: projectedPixelsPerMeter,
          morphologyBuffer: morphologyBuffer,
          poseBuffer: poseBuffers[slot],
          neckTransformBuffer: neckTransformBuffers[slot],
          workBuffer: workBuffers[slot],
          indirectDrawBuffer: indirectDrawBuffers[slot],
          indirectDrawBufferOffset: topologyIndex
            * MemoryLayout<DrawPrimitivesIndirectArguments>.stride,
          rachisIndirectDrawBufferOffset:
            (CrowBodyVaneRecords.productionTopologies.count + topologyIndex)
            * MemoryLayout<DrawPrimitivesIndirectArguments>.stride,
          detail: CrowBodyVaneDetailBatchFrame(
            indirectDrawBufferOffset:
              (2 * CrowBodyVaneRecords.productionTopologies.count + topologyIndex)
              * MemoryLayout<DrawPrimitivesIndirectArguments>.stride,
            segmentBuffer: detailSegmentBuffers[slot],
            segmentCapacityPerRecord: retainedDetailSegmentCapacity,
            auditOutputBuffer: auditDetailOutputBuffer
          ),
          auditRecords: auditRecords,
          auditRecordCount: auditRecords.count,
          auditOutputBuffer: auditOutputBuffer,
          auditRachisOutputBuffer: auditRachisOutputBuffer
        )
      )
    }
    return CrowBodyVaneGeometryFrame(
      slot: slot,
      batches: batches,
      morphologyRecordCount: recordCount,
      morphologyRecordBytes: requiredRecordBytes,
      morphologyCapacityBytes: morphologyBuffer.length,
      poseInputBytes: poseInputBytes,
      retainedPoseCapacityBytes: retainedPoseCapacityBytes,
      morphologyBufferAllocationCount: morphologyBufferAllocationCount,
      retainedDetailSegmentCapacityBytes: retainedDetailSegmentCapacityBytes,
      detailSegmentBufferAllocationCount: detailSegmentBufferAllocationCount,
      auditReadbackReady: auditReadback
    )
  }

  func bindRenderResources(
    for batch: CrowBodyVaneGeometryBatchFrame,
    encoder: MTLRenderCommandEncoder
  ) {
    var uniforms = CrowBodyVaneGeometryUniforms(
      counts: SIMD4<UInt32>(
        UInt32(batch.topology.axialSections),
        UInt32(batch.topology.widthSections),
        0,
        UInt32(batch.vertexCount)
      ),
      selection: SIMD4<Float>(
        batch.projectedPixelsPerMeter,
        Float(batch.detailSegmentCapacityPerRecord),
        0,
        0
      )
    )
    encoder.setVertexBuffer(batch.morphologyBuffer, offset: 0, index: 0)
    encoder.setVertexBuffer(batch.workBuffer, offset: 0, index: 1)
    encoder.setVertexBytes(
      &uniforms,
      length: MemoryLayout<CrowBodyVaneGeometryUniforms>.stride,
      index: 2
    )
    encoder.setVertexBuffer(batch.poseBuffer, offset: 0, index: 4)
    encoder.setVertexBuffer(batch.neckTransformBuffer, offset: 0, index: 5)
    encoder.setVertexBuffer(batch.detailSegmentBuffer, offset: 0, index: 6)
  }

  func drawArguments(
    for batch: CrowBodyVaneGeometryBatchFrame
  ) -> DrawPrimitivesIndirectArguments {
    batch.indirectDrawBuffer.contents().advanced(
      by: batch.indirectDrawBufferOffset
    ).bindMemory(
      to: DrawPrimitivesIndirectArguments.self,
      capacity: 1
    ).pointee
  }

  func drawRachisArguments(
    for batch: CrowBodyVaneGeometryBatchFrame
  ) -> DrawPrimitivesIndirectArguments {
    batch.indirectDrawBuffer.contents().advanced(
      by: batch.rachisIndirectDrawBufferOffset
    ).bindMemory(
      to: DrawPrimitivesIndirectArguments.self,
      capacity: 1
    ).pointee
  }

  func drawDetailArguments(
    for batch: CrowBodyVaneGeometryBatchFrame
  ) -> DrawPrimitivesIndirectArguments {
    batch.indirectDrawBuffer.contents().advanced(
      by: batch.detailIndirectDrawBufferOffset
    ).bindMemory(
      to: DrawPrimitivesIndirectArguments.self,
      capacity: 1
    ).pointee
  }

  func activeRecordCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    Int(topologyCounts(for: frame)[7])
  }

  func expandedVertexCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    frame.batches.reduce(0) {
      $0 + Int(drawArguments(for: $1).vertexCount)
        * Int(drawArguments(for: $1).instanceCount)
    }
  }

  func expandedRachisVertexCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    frame.batches.reduce(0) {
      $0 + Int(drawRachisArguments(for: $1).vertexCount)
        * Int(drawRachisArguments(for: $1).instanceCount)
    }
  }

  func expandedDetailVertexCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    frame.batches.reduce(0) {
      $0 + Int(drawDetailArguments(for: $1).vertexCount)
        * Int(drawDetailArguments(for: $1).instanceCount)
    }
  }

  func topologyCounts(for frame: CrowBodyVaneGeometryFrame) -> [UInt32] {
    let pointer = topologyCountBuffers[frame.slot].contents().bindMemory(
      to: UInt32.self,
      capacity: 8
    )
    return Array(UnsafeBufferPointer(start: pointer, count: 8))
  }

  func selectedRecordIndices(
    for frame: CrowBodyVaneGeometryFrame,
    topologyIndex: Int
  ) -> [UInt32] {
    let counts = topologyCounts(for: frame)
    let base = counts[..<topologyIndex].reduce(0, +)
    let count = counts[topologyIndex]
    let pointer = workBuffers[frame.slot].contents().bindMemory(
      to: UInt32.self,
      capacity: frame.morphologyRecordCount
    )
    return Array(
      UnsafeBufferPointer(
        start: pointer.advanced(by: Int(base)),
        count: Int(count)
      )
    )
  }

  func vertices(
    for batch: CrowBodyVaneGeometryBatchFrame
  ) -> [CrowFeatherVertexGPU] {
    guard let buffer = batch.auditOutputBuffer else {
      preconditionFailure("body vane frame lacks audit readback")
    }
    let count = batch.vertexCount * batch.auditRecordCount
    let pointer = buffer.contents().bindMemory(
      to: CrowFeatherVertexGPU.self,
      capacity: count
    )
    return Array(UnsafeBufferPointer(start: pointer, count: count))
  }

  func rachisVertices(
    for batch: CrowBodyVaneGeometryBatchFrame
  ) -> [CrowFeatherVertexGPU] {
    let count = batch.rachisVertexCount * batch.auditRecordCount
    guard count > 0 else { return [] }
    guard let buffer = batch.auditRachisOutputBuffer else {
      preconditionFailure("body rachis frame lacks audit readback")
    }
    let pointer = buffer.contents().bindMemory(
      to: CrowFeatherVertexGPU.self,
      capacity: count
    )
    return Array(UnsafeBufferPointer(start: pointer, count: count))
  }

  func detailVertices(
    for batch: CrowBodyVaneGeometryBatchFrame
  ) -> [CrowFeatherVertexGPU] {
    let count = batch.detailVertexCount * batch.auditRecordCount
    guard count > 0 else { return [] }
    guard let buffer = batch.auditDetailOutputBuffer else {
      preconditionFailure("body detail frame lacks audit readback")
    }
    let pointer = buffer.contents().bindMemory(
      to: CrowFeatherVertexGPU.self,
      capacity: count
    )
    return Array(UnsafeBufferPointer(start: pointer, count: count))
  }

  func auditRecords(
    for batch: CrowBodyVaneGeometryBatchFrame
  ) -> [CrowBodyVaneRecordGPU] {
    batch.auditRecords
  }

  private func ensureDetailSegmentCapacity(
    projectedPixelsPerMeter: Float
  ) throws {
    let requiredCapacity = maximumMorphologyLength * projectedPixelsPerMeter >= 480
      ? 149 : 25
    guard requiredCapacity > detailSegmentCapacityPerRecord else { return }
    detailSegmentBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(
        length: morphologyRecords.count * requiredCapacity
          * MemoryLayout<CrowBodyDetailSegmentGPU>.stride
      )
    }
    detailSegmentCapacityPerRecord = requiredCapacity
    detailSegmentBufferAllocationCount += Self.bufferedFrameCount
  }

  private static func sharedBuffer<T>(
    values: [T],
    backend: VisualizationBackend
  ) throws -> MTLBuffer {
    let buffer = try backend.buffer(
      length: values.count * MemoryLayout<T>.stride,
      shared: true
    )
    values.withUnsafeBytes { bytes in
      if let baseAddress = bytes.baseAddress, !bytes.isEmpty {
        memcpy(buffer.contents(), baseAddress, bytes.count)
      }
    }
    return buffer
  }
}

enum CrowBodyVaneRecords {
  static let productionTopologies: [CrowBodyVaneTopology] = [
    CrowBodyVaneTopology(axialSections: 3, widthSections: 1),
    CrowBodyVaneTopology(axialSections: 4, widthSections: 1),
    CrowBodyVaneTopology(axialSections: 6, widthSections: 5),
    CrowBodyVaneTopology(axialSections: 8, widthSections: 5),
    CrowBodyVaneTopology(axialSections: 10, widthSections: 5),
    CrowBodyVaneTopology(axialSections: 12, widthSections: 5),
    CrowBodyVaneTopology(axialSections: 16, widthSections: 7),
  ]

  static func rachisSections(for topology: CrowBodyVaneTopology) -> Int {
    switch topology.axialSections {
    case ...4: 0
    case 6, 8: 4
    case 10, 12: 8
    default: 12
    }
  }

  static func rachisVerticesPerInstance(
    for topology: CrowBodyVaneTopology
  ) -> Int {
    rachisSections(for: topology) * 24
  }

  static func detailSegmentCount(for topology: CrowBodyVaneTopology) -> Int {
    switch topology.axialSections {
    case ...4: 0
    case 6, 8: 25
    case 10, 12: 23
    default: 149
    }
  }

  static func detailVerticesPerInstance(
    for topology: CrowBodyVaneTopology
  ) -> Int {
    detailSegmentCount(for: topology) * 18
  }

  static func morphologyRecords() -> [CrowBodyVaneMorphologyGPU] {
    CrowBodyFeatherTracts.samples().enumerated().map { index, sample in
      let identityHash = stableHash(identity(of: sample))
      return CrowBodyVaneMorphologyGPU(
        rootAndRootWidth: SIMD4<Float>(
          sample.rootOffset,
          sample.rootWidthMeters
        ),
        tipAndMaximumWidth: SIMD4<Float>(
          sample.tipOffset,
          sample.maximumWidthMeters
        ),
        normalAndCamber: SIMD4<Float>(
          sample.planeNormal,
          sample.camberMeters
        ),
        sweepAsymmetryAndRipple: SIMD4<Float>(
          sample.lateralSweepMeters,
          sample.vaneAsymmetry,
          sample.edgeRippleAmplitude,
          sample.edgeRipplePhase
        ),
        envelopeAndTaper: SIMD4<Float>(
          sample.edgeRippleCycles,
          sample.rootEnvelopeRatio,
          sample.terminalWidthRatio,
          sample.distalTaperExponent
        ),
        color: color(for: sample),
        morphology: SIMD4<Float>(
          sample.pennaceousStartFraction,
          Float(sample.region.rawValue),
          Float(sample.row),
          Float(sample.column)
        ),
        identity: SIMD4<UInt32>(
          0x0200_0000 | UInt32(index),
          identityHash,
          1,
          sample.surfaceFeatherClass
        )
      )
    }
  }

  static func groupedMorphologyIndices(
    projectedPixelsPerMeter: Float
  ) -> [CrowBodyVaneTopology: [Int]] {
    var grouped: [CrowBodyVaneTopology: [Int]] = [:]
    for (index, sample) in CrowBodyFeatherTracts.samples().enumerated()
    where isVisible(
      sample,
      projectedPixelsPerMeter: projectedPixelsPerMeter
    ) {
      grouped[
        topology(
          for: sample,
          projectedPixelsPerMeter: projectedPixelsPerMeter
        ),
        default: []
      ].append(index)
    }
    return grouped
  }

  static func neckTransforms(
    current: CrowStandingNeckPose?,
    previous: CrowStandingNeckPose?
  ) -> [CrowBodyVaneNeckTransformGPU] {
    transforms(for: current) + transforms(for: previous)
  }

  private static func transforms(
    for pose: CrowStandingNeckPose?
  ) -> [CrowBodyVaneNeckTransformGPU] {
    guard let pose else {
      let identity = CrowBodyVaneNeckTransformGPU(
        row0: SIMD4<Float>(1, 0, 0, 0),
        row1: SIMD4<Float>(0, 1, 0, 0),
        row2: SIMD4<Float>(0, 0, 1, 0)
      )
      return Array(
        repeating: identity,
        count: CrowBodyFeatherTracts.cervicalColumnCount
      )
    }
    return (0..<CrowBodyFeatherTracts.cervicalColumnCount).map { column in
      let axial = Float(column)
        / Float(CrowBodyFeatherTracts.cervicalColumnCount - 1)
      let coupling = 0.10 + 0.78 * axial
      let x = pose.rotated(SIMD3<Float>(1, 0, 0), coupling: coupling)
      let y = pose.rotated(SIMD3<Float>(0, 1, 0), coupling: coupling)
      let z = pose.rotated(SIMD3<Float>(0, 0, 1), coupling: coupling)
      let translation = pose.transform(offset: .zero, coupling: coupling)
      return CrowBodyVaneNeckTransformGPU(
        row0: SIMD4<Float>(x.x, y.x, z.x, translation.x),
        row1: SIMD4<Float>(x.y, y.y, z.y, translation.y),
        row2: SIMD4<Float>(x.z, y.z, z.z, translation.z)
      )
    }
  }

  static func temporalRecords(
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    currentNeckPose: CrowStandingNeckPose?,
    previousNeckPose: CrowStandingNeckPose?,
    currentDeployment: Float,
    previousDeployment: Float
  ) -> [CrowBodyVaneRecordGPU] {
    let current = CrowBodyFeatherTracts.samples(neckPose: currentNeckPose)
    let previous = CrowBodyFeatherTracts.samples(neckPose: previousNeckPose)
    precondition(current.count == previous.count, "body vane temporal inventory")
    return zip(current, previous).enumerated().map { index, pair in
      precondition(identity(of: pair.0) == identity(of: pair.1))
      return record(
        current: pair.0,
        previous: pair.1,
        currentBodyCenter: currentBodyCenter,
        previousBodyCenter: previousBodyCenter,
        currentDeployment: currentDeployment,
        previousDeployment: previousDeployment,
        inventoryIndex: index
      )
    }
  }

  static func groupedRecords(
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    currentNeckPose: CrowStandingNeckPose?,
    previousNeckPose: CrowStandingNeckPose?,
    currentDeployment: Float,
    previousDeployment: Float,
    projectedPixelsPerMeter: Float
  ) -> [CrowBodyVaneTopology: [CrowBodyVaneRecordGPU]] {
    let current = CrowBodyFeatherTracts.samples(neckPose: currentNeckPose)
    let previous = CrowBodyFeatherTracts.samples(neckPose: previousNeckPose)
    precondition(current.count == previous.count, "body vane temporal inventory")
    var grouped: [CrowBodyVaneTopology: [CrowBodyVaneRecordGPU]] = [:]
    for (index, pair) in zip(current, previous).enumerated() {
      precondition(identity(of: pair.0) == identity(of: pair.1))
      guard
        isVisible(
          pair.0,
          projectedPixelsPerMeter: projectedPixelsPerMeter
        )
      else { continue }
      let topology = topology(
        for: pair.0,
        projectedPixelsPerMeter: projectedPixelsPerMeter
      )
      grouped[topology, default: []].append(
        record(
          current: pair.0,
          previous: pair.1,
          currentBodyCenter: currentBodyCenter,
          previousBodyCenter: previousBodyCenter,
          currentDeployment: currentDeployment,
          previousDeployment: previousDeployment,
          inventoryIndex: index
        )
      )
    }
    return grouped
  }

  static func isVisible(
    _ sample: CrowBodyFeatherTractSample,
    projectedPixelsPerMeter: Float
  ) -> Bool {
    if projectedPixelsPerMeter >= 1_400 { return true }
    if projectedPixelsPerMeter >= 900 {
      return (sample.row + sample.column).isMultiple(of: 2)
    }
    if sample.region == .cervical {
      return sample.column.isMultiple(of: 2)
    }
    return sample.row.isMultiple(of: 2) && sample.column.isMultiple(of: 2)
  }

  static func topology(
    for sample: CrowBodyFeatherTractSample,
    projectedPixelsPerMeter: Float
  ) -> CrowBodyVaneTopology {
    let length = simd_distance(sample.rootOffset, sample.tipOffset)
    let tessellation = CrowFeatherCoverageLOD.tessellation(
      lengthMeters: length,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      baseAxialSections: sample.region == .cervical ? 6 : 8
    )
    return CrowBodyVaneTopology(
      axialSections: tessellation.axialSections,
      widthSections: max(
        tessellation.widthSections,
        CrowFeatherCoverageLOD.bodyTractMinimumWidthSections(
          lengthMeters: length,
          projectedPixelsPerMeter: projectedPixelsPerMeter
        )
      )
    )
  }

  static func point(
    record: CrowBodyVaneRecordGPU,
    topology: CrowBodyVaneTopology,
    current: Bool,
    axialIndex: Int,
    widthIndex: Int
  ) -> SIMD3<Float> {
    let localFraction = Float(axialIndex) / Float(topology.axialSections)
    let start = min(max(record.morphology.x, 0), 0.95)
    let t = start + (1 - start) * localFraction
    let root =
      current
      ? record.currentRootAndRootWidth.xyz
      : record.previousRootAndCurrentCamber.xyz
    let tip =
      current
      ? record.currentTipAndMaximumWidth.xyz
      : record.previousTipAndPreviousCamber.xyz
    let suppliedNormal =
      current
      ? record.currentNormalAndTransverseCamber.xyz
      : record.previousNormalAndTransverseCamber.xyz
    let normal = normalized(suppliedNormal, fallback: SIMD3<Float>(0, 0, 1))
    let direction = normalized(tip - root, fallback: SIMD3<Float>(1, 0, 0))
    let widthAxis = normalized(
      simd_cross(normal, direction),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    let rootEnvelope = min(max(record.envelopeAndTaper.y, 0.05), 1)
    let bodyEnvelope =
      rootEnvelope
      + (1 - rootEnvelope) * pow(max(sin(.pi * t), 0), 0.58)
    let terminal = min(max(record.envelopeAndTaper.z, 0), 1)
    let exponent = min(max(record.envelopeAndTaper.w, 2), 5)
    let tipTaper = 1 - (1 - terminal) * pow(t, exponent)
    let rippleEnvelope = pow(max(sin(.pi * t), 0), 2)
    let ripple =
      1 + record.sweepAsymmetryAndRipple.z
      * sin(
        2 * .pi * record.envelopeAndTaper.x * t
          + record.sweepAsymmetryAndRipple.w) * rippleEnvelope
    let rootWidth = record.currentRootAndRootWidth.w
    let maximumWidth = record.currentTipAndMaximumWidth.w
    let width =
      (rootWidth * (1 - t) + maximumWidth * t)
      * bodyEnvelope * tipTaper * ripple
    let camber =
      current
      ? record.previousRootAndCurrentCamber.w
      : record.previousTipAndPreviousCamber.w
    let transverse =
      current
      ? record.currentNormalAndTransverseCamber.w
      : record.previousNormalAndTransverseCamber.w
    let center =
      root + (tip - root) * t
      + normal * (camber * sin(.pi * t))
      + widthAxis * (record.sweepAsymmetryAndRipple.x * sin(.pi * t))
    let signedWidth = 2 * Float(widthIndex) / Float(topology.widthSections) - 1
    let localWidth = width * (1 + record.sweepAsymmetryAndRipple.y * signedWidth)
    return center + widthAxis * (signedWidth * localWidth)
      + normal * (localWidth * transverse * max(0, 1 - signedWidth * signedWidth))
  }

  static func normal(
    record: CrowBodyVaneRecordGPU,
    topology: CrowBodyVaneTopology,
    axialIndex: Int,
    widthIndex: Int
  ) -> SIMD3<Float> {
    let supplied = normalized(
      record.currentNormalAndTransverseCamber.xyz,
      fallback: SIMD3<Float>(0, 0, 1)
    )
    let axialFirst = point(
      record: record, topology: topology, current: true,
      axialIndex: max(0, axialIndex - 1), widthIndex: widthIndex
    )
    let axialSecond = point(
      record: record, topology: topology, current: true,
      axialIndex: min(topology.axialSections, axialIndex + 1),
      widthIndex: widthIndex
    )
    let widthFirst = point(
      record: record, topology: topology, current: true,
      axialIndex: axialIndex, widthIndex: max(0, widthIndex - 1)
    )
    let widthSecond = point(
      record: record, topology: topology, current: true,
      axialIndex: axialIndex,
      widthIndex: min(topology.widthSections, widthIndex + 1)
    )
    var resolved = normalized(
      simd_cross(axialSecond - axialFirst, widthSecond - widthFirst),
      fallback: supplied
    )
    if simd_dot(resolved, supplied) < 0 { resolved = -resolved }
    return resolved
  }

  static func rachisIsResolved(
    record: CrowBodyVaneRecordGPU,
    projectedPixelsPerMeter: Float
  ) -> Bool {
    2 * record.currentTipAndMaximumWidth.w * projectedPixelsPerMeter
      < CrowFeatherMesostructure.bodyTractResolvedRachisWidthThresholdPixels
  }

  static func rachisVertex(
    record: CrowBodyVaneRecordGPU,
    topology: CrowBodyVaneTopology,
    projectedPixelsPerMeter: Float,
    vertexIndex: Int
  ) -> CrowFeatherVertexGPU {
    let verticesPerInstance = rachisVerticesPerInstance(for: topology)
    precondition(vertexIndex >= 0 && vertexIndex < verticesPerInstance)
    guard
      rachisIsResolved(
        record: record,
        projectedPixelsPerMeter: projectedPixelsPerMeter
      )
    else {
      return CrowFeatherVertexGPU(
        position: SIMD4<Float>(record.currentRootAndRootWidth.xyz, 1),
        normal: SIMD4<Float>(0, 0, 1, 0),
        color: .zero,
        previousPosition: SIMD4<Float>(record.previousRootAndCurrentCamber.xyz, 1),
        identity: record.identity,
        parameters: .zero
      )
    }
    let sections = rachisSections(for: topology)
    let section = vertexIndex / 24
    let localVertex = vertexIndex % 24
    let radialSegment = localVertex / 6
    let corner = [0, 1, 2, 0, 2, 3][localVertex % 6]
    let start = min(max(record.morphology.x, 0), 0.95)
    let firstAxial = start
      + (1 - start) * Float(section) / Float(sections)
    let secondAxial = start
      + (1 - start) * Float(section + 1) / Float(sections)
    let current = rachisTubeQuad(
      record: record,
      current: true,
      firstAxial: firstAxial,
      secondAxial: secondAxial,
      radialSegment: radialSegment
    )
    let previous = rachisTubeQuad(
      record: record,
      current: false,
      firstAxial: firstAxial,
      secondAxial: secondAxial,
      radialSegment: radialSegment
    )
    return CrowFeatherVertexGPU(
      position: SIMD4<Float>(current.points[corner], 1),
      normal: SIMD4<Float>(current.normal, 0),
      color: rachisColor(record: record),
      previousPosition: SIMD4<Float>(previous.points[corner], 1),
      identity: record.identity,
      parameters: SIMD4<Float>(0.5, 0, 0, 0)
    )
  }

  private static func rachisTubeQuad(
    record: CrowBodyVaneRecordGPU,
    current: Bool,
    firstAxial: Float,
    secondAxial: Float,
    radialSegment: Int
  ) -> (points: [SIMD3<Float>], normal: SIMD3<Float>) {
    let start = rachisCenter(record: record, current: current, axial: firstAxial)
    let end = rachisCenter(record: record, current: current, axial: secondAxial)
    let axis = normalized(end - start, fallback: SIMD3<Float>(0, 0, 1))
    let helper: SIMD3<Float> = abs(axis.z) < 0.82
      ? SIMD3<Float>(0, 0, 1)
      : SIMD3<Float>(0, 1, 0)
    let first = normalized(simd_cross(axis, helper), fallback: SIMD3<Float>(1, 0, 0))
    let second = normalized(simd_cross(axis, first), fallback: SIMD3<Float>(0, 1, 0))
    let next = (radialSegment + 1) % 4
    let angle0 = 2 * Float.pi * Float(radialSegment) / 4
    let angle1 = 2 * Float.pi * Float(next) / 4
    let radial0 = cos(angle0) * first + sin(angle0) * second
    let radial1 = cos(angle1) * first + sin(angle1) * second
    let startRadius = 0.00022 + (0.000055 - 0.00022) * firstAxial
    let endRadius = 0.00022 + (0.000055 - 0.00022) * secondAxial
    let points = [
      start + startRadius * radial0,
      start + startRadius * radial1,
      end + endRadius * radial1,
      end + endRadius * radial0,
    ]
    let normal = normalized(
      simd_cross(points[1] - points[0], points[2] - points[0]),
      fallback: SIMD3<Float>(0, 0, 1)
    )
    return (points, normal)
  }

  private static func rachisCenter(
    record: CrowBodyVaneRecordGPU,
    current: Bool,
    axial: Float
  ) -> SIMD3<Float> {
    let root = current
      ? record.currentRootAndRootWidth.xyz
      : record.previousRootAndCurrentCamber.xyz
    let tip = current
      ? record.currentTipAndMaximumWidth.xyz
      : record.previousTipAndPreviousCamber.xyz
    let suppliedNormal = current
      ? record.currentNormalAndTransverseCamber.xyz
      : record.previousNormalAndTransverseCamber.xyz
    let direction = normalized(tip - root, fallback: SIMD3<Float>(-1, 0, 0))
    let normal = normalized(
      suppliedNormal - direction * simd_dot(suppliedNormal, direction),
      fallback: suppliedNormal
    )
    let widthAxis = normalized(
      simd_cross(normal, direction),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    let camber = current
      ? record.previousRootAndCurrentCamber.w
      : record.previousTipAndPreviousCamber.w
    let vaneTransverse = current
      ? record.currentNormalAndTransverseCamber.w
      : record.previousNormalAndTransverseCamber.w
    let region = Int(record.morphology.y)
    let row = min(max(record.morphology.z, 0), 21)
    let course = row / 21
    let retainedTransverse: Float =
      region == Int(CrowBodyFeatherTractRegion.scapular.rawValue)
        && course >= CrowBodyFeatherTracts
          .scapularFlightTransverseCamberStartCourseFraction
      ? CrowBodyFeatherTracts.retainedDetailCrownInsetScale * vaneTransverse
      : 0
    let halfWidth = bodyVaneHalfWidth(record: record, axial: axial)
    return root + (tip - root) * axial
      + widthAxis * (record.sweepAsymmetryAndRipple.x * sin(.pi * axial))
      + normal
        * (camber * sin(.pi * axial) + retainedTransverse * halfWidth + 0.00012)
  }

  private static func bodyVaneHalfWidth(
    record: CrowBodyVaneRecordGPU,
    axial: Float
  ) -> Float {
    let rootEnvelope = min(max(record.envelopeAndTaper.y, 0.05), 1)
    let bodyEnvelope = rootEnvelope
      + (1 - rootEnvelope) * pow(max(sin(.pi * axial), 0), 0.58)
    let terminal = min(max(record.envelopeAndTaper.z, 0), 1)
    let exponent = min(max(record.envelopeAndTaper.w, 2), 5)
    let tipTaper = 1 - (1 - terminal) * pow(axial, exponent)
    let rippleEnvelope = pow(max(sin(.pi * axial), 0), 2)
    let ripple = 1 + record.sweepAsymmetryAndRipple.z
      * sin(
        2 * .pi * record.envelopeAndTaper.x * axial
          + record.sweepAsymmetryAndRipple.w
      ) * rippleEnvelope
    return (
      record.currentRootAndRootWidth.w * (1 - axial)
        + record.currentTipAndMaximumWidth.w * axial
    ) * bodyEnvelope * tipTaper * ripple
  }

  private static func rachisColor(
    record: CrowBodyVaneRecordGPU
  ) -> SIMD4<Float> {
    let region = Int(record.morphology.y)
    let baseAndScale: (Float, Float)
    switch region {
    case Int(CrowBodyFeatherTractRegion.cervical.rawValue):
      baseAndScale = (0.006, 0.07)
    case Int(CrowBodyFeatherTractRegion.mantle.rawValue):
      baseAndScale = (0.0065, 0.09)
    case Int(CrowBodyFeatherTractRegion.humeral.rawValue):
      baseAndScale = (0.0058, 0.080)
    default:
      baseAndScale = (0.0060, 0.085)
    }
    let material = (record.color.x / baseAndScale.0 - 1) / baseAndScale.1
    return SIMD4<Float>(
      0.010 * (1 + 0.06 * material),
      0.014 * (1 + 0.04 * material),
      0.022 * (1 + 0.03 * material),
      0.14
    )
  }

  struct BodyDetailSegment: Equatable {
    let kind: CrowFeatherMesostructureKind
    let start: SIMD3<Float>
    let end: SIMD3<Float>
    let startRadiusMeters: Float
    let endRadiusMeters: Float
  }

  private struct BodyDetailFrame {
    let root: SIMD3<Float>
    let tip: SIMD3<Float>
    let direction: SIMD3<Float>
    let normal: SIMD3<Float>
    let widthAxis: SIMD3<Float>
    let camber: Float
    let transverseCamber: Float
  }

  static func detailSegments(
    record: CrowBodyVaneRecordGPU,
    topology: CrowBodyVaneTopology,
    projectedPixelsPerMeter: Float,
    current: Bool
  ) -> [BodyDetailSegment] {
    let edgePairCount: Int
    let baseBarbPairCount: Int
    let barbulesPerBarb: Int
    switch topology.axialSections {
    case ...4:
      return []
    case 6, 8:
      edgePairCount = 10
      baseBarbPairCount = 0
      barbulesPerBarb = 0
    case 10, 12:
      edgePairCount = 9
      baseBarbPairCount = 9
      barbulesPerBarb = 0
    default:
      edgePairCount = 18
      baseBarbPairCount = 18
      barbulesPerBarb = 3
    }
    let region = Int(record.morphology.y)
    let length = simd_distance(
      record.currentRootAndRootWidth.xyz,
      record.currentTipAndMaximumWidth.xyz
    )
    let promotesInterior =
      (region == Int(CrowBodyFeatherTractRegion.humeral.rawValue)
        || region == Int(CrowBodyFeatherTractRegion.scapular.rawValue))
      && length * projectedPixelsPerMeter
        >= CrowFeatherMesostructure.shoulderInteriorBarbThresholdPixels
    let pairCount = promotesInterior
      ? max(baseBarbPairCount, edgePairCount) : baseBarbPairCount
    let coarseEdgeOnly = pairCount == 0
    let safePixelsPerMeter = max(projectedPixelsPerMeter, 1)
    let aggregateRadius = min(
      0.00020,
      max(0.000035, 0.30 / safePixelsPerMeter)
    )
    let baseExtension = min(
      0.0012,
      max(0.00050, 1.10 / safePixelsPerMeter)
    )
    let frame = bodyDetailFrame(record: record, current: current)
    let identityFirst = Int(record.morphology.z) + 31 * region
    let tractSide = bodyTractSide(record: record)
    let identitySecond = Int(record.morphology.w) + (tractSide < 0 ? 97 : 0)
    let stationSpacing = 0.77 / Float(edgePairCount + 1)
    var result: [BodyDetailSegment] = []
    result.reserveCapacity(detailSegmentCount(for: topology))
    for pair in 0..<edgePairCount {
      let featherPhase = Float(identityFirst + 1) * 19.193
        + Float(identitySecond + 1) * 47.117
      let stationPhase = Float(pair + 1) * 11.731
      let stationIdentity = sin(featherPhase + stationPhase)
      let localAxial = 0.10 + stationSpacing * Float(pair + 1)
        + CrowFeatherMesostructure.bodyTractBarbStationJitterFractionOfSpacing
          * stationSpacing * stationIdentity
      let axial = pennaceousAxial(record: record, localFraction: localAxial)
      let reachAxial = pennaceousAxial(
        record: record,
        localFraction: min(0.94, localAxial + 0.035 + 0.020 * localAxial)
      )
      for side: Float in [-1, 1] {
        let identity = sin(
          Float(identityFirst + 1) * 12.9898
            + Float(identitySecond + 1) * 78.233
            + Float(pair + 1) * 37.719
            + side * 1.371
        )
        let start = bodyDetailCenter(
          record: record,
          frame: frame,
          axial: axial
        )
          + side * frame.widthAxis
            * detailHalfWidth(record: record, axial: axial, signedWidth: side)
            * (coarseEdgeOnly ? 0.72 : 0)
          + frame.normal * (coarseEdgeOnly ? 0.00010 : 0.00005)
        let edgeExtension = baseExtension * (0.86 + 0.14 * identity)
        let reachHalfWidth = detailHalfWidth(
          record: record,
          axial: reachAxial,
          signedWidth: side
        )
        let lateralReach = coarseEdgeOnly
          ? reachHalfWidth + edgeExtension : 0.97 * reachHalfWidth
        let end = bodyDetailCenter(
          record: record,
          frame: frame,
          axial: reachAxial
        )
          + side * frame.widthAxis * lateralReach
          + frame.normal * (coarseEdgeOnly ? 0.00018 : 0.00008)
        result.append(
          BodyDetailSegment(
            kind: coarseEdgeOnly ? .edgeBarbGroup : .barb,
            start: start,
            end: end,
            startRadiusMeters: coarseEdgeOnly ? aggregateRadius : 0.000050,
            endRadiusMeters: coarseEdgeOnly
              ? 0.58 * aggregateRadius : 0.000018
          )
        )
        if !coarseEdgeOnly && barbulesPerBarb > 0 {
          let barbDirection = normalized(
            end - start,
            fallback: side * frame.widthAxis
          )
          let barbuleLength = min(0.0014, 0.22 * simd_distance(start, end))
          for index in 0..<barbulesPerBarb {
            let fraction = Float(index + 1) / Float(barbulesPerBarb + 1)
            let root = start + fraction * (end - start)
            let hookDirection = normalized(
              0.82 * frame.direction - 0.24 * side * frame.widthAxis
                + 0.10 * barbDirection,
              fallback: frame.direction
            )
            result.append(
              BodyDetailSegment(
                kind: .barbule,
                start: root,
                end: root + barbuleLength * hookDirection,
                startRadiusMeters: 0.000014,
                endRadiusMeters: 0.000006
              )
            )
          }
        }
      }
    }
    let tipReferenceHalfWidth = detailHalfWidth(
      record: record,
      axial: 0.88,
      signedWidth: 0
    )
    for lane: Float in [-1, -0.5, 0, 0.5, 1] {
      let featherPhase = Float(identityFirst + 1) * 23.417
        + Float(identitySecond + 1) * 51.193
      let rootIdentity = sin(featherPhase + lane * 5.173)
      let rootAxial = 0.88
        + CrowFeatherMesostructure.bodyTractTerminalRootAxialJitter
          * rootIdentity
      let root = bodyDetailCenter(
        record: record,
        frame: frame,
        axial: rootAxial
      )
        + lane * frame.widthAxis
          * detailHalfWidth(record: record, axial: rootAxial, signedWidth: 0)
          * 0.42
        + frame.normal * 0.00012
      let laneIdentity = sin(
        Float(identityFirst + 1) * 17.117
          + Float(identitySecond + 1) * 43.731
          + lane * 2.913
      )
      let tip = frame.tip
        + frame.direction * baseExtension * (0.82 + 0.12 * laneIdentity)
        + lane * frame.widthAxis * 0.18 * tipReferenceHalfWidth
        + frame.normal * 0.00020
      result.append(
        BodyDetailSegment(
          kind: .edgeBarbGroup,
          start: root,
          end: tip,
          startRadiusMeters: 0.88 * aggregateRadius,
          endRadiusMeters: 0.50 * aggregateRadius
        )
      )
    }
    precondition(result.count == detailSegmentCount(for: topology))
    return result
  }

  static func detailVertex(
    record: CrowBodyVaneRecordGPU,
    topology: CrowBodyVaneTopology,
    projectedPixelsPerMeter: Float,
    vertexIndex: Int
  ) -> CrowFeatherVertexGPU {
    let count = detailVerticesPerInstance(for: topology)
    precondition(vertexIndex >= 0 && vertexIndex < count)
    let currentSegments = detailSegments(
      record: record,
      topology: topology,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      current: true
    )
    let previousSegments = detailSegments(
      record: record,
      topology: topology,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      current: false
    )
    let segmentIndex = vertexIndex / 18
    let localVertex = vertexIndex % 18
    let current = currentSegments[segmentIndex]
    let previous = previousSegments[segmentIndex]
    let currentGeometry: (point: SIMD3<Float>, normal: SIMD3<Float>)
    let previousPoint: SIMD3<Float>
    if current.kind == .edgeBarbGroup {
      let currentRibbon = detailRibbonQuad(
        segment: current,
        surfaceNormal: bodyDetailFrame(record: record, current: true).normal
      )
      let previousRibbon = detailRibbonQuad(
        segment: previous,
        surfaceNormal: bodyDetailFrame(record: record, current: false).normal
      )
      let corners = [0, 1, 2, 0, 2, 3]
      if localVertex < 6 {
        currentGeometry = (
          currentRibbon.points[corners[localVertex]],
          currentRibbon.normal
        )
        previousPoint = previousRibbon.points[corners[localVertex]]
      } else {
        currentGeometry = (currentRibbon.points[0], currentRibbon.normal)
        previousPoint = previousRibbon.points[0]
      }
    } else {
      let radialSegment = localVertex / 6
      let corner = [0, 1, 2, 0, 2, 3][localVertex % 6]
      let currentTube = detailTubeQuad(
        segment: current,
        radialSegment: radialSegment
      )
      let previousTube = detailTubeQuad(
        segment: previous,
        radialSegment: radialSegment
      )
      currentGeometry = (currentTube.points[corner], currentTube.normal)
      previousPoint = previousTube.points[corner]
    }
    return CrowFeatherVertexGPU(
      position: SIMD4<Float>(currentGeometry.point, 1),
      normal: SIMD4<Float>(currentGeometry.normal, 0),
      color: detailColor(record: record, kind: current.kind),
      previousPosition: SIMD4<Float>(previousPoint, 1),
      identity: record.identity,
      parameters: SIMD4<Float>(0.5, 0, 0, 0)
    )
  }

  private static func bodyDetailFrame(
    record: CrowBodyVaneRecordGPU,
    current: Bool
  ) -> BodyDetailFrame {
    let root = current
      ? record.currentRootAndRootWidth.xyz
      : record.previousRootAndCurrentCamber.xyz
    let tip = current
      ? record.currentTipAndMaximumWidth.xyz
      : record.previousTipAndPreviousCamber.xyz
    let suppliedNormal = current
      ? record.currentNormalAndTransverseCamber.xyz
      : record.previousNormalAndTransverseCamber.xyz
    let direction = normalized(tip - root, fallback: SIMD3<Float>(-1, 0, 0))
    let normal = normalized(
      suppliedNormal - direction * simd_dot(suppliedNormal, direction),
      fallback: suppliedNormal
    )
    return BodyDetailFrame(
      root: root,
      tip: tip,
      direction: direction,
      normal: normal,
      widthAxis: normalized(
        simd_cross(normal, direction),
        fallback: SIMD3<Float>(0, 1, 0)
      ),
      camber: current
        ? record.previousRootAndCurrentCamber.w
        : record.previousTipAndPreviousCamber.w,
      transverseCamber: current
        ? record.currentNormalAndTransverseCamber.w
        : record.previousNormalAndTransverseCamber.w
    )
  }

  private static func bodyDetailCenter(
    record: CrowBodyVaneRecordGPU,
    frame: BodyDetailFrame,
    axial: Float
  ) -> SIMD3<Float> {
    frame.root + (frame.tip - frame.root) * axial
      + frame.widthAxis
        * (record.sweepAsymmetryAndRipple.x * sin(.pi * axial))
      + frame.normal
        * (frame.camber * sin(.pi * axial)
          + frame.transverseCamber
            * detailHalfWidth(record: record, axial: axial, signedWidth: 0)
          + 0.00012)
  }

  private static func detailHalfWidth(
    record: CrowBodyVaneRecordGPU,
    axial: Float,
    signedWidth: Float
  ) -> Float {
    bodyVaneHalfWidth(record: record, axial: axial)
      * (1 + record.sweepAsymmetryAndRipple.y * min(max(signedWidth, -1), 1))
  }

  private static func pennaceousAxial(
    record: CrowBodyVaneRecordGPU,
    localFraction: Float
  ) -> Float {
    let start = min(max(record.morphology.x, 0), 0.95)
    return start + (1 - start) * min(max(localFraction, 0), 1)
  }

  private static func bodyTractSide(
    record: CrowBodyVaneRecordGPU
  ) -> Float {
    let inventoryIndex = Int(record.identity.x & 0x00FF_FFFF)
    let region = Int(record.morphology.y)
    let base: Int
    let perSide: Int
    switch region {
    case 0:
      base = 0
      perSide = CrowBodyFeatherTracts.cervicalRowCount
        * CrowBodyFeatherTracts.cervicalColumnCount
    case 1:
      base = 2 * CrowBodyFeatherTracts.cervicalRowCount
        * CrowBodyFeatherTracts.cervicalColumnCount
      perSide = CrowBodyFeatherTracts.mantleRowCount
        * CrowBodyFeatherTracts.mantleColumnCount
    case 2:
      base = 2 * (
        CrowBodyFeatherTracts.cervicalRowCount
          * CrowBodyFeatherTracts.cervicalColumnCount
          + CrowBodyFeatherTracts.mantleRowCount
            * CrowBodyFeatherTracts.mantleColumnCount
      )
      perSide = CrowBodyFeatherTracts.humeralRowCount
        * CrowBodyFeatherTracts.humeralColumnCount
    default:
      base = 2 * (
        CrowBodyFeatherTracts.cervicalRowCount
          * CrowBodyFeatherTracts.cervicalColumnCount
          + CrowBodyFeatherTracts.mantleRowCount
            * CrowBodyFeatherTracts.mantleColumnCount
          + CrowBodyFeatherTracts.humeralRowCount
            * CrowBodyFeatherTracts.humeralColumnCount
      )
      perSide = CrowBodyFeatherTracts.scapularRowCount
        * CrowBodyFeatherTracts.scapularColumnCount
    }
    return inventoryIndex - base < perSide ? -1 : 1
  }

  private static func detailRibbonQuad(
    segment: BodyDetailSegment,
    surfaceNormal: SIMD3<Float>
  ) -> (points: [SIMD3<Float>], normal: SIMD3<Float>) {
    let axis = normalized(segment.end - segment.start, fallback: SIMD3<Float>(-1, 0, 0))
    let normal = normalized(
      surfaceNormal - axis * simd_dot(surfaceNormal, axis),
      fallback: surfaceNormal
    )
    let across = normalized(
      simd_cross(normal, axis),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    return (
      [
        segment.start - across * segment.startRadiusMeters,
        segment.start + across * segment.startRadiusMeters,
        segment.end + across * segment.endRadiusMeters,
        segment.end - across * segment.endRadiusMeters,
      ],
      normal
    )
  }

  private static func detailTubeQuad(
    segment: BodyDetailSegment,
    radialSegment: Int
  ) -> (points: [SIMD3<Float>], normal: SIMD3<Float>) {
    let axis = normalized(segment.end - segment.start, fallback: SIMD3<Float>(0, 0, 1))
    let helper: SIMD3<Float> = abs(axis.z) < 0.82
      ? SIMD3<Float>(0, 0, 1) : SIMD3<Float>(0, 1, 0)
    let first = normalized(simd_cross(axis, helper), fallback: SIMD3<Float>(1, 0, 0))
    let second = normalized(simd_cross(axis, first), fallback: SIMD3<Float>(0, 1, 0))
    let next = (radialSegment + 1) % 3
    let angle0 = 2 * Float.pi * Float(radialSegment) / 3
    let angle1 = 2 * Float.pi * Float(next) / 3
    let radial0 = cos(angle0) * first + sin(angle0) * second
    let radial1 = cos(angle1) * first + sin(angle1) * second
    let points = [
      segment.start + segment.startRadiusMeters * radial0,
      segment.start + segment.startRadiusMeters * radial1,
      segment.end + segment.endRadiusMeters * radial1,
      segment.end + segment.endRadiusMeters * radial0,
    ]
    return (
      points,
      normalized(
        simd_cross(points[1] - points[0], points[2] - points[0]),
        fallback: SIMD3<Float>(0, 0, 1)
      )
    )
  }

  private static func detailColor(
    record: CrowBodyVaneRecordGPU,
    kind: CrowFeatherMesostructureKind
  ) -> SIMD4<Float> {
    switch kind {
    case .edgeBarbGroup:
      let region = Int(record.morphology.y)
      let base: Float = region == 0 ? 0.006
        : (region == 1 ? 0.0065 : (region == 2 ? 0.0058 : 0.0060))
      let scale: Float = region == 0 ? 0.07
        : (region == 1 ? 0.09 : (region == 2 ? 0.080 : 0.085))
      let material = (record.color.x / base - 1) / scale
      return SIMD4<Float>(
        0.0075 * (1 + 0.08 * material),
        0.011 * (1 + 0.06 * material),
        0.019 * (1 + 0.04 * material),
        0.135
      )
    case .barb:
      return SIMD4<Float>(0.008, 0.012, 0.020, 0.14)
    case .barbule:
      return SIMD4<Float>(0.006, 0.010, 0.017, 0.14)
    case .rachis:
      return rachisColor(record: record)
    }
  }

  static func decodedVertex(
    _ vertex: Int,
    topology: CrowBodyVaneTopology
  ) -> (axial: Int, width: Int) {
    let corners = [(0, 0), (0, 1), (1, 1), (0, 0), (1, 1), (1, 0)]
    let cell = vertex / 6
    let corner = corners[vertex % 6]
    return (
      cell / topology.widthSections + corner.0,
      cell % topology.widthSections + corner.1
    )
  }

  private static func record(
    current: CrowBodyFeatherTractSample,
    previous: CrowBodyFeatherTractSample,
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    currentDeployment: Float,
    previousDeployment: Float,
    inventoryIndex: Int
  ) -> CrowBodyVaneRecordGPU {
    let currentCamberScale = CrowBodyFeatherTracts.deploymentCamberScale(
      region: current.region,
      column: current.column,
      transitionProgress: currentDeployment
    )
    let previousCamberScale = CrowBodyFeatherTracts.deploymentCamberScale(
      region: previous.region,
      column: previous.column,
      transitionProgress: previousDeployment
    )
    let currentTransverse = CrowBodyFeatherTracts.transverseCamberRatio(
      region: current.region,
      row: current.row,
      transitionProgress: currentDeployment
    )
    let previousTransverse = CrowBodyFeatherTracts.transverseCamberRatio(
      region: previous.region,
      row: previous.row,
      transitionProgress: previousDeployment
    )
    let identityHash = stableHash(identity(of: current))
    return CrowBodyVaneRecordGPU(
      currentRootAndRootWidth: SIMD4<Float>(
        currentBodyCenter + current.rootOffset, current.rootWidthMeters
      ),
      currentTipAndMaximumWidth: SIMD4<Float>(
        currentBodyCenter + current.tipOffset, current.maximumWidthMeters
      ),
      previousRootAndCurrentCamber: SIMD4<Float>(
        previousBodyCenter + previous.rootOffset,
        current.camberMeters * currentCamberScale
      ),
      previousTipAndPreviousCamber: SIMD4<Float>(
        previousBodyCenter + previous.tipOffset,
        previous.camberMeters * previousCamberScale
      ),
      currentNormalAndTransverseCamber: SIMD4<Float>(
        current.planeNormal, currentTransverse
      ),
      previousNormalAndTransverseCamber: SIMD4<Float>(
        previous.planeNormal, previousTransverse
      ),
      sweepAsymmetryAndRipple: SIMD4<Float>(
        current.lateralSweepMeters,
        current.vaneAsymmetry,
        current.edgeRippleAmplitude,
        current.edgeRipplePhase
      ),
      envelopeAndTaper: SIMD4<Float>(
        current.edgeRippleCycles,
        current.rootEnvelopeRatio,
        current.terminalWidthRatio,
        current.distalTaperExponent
      ),
      color: color(for: current),
      morphology: SIMD4<Float>(
        current.pennaceousStartFraction,
        Float(current.region.rawValue),
        Float(current.row),
        Float(current.column)
      ),
      identity: SIMD4<UInt32>(
        0x0200_0000 | UInt32(inventoryIndex),
        identityHash,
        1,
        current.surfaceFeatherClass
      )
    )
  }

  private static func color(
    for sample: CrowBodyFeatherTractSample
  ) -> SIMD4<Float> {
    let material = sample.materialVariation
    switch sample.region {
    case .cervical:
      return SIMD4<Float>(
        0.006 * (1 + 0.07 * material), 0.009 * (1 + 0.05 * material),
        0.016 * (1 + 0.035 * material), 0.14
      )
    case .mantle:
      return SIMD4<Float>(
        0.0065 * (1 + 0.09 * material), 0.010 * (1 + 0.07 * material),
        0.018 * (1 + 0.045 * material), 0.16
      )
    case .humeral:
      return SIMD4<Float>(
        0.0058 * (1 + 0.080 * material), 0.0090 * (1 + 0.060 * material),
        0.0162 * (1 + 0.040 * material), 0.17
      )
    case .scapular:
      return SIMD4<Float>(
        0.0060 * (1 + 0.085 * material), 0.0094 * (1 + 0.065 * material),
        0.0170 * (1 + 0.042 * material), 0.18
      )
    }
  }

  private static func identity(
    of sample: CrowBodyFeatherTractSample
  ) -> SIMD4<UInt32> {
    SIMD4<UInt32>(
      UInt32(sample.region.rawValue),
      sample.side < 0 ? 0 : 1,
      UInt32(sample.row),
      UInt32(sample.column)
    )
  }

  private static func stableHash(_ identity: SIMD4<UInt32>) -> UInt32 {
    var value = identity.x &* 0xA511_E9B3
    value ^= identity.y &* 0x63D8_3595
    value ^= identity.z &* 0x9E37_79B9
    value ^= identity.w &* 0x85EB_CA6B
    value ^= value >> 16
    value &*= 0x7FEB_352D
    value ^= value >> 15
    return value == 0 ? 1 : value
  }
}

extension SIMD4 where Scalar == Float {
  fileprivate var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}

private func normalized(
  _ value: SIMD3<Float>,
  fallback: SIMD3<Float>
) -> SIMD3<Float> {
  let length = simd_length(value)
  return length > 1e-12 ? value / length : fallback
}
