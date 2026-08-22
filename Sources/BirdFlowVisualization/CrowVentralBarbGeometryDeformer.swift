import Metal
import simd

/// Future-compute expansion of explicit class-7 body-feather barb curves.
///
/// Production allocates only a tiny dormant output buffer at ordinary viewing
/// distances. Once a retained feather spans at least 480 output pixels, a
/// compact interval list activates four-segment crown-following curves and
/// Metal writes the complete temporal/AOV tube stream.
final class CrowVentralBarbGeometryDeformer {
  private static let bufferedFrameCount = 3

  private let backend: VisualizationBackend
  private let pipeline: MTLComputePipelineState
  private let records: [CrowVentralRachisCurveRecordGPU]
  private let recordBuffer: MTLBuffer
  private let workBuffers: [MTLBuffer]
  private var outputBuffers: [MTLBuffer]
  private let indirectDrawBuffers: [MTLBuffer]
  private var readbackBuffers: [MTLBuffer?]
  private var nextSlot = 0

  let curveCount: Int

  init(
    backend: VisualizationBackend,
    records: [CrowVentralRachisCurveRecordGPU] = CrowVentralRachisCurveRecords.records()
  ) throws {
    self.backend = backend
    self.records = records
    pipeline = try backend.compute("expandCrowVentralBarbCurves")
    curveCount = records.count
    recordBuffer = try Self.sharedBuffer(values: records, backend: backend)
    let maximumWorkCount =
      records.count
      * CrowVentralBarbCurveRecords.maximumBarbPairCount * 2
      * CrowVentralBarbCurveRecords.intervalCount
    workBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(
        length: max(
          maximumWorkCount
            * MemoryLayout<CrowVentralBarbSegmentWorkGPU>.stride,
          16
        ),
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
    readbackBuffers = Array(repeating: nil, count: Self.bufferedFrameCount)
  }

  func encode(
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    projectedPixelsPerMeter: Float,
    commandBuffer: MTLCommandBuffer,
    auditReadback: Bool = false
  ) throws -> CrowFeatherGeometryFrame {
    let slot = nextSlot
    nextSlot = (nextSlot + 1) % Self.bufferedFrameCount
    let work = CrowVentralBarbCurveRecords.segmentWork(
      records: records,
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
    let workBuffer = workBuffers[slot]
    work.withUnsafeBytes { bytes in
      if let baseAddress = bytes.baseAddress, !bytes.isEmpty {
        memcpy(workBuffer.contents(), baseAddress, bytes.count)
      }
    }
    let vertexCount =
      work.count
      * CrowVentralBarbCurveRecords.verticesPerCurveInterval
    let requiredOutputBytes = max(
      vertexCount * MemoryLayout<CrowFeatherVertexGPU>.stride,
      16
    )
    if requiredOutputBytes > outputBuffers[slot].length {
      outputBuffers[slot] = try backend.buffer(length: requiredOutputBytes)
    }
    let drawArguments = DrawPrimitivesIndirectArguments(
      vertexCount: UInt32(vertexCount),
      instanceCount: 1,
      vertexStart: 0,
      baseInstance: 0
    )
    _ = withUnsafeBytes(of: drawArguments) { bytes in
      memcpy(
        indirectDrawBuffers[slot].contents(),
        bytes.baseAddress!,
        bytes.count
      )
    }
    var uniforms = CrowVentralBarbGeometryUniforms(
      counts: SIMD4<UInt32>(
        UInt32(records.count),
        UInt32(work.count),
        UInt32(CrowVentralBarbCurveRecords.verticesPerCurveInterval),
        CrowVentralBarbCurveRecords.surfaceFeatherClass
      ),
      currentBodyCenter: SIMD4<Float>(currentBodyCenter, 1),
      previousBodyCenter: SIMD4<Float>(previousBodyCenter, 1)
    )
    if vertexCount > 0 {
      guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
        throw VisualizationError.pipeline("crow ventral barb geometry encoder")
      }
      encoder.label = "Retained ventral barb curve expansion"
      encoder.setBuffer(recordBuffer, offset: 0, index: 0)
      encoder.setBuffer(workBuffer, offset: 0, index: 1)
      encoder.setBuffer(outputBuffers[slot], offset: 0, index: 2)
      encoder.setBytes(
        &uniforms,
        length: MemoryLayout<CrowVentralBarbGeometryUniforms>.stride,
        index: 3
      )
      backend.dispatch1D(encoder, pipeline: pipeline, count: vertexCount)
      encoder.endEncoding()
    }
    if auditReadback && vertexCount > 0 {
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
        size: vertexCount * MemoryLayout<CrowFeatherVertexGPU>.stride
      )
      blit.endEncoding()
    }
    return CrowFeatherGeometryFrame(
      slot: slot,
      readbackReady: auditReadback,
      outputBuffer: outputBuffers[slot],
      indirectDrawBuffer: indirectDrawBuffers[slot],
      vertexCount: vertexCount
    )
  }

  func vertices(for frame: CrowFeatherGeometryFrame) -> [CrowFeatherVertexGPU] {
    precondition(frame.readbackReady, "ventral barb geometry lacks readback")
    guard let readback = readbackBuffers[frame.slot] else {
      preconditionFailure("ventral barb audit buffer is unavailable")
    }
    let pointer = readback.contents().bindMemory(
      to: CrowFeatherVertexGPU.self,
      capacity: frame.vertexCount
    )
    return Array(UnsafeBufferPointer(start: pointer, count: frame.vertexCount))
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
