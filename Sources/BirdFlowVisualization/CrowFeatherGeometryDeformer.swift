import Foundation
import Metal
import simd

struct CrowFeatherGeometryFrame {
  fileprivate let slot: Int
  fileprivate let readbackReady: Bool
  let outputBuffer: MTLBuffer
  let vertexCount: Int
}

/// Expands one retained canonical vane template for every persistent feather.
///
/// The output is a conventional triangle stream so the current renderer can
/// consume it directly. The compact template and root-state contract can also
/// feed mesh shaders or ray-tracing geometry without changing asset identity.
final class CrowFeatherGeometryDeformer {
  private static let bufferedFrameCount = 3
  private static let sectionCount = 12

  private let backend: VisualizationBackend
  private let pipeline: MTLComputePipelineState
  private let templateVertices: [CrowFeatherTemplateVertexGPU]
  private let templateBuffer: MTLBuffer
  private let outputBuffers: [MTLBuffer]
  private let readbackBuffers: [MTLBuffer]
  private var nextSlot = 0

  let featherCount: Int
  let vertexCount: Int

  init(backend: VisualizationBackend, featherCount: Int) throws {
    self.backend = backend
    self.featherCount = featherCount
    pipeline = try backend.compute("deformCrowFeatherTemplates")
    templateVertices = Self.makeTemplateVertices()
    templateBuffer = try Self.sharedBuffer(
      values: templateVertices,
      backend: backend
    )
    vertexCount = featherCount * templateVertices.count
    let outputBytes = MemoryLayout<CrowFeatherVertexGPU>.stride * vertexCount
    outputBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(length: outputBytes)
    }
    readbackBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(length: outputBytes, shared: true)
    }
  }

  func encode(
    rootFrame: CrowFeatherRootFrame,
    renderOffset: SIMD3<Float>,
    commandBuffer: MTLCommandBuffer,
    auditReadback: Bool = false
  ) throws -> CrowFeatherGeometryFrame {
    let slot = nextSlot
    nextSlot = (nextSlot + 1) % Self.bufferedFrameCount
    let output = outputBuffers[slot]
    var uniforms = CrowFeatherGeometryUniforms(
      counts: SIMD4<UInt32>(
        UInt32(featherCount),
        UInt32(templateVertices.count),
        UInt32(vertexCount),
        0
      ),
      renderOffsetAndPadding: SIMD4<Float>(renderOffset, 0)
    )
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow feather geometry compute encoder")
    }
    encoder.label = "Persistent crow feather-template deformation"
    encoder.setBuffer(templateBuffer, offset: 0, index: 0)
    encoder.setBuffer(rootFrame.outputBuffer, offset: 0, index: 1)
    encoder.setBuffer(output, offset: 0, index: 2)
    encoder.setBytes(
      &uniforms,
      length: MemoryLayout<CrowFeatherGeometryUniforms>.stride,
      index: 3
    )
    backend.dispatch1D(encoder, pipeline: pipeline, count: vertexCount)
    encoder.endEncoding()

    if auditReadback {
      guard let blit = commandBuffer.makeBlitCommandEncoder() else {
        throw VisualizationError.pipeline("crow feather geometry readback encoder")
      }
      blit.label = "Crow feather geometry audit readback"
      blit.copy(
        from: output,
        sourceOffset: 0,
        to: readbackBuffers[slot],
        destinationOffset: 0,
        size: MemoryLayout<CrowFeatherVertexGPU>.stride * vertexCount
      )
      blit.endEncoding()
    }
    return CrowFeatherGeometryFrame(
      slot: slot,
      readbackReady: auditReadback,
      outputBuffer: output,
      vertexCount: vertexCount
    )
  }

  func vertices(for frame: CrowFeatherGeometryFrame) -> [CrowFeatherVertexGPU] {
    precondition(frame.readbackReady, "feather geometry was not encoded for readback")
    let pointer = readbackBuffers[frame.slot].contents().bindMemory(
      to: CrowFeatherVertexGPU.self,
      capacity: vertexCount
    )
    return Array(UnsafeBufferPointer(start: pointer, count: vertexCount))
  }

  func referenceVertices(
    roots: [CrowFeatherRootStateGPU],
    renderOffset: SIMD3<Float>
  ) -> [CrowFeatherVertexGPU] {
    roots.flatMap { root in
      templateVertices.map { template in
        let axial = template.parameters.x
        let signedWidth = template.parameters.y
        let currentDirection = Self.xyz(root.currentDirectionAndRachis)
        let previousDirection = Self.xyz(root.previousDirectionAndCamber)
        let currentNormal = Self.xyz(root.currentNormalAndPadding)
        let previousNormal = Self.xyz(root.previousNormalAndPadding)
        let lengthMeters = root.currentPositionAndLength.w
        let maximumWidthMeters = root.previousPositionAndWidth.w
        let camberMeters = root.previousDirectionAndCamber.w
        let featherClass = root.identity.w & 255
        let material: Float =
          featherClass == 1 ? 0.25 : (featherClass == 2 ? 0.22 : 0.23)
        let shade = 0.0075 + 0.00045 * Float(root.identity.x % 11)
        return CrowFeatherVertexGPU(
          position: SIMD4<Float>(
            Self.position(
              root: Self.xyz(root.currentPositionAndLength),
              direction: currentDirection,
              surfaceNormal: currentNormal,
              lengthMeters: lengthMeters,
              maximumWidthMeters: maximumWidthMeters,
              camberMeters: camberMeters,
              axial: axial,
              signedWidth: signedWidth
            ) + renderOffset,
            1
          ),
          normal: SIMD4<Float>(currentNormal, 0),
          color: SIMD4<Float>(shade, shade * 1.28, shade * 1.72, material),
          previousPosition: SIMD4<Float>(
            Self.position(
              root: Self.xyz(root.previousPositionAndWidth),
              direction: previousDirection,
              surfaceNormal: previousNormal,
              lengthMeters: lengthMeters,
              maximumWidthMeters: maximumWidthMeters,
              camberMeters: camberMeters,
              axial: axial,
              signedWidth: signedWidth
            ) + renderOffset,
            1
          ),
          identity: root.identity,
          parameters: SIMD4<Float>(axial, signedWidth, Float(featherClass), 0)
        )
      }
    }
  }

  private static func makeTemplateVertices() -> [CrowFeatherTemplateVertexGPU] {
    var result: [CrowFeatherTemplateVertexGPU] = []
    result.reserveCapacity(sectionCount * 6)
    for section in 0..<sectionCount {
      let first = Float(section) / Float(sectionCount)
      let second = Float(section + 1) / Float(sectionCount)
      for parameter in [
        SIMD2<Float>(first, -1),
        SIMD2<Float>(first, 1),
        SIMD2<Float>(second, 1),
        SIMD2<Float>(first, -1),
        SIMD2<Float>(second, 1),
        SIMD2<Float>(second, -1),
      ] {
        result.append(
          CrowFeatherTemplateVertexGPU(
            parameters: SIMD4<Float>(parameter.x, parameter.y, 0, 0)
          )
        )
      }
    }
    return result
  }

  private static func position(
    root: SIMD3<Float>,
    direction: SIMD3<Float>,
    surfaceNormal: SIMD3<Float>,
    lengthMeters: Float,
    maximumWidthMeters: Float,
    camberMeters: Float,
    axial: Float,
    signedWidth: Float
  ) -> SIMD3<Float> {
    let widthAxis = safeNormalize(
      simd_cross(surfaceNormal, direction),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    let bodyEnvelope = 0.32 + 0.68 * pow(max(sin(Float.pi * axial), 0), 0.58)
    let tipTaper = 1 - 0.985 * pow(axial, 3.2)
    let width =
      (0.55 * maximumWidthMeters * (1 - axial)
        + maximumWidthMeters * axial) * bodyEnvelope * tipTaper
    let center =
      root + direction * (lengthMeters * axial)
      + surfaceNormal * (camberMeters * sin(Float.pi * axial))
    return center + widthAxis * (signedWidth * width)
  }

  private static func safeNormalize(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let magnitude = simd_length(value)
    return magnitude > 1e-12 ? value / magnitude : fallback
  }

  private static func xyz(_ value: SIMD4<Float>) -> SIMD3<Float> {
    SIMD3<Float>(value.x, value.y, value.z)
  }

  private static func sharedBuffer<T>(
    values: [T],
    backend: VisualizationBackend
  ) throws -> MTLBuffer {
    let length = MemoryLayout<T>.stride * values.count
    let buffer = try backend.buffer(length: length, shared: true)
    values.withUnsafeBytes { bytes in
      guard let baseAddress = bytes.baseAddress else { return }
      memcpy(buffer.contents(), baseAddress, bytes.count)
    }
    return buffer
  }
}
