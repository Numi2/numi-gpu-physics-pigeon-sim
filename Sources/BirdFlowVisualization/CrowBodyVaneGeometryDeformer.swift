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
  let topologyIndex: Int
  let topology: CrowBodyVaneTopology
  let recordBuffer: MTLBuffer
  let workBuffer: MTLBuffer
  let indirectDrawBuffer: MTLBuffer
  let indirectDrawBufferOffset: Int
  let auditRecordBuffer: MTLBuffer?
  let auditRecordCount: Int
  let auditOutputBuffer: MTLBuffer?

  var vertexCount: Int { topology.verticesPerInstance }
}

struct CrowBodyVaneGeometryFrame {
  let slot: Int
  let batches: [CrowBodyVaneGeometryBatchFrame]
  let inputRecordCount: Int
  let inputRecordBytes: Int
  let recordCapacityBytes: Int
  let recordBufferAllocationCount: Int
  let auditReadbackReady: Bool
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
  private let auditPipeline: MTLComputePipelineState
  private var recordBuffers: [MTLBuffer]
  private let topologyIndexBuffers: [MTLBuffer]
  private let topologyOffsetBuffers: [MTLBuffer]
  private let topologyCountBuffers: [MTLBuffer]
  private let workBuffers: [MTLBuffer]
  private let indirectDrawBuffers: [MTLBuffer]
  private var nextSlot = 0
  private(set) var recordBufferAllocationCount = 0

  var retainedRecordCapacityBytes: Int {
    recordBuffers.reduce(0) { $0 + $1.length }
  }

  var retainedIndirectDrawBytes: Int {
    indirectDrawBuffers.reduce(0) { $0 + $1.length }
  }

  init(backend: VisualizationBackend) throws {
    self.backend = backend
    classifyPipeline = try backend.compute("classifyCrowBodyVaneRecords")
    scanPipeline = try backend.compute("scanCrowBodyVaneRecords")
    emitPipeline = try backend.compute("emitCrowBodyVaneWork")
    indirectPipeline = try backend.compute("prepareCrowBodyVaneIndirectWork")
    auditPipeline = try backend.compute("probeCrowBodyVaneVertices")
    let maximumRecordCount = CrowBodyFeatherTracts.samples().count
    recordBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(length: 16, shared: true)
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
        length: CrowBodyVaneRecords.productionTopologies.count
          * MemoryLayout<DrawPrimitivesIndirectArguments>.stride,
        shared: true
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
    let records = CrowBodyVaneRecords.temporalRecords(
      currentBodyCenter: currentBodyCenter,
      previousBodyCenter: previousBodyCenter,
      currentNeckPose: currentNeckPose,
      previousNeckPose: previousNeckPose,
      currentDeployment: currentDeployment,
      previousDeployment: previousDeployment
    )
    let requiredRecordBytes =
      records.count
      * MemoryLayout<CrowBodyVaneRecordGPU>.stride
    if recordBuffers[slot].length < requiredRecordBytes {
      let created = try backend.buffer(length: requiredRecordBytes, shared: true)
      created.label = "Full body vane temporal records slot \(slot)"
      recordBuffers[slot] = created
      recordBufferAllocationCount += 1
    }
    records.withUnsafeBytes { bytes in
      if let baseAddress = bytes.baseAddress, !bytes.isEmpty {
        memcpy(recordBuffers[slot].contents(), baseAddress, bytes.count)
      }
    }
    memset(
      topologyCountBuffers[slot].contents(),
      0,
      8 * MemoryLayout<UInt32>.stride
    )
    memset(
      indirectDrawBuffers[slot].contents(),
      0,
      CrowBodyVaneRecords.productionTopologies.count
        * MemoryLayout<DrawPrimitivesIndirectArguments>.stride
    )
    var selection = CrowBodyVaneSelectionUniforms(
      selection: SIMD4<Float>(projectedPixelsPerMeter, 0, 0, 0),
      counts: SIMD4<UInt32>(
        UInt32(records.count),
        UInt32(CrowBodyVaneRecords.productionTopologies.count),
        0,
        0
      )
    )
    guard let classify = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow body vane selection encoder")
    }
    classify.label = "Classify full body vane inventory"
    classify.setBuffer(recordBuffers[slot], offset: 0, index: 0)
    classify.setBuffer(topologyIndexBuffers[slot], offset: 0, index: 1)
    classify.setBytes(
      &selection,
      length: MemoryLayout<CrowBodyVaneSelectionUniforms>.stride,
      index: 2
    )
    backend.dispatch1D(classify, pipeline: classifyPipeline, count: records.count)
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
    backend.dispatch1D(emit, pipeline: emitPipeline, count: records.count)
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

    let auditGroups =
      auditReadback
      ? CrowBodyVaneRecords.groupedRecords(
        currentBodyCenter: currentBodyCenter,
        previousBodyCenter: previousBodyCenter,
        currentNeckPose: currentNeckPose,
        previousNeckPose: previousNeckPose,
        currentDeployment: currentDeployment,
        previousDeployment: previousDeployment,
        projectedPixelsPerMeter: projectedPixelsPerMeter
      )
      : [:]
    var batches: [CrowBodyVaneGeometryBatchFrame] = []
    for (topologyIndex, topology) in CrowBodyVaneRecords.productionTopologies.enumerated() {
      let auditRecords = auditGroups[topology] ?? []
      let auditRecordBuffer: MTLBuffer?
      let auditOutputBuffer: MTLBuffer?
      if auditReadback && !auditRecords.isEmpty {
        let auditInput = try Self.sharedBuffer(values: auditRecords, backend: backend)
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
          )
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
        backend.dispatch1D(
          audit,
          pipeline: auditPipeline,
          count: auditVertexCount
        )
        audit.endEncoding()
        auditRecordBuffer = auditInput
        auditOutputBuffer = auditOutput
      } else {
        auditRecordBuffer = nil
        auditOutputBuffer = nil
      }
      batches.append(
        CrowBodyVaneGeometryBatchFrame(
          topologyIndex: topologyIndex,
          topology: topology,
          recordBuffer: recordBuffers[slot],
          workBuffer: workBuffers[slot],
          indirectDrawBuffer: indirectDrawBuffers[slot],
          indirectDrawBufferOffset: topologyIndex
            * MemoryLayout<DrawPrimitivesIndirectArguments>.stride,
          auditRecordBuffer: auditRecordBuffer,
          auditRecordCount: auditRecords.count,
          auditOutputBuffer: auditOutputBuffer
        )
      )
    }
    return CrowBodyVaneGeometryFrame(
      slot: slot,
      batches: batches,
      inputRecordCount: records.count,
      inputRecordBytes: requiredRecordBytes,
      recordCapacityBytes: recordBuffers[slot].length,
      recordBufferAllocationCount: recordBufferAllocationCount,
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
      )
    )
    encoder.setVertexBuffer(batch.recordBuffer, offset: 0, index: 0)
    encoder.setVertexBuffer(batch.workBuffer, offset: 0, index: 1)
    encoder.setVertexBytes(
      &uniforms,
      length: MemoryLayout<CrowBodyVaneGeometryUniforms>.stride,
      index: 2
    )
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

  func activeRecordCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    Int(topologyCounts(for: frame)[7])
  }

  func expandedVertexCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    frame.batches.reduce(0) {
      $0 + Int(drawArguments(for: $1).vertexCount)
        * Int(drawArguments(for: $1).instanceCount)
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
      capacity: frame.inputRecordCount
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

  func auditRecords(
    for batch: CrowBodyVaneGeometryBatchFrame
  ) -> [CrowBodyVaneRecordGPU] {
    guard let buffer = batch.auditRecordBuffer else { return [] }
    let pointer = buffer.contents().bindMemory(
      to: CrowBodyVaneRecordGPU.self,
      capacity: batch.auditRecordCount
    )
    return Array(
      UnsafeBufferPointer(start: pointer, count: batch.auditRecordCount)
    )
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
