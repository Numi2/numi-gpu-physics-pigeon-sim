import Metal
import simd

/// Per-ray diagnostic output for the future full-image retained-plumage audit.
/// This is deliberately separate from beauty/AOV resources: it carries only
/// acceleration-structure visibility evidence and never drives rendering.
struct CrowRayImageAuditResultGPU: Equatable {
  var hit: UInt32
  var primitiveIndex: UInt32
  var distance: Float
  var reserved: Float
  var identity: SIMD4<UInt32>
}

/// Compute-only image-audit query over the exact retained curve-ribbon buffer.
/// Callers provide one camera ray per diagnostic pixel; production raster
/// visibility remains authoritative regardless of the results.
final class CrowPlumageRayImageAudit {
  private let backend: VisualizationBackend
  private let pipeline: MTLComputePipelineState

  init(backend: VisualizationBackend) throws {
    self.backend = backend
    pipeline = try backend.compute("auditCrowRayImageGeometry")
  }

  func encode(
    build: CrowPlumageRayGeometryBuild,
    rays: [CrowRayProbeInputGPU],
    vertices: MTLBuffer,
    commandBuffer: MTLCommandBuffer
  ) throws -> MTLBuffer {
    guard !rays.isEmpty else { throw VisualizationError.allocation(0) }
    let inputs = try Self.sharedBuffer(values: rays, backend: backend)
    let results = try backend.buffer(
      length: rays.count * MemoryLayout<CrowRayImageAuditResultGPU>.stride,
      shared: true
    )
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow full-image ray audit")
    }
    encoder.label = "Diagnostic retained crow curve-ribbon image audit"
    encoder.setBuffer(inputs, offset: 0, index: 0)
    encoder.setBuffer(results, offset: 0, index: 1)
    encoder.setAccelerationStructure(build.accelerationStructure, bufferIndex: 2)
    encoder.setBuffer(vertices, offset: 0, index: 3)
    backend.dispatch1D(encoder, pipeline: pipeline, count: rays.count)
    encoder.endEncoding()
    return results
  }

  static func results(
    from buffer: MTLBuffer,
    count: Int
  ) -> [CrowRayImageAuditResultGPU] {
    let pointer = buffer.contents().bindMemory(
      to: CrowRayImageAuditResultGPU.self,
      capacity: count
    )
    return Array(UnsafeBufferPointer(start: pointer, count: count))
  }

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
