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
  private static let sectionCount = 24
  private static let widthSectionCount = 6

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
        let packedIdentity = root.identity.w
        let featherClass = packedIdentity & 255
        let material: Float =
          featherClass == 1 ? 0.25 : (featherClass == 2 ? 0.22 : 0.23)
        let shade = 0.0075 + 0.00045 * Float(root.identity.x % 11)
        let currentRoot = Self.xyz(root.currentPositionAndLength)
        let previousRoot = Self.xyz(root.previousPositionAndWidth)
        return CrowFeatherVertexGPU(
          position: SIMD4<Float>(
            Self.position(
              root: currentRoot,
              direction: currentDirection,
              surfaceNormal: currentNormal,
              lengthMeters: lengthMeters,
              maximumWidthMeters: maximumWidthMeters,
              camberMeters: camberMeters,
              axial: axial,
              signedWidth: signedWidth,
              packedIdentity: packedIdentity
            ) + renderOffset,
            1
          ),
          normal: SIMD4<Float>(
            Self.normal(
              direction: currentDirection,
              surfaceNormal: currentNormal,
              lengthMeters: lengthMeters,
              maximumWidthMeters: maximumWidthMeters,
              camberMeters: camberMeters,
              axial: axial,
              signedWidth: signedWidth,
              packedIdentity: packedIdentity
            ),
            0
          ),
          color: SIMD4<Float>(shade, shade * 1.28, shade * 1.72, material),
          previousPosition: SIMD4<Float>(
            Self.position(
              root: previousRoot,
              direction: previousDirection,
              surfaceNormal: previousNormal,
              lengthMeters: lengthMeters,
              maximumWidthMeters: maximumWidthMeters,
              camberMeters: camberMeters,
              axial: axial,
              signedWidth: signedWidth,
              packedIdentity: packedIdentity
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
    result.reserveCapacity(sectionCount * widthSectionCount * 6)
    for section in 0..<sectionCount {
      let first = Float(section) / Float(sectionCount)
      let second = Float(section + 1) / Float(sectionCount)
      for widthSection in 0..<widthSectionCount {
        let left = -1 + 2 * Float(widthSection) / Float(widthSectionCount)
        let right = -1 + 2 * Float(widthSection + 1) / Float(widthSectionCount)
        for parameter in [
          SIMD2<Float>(first, left),
          SIMD2<Float>(first, right),
          SIMD2<Float>(second, right),
          SIMD2<Float>(first, left),
          SIMD2<Float>(second, right),
          SIMD2<Float>(second, left),
        ] {
          result.append(
            CrowFeatherTemplateVertexGPU(
              parameters: SIMD4<Float>(parameter.x, parameter.y, 0, 0)
            )
          )
        }
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
    signedWidth: Float,
    packedIdentity: UInt32
  ) -> SIMD3<Float> {
    let tangent = safeNormalize(direction, fallback: SIMD3<Float>(1, 0, 0))
    let orthogonalNormal = safeNormalize(
      surfaceNormal - tangent * simd_dot(surfaceNormal, tangent),
      fallback: surfaceNormal
    )
    let widthAxis = safeNormalize(
      simd_cross(orthogonalNormal, tangent),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    let bodyEnvelope = 0.32 + 0.68 * pow(max(sin(Float.pi * axial), 0), 0.58)
    let tipTaper = 1 - 0.985 * pow(axial, 3.2)
    let baseWidth =
      (0.55 * maximumWidthMeters * (1 - axial)
        + maximumWidthMeters * axial) * bodyEnvelope * tipTaper
    let rectrix = CrowRectrixVaneAnatomy.profile(packedIdentity: packedIdentity)
    let sideScale =
      1
      - (rectrix?.vaneAsymmetry ?? 0) * signedWidth
      * (rectrix?.outerSignedWidth ?? 0)
    let width = baseWidth * sideScale
    let camberEnvelope =
      rectrix.map {
        CrowRectrixVaneAnatomy.camberEnvelope(axial: axial, profile: $0)
      } ?? sin(Float.pi * axial)
    let center =
      root + tangent * (lengthMeters * axial)
      + orthogonalNormal * (camberMeters * camberEnvelope)
    let transverseEnvelope = max(0, 1 - signedWidth * signedWidth)
    let crownEnvelope = pow(max(sin(Float.pi * axial), 0), 0.65)
    let crown =
      crownRatio(packedIdentity: packedIdentity) * width
      * transverseEnvelope * crownEnvelope
    return center + widthAxis * (signedWidth * width) + orthogonalNormal * crown
  }

  private static func normal(
    direction: SIMD3<Float>,
    surfaceNormal: SIMD3<Float>,
    lengthMeters: Float,
    maximumWidthMeters: Float,
    camberMeters: Float,
    axial: Float,
    signedWidth: Float,
    packedIdentity: UInt32
  ) -> SIMD3<Float> {
    let tangent = safeNormalize(direction, fallback: SIMD3<Float>(1, 0, 0))
    let orthogonalNormal = safeNormalize(
      surfaceNormal - tangent * simd_dot(surfaceNormal, tangent),
      fallback: surfaceNormal
    )
    let widthAxis = safeNormalize(
      simd_cross(orthogonalNormal, tangent),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    let sampledAxial = min(max(axial, 1e-4), 1 - 1e-4)
    let sine = max(sin(Float.pi * sampledAxial), 1e-5)
    let cosine = cos(Float.pi * sampledAxial)
    let sineDerivative = Float.pi * cosine
    let bodyEnvelope = 0.32 + 0.68 * pow(sine, 0.58)
    let bodyDerivative = 0.68 * 0.58 * pow(sine, -0.42) * sineDerivative
    let tipTaper = 1 - 0.985 * pow(sampledAxial, 3.2)
    let tipDerivative = -0.985 * 3.2 * pow(sampledAxial, 2.2)
    let baseWidth = maximumWidthMeters * (0.55 + 0.45 * sampledAxial)
    let baseWidthDerivative = 0.45 * maximumWidthMeters
    let symmetricWidth = baseWidth * bodyEnvelope * tipTaper
    let symmetricWidthDerivative =
      baseWidthDerivative * bodyEnvelope * tipTaper
      + baseWidth * bodyDerivative * tipTaper
      + baseWidth * bodyEnvelope * tipDerivative
    let rectrix = CrowRectrixVaneAnatomy.profile(packedIdentity: packedIdentity)
    let asymmetry = rectrix?.vaneAsymmetry ?? 0
    let outerSignedWidth = rectrix?.outerSignedWidth ?? 0
    let sideScale = 1 - asymmetry * signedWidth * outerSignedWidth
    let width = symmetricWidth * sideScale
    let widthDerivative = symmetricWidthDerivative * sideScale
    let widthSignedDerivative = -symmetricWidth * asymmetry * outerSignedWidth
    let crownEnvelope = pow(sine, 0.65)
    let crownDerivative = 0.65 * pow(sine, -0.35) * sineDerivative
    let transverseEnvelope = max(0, 1 - signedWidth * signedWidth)
    let crownRatio = crownRatio(packedIdentity: packedIdentity)
    let camberSkew = rectrix?.camberSkew ?? 0
    let camberDerivative =
      sineDerivative * (1 + camberSkew * (2 * sampledAxial - 1))
      + sine * 2 * camberSkew
    let axialTangent =
      tangent * lengthMeters
      + orthogonalNormal * (camberMeters * camberDerivative)
      + widthAxis * (signedWidth * widthDerivative)
      + orthogonalNormal
      * (crownRatio * transverseEnvelope
        * (widthDerivative * crownEnvelope + width * crownDerivative))
    let widthTangent =
      widthAxis * (width + signedWidth * widthSignedDerivative)
      + orthogonalNormal
      * (crownRatio * crownEnvelope
        * (widthSignedDerivative * transverseEnvelope
          + width * (-2 * signedWidth)))
    var result = safeNormalize(
      simd_cross(axialTangent, widthTangent),
      fallback: surfaceNormal
    )
    if simd_dot(result, surfaceNormal) < 0 { result = -result }
    return result
  }

  private static func crownRatio(packedIdentity: UInt32) -> Float {
    if let rectrix = CrowRectrixVaneAnatomy.profile(packedIdentity: packedIdentity) {
      return rectrix.crownRatio
    }
    let featherClass = packedIdentity & 255
    switch featherClass {
    case 1: return 0.13
    case 2: return 0.16
    case 3: return 0.11
    default: return 0.14
    }
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
