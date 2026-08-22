import Foundation
import Metal
import simd

struct CrowFeatherGeometryFrame {
  let slot: Int
  let readbackReady: Bool
  let outputBuffer: MTLBuffer
  let indirectDrawBuffer: MTLBuffer
  let indirectMeshDispatchBuffer: MTLBuffer?
  let vertexCount: Int

  init(
    slot: Int,
    readbackReady: Bool,
    outputBuffer: MTLBuffer,
    indirectDrawBuffer: MTLBuffer,
    indirectMeshDispatchBuffer: MTLBuffer? = nil,
    vertexCount: Int
  ) {
    self.slot = slot
    self.readbackReady = readbackReady
    self.outputBuffer = outputBuffer
    self.indirectDrawBuffer = indirectDrawBuffer
    self.indirectMeshDispatchBuffer = indirectMeshDispatchBuffer
    self.vertexCount = vertexCount
  }
}

/// Expands one retained canonical vane template for every persistent feather.
///
/// A GPU prepass converts final-output coverage into triangle-safe vane,
/// vane-plus-rachis, or full-barb prefixes and writes both indirect compute and
/// draw arguments. The compact template and stable root contract can also feed
/// mesh shaders or ray-tracing geometry without changing feather identity.
final class CrowFeatherGeometryDeformer {
  private static let bufferedFrameCount = 3
  private static let sectionCount = 48
  private static let widthSectionCount = 8
  private static let rachisSectionCount = 24
  private static let barbPairCount = 20
  private static let rachisDetailPixelsPerMeter: Float = 1_050
  private static let fullDetailPixelsPerMeter: Float = 1_400

  private enum TemplateKind: Float {
    case vane = 0
    case rachis = 1
    case barb = 2
  }

  private let backend: VisualizationBackend
  private let gpuSelectedDetailDensity: Bool
  private let indirectPipeline: MTLComputePipelineState
  private let pipeline: MTLComputePipelineState
  private let templateVertices: [CrowFeatherTemplateVertexGPU]
  private let templateBuffer: MTLBuffer
  private let outputBuffers: [MTLBuffer]
  private let indirectDrawBuffers: [MTLBuffer]
  private let indirectDispatchBuffers: [MTLBuffer]
  private let outputByteCount: Int
  /// Audit mirrors are allocated per slot only when a caller requests them.
  /// Production capture otherwise avoids retaining another complete copy of
  /// the future-density geometry stream in unified memory.
  private var readbackBuffers: [MTLBuffer?]
  private var nextSlot = 0

  let featherCount: Int
  let vertexCount: Int

  init(
    backend: VisualizationBackend,
    featherCount: Int,
    gpuSelectedDetailDensity: Bool = false
  ) throws {
    self.backend = backend
    self.featherCount = featherCount
    self.gpuSelectedDetailDensity = gpuSelectedDetailDensity
    indirectPipeline = try backend.compute("prepareCrowFeatherIndirectWork")
    pipeline = try backend.compute("deformCrowFeatherTemplates")
    templateVertices = Self.makeTemplateVertices()
    templateBuffer = try Self.sharedBuffer(
      values: templateVertices,
      backend: backend
    )
    vertexCount = featherCount * templateVertices.count
    let outputBytes = MemoryLayout<CrowFeatherVertexGPU>.stride * vertexCount
    outputByteCount = outputBytes
    outputBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(length: outputBytes)
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
    readbackBuffers = Array(repeating: nil, count: Self.bufferedFrameCount)
  }

  func encode(
    rootFrame: CrowFeatherRootFrame,
    renderOffset: SIMD3<Float>,
    projectedPixelsPerMeter: Float = 0,
    commandBuffer: MTLCommandBuffer,
    auditReadback: Bool = false
  ) throws -> CrowFeatherGeometryFrame {
    let slot = nextSlot
    nextSlot = (nextSlot + 1) % Self.bufferedFrameCount
    let output = outputBuffers[slot]
    let indirectDraw = indirectDrawBuffers[slot]
    let indirectDispatch = indirectDispatchBuffers[slot]
    let detailTier: Float =
      gpuSelectedDetailDensity
      ? (projectedPixelsPerMeter >= Self.fullDetailPixelsPerMeter
        ? 2
        : (projectedPixelsPerMeter >= Self.rachisDetailPixelsPerMeter ? 1 : 0))
      : (projectedPixelsPerMeter >= Self.fullDetailPixelsPerMeter ? 2 : 0)
    var uniforms = CrowFeatherGeometryUniforms(
      counts: SIMD4<UInt32>(
        UInt32(featherCount),
        UInt32(templateVertices.count),
        UInt32(vertexCount),
        gpuSelectedDetailDensity
          ? UInt32(Self.sectionCount * Self.widthSectionCount * 6) : 0
      ),
      renderOffsetAndDetailScale: SIMD4<Float>(
        renderOffset,
        detailTier
      )
    )
    var threadsPerThreadgroup = UInt32(
      min(pipeline.maxTotalThreadsPerThreadgroup, pipeline.threadExecutionWidth)
    )
    guard let indirectEncoder = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow feather indirect-work encoder")
    }
    indirectEncoder.label = "GPU-selected crow feather detail density"
    indirectEncoder.setComputePipelineState(indirectPipeline)
    indirectEncoder.setBuffer(indirectDraw, offset: 0, index: 0)
    indirectEncoder.setBuffer(indirectDispatch, offset: 0, index: 1)
    indirectEncoder.setBytes(
      &uniforms,
      length: MemoryLayout<CrowFeatherGeometryUniforms>.stride,
      index: 2
    )
    indirectEncoder.setBytes(
      &threadsPerThreadgroup,
      length: MemoryLayout<UInt32>.stride,
      index: 3
    )
    backend.dispatch1D(indirectEncoder, pipeline: indirectPipeline, count: 1)
    indirectEncoder.endEncoding()

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
    if auditReadback {
      backend.dispatch1D(encoder, pipeline: pipeline, count: vertexCount)
    } else {
      encoder.setComputePipelineState(pipeline)
      encoder.dispatchThreadgroups(
        indirectBuffer: indirectDispatch,
        indirectBufferOffset: 0,
        threadsPerThreadgroup: MTLSize(
          width: Int(threadsPerThreadgroup),
          height: 1,
          depth: 1
        )
      )
    }
    encoder.endEncoding()

    if auditReadback {
      let readback: MTLBuffer
      if let existing = readbackBuffers[slot] {
        readback = existing
      } else {
        let created = try backend.buffer(length: outputByteCount, shared: true)
        readbackBuffers[slot] = created
        readback = created
      }
      guard let blit = commandBuffer.makeBlitCommandEncoder() else {
        throw VisualizationError.pipeline("crow feather geometry readback encoder")
      }
      blit.label = "Crow feather geometry audit readback"
      blit.copy(
        from: output,
        sourceOffset: 0,
        to: readback,
        destinationOffset: 0,
        size: MemoryLayout<CrowFeatherVertexGPU>.stride * vertexCount
      )
      blit.endEncoding()
    }
    return CrowFeatherGeometryFrame(
      slot: slot,
      readbackReady: auditReadback,
      outputBuffer: output,
      indirectDrawBuffer: indirectDraw,
      vertexCount: vertexCount
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

  func vertices(for frame: CrowFeatherGeometryFrame) -> [CrowFeatherVertexGPU] {
    precondition(frame.readbackReady, "feather geometry was not encoded for readback")
    guard let readback = readbackBuffers[frame.slot] else {
      preconditionFailure("feather geometry audit buffer is unavailable")
    }
    let pointer = readback.contents().bindMemory(
      to: CrowFeatherVertexGPU.self,
      capacity: vertexCount
    )
    return Array(UnsafeBufferPointer(start: pointer, count: vertexCount))
  }

  func referenceVertices(
    roots: [CrowFeatherRootStateGPU],
    renderOffset: SIMD3<Float>,
    projectedPixelsPerMeter: Float = 0
  ) -> [CrowFeatherVertexGPU] {
    let detailScale: Float =
      projectedPixelsPerMeter >= Self.fullDetailPixelsPerMeter
      ? 2
      : (projectedPixelsPerMeter >= Self.rachisDetailPixelsPerMeter ? 1 : 0)
    let rootMajor = roots.flatMap { root in
      templateVertices.map { template in
        let axial = template.parameters.x
        let signedWidth = template.parameters.y
        let detailKind = template.parameters.z
        let ribbonSide = template.parameters.w
        let currentDirection = Self.xyz(root.currentDirectionAndRachis)
        let previousDirection = Self.xyz(root.previousDirectionAndCamber)
        let currentNormal = Self.xyz(root.currentNormalAndPadding)
        let previousNormal = Self.xyz(root.previousNormalAndPadding)
        let lengthMeters = root.currentPositionAndLength.w
        let maximumWidthMeters = root.previousPositionAndWidth.w
        let camberMeters = root.previousDirectionAndCamber.w
        let previousLengthMeters = root.previousMorphology.x
        let previousMaximumWidthMeters = root.previousMorphology.y
        let previousRachisRadiusMeters = root.previousMorphology.z
        let previousCamberMeters = root.previousMorphology.w
        let packedIdentity = root.identity.w
        let featherClass = packedIdentity & 255
        let isUnderwingCovert = featherClass == 12 || featherClass == 13
        let isLiveCovert = CrowCovertVaneAnatomy.isLiveCovertClass(featherClass)
        let isRectrixBarb =
          featherClass == 3 && detailKind == TemplateKind.barb.rawValue
        let temporallyVariableMorphology = isLiveCovert
        let material: Float =
          featherClass == 1
          ? 0.25
          : (featherClass == 2 ? 0.22 : (isUnderwingCovert ? 0.17 : 0.23))
        let shade =
          isUnderwingCovert
          ? 0.0066 + 0.00022 * Float(root.identity.x % 9)
          : 0.0075 + 0.00045 * Float(root.identity.x % 11)
        let currentRoot = Self.xyz(root.currentPositionAndLength)
        let previousRoot = Self.xyz(root.previousPositionAndWidth)
        let detailEnabled =
          detailKind == TemplateKind.vane.rawValue
          || (detailScale >= detailKind
            && (featherClass == 1 || featherClass == 2 || isLiveCovert
              || isRectrixBarb))
        let currentPosition =
          detailEnabled
          ? Self.detailPosition(
            root: currentRoot,
            direction: currentDirection,
            surfaceNormal: currentNormal,
            lengthMeters: lengthMeters,
            maximumWidthMeters: maximumWidthMeters,
            camberMeters: camberMeters,
            rachisRadiusMeters: root.currentDirectionAndRachis.w,
            axial: axial,
            signedWidth: signedWidth,
            detailKind: detailKind,
            ribbonSide: ribbonSide,
            packedIdentity: packedIdentity
          )
          : currentRoot
        let previousPosition =
          detailEnabled
          ? Self.detailPosition(
            root: previousRoot,
            direction: previousDirection,
            surfaceNormal: previousNormal,
            lengthMeters: temporallyVariableMorphology
              ? previousLengthMeters : lengthMeters,
            maximumWidthMeters: temporallyVariableMorphology
              ? previousMaximumWidthMeters : maximumWidthMeters,
            camberMeters: temporallyVariableMorphology
              ? previousCamberMeters : camberMeters,
            rachisRadiusMeters: temporallyVariableMorphology
              ? previousRachisRadiusMeters : root.currentDirectionAndRachis.w,
            axial: axial,
            signedWidth: signedWidth,
            detailKind: detailKind,
            ribbonSide: ribbonSide,
            packedIdentity: packedIdentity
          )
          : previousRoot
        let deformedNormal =
          detailEnabled
          ? Self.detailNormal(
            direction: currentDirection,
            surfaceNormal: currentNormal,
            lengthMeters: lengthMeters,
            maximumWidthMeters: maximumWidthMeters,
            camberMeters: camberMeters,
            axial: axial,
            signedWidth: signedWidth,
            detailKind: detailKind,
            ribbonSide: ribbonSide,
            packedIdentity: packedIdentity
          )
          : currentNormal
        let detailShadeScale: Float =
          detailKind == TemplateKind.rachis.rawValue
          ? 1.18
          : (detailKind == TemplateKind.barb.rawValue ? 1.08 : 1)
        let greenScale: Float = isUnderwingCovert ? 1.45 : 1.28
        let blueScale: Float = isUnderwingCovert ? 2.55 : 1.72
        return CrowFeatherVertexGPU(
          position: SIMD4<Float>(
            currentPosition + renderOffset,
            1
          ),
          normal: SIMD4<Float>(deformedNormal, 0),
          color: SIMD4<Float>(
            shade * detailShadeScale,
            shade * greenScale * detailShadeScale,
            shade * blueScale * detailShadeScale,
            material
          ),
          previousPosition: SIMD4<Float>(
            previousPosition + renderOffset,
            1
          ),
          identity: root.identity,
          parameters: SIMD4<Float>(
            CrowCovertVaneAnatomy.geometryAxialFraction(
              localAxialFraction: axial,
              featherClass: featherClass
            ),
            signedWidth,
            Float(featherClass),
            detailKind
          )
        )
      }
    }
    guard gpuSelectedDetailDensity, detailScale < 2 else { return rootMajor }
    var triangleMajor: [CrowFeatherVertexGPU] = []
    triangleMajor.reserveCapacity(rootMajor.count)
    for templateTriangle in 0..<(templateVertices.count / 3) {
      for featherIndex in roots.indices {
        let source = featherIndex * templateVertices.count + templateTriangle * 3
        triangleMajor.append(contentsOf: rootMajor[source..<(source + 3)])
      }
    }
    return triangleMajor
  }

  private static func makeTemplateVertices() -> [CrowFeatherTemplateVertexGPU] {
    var result: [CrowFeatherTemplateVertexGPU] = []
    result.reserveCapacity(
      sectionCount * widthSectionCount * 6
        + rachisSectionCount * 6
        + barbPairCount * 2 * 6
    )
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
    for section in 0..<rachisSectionCount {
      let first = 0.035 + 0.93 * Float(section) / Float(rachisSectionCount)
      let second = 0.035 + 0.93 * Float(section + 1) / Float(rachisSectionCount)
      appendRibbon(
        first: SIMD2<Float>(first, 0),
        second: SIMD2<Float>(second, 0),
        kind: .rachis,
        to: &result
      )
    }
    for pair in 0..<barbPairCount {
      let fraction = Float(pair + 1) / Float(barbPairCount + 1)
      let firstAxial = 0.10 + 0.76 * fraction
      let secondAxial = min(0.95, firstAxial + 0.045 + 0.020 * fraction)
      for side: Float in [-1, 1] {
        appendRibbon(
          first: SIMD2<Float>(firstAxial, side * 0.025),
          second: SIMD2<Float>(secondAxial, side * 0.94),
          kind: .barb,
          to: &result
        )
      }
    }
    return result
  }

  private static func appendRibbon(
    first: SIMD2<Float>,
    second: SIMD2<Float>,
    kind: TemplateKind,
    to result: inout [CrowFeatherTemplateVertexGPU]
  ) {
    for parameter in [
      SIMD3<Float>(first.x, first.y, -1),
      SIMD3<Float>(first.x, first.y, 1),
      SIMD3<Float>(second.x, second.y, 1),
      SIMD3<Float>(first.x, first.y, -1),
      SIMD3<Float>(second.x, second.y, 1),
      SIMD3<Float>(second.x, second.y, -1),
    ] {
      result.append(
        CrowFeatherTemplateVertexGPU(
          parameters: SIMD4<Float>(
            parameter.x,
            parameter.y,
            kind.rawValue,
            parameter.z
          )
        )
      )
    }
  }

  private static func detailPosition(
    root: SIMD3<Float>,
    direction: SIMD3<Float>,
    surfaceNormal: SIMD3<Float>,
    lengthMeters: Float,
    maximumWidthMeters: Float,
    camberMeters: Float,
    rachisRadiusMeters: Float,
    axial: Float,
    signedWidth: Float,
    detailKind: Float,
    ribbonSide: Float,
    packedIdentity: UInt32
  ) -> SIMD3<Float> {
    let base = position(
      root: root,
      direction: direction,
      surfaceNormal: surfaceNormal,
      lengthMeters: lengthMeters,
      maximumWidthMeters: maximumWidthMeters,
      camberMeters: camberMeters,
      axial: axial,
      signedWidth: signedWidth,
      packedIdentity: packedIdentity
    )
    guard detailKind != TemplateKind.vane.rawValue else { return base }
    let tangent = safeNormalize(direction, fallback: SIMD3<Float>(1, 0, 0))
    let baseNormal = normal(
      direction: direction,
      surfaceNormal: surfaceNormal,
      lengthMeters: lengthMeters,
      maximumWidthMeters: maximumWidthMeters,
      camberMeters: camberMeters,
      axial: axial,
      signedWidth: signedWidth,
      packedIdentity: packedIdentity
    )
    let widthAxis = safeNormalize(
      simd_cross(baseNormal, tangent),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    if detailKind == TemplateKind.rachis.rawValue {
      let halfWidth = max(
        0.00011,
        rachisRadiusMeters * (0.96 - 0.72 * axial)
      )
      return base + baseNormal * (0.34 * halfWidth)
        + widthAxis * (ribbonSide * halfWidth)
    }
    let barbDirection = safeNormalize(
      widthAxis * (signedWidth < 0 ? -1 : 1) + tangent * 0.16,
      fallback: widthAxis
    )
    let ribbonAxis = safeNormalize(
      simd_cross(baseNormal, barbDirection),
      fallback: tangent
    )
    let halfWidth = 0.00010 * (1 - 0.28 * axial)
    return base + baseNormal * 0.00010
      + ribbonAxis * (ribbonSide * halfWidth)
  }

  private static func detailNormal(
    direction: SIMD3<Float>,
    surfaceNormal: SIMD3<Float>,
    lengthMeters: Float,
    maximumWidthMeters: Float,
    camberMeters: Float,
    axial: Float,
    signedWidth: Float,
    detailKind: Float,
    ribbonSide: Float,
    packedIdentity: UInt32
  ) -> SIMD3<Float> {
    let baseNormal = normal(
      direction: direction,
      surfaceNormal: surfaceNormal,
      lengthMeters: lengthMeters,
      maximumWidthMeters: maximumWidthMeters,
      camberMeters: camberMeters,
      axial: axial,
      signedWidth: signedWidth,
      packedIdentity: packedIdentity
    )
    guard detailKind != TemplateKind.vane.rawValue else { return baseNormal }
    let tangent = safeNormalize(direction, fallback: SIMD3<Float>(1, 0, 0))
    let widthAxis = safeNormalize(
      simd_cross(baseNormal, tangent),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    if detailKind == TemplateKind.rachis.rawValue {
      return safeNormalize(
        baseNormal - widthAxis * (0.38 * ribbonSide),
        fallback: baseNormal
      )
    }
    let barbDirection = safeNormalize(
      widthAxis * (signedWidth < 0 ? -1 : 1) + tangent * 0.16,
      fallback: widthAxis
    )
    let ribbonAxis = safeNormalize(
      simd_cross(baseNormal, barbDirection),
      fallback: tangent
    )
    return safeNormalize(
      baseNormal - ribbonAxis * (0.24 * ribbonSide),
      fallback: baseNormal
    )
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
    let featherClass = packedIdentity & 255
    let geometryAxial = CrowCovertVaneAnatomy.geometryAxialFraction(
      localAxialFraction: axial,
      featherClass: featherClass
    )
    let rectrix = CrowRectrixVaneAnatomy.profile(packedIdentity: packedIdentity)
    let shapedAxial = max(
      0,
      geometryAxial
        - (rectrix.map {
          CrowRectrixVaneAnatomy.terminalRoundbackFraction(
            axial: geometryAxial,
            signedWidth: signedWidth,
            profile: $0
          )
        } ?? 0)
    )
    let tangent = safeNormalize(direction, fallback: SIMD3<Float>(1, 0, 0))
    let orthogonalNormal = safeNormalize(
      surfaceNormal - tangent * simd_dot(surfaceNormal, tangent),
      fallback: surfaceNormal
    )
    let widthAxis = safeNormalize(
      simd_cross(orthogonalNormal, tangent),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    let bodyEnvelope =
      0.32
      + 0.68 * pow(max(sin(Float.pi * shapedAxial), 0), 0.58)
    let tipTaper = 1 - 0.985 * pow(shapedAxial, 3.2)
    let widthEnvelope =
      rectrix.map {
        CrowRectrixVaneAnatomy.terminalWidthEnvelope(
          axial: shapedAxial,
          profile: $0
        )
      } ?? (bodyEnvelope * tipTaper)
    let rootWidthRatio = rootWidthRatio(packedIdentity: packedIdentity)
    let baseWidth =
      (rootWidthRatio * maximumWidthMeters * (1 - shapedAxial)
        + maximumWidthMeters * shapedAxial) * widthEnvelope
    let remex = CrowRemexVaneAnatomy.profile(packedIdentity: packedIdentity)
    let covert = CrowCovertVaneAnatomy.profile(packedIdentity: packedIdentity)
    let sideScale =
      1
      - (rectrix?.vaneAsymmetry ?? remex?.vaneAsymmetry
        ?? covert?.vaneAsymmetry ?? 0) * signedWidth
      * (rectrix?.outerSignedWidth ?? remex?.dorsalSignedWidth
        ?? covert?.exposedSignedWidth ?? 0)
    let edgeModulation =
      rectrix.map {
        CrowRectrixVaneAnatomy.edgeModulation(
          axial: shapedAxial,
          signedWidth: signedWidth,
          profile: $0
        )
      }
      ?? remex.map {
        CrowRemexVaneAnatomy.edgeModulation(
          axial: shapedAxial,
          signedWidth: signedWidth,
          profile: $0
        )
      }
      ?? covert.map {
        CrowCovertVaneAnatomy.edgeModulation(
          axial: shapedAxial,
          signedWidth: signedWidth,
          profile: $0
        )
      } ?? 1
    let broadEdge = CrowRemexVaneAnatomy.terminalPrimaryBroadEdgeTerms(
      axial: geometryAxial,
      signedWidth: signedWidth,
      packedIdentity: packedIdentity
    )
    let foldedJunction = CrowRemexVaneAnatomy.terminalFoldedRemexJunctionTerms(
      axial: geometryAxial,
      signedWidth: signedWidth,
      packedIdentity: packedIdentity
    )
    let width =
      baseWidth * sideScale * edgeModulation * broadEdge.scale
      * foldedJunction.scale
      * CrowCovertVaneAnatomy.rankCoverageScale(
        localAxialFraction: axial,
        featherClass: featherClass
      )
    let camberEnvelope =
      rectrix.map {
        CrowRectrixVaneAnatomy.camberEnvelope(axial: shapedAxial, profile: $0)
      }
      ?? remex.map {
        CrowRemexVaneAnatomy.camberEnvelope(axial: shapedAxial, profile: $0)
      }
      ?? covert.map {
        CrowCovertVaneAnatomy.camberEnvelope(axial: shapedAxial, profile: $0)
      } ?? sin(Float.pi * shapedAxial)
    let center =
      root + tangent * (lengthMeters * shapedAxial)
      + orthogonalNormal
      * (camberMeters * camberEnvelope
        + CrowCovertVaneAnatomy.rankNormalOffsetMeters(
          localAxialFraction: axial,
          featherClass: featherClass
        ))
    let transverseEnvelope = max(0, 1 - signedWidth * signedWidth)
    let crownEnvelope = pow(max(sin(Float.pi * shapedAxial), 0), 0.65)
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
    let featherClass = packedIdentity & 255
    if featherClass == 3 || CrowCovertVaneAnatomy.isTrailingRankClass(featherClass) {
      // Resolve the full vane chord so rounded terminal normals remain stable
      // across Swift and Metal instead of amplifying sub-vertex cancellation.
      let axialEpsilon: Float = featherClass == 3 ? 1.0 / 48.0 : 0.0005
      let widthEpsilon: Float = featherClass == 3 ? 1 : 0.0005
      let firstAxial = max(0, axial - axialEpsilon)
      let secondAxial = min(1, axial + axialEpsilon)
      let firstWidth = max(-1, signedWidth - widthEpsilon)
      let secondWidth = min(1, signedWidth + widthEpsilon)
      let axialFirst = position(
        root: .zero,
        direction: direction,
        surfaceNormal: surfaceNormal,
        lengthMeters: lengthMeters,
        maximumWidthMeters: maximumWidthMeters,
        camberMeters: camberMeters,
        axial: firstAxial,
        signedWidth: signedWidth,
        packedIdentity: packedIdentity
      )
      let axialSecond = position(
        root: .zero,
        direction: direction,
        surfaceNormal: surfaceNormal,
        lengthMeters: lengthMeters,
        maximumWidthMeters: maximumWidthMeters,
        camberMeters: camberMeters,
        axial: secondAxial,
        signedWidth: signedWidth,
        packedIdentity: packedIdentity
      )
      let widthFirst = position(
        root: .zero,
        direction: direction,
        surfaceNormal: surfaceNormal,
        lengthMeters: lengthMeters,
        maximumWidthMeters: maximumWidthMeters,
        camberMeters: camberMeters,
        axial: axial,
        signedWidth: firstWidth,
        packedIdentity: packedIdentity
      )
      let widthSecond = position(
        root: .zero,
        direction: direction,
        surfaceNormal: surfaceNormal,
        lengthMeters: lengthMeters,
        maximumWidthMeters: maximumWidthMeters,
        camberMeters: camberMeters,
        axial: axial,
        signedWidth: secondWidth,
        packedIdentity: packedIdentity
      )
      var resolved = safeNormalize(
        simd_cross(axialSecond - axialFirst, widthSecond - widthFirst),
        fallback: surfaceNormal
      )
      if simd_dot(resolved, surfaceNormal) < 0 { resolved = -resolved }
      return resolved
    }
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
    let rootWidthRatio = rootWidthRatio(packedIdentity: packedIdentity)
    let baseWidth =
      maximumWidthMeters
      * (rootWidthRatio + (1 - rootWidthRatio) * sampledAxial)
    let baseWidthDerivative = (1 - rootWidthRatio) * maximumWidthMeters
    let symmetricWidth = baseWidth * bodyEnvelope * tipTaper
    let symmetricWidthDerivative =
      baseWidthDerivative * bodyEnvelope * tipTaper
      + baseWidth * bodyDerivative * tipTaper
      + baseWidth * bodyEnvelope * tipDerivative
    let rectrix = CrowRectrixVaneAnatomy.profile(packedIdentity: packedIdentity)
    let remex = CrowRemexVaneAnatomy.profile(packedIdentity: packedIdentity)
    let covert = CrowCovertVaneAnatomy.profile(packedIdentity: packedIdentity)
    let asymmetry =
      rectrix?.vaneAsymmetry ?? remex?.vaneAsymmetry
      ?? covert?.vaneAsymmetry ?? 0
    let outerSignedWidth =
      rectrix?.outerSignedWidth ?? remex?.dorsalSignedWidth
      ?? covert?.exposedSignedWidth ?? 0
    let sideScale = 1 - asymmetry * signedWidth * outerSignedWidth
    let edgeModulation =
      rectrix.map {
        CrowRectrixVaneAnatomy.edgeModulation(
          axial: sampledAxial,
          signedWidth: signedWidth,
          profile: $0
        )
      }
      ?? remex.map {
        CrowRemexVaneAnatomy.edgeModulation(
          axial: sampledAxial,
          signedWidth: signedWidth,
          profile: $0
        )
      }
      ?? covert.map {
        CrowCovertVaneAnatomy.edgeModulation(
          axial: sampledAxial,
          signedWidth: signedWidth,
          profile: $0
        )
      } ?? 1
    let edgeAxialDerivative =
      rectrix.map {
        CrowRectrixVaneAnatomy.edgeModulationAxialDerivative(
          axial: sampledAxial,
          signedWidth: signedWidth,
          profile: $0
        )
      }
      ?? remex.map {
        CrowRemexVaneAnatomy.edgeModulationAxialDerivative(
          axial: sampledAxial,
          signedWidth: signedWidth,
          profile: $0
        )
      }
      ?? covert.map {
        CrowCovertVaneAnatomy.edgeModulationAxialDerivative(
          axial: sampledAxial,
          signedWidth: signedWidth,
          profile: $0
        )
      } ?? 0
    let edgeSignedWidthDerivative =
      rectrix.map {
        CrowRectrixVaneAnatomy.edgeModulationSignedWidthDerivative(
          axial: sampledAxial,
          signedWidth: signedWidth,
          profile: $0
        )
      }
      ?? remex.map {
        CrowRemexVaneAnatomy.edgeModulationSignedWidthDerivative(
          axial: sampledAxial,
          signedWidth: signedWidth,
          profile: $0
        )
      }
      ?? covert.map {
        CrowCovertVaneAnatomy.edgeModulationSignedWidthDerivative(
          axial: sampledAxial,
          signedWidth: signedWidth,
          profile: $0
        )
      } ?? 0
    let broadEdge = CrowRemexVaneAnatomy.terminalPrimaryBroadEdgeTerms(
      axial: sampledAxial,
      signedWidth: signedWidth,
      packedIdentity: packedIdentity
    )
    let foldedJunction = CrowRemexVaneAnatomy.terminalFoldedRemexJunctionTerms(
      axial: sampledAxial,
      signedWidth: signedWidth,
      packedIdentity: packedIdentity
    )
    let identityScale = broadEdge.scale * foldedJunction.scale
    let identityAxialDerivative =
      broadEdge.axialDerivative * foldedJunction.scale
      + broadEdge.scale * foldedJunction.axialDerivative
    let identitySignedWidthDerivative =
      broadEdge.signedWidthDerivative * foldedJunction.scale
      + broadEdge.scale * foldedJunction.signedWidthDerivative
    let combinedModulation = edgeModulation * identityScale
    let combinedAxialDerivative =
      edgeAxialDerivative * identityScale
      + edgeModulation * identityAxialDerivative
    let combinedSignedWidthDerivative =
      edgeSignedWidthDerivative * identityScale
      + edgeModulation * identitySignedWidthDerivative
    let width = symmetricWidth * sideScale * combinedModulation
    let widthDerivative =
      sideScale
      * (symmetricWidthDerivative * combinedModulation
        + symmetricWidth * combinedAxialDerivative)
    let widthSignedDerivative =
      symmetricWidth
      * (-asymmetry * outerSignedWidth * combinedModulation
        + sideScale * combinedSignedWidthDerivative)
    let crownEnvelope = pow(sine, 0.65)
    let crownDerivative = 0.65 * pow(sine, -0.35) * sineDerivative
    let transverseEnvelope = max(0, 1 - signedWidth * signedWidth)
    let crownRatio = crownRatio(packedIdentity: packedIdentity)
    let camberSkew =
      rectrix?.camberSkew ?? remex?.camberSkew
      ?? covert?.camberSkew ?? 0
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
    if let remex = CrowRemexVaneAnatomy.profile(packedIdentity: packedIdentity) {
      return remex.crownRatio
    }
    if let covert = CrowCovertVaneAnatomy.profile(packedIdentity: packedIdentity) {
      return covert.crownRatio
    }
    let featherClass = packedIdentity & 255
    switch featherClass {
    case 1: return 0.13
    case 2: return 0.16
    case 3: return 0.11
    default: return 0.14
    }
  }

  private static func rootWidthRatio(packedIdentity: UInt32) -> Float {
    CrowCovertVaneAnatomy.profile(packedIdentity: packedIdentity)?
      .rootWidthRatio ?? 0.55
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
