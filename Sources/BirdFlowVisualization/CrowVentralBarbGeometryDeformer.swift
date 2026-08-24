import Metal
import simd

/// GPU-compacted explicit class-7 body-feather barb curves.
///
/// Once a retained feather spans at least 40 output pixels, a compact interval
/// list activates ten paired four-segment crown-following curves; the existing
/// 480-pixel tier promotes that record to 72 pairs. The production raster stage
/// pulls those vertices directly; compute expansion is retained only as an
/// exact audit oracle.
final class CrowVentralBarbGeometryDeformer {
  private static let bufferedFrameCount = 3

  private let backend: VisualizationBackend
  private let classifyPipeline: MTLComputePipelineState
  private let scanPipeline: MTLComputePipelineState
  private let emitPipeline: MTLComputePipelineState
  private let indirectPipeline: MTLComputePipelineState
  private let pipeline: MTLComputePipelineState
  private let records: [CrowVentralRachisCurveRecordGPU]
  private let recordBuffer: MTLBuffer
  private let fallbackDepthTexture: MTLTexture
  private let selectedBuffers: [MTLBuffer]
  private let offsetBuffers: [MTLBuffer]
  private let compactedCountBuffers: [MTLBuffer]
  private var workBuffers: [MTLBuffer]
  private let geometryUniformBuffers: [MTLBuffer]
  private var outputBuffers: [MTLBuffer]
  private let indirectDrawBuffers: [MTLBuffer]
  private let indirectDispatchBuffers: [MTLBuffer]
  private let indirectMeshDispatchBuffers: [MTLBuffer]
  private var readbackBuffers: [MTLBuffer?]
  private var nextSlot = 0

  let curveCount: Int

  func candidateRecordCount(projectedPixelsPerMeter: Float) -> Int {
    CrowVentralBarbCurveRecords.activeRecordIndices(
      records: records,
      projectedPixelsPerMeter: projectedPixelsPerMeter
    ).count
  }

  func candidateCloseRecordCount(projectedPixelsPerMeter: Float) -> Int {
    CrowVentralBarbCurveRecords.activeCloseRecordIndices(
      records: records,
      projectedPixelsPerMeter: projectedPixelsPerMeter
    ).count
  }

  func candidateBarbuleRecordCount(projectedPixelsPerMeter: Float) -> Int {
    CrowVentralBarbCurveRecords.activeBarbuleRecordIndices(
      records: records,
      projectedPixelsPerMeter: projectedPixelsPerMeter
    ).count
  }

  init(
    backend: VisualizationBackend,
    records: [CrowVentralRachisCurveRecordGPU] = CrowVentralRachisCurveRecords.records()
  ) throws {
    self.backend = backend
    self.records = records
    classifyPipeline = try backend.compute("classifyCrowVentralBarbRecords")
    scanPipeline = try backend.compute("scanCrowVentralBarbRecordVisibility")
    emitPipeline = try backend.compute("emitCrowVentralBarbWork")
    indirectPipeline = try backend.compute("prepareCrowVentralBarbIndirectWork")
    pipeline = try backend.compute("expandCrowVentralBarbCurves")
    curveCount = records.count
    recordBuffer = try Self.sharedBuffer(values: records, backend: backend)
    let fallbackDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .r32Float,
      width: 1,
      height: 1,
      mipmapped: false
    )
    fallbackDescriptor.storageMode = .shared
    fallbackDescriptor.usage = .shaderRead
    guard
      let fallbackDepthTexture = backend.device.makeTexture(
        descriptor: fallbackDescriptor
      )
    else {
      throw VisualizationError.allocation(MemoryLayout<Float>.stride)
    }
    var clearDepth: Float = 1
    fallbackDepthTexture.replace(
      region: MTLRegionMake2D(0, 0, 1, 1),
      mipmapLevel: 0,
      withBytes: &clearDepth,
      bytesPerRow: MemoryLayout<Float>.stride
    )
    self.fallbackDepthTexture = fallbackDepthTexture
    selectedBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(
        length: max(records.count * MemoryLayout<UInt32>.stride, 16),
        shared: true
      )
    }
    offsetBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(
        length: max(records.count * MemoryLayout<UInt32>.stride, 16),
        shared: true
      )
    }
    compactedCountBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(
        length: MemoryLayout<CrowVentralBarbVisibilityCounts>.stride,
        shared: true
      )
    }
    workBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(length: 16, shared: true)
    }
    geometryUniformBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(
        length: MemoryLayout<CrowVentralBarbGeometryUniforms>.stride,
        shared: true
      )
    }
    outputBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(length: 16)
    }
    indirectDrawBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(
        length: MemoryLayout<DrawPrimitivesIndirectArguments>.stride,
        shared: true
      )
    }
    indirectDispatchBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(length: 3 * MemoryLayout<UInt32>.stride, shared: true)
    }
    indirectMeshDispatchBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(length: 3 * MemoryLayout<UInt32>.stride, shared: true)
    }
    readbackBuffers = Array(repeating: nil, count: Self.bufferedFrameCount)
  }

  func encode(
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    projectedPixelsPerMeter: Float,
    viewProjection: simd_float4x4,
    previousViewProjection: simd_float4x4 = matrix_identity_float4x4,
    previousDepthPyramid: MTLTexture? = nil,
    occlusionViewport: SIMD2<Int> = .zero,
    commandBuffer: MTLCommandBuffer,
    auditReadback: Bool = false,
    rayGeometryStaging: Bool = false
  ) throws -> CrowFeatherGeometryFrame {
    let slot = nextSlot
    nextSlot = (nextSlot + 1) % Self.bufferedFrameCount
    let candidateBarbuleRecordCount = candidateBarbuleRecordCount(
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
    let barbWorkCount = CrowVentralBarbCurveRecords.candidateBarbWorkCount(
      records: records,
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
    let barbuleWorkCount =
      candidateBarbuleRecordCount
      * CrowVentralBarbCurveRecords.maximumBarbPairCount * 2
      * CrowVentralBarbCurveRecords.barbuleBranchCount
      * CrowVentralBarbCurveRecords.explicitBarbulesPerBranch
    let maximumWorkCount = barbWorkCount + barbuleWorkCount
    let maximumVertexCount =
      maximumWorkCount
      * CrowVentralBarbCurveRecords.verticesPerCurveInterval
    let requiredWorkBytes = max(
      maximumWorkCount * MemoryLayout<CrowVentralBarbSegmentWorkGPU>.stride,
      16
    )
    if requiredWorkBytes > workBuffers[slot].length {
      workBuffers[slot] = try backend.buffer(
        length: requiredWorkBytes,
        shared: true
      )
    }
    let requiredOutputBytes = max(
      maximumVertexCount * MemoryLayout<CrowFeatherVertexGPU>.stride,
      16
    )
    if (auditReadback || rayGeometryStaging)
      && requiredOutputBytes > outputBuffers[slot].length
    {
      outputBuffers[slot] = try backend.buffer(length: requiredOutputBytes)
    }
    let emptyDrawArguments = DrawPrimitivesIndirectArguments(
      vertexCount: 0,
      instanceCount: 1,
      vertexStart: 0,
      baseInstance: 0
    )
    _ = withUnsafeBytes(of: emptyDrawArguments) { bytes in
      memcpy(
        indirectDrawBuffers[slot].contents(),
        bytes.baseAddress!,
        bytes.count
      )
    }
    memset(
      indirectMeshDispatchBuffers[slot].contents(),
      0,
      3 * MemoryLayout<UInt32>.stride
    )
    memset(
      compactedCountBuffers[slot].contents(),
      0,
      MemoryLayout<CrowVentralBarbVisibilityCounts>.stride
    )
    var uniforms = CrowVentralBarbGeometryUniforms(
      counts: SIMD4<UInt32>(
        UInt32(records.count),
        UInt32(maximumWorkCount),
        UInt32(CrowVentralBarbCurveRecords.verticesPerCurveInterval),
        CrowVentralBarbCurveRecords.surfaceFeatherClass
      ),
      currentBodyCenter: SIMD4<Float>(currentBodyCenter, 1),
      previousBodyCenter: SIMD4<Float>(previousBodyCenter, 1)
    )
    _ = withUnsafeBytes(of: uniforms) { bytes in
      memcpy(
        geometryUniformBuffers[slot].contents(),
        bytes.baseAddress!,
        bytes.count
      )
    }
    var visibilityUniforms = CrowVentralBarbCurveRecords.visibilityUniforms(
      viewProjection: viewProjection,
      currentBodyCenter: currentBodyCenter,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      recordCount: records.count,
      previousViewProjection: previousViewProjection,
      occlusionViewport: occlusionViewport,
      occlusionEnabled: previousDepthPyramid != nil
    )
    var threadsPerThreadgroup = UInt32(
      min(pipeline.maxTotalThreadsPerThreadgroup, pipeline.threadExecutionWidth)
    )
    if maximumVertexCount > 0 {
      guard let classify = commandBuffer.makeComputeCommandEncoder() else {
        throw VisualizationError.pipeline("crow ventral barb visibility encoder")
      }
      classify.label = "Classify retained ventral barb records"
      classify.setBuffer(recordBuffer, offset: 0, index: 0)
      classify.setBuffer(selectedBuffers[slot], offset: 0, index: 1)
      classify.setTexture(previousDepthPyramid ?? fallbackDepthTexture, index: 0)
      classify.setBytes(
        &visibilityUniforms,
        length: MemoryLayout<CrowVentralBarbVisibilityUniforms>.stride,
        index: 2
      )
      backend.dispatch1D(classify, pipeline: classifyPipeline, count: records.count)
      classify.endEncoding()

      guard let scan = commandBuffer.makeComputeCommandEncoder() else {
        throw VisualizationError.pipeline("crow ventral barb visibility scan")
      }
      scan.label = "Scan retained ventral barb visibility"
      scan.setBuffer(selectedBuffers[slot], offset: 0, index: 0)
      scan.setBuffer(offsetBuffers[slot], offset: 0, index: 1)
      scan.setBuffer(compactedCountBuffers[slot], offset: 0, index: 2)
      scan.setBytes(
        &visibilityUniforms,
        length: MemoryLayout<CrowVentralBarbVisibilityUniforms>.stride,
        index: 3
      )
      backend.dispatch1D(scan, pipeline: scanPipeline, count: 1)
      scan.endEncoding()

      guard let emit = commandBuffer.makeComputeCommandEncoder() else {
        throw VisualizationError.pipeline("crow ventral barb compact work encoder")
      }
      emit.label = "Emit compact retained ventral barb work"
      emit.setBuffer(selectedBuffers[slot], offset: 0, index: 0)
      emit.setBuffer(offsetBuffers[slot], offset: 0, index: 1)
      emit.setBuffer(workBuffers[slot], offset: 0, index: 2)
      emit.setBytes(
        &visibilityUniforms,
        length: MemoryLayout<CrowVentralBarbVisibilityUniforms>.stride,
        index: 3
      )
      backend.dispatch1D(emit, pipeline: emitPipeline, count: records.count)
      emit.endEncoding()

      guard let prepare = commandBuffer.makeComputeCommandEncoder() else {
        throw VisualizationError.pipeline("crow ventral barb indirect-work encoder")
      }
      prepare.label = "Prepare compact ventral barb indirect work"
      prepare.setBuffer(compactedCountBuffers[slot], offset: 0, index: 0)
      prepare.setBuffer(indirectDrawBuffers[slot], offset: 0, index: 1)
      prepare.setBuffer(indirectDispatchBuffers[slot], offset: 0, index: 2)
      prepare.setBytes(
        &visibilityUniforms,
        length: MemoryLayout<CrowVentralBarbVisibilityUniforms>.stride,
        index: 3
      )
      prepare.setBytes(
        &threadsPerThreadgroup,
        length: MemoryLayout<UInt32>.stride,
        index: 4
      )
      prepare.setBuffer(indirectMeshDispatchBuffers[slot], offset: 0, index: 5)
      backend.dispatch1D(prepare, pipeline: indirectPipeline, count: 1)
      prepare.endEncoding()

      if auditReadback || rayGeometryStaging {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
          throw VisualizationError.pipeline("crow ventral barb geometry encoder")
        }
        encoder.label = auditReadback
          ? "Audit retained ventral barb curve expansion"
          : "Stage retained ventral barb curve ribbons for ray audit"
        encoder.setBuffer(recordBuffer, offset: 0, index: 0)
        encoder.setBuffer(workBuffers[slot], offset: 0, index: 1)
        encoder.setBuffer(outputBuffers[slot], offset: 0, index: 2)
        encoder.setBytes(
          &uniforms,
          length: MemoryLayout<CrowVentralBarbGeometryUniforms>.stride,
          index: 3
        )
        encoder.setComputePipelineState(pipeline)
        encoder.dispatchThreadgroups(
          indirectBuffer: indirectDispatchBuffers[slot],
          indirectBufferOffset: 0,
          threadsPerThreadgroup: MTLSize(
            width: Int(threadsPerThreadgroup),
            height: 1,
            depth: 1
          )
        )
        encoder.endEncoding()
      }
    }
    if auditReadback && maximumVertexCount > 0 {
      let readback: MTLBuffer
      if let existing = readbackBuffers[slot],
        existing.length >= requiredOutputBytes
      {
        readback = existing
      } else {
        let created = try backend.buffer(
          length: requiredOutputBytes,
          shared: true
        )
        readbackBuffers[slot] = created
        readback = created
      }
      guard let blit = commandBuffer.makeBlitCommandEncoder() else {
        throw VisualizationError.pipeline("crow ventral barb audit readback")
      }
      blit.copy(
        from: outputBuffers[slot],
        sourceOffset: 0,
        to: readback,
        destinationOffset: 0,
        size: maximumVertexCount * MemoryLayout<CrowFeatherVertexGPU>.stride
      )
      blit.endEncoding()
    }
    return CrowFeatherGeometryFrame(
      slot: slot,
      readbackReady: auditReadback,
      outputBuffer: outputBuffers[slot],
      indirectDrawBuffer: indirectDrawBuffers[slot],
      indirectMeshDispatchBuffer: indirectMeshDispatchBuffers[slot],
      vertexCount: maximumVertexCount
    )
  }

  func drawArguments(
    for frame: CrowFeatherGeometryFrame
  ) -> DrawPrimitivesIndirectArguments {
    frame.indirectDrawBuffer.contents().bindMemory(
      to: DrawPrimitivesIndirectArguments.self,
      capacity: 1
    ).pointee
  }

  func meshDispatchDimensions(
    for frame: CrowFeatherGeometryFrame
  ) -> SIMD3<UInt32> {
    guard let buffer = frame.indirectMeshDispatchBuffer else { return .zero }
    let values = buffer.contents().bindMemory(to: UInt32.self, capacity: 3)
    return SIMD3<UInt32>(values[0], values[1], values[2])
  }

  /// Binds the GPU-resident compact work and stable procedural inputs. Camera
  /// uniforms intentionally occupy index 3 in the specialized vertex stage.
  func bindRenderResources(
    for frame: CrowFeatherGeometryFrame,
    encoder: MTLRenderCommandEncoder
  ) {
    encoder.setVertexBuffer(recordBuffer, offset: 0, index: 0)
    encoder.setVertexBuffer(workBuffers[frame.slot], offset: 0, index: 1)
    encoder.setVertexBuffer(
      geometryUniformBuffers[frame.slot],
      offset: 0,
      index: 2
    )
  }

  /// Mesh stages have independent resource tables from vertex stages.
  func bindMeshRenderResources(
    for frame: CrowFeatherGeometryFrame,
    encoder: MTLRenderCommandEncoder
  ) {
    encoder.setMeshBuffer(recordBuffer, offset: 0, index: 0)
    encoder.setMeshBuffer(workBuffers[frame.slot], offset: 0, index: 1)
    encoder.setMeshBuffer(
      geometryUniformBuffers[frame.slot],
      offset: 0,
      index: 2
    )
    encoder.setMeshBuffer(
      compactedCountBuffers[frame.slot],
      offset: 0,
      index: 4
    )
  }

  func compactedRecordCount(for frame: CrowFeatherGeometryFrame) -> Int {
    Int(visibilityCounts(for: frame).postOcclusionVisible)
  }

  func visibilityCounts(
    for frame: CrowFeatherGeometryFrame
  ) -> CrowVentralBarbVisibilityCounts {
    compactedCountBuffers[frame.slot].contents().bindMemory(
      to: CrowVentralBarbVisibilityCounts.self,
      capacity: 1
    ).pointee
  }

  func segmentWork(
    for frame: CrowFeatherGeometryFrame
  ) -> [CrowVentralBarbSegmentWorkGPU] {
    let count = Int(visibilityCounts(for: frame).emittedWorkCount)
    let pointer = workBuffers[frame.slot].contents().bindMemory(
      to: CrowVentralBarbSegmentWorkGPU.self,
      capacity: count
    )
    return Array(UnsafeBufferPointer(start: pointer, count: count))
  }

  func vertices(for frame: CrowFeatherGeometryFrame) -> [CrowFeatherVertexGPU] {
    precondition(frame.readbackReady, "ventral barb geometry lacks readback")
    let actualVertexCount = Int(drawArguments(for: frame).vertexCount)
    guard actualVertexCount > 0 else { return [] }
    guard let readback = readbackBuffers[frame.slot] else {
      preconditionFailure("ventral barb audit buffer is unavailable")
    }
    let pointer = readback.contents().bindMemory(
      to: CrowFeatherVertexGPU.self,
      capacity: actualVertexCount
    )
    return Array(UnsafeBufferPointer(start: pointer, count: actualVertexCount))
  }

  func recordsForTesting() -> [CrowVentralRachisCurveRecordGPU] { records }

  private static func sharedBuffer<T>(
    values: [T],
    backend: VisualizationBackend
  ) throws -> MTLBuffer {
    let buffer = try backend.buffer(
      length: max(values.count * MemoryLayout<T>.stride, 16),
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
