import Metal
import simd

/// Input for a probe ray over the experimental retained-feather structure.
/// The w components are the near and far intersection distances in meters.
struct CrowRayProbeInputGPU: Equatable {
  var originAndMinimumDistance: SIMD4<Float>
  var directionAndMaximumDistance: SIMD4<Float>
}

/// Readback-only result from `probeCrowRayGeometry`.
struct CrowRayProbeResultGPU: Equatable {
  var hit: UInt32
  var primitiveIndex: UInt32
  var distance: Float
  var reserved: Float
}

/// Binds an already-built retained curve-ribbon acceleration structure to a
/// compute intersector. This is an AOV probe utility, not a renderer visibility
/// path: the result never changes crow beauty, depth, motion, or identity.
final class CrowPlumageRayGeometryProbe {
  private let backend: VisualizationBackend
  private let pipeline: MTLComputePipelineState

  init(backend: VisualizationBackend) throws {
    self.backend = backend
    pipeline = try backend.compute("probeCrowRayGeometry")
  }

  func encode(
    build: CrowPlumageRayGeometryBuild,
    rays: [CrowRayProbeInputGPU],
    commandBuffer: MTLCommandBuffer
  ) throws -> MTLBuffer {
    guard !rays.isEmpty else { throw VisualizationError.allocation(0) }
    let inputs = try Self.sharedBuffer(values: rays, backend: backend)
    let results = try backend.buffer(
      length: rays.count * MemoryLayout<CrowRayProbeResultGPU>.stride,
      shared: true
    )
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow ray geometry probe")
    }
    encoder.label = "Experimental retained crow curve-ribbon ray probe"
    encoder.setBuffer(inputs, offset: 0, index: 0)
    encoder.setBuffer(results, offset: 0, index: 1)
    encoder.setAccelerationStructure(build.accelerationStructure, bufferIndex: 2)
    backend.dispatch1D(encoder, pipeline: pipeline, count: rays.count)
    encoder.endEncoding()
    return results
  }

  static func results(
    from buffer: MTLBuffer,
    count: Int
  ) -> [CrowRayProbeResultGPU] {
    let pointer = buffer.contents().bindMemory(
      to: CrowRayProbeResultGPU.self,
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
