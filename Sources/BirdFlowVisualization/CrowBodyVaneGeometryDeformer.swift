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

struct CrowBodyVaneGeometryBatchFrame {
  let topology: CrowBodyVaneTopology
  let recordBuffer: MTLBuffer
  let recordCount: Int
  let auditOutputBuffer: MTLBuffer?

  var vertexCount: Int { topology.verticesPerInstance }
}

struct CrowBodyVaneGeometryFrame {
  let batches: [CrowBodyVaneGeometryBatchFrame]
  let recordCount: Int
  let expandedVertexCount: Int
  let auditReadbackReady: Bool
}

/// Live procedural expansion of body contour vanes.
///
/// Production rasterization pulls compact temporal records directly. The
/// compute pipeline invokes the same Metal helper only as a parity oracle.
final class CrowBodyVaneGeometryDeformer {
  private let backend: VisualizationBackend
  private let auditPipeline: MTLComputePipelineState

  init(backend: VisualizationBackend) throws {
    self.backend = backend
    auditPipeline = try backend.compute("probeCrowBodyVaneVertices")
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
    let grouped = CrowBodyVaneRecords.groupedRecords(
      currentBodyCenter: currentBodyCenter,
      previousBodyCenter: previousBodyCenter,
      currentNeckPose: currentNeckPose,
      previousNeckPose: previousNeckPose,
      currentDeployment: currentDeployment,
      previousDeployment: previousDeployment,
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
    var batches: [CrowBodyVaneGeometryBatchFrame] = []
    var expandedVertexCount = 0
    for topology in grouped.keys.sorted() {
      guard let records = grouped[topology], !records.isEmpty else { continue }
      let recordBuffer = try Self.sharedBuffer(values: records, backend: backend)
      let batchVertexCount = topology.verticesPerInstance * records.count
      expandedVertexCount += batchVertexCount
      let auditOutput: MTLBuffer?
      if auditReadback {
        let output = try backend.buffer(
          length: batchVertexCount * MemoryLayout<CrowFeatherVertexGPU>.stride,
          shared: true
        )
        var uniforms = CrowBodyVaneGeometryUniforms(
          counts: SIMD4<UInt32>(
            UInt32(topology.axialSections),
            UInt32(topology.widthSections),
            UInt32(records.count),
            UInt32(topology.verticesPerInstance)
          )
        )
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
          throw VisualizationError.pipeline("crow body vane audit encoder")
        }
        encoder.label = "Audit live procedural body vanes"
        encoder.setBuffer(recordBuffer, offset: 0, index: 0)
        encoder.setBytes(
          &uniforms,
          length: MemoryLayout<CrowBodyVaneGeometryUniforms>.stride,
          index: 1
        )
        encoder.setBuffer(output, offset: 0, index: 2)
        backend.dispatch1D(encoder, pipeline: auditPipeline, count: batchVertexCount)
        encoder.endEncoding()
        auditOutput = output
      } else {
        auditOutput = nil
      }
      batches.append(
        CrowBodyVaneGeometryBatchFrame(
          topology: topology,
          recordBuffer: recordBuffer,
          recordCount: records.count,
          auditOutputBuffer: auditOutput
        )
      )
    }
    return CrowBodyVaneGeometryFrame(
      batches: batches,
      recordCount: grouped.values.reduce(0) { $0 + $1.count },
      expandedVertexCount: expandedVertexCount,
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
        UInt32(batch.recordCount),
        UInt32(batch.vertexCount)
      )
    )
    encoder.setVertexBuffer(batch.recordBuffer, offset: 0, index: 0)
    encoder.setVertexBytes(
      &uniforms,
      length: MemoryLayout<CrowBodyVaneGeometryUniforms>.stride,
      index: 1
    )
  }

  func vertices(
    for batch: CrowBodyVaneGeometryBatchFrame
  ) -> [CrowFeatherVertexGPU] {
    guard let buffer = batch.auditOutputBuffer else {
      preconditionFailure("body vane frame lacks audit readback")
    }
    let count = batch.vertexCount * batch.recordCount
    let pointer = buffer.contents().bindMemory(
      to: CrowFeatherVertexGPU.self,
      capacity: count
    )
    return Array(UnsafeBufferPointer(start: pointer, count: count))
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
  static func groupedRecords(
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    currentNeckPose: CrowStandingNeckPose?,
    previousNeckPose: CrowStandingNeckPose?,
    currentDeployment: Float,
    previousDeployment: Float,
    projectedPixelsPerMeter: Float
  ) -> [CrowBodyVaneTopology: [CrowBodyVaneRecordGPU]] {
    let current = CrowBodyFeatherTracts.visibleSamples(
      neckPose: currentNeckPose,
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
    let previous = CrowBodyFeatherTracts.visibleSamples(
      neckPose: previousNeckPose,
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
    precondition(current.count == previous.count, "body vane temporal inventory")
    var grouped: [CrowBodyVaneTopology: [CrowBodyVaneRecordGPU]] = [:]
    for (index, pair) in zip(current, previous).enumerated() {
      precondition(identity(of: pair.0) == identity(of: pair.1))
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
      morphology: SIMD4<Float>(current.pennaceousStartFraction, 0, 0, 0),
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
