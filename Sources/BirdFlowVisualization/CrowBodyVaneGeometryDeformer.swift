import Foundation
import Metal
import simd

private let crowCranialVisibilityCounterCount = 20

struct CrowBodyVaneTopology: Hashable, Comparable {
  let axialSections: Int
  let widthSections: Int

  static func < (lhs: Self, rhs: Self) -> Bool {
    (lhs.axialSections, lhs.widthSections)
      < (rhs.axialSections, rhs.widthSections)
  }

  var verticesPerInstance: Int { axialSections * widthSections * 6 }
}

/// Trivial limb-only pose transport.  Keeping digit arrays out of the retained
/// vane path avoids reference-counted anatomy crossing the optimized render
/// boundary when only five points are required.
struct CrowFemoralVanePoseSample: Equatable {
  let bodyCenter: SIMD3<Float>
  let leftHip: SIMD3<Float>
  let leftHock: SIMD3<Float>
  let rightHip: SIMD3<Float>
  let rightHock: SIMD3<Float>

  static let inactive = CrowFemoralVanePoseSample(
    bodyCenter: .zero,
    leftHip: .zero,
    leftHock: .zero,
    rightHip: .zero,
    rightHock: .zero
  )

  init(
    bodyCenter: SIMD3<Float>,
    leftHip: SIMD3<Float>,
    leftHock: SIMD3<Float>,
    rightHip: SIMD3<Float>,
    rightHock: SIMD3<Float>
  ) {
    self.bodyCenter = bodyCenter
    self.leftHip = leftHip
    self.leftHock = leftHock
    self.rightHip = rightHip
    self.rightHock = rightHock
  }

  init(_ pose: CrowStandingPoseSample) {
    bodyCenter = pose.bodyCenter
    leftHip = pose.leftFoot.hip
    leftHock = pose.leftFoot.hock
    rightHip = pose.rightFoot.hip
    rightHock = pose.rightFoot.hock
  }
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

/// One GPU-resident visibility decision shared by family-7 vane and gular
/// rasterization. Work remains topology-grouped and inventory-stable.
final class CrowCranialVisibilityFrame {
  let slot: Int
  let workBuffer: MTLBuffer
  let gularWorkBuffer: MTLBuffer
  let indirectDrawBuffer: MTLBuffer
  let countBuffer: MTLBuffer

  init(
    slot: Int,
    workBuffer: MTLBuffer,
    gularWorkBuffer: MTLBuffer,
    indirectDrawBuffer: MTLBuffer,
    countBuffer: MTLBuffer
  ) {
    self.slot = slot
    self.workBuffer = workBuffer
    self.gularWorkBuffer = gularWorkBuffer
    self.indirectDrawBuffer = indirectDrawBuffer
    self.countBuffer = countBuffer
  }
}

/// Boxes the newest retained resources so extending family work does not widen
/// the optimizer-sensitive showcase deformer value captured by the renderer.
final class CrowCranialVisibilityResources {
  let cranialVisibilityClassifyPipeline: MTLComputePipelineState
  let cranialVisibilityScanPipeline: MTLComputePipelineState
  let cranialVisibilityEmitPipeline: MTLComputePipelineState
  let cranialVisibilityIndirectPipeline: MTLComputePipelineState
  let fallbackDepthTexture: MTLTexture
  let cranialVisibilityTopologyBuffers: [MTLBuffer]
  let cranialVisibilityOffsetBuffers: [MTLBuffer]
  let cranialGularOffsetBuffers: [MTLBuffer]
  let cranialVisibilityCountBuffers: [MTLBuffer]
  let cranialVisibilityWorkBuffers: [MTLBuffer]
  let cranialGularWorkBuffers: [MTLBuffer]
  let cranialVisibilityIndirectBuffers: [MTLBuffer]
  var frames: [CrowCranialVisibilityFrame?]

  init(
    backend: VisualizationBackend,
    bufferedFrameCount: Int,
    cranialRecordCount: Int
  ) throws {
    cranialVisibilityClassifyPipeline = try backend.compute(
      "classifyCrowCranialVisibility"
    )
    cranialVisibilityScanPipeline = try backend.compute(
      "scanCrowCranialVisibility"
    )
    cranialVisibilityEmitPipeline = try backend.compute(
      "emitCrowCranialVisibilityWork"
    )
    cranialVisibilityIndirectPipeline = try backend.compute(
      "prepareCrowCranialVisibilityIndirectWork"
    )
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
    cranialVisibilityTopologyBuffers = try (0..<bufferedFrameCount).map { _ in
      try backend.buffer(length: cranialRecordCount * MemoryLayout<UInt32>.stride)
    }
    cranialVisibilityOffsetBuffers = try (0..<bufferedFrameCount).map { _ in
      try backend.buffer(length: cranialRecordCount * MemoryLayout<UInt32>.stride)
    }
    cranialGularOffsetBuffers = try (0..<bufferedFrameCount).map { _ in
      try backend.buffer(length: cranialRecordCount * MemoryLayout<UInt32>.stride)
    }
    cranialVisibilityCountBuffers = try (0..<bufferedFrameCount).map { _ in
      try backend.buffer(
        length: crowCranialVisibilityCounterCount * MemoryLayout<UInt32>.stride,
        shared: true
      )
    }
    cranialVisibilityWorkBuffers = try (0..<bufferedFrameCount).map { _ in
      try backend.buffer(length: cranialRecordCount * MemoryLayout<UInt32>.stride)
    }
    cranialGularWorkBuffers = try (0..<bufferedFrameCount).map { _ in
      try backend.buffer(length: cranialRecordCount * MemoryLayout<UInt32>.stride)
    }
    cranialVisibilityIndirectBuffers = try (0..<bufferedFrameCount).map { _ in
      try backend.buffer(
        length: (CrowBodyVaneRecords.productionTopologies.count + 1)
          * MemoryLayout<DrawPrimitivesIndirectArguments>.stride,
        shared: true
      )
    }
    frames = Array(repeating: nil, count: bufferedFrameCount)
  }

  var capacityBytes: Int {
    [
      cranialVisibilityTopologyBuffers,
      cranialVisibilityOffsetBuffers,
      cranialGularOffsetBuffers,
      cranialVisibilityCountBuffers,
      cranialVisibilityWorkBuffers,
      cranialGularWorkBuffers,
      cranialVisibilityIndirectBuffers,
    ].reduce(0) { total, buffers in
      total + buffers.reduce(0) { $0 + $1.length }
    }
  }
}

private final class CrowCranialVisibilityResourceEntry {
  weak var backend: VisualizationBackend?
  let resources: CrowCranialVisibilityResources

  init(backend: VisualizationBackend, resources: CrowCranialVisibilityResources) {
    self.backend = backend
    self.resources = resources
  }
}

private final class CrowCranialVisibilityResourceCache: @unchecked Sendable {
  static let shared = CrowCranialVisibilityResourceCache()

  private let lock = NSLock()
  private var entries: [ObjectIdentifier: CrowCranialVisibilityResourceEntry] = [:]

  func resources(
    for backend: VisualizationBackend
  ) throws -> CrowCranialVisibilityResources {
    lock.lock()
    defer { lock.unlock() }
    entries = entries.filter { $0.value.backend != nil }
    let key = ObjectIdentifier(backend)
    if let existing = entries[key]?.resources { return existing }
    let created = try CrowCranialVisibilityResources(
      backend: backend,
      bufferedFrameCount: 3,
      cranialRecordCount: CrowBodyVaneRecords.cranialMorphologyRecordCount
    )
    entries[key] = CrowCranialVisibilityResourceEntry(
      backend: backend,
      resources: created
    )
    return created
  }

  func existing(
    for backend: VisualizationBackend
  ) -> CrowCranialVisibilityResources? {
    lock.lock()
    defer { lock.unlock() }
    return entries[ObjectIdentifier(backend)]?.resources
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
  private var detailSegmentCapacityPerRecord = 43
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

  var retainedCranialVisibilityCapacityBytes: Int {
    CrowCranialVisibilityResourceCache.shared.existing(for: backend)?.capacityBytes
      ?? 0
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
    let createdMorphologyRecords = CrowBodyVaneRecords.retainedMorphologyRecords()
    morphologyRecords = createdMorphologyRecords
    maximumMorphologyLength = createdMorphologyRecords
      .prefix(CrowBodyVaneRecords.bodyMorphologyRecordCount)
      .reduce(.zero) {
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
          * MemoryLayout<CrowBodyVaneNeckTransformGPU>.stride
          + 2 * CrowThroatBridgeFeathers.columnCount
          * MemoryLayout<CrowBodyVaneNeckTransformGPU>.stride
          + 8 * MemoryLayout<SIMD4<Float>>.stride,
        shared: true
      )
      buffer.label = "Body vane neck and limb transforms slot \(slot)"
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
      try backend.buffer(
        length: (CrowBodyVaneRecords.productionTopologies.count + 1)
          * MemoryLayout<UInt32>.stride,
        shared: true
      )
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
        length: CrowBodyVaneRecords.bodyTractMorphologyRecordCount * 43
          * MemoryLayout<CrowBodyDetailSegmentGPU>.stride
      )
    }
  }

  @inline(never)
  func encode(
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    currentNeckPose: CrowStandingNeckPose?,
    previousNeckPose: CrowStandingNeckPose?,
    cranialRadii: SIMD3<Float>? = nil,
    currentCranialBreathingScale: Float? = nil,
    previousCranialBreathingScale: Float? = nil,
    currentFemoralPose: CrowFemoralVanePoseSample? = nil,
    previousFemoralPose: CrowFemoralVanePoseSample? = nil,
    retainedFamilyMask: UInt32 = 0xF,
    currentDeployment: Float,
    previousDeployment: Float,
    currentBodyContourPhase: Float? = nil,
    previousBodyContourPhase: Float? = nil,
    projectedPixelsPerMeter: Float,
    commandBuffer: MTLCommandBuffer,
    auditReadback: Bool = false
  ) throws -> CrowBodyVaneGeometryFrame {
    let slot = nextSlot
    nextSlot = (nextSlot + 1) % Self.bufferedFrameCount
    let poseInputBytes = writePoseInputs(
      slot: slot,
      currentBodyCenter: currentBodyCenter,
      previousBodyCenter: previousBodyCenter,
      currentNeckPose: currentNeckPose,
      previousNeckPose: previousNeckPose,
      cranialRadii: cranialRadii,
      currentCranialBreathingScale: currentCranialBreathingScale,
      previousCranialBreathingScale: previousCranialBreathingScale,
      currentFemoralPose: currentFemoralPose,
      previousFemoralPose: previousFemoralPose,
      currentDeployment: currentDeployment,
      previousDeployment: previousDeployment,
      currentBodyContourPhase: currentBodyContourPhase,
      previousBodyContourPhase: previousBodyContourPhase
    )
    let recordCount = morphologyRecords.count
    try ensureDetailSegmentCapacity(
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
    let retainedDetailSegmentCapacity = detailSegmentCapacityPerRecord
    let requiredRecordBytes =
      recordCount
      * MemoryLayout<CrowBodyVaneMorphologyGPU>.stride
    let auditTemporalRecords =
      auditReadback
      ? CrowBodyVaneRecords.retainedTemporalRecords(
        currentBodyCenter: currentBodyCenter,
        previousBodyCenter: previousBodyCenter,
        currentNeckPose: currentNeckPose,
        previousNeckPose: previousNeckPose,
        cranialRadii: cranialRadii,
        currentCranialBreathingScale: currentCranialBreathingScale,
        previousCranialBreathingScale: previousCranialBreathingScale,
        currentFemoralPose: currentFemoralPose,
        previousFemoralPose: previousFemoralPose,
        currentDeployment: currentDeployment,
        previousDeployment: previousDeployment
      )
      : []
    memset(
      topologyCountBuffers[slot].contents(),
      0,
      (CrowBodyVaneRecords.productionTopologies.count + 1)
        * MemoryLayout<UInt32>.stride
    )
    memset(
      indirectDrawBuffers[slot].contents(),
      0,
      3 * CrowBodyVaneRecords.productionTopologies.count
        * MemoryLayout<DrawPrimitivesIndirectArguments>.stride
    )
    var activeFamilyMask = retainedFamilyMask
    if currentFemoralPose == nil || previousFemoralPose == nil {
      activeFamilyMask &= ~UInt32(0x3)
    }
    if cranialRadii == nil
      || currentCranialBreathingScale == nil
      || previousCranialBreathingScale == nil
    {
      activeFamilyMask &= ~UInt32(0x8)
    }
    var selection = CrowBodyVaneSelectionUniforms(
      selection: SIMD4<Float>(projectedPixelsPerMeter, 0, 0, 0),
      counts: SIMD4<UInt32>(
        UInt32(recordCount),
        UInt32(CrowBodyVaneRecords.productionTopologies.count),
        UInt32(retainedDetailSegmentCapacity),
        activeFamilyMask
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
    prepare.setBuffer(morphologyBuffer, offset: 0, index: 2)
    prepare.setBuffer(workBuffers[slot], offset: 0, index: 3)
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
    detailSegments.setBuffer(
      detailSegmentBuffers[slot], offset: 0, index: 4
    )
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
      count: CrowBodyVaneRecords.bodyTractMorphologyRecordCount
        * retainedDetailSegmentCapacity
    )
    detailSegments.endEncoding()

    let auditGroups =
      auditReadback
      ? CrowBodyVaneRecords.retainedGroupedMorphologyIndices(
        projectedPixelsPerMeter: projectedPixelsPerMeter,
        femoralActive: currentFemoralPose != nil && previousFemoralPose != nil
          && retainedFamilyMask & 0x1 != 0,
        cruralActive: currentFemoralPose != nil && previousFemoralPose != nil
          && retainedFamilyMask & 0x2 != 0,
        throatBridgeActive: retainedFamilyMask & 0x4 != 0,
        cranialActive: cranialRadii != nil
          && currentCranialBreathingScale != nil
          && previousCranialBreathingScale != nil
          && retainedFamilyMask & 0x8 != 0
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

  func encodeCranialVisibility(
    for frame: CrowBodyVaneGeometryFrame,
    viewProjection: simd_float4x4,
    previousViewProjection: simd_float4x4 = matrix_identity_float4x4,
    previousDepthPyramid: MTLTexture? = nil,
    occlusionViewport: SIMD2<Int> = .zero,
    commandBuffer: MTLCommandBuffer
  ) throws -> CrowCranialVisibilityFrame {
    let slot = frame.slot
    let retainedResources = try CrowCranialVisibilityResourceCache.shared
      .resources(for: backend)
    memset(
      retainedResources.cranialVisibilityCountBuffers[slot].contents(),
      0,
      crowCranialVisibilityCounterCount * MemoryLayout<UInt32>.stride
    )
    memset(
      retainedResources.cranialVisibilityIndirectBuffers[slot].contents(),
      0,
      (CrowBodyVaneRecords.productionTopologies.count + 1)
        * MemoryLayout<DrawPrimitivesIndirectArguments>.stride
    )
    var uniforms = Self.cranialVisibilityUniforms(
      viewProjection: viewProjection,
      projectedPixelsPerMeter: frame.batches.first?.projectedPixelsPerMeter ?? 0,
      previousViewProjection: previousViewProjection,
      occlusionViewport: occlusionViewport,
      occlusionEnabled: previousDepthPyramid != nil
    )
    guard let classify = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow cranial visibility encoder")
    }
    classify.label = "Classify retained cranial visibility"
    classify.setBuffer(morphologyBuffer, offset: 0, index: 0)
    classify.setBuffer(poseBuffers[slot], offset: 0, index: 1)
    classify.setBuffer(neckTransformBuffers[slot], offset: 0, index: 2)
    classify.setBuffer(
      retainedResources.cranialVisibilityTopologyBuffers[slot],
      offset: 0,
      index: 3
    )
    classify.setTexture(
      previousDepthPyramid ?? retainedResources.fallbackDepthTexture,
      index: 0
    )
    classify.setBytes(
      &uniforms,
      length: MemoryLayout<CrowCranialVisibilityUniforms>.stride,
      index: 4
    )
    backend.dispatch1D(
      classify,
      pipeline: retainedResources.cranialVisibilityClassifyPipeline,
      count: CrowBodyVaneRecords.cranialMorphologyRecordCount
    )
    classify.endEncoding()

    guard let scan = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow cranial visibility scan")
    }
    scan.label = "Scan retained cranial visibility"
    scan.setBuffer(morphologyBuffer, offset: 0, index: 0)
    scan.setBuffer(
      retainedResources.cranialVisibilityTopologyBuffers[slot], offset: 0, index: 1
    )
    scan.setBuffer(
      retainedResources.cranialVisibilityOffsetBuffers[slot], offset: 0, index: 2
    )
    scan.setBuffer(
      retainedResources.cranialGularOffsetBuffers[slot], offset: 0, index: 3
    )
    scan.setBuffer(
      retainedResources.cranialVisibilityCountBuffers[slot], offset: 0, index: 4
    )
    scan.setBytes(
      &uniforms,
      length: MemoryLayout<CrowCranialVisibilityUniforms>.stride,
      index: 5
    )
    backend.dispatch1D(
      scan, pipeline: retainedResources.cranialVisibilityScanPipeline, count: 1
    )
    scan.endEncoding()

    guard let emit = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow cranial compact work encoder")
    }
    emit.label = "Emit compact retained cranial work"
    emit.setBuffer(
      retainedResources.cranialVisibilityTopologyBuffers[slot], offset: 0, index: 1
    )
    emit.setBuffer(
      retainedResources.cranialVisibilityOffsetBuffers[slot], offset: 0, index: 2
    )
    emit.setBuffer(
      retainedResources.cranialGularOffsetBuffers[slot], offset: 0, index: 3
    )
    emit.setBuffer(
      retainedResources.cranialVisibilityCountBuffers[slot], offset: 0, index: 4
    )
    emit.setBuffer(
      retainedResources.cranialVisibilityWorkBuffers[slot], offset: 0, index: 5
    )
    emit.setBuffer(
      retainedResources.cranialGularWorkBuffers[slot], offset: 0, index: 6
    )
    emit.setBytes(
      &uniforms,
      length: MemoryLayout<CrowCranialVisibilityUniforms>.stride,
      index: 7
    )
    backend.dispatch1D(
      emit,
      pipeline: retainedResources.cranialVisibilityEmitPipeline,
      count: CrowBodyVaneRecords.cranialMorphologyRecordCount
    )
    emit.endEncoding()

    guard let prepare = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow cranial indirect-work encoder")
    }
    prepare.label = "Prepare compact cranial and gular indirect draws"
    prepare.setBuffer(
      retainedResources.cranialVisibilityCountBuffers[slot], offset: 0, index: 0
    )
    prepare.setBuffer(
      retainedResources.cranialVisibilityIndirectBuffers[slot], offset: 0, index: 1
    )
    backend.dispatch1D(
      prepare,
      pipeline: retainedResources.cranialVisibilityIndirectPipeline,
      count: CrowBodyVaneRecords.productionTopologies.count + 1
    )
    prepare.endEncoding()

    let visibilityFrame = CrowCranialVisibilityFrame(
      slot: slot,
      workBuffer: retainedResources.cranialVisibilityWorkBuffers[slot],
      gularWorkBuffer: retainedResources.cranialGularWorkBuffers[slot],
      indirectDrawBuffer: retainedResources.cranialVisibilityIndirectBuffers[slot],
      countBuffer: retainedResources.cranialVisibilityCountBuffers[slot]
    )
    retainedResources.frames[slot] = visibilityFrame
    return visibilityFrame
  }

  func cranialVisibilityFrame(
    for frame: CrowBodyVaneGeometryFrame
  ) -> CrowCranialVisibilityFrame? {
    CrowCranialVisibilityResourceCache.shared.existing(for: backend)?
      .frames[frame.slot]
  }

  func bindCranialRenderResources(
    for batch: CrowBodyVaneGeometryBatchFrame,
    visibility: CrowCranialVisibilityFrame,
    gular: Bool = false,
    encoder: MTLRenderCommandEncoder
  ) {
    var uniforms = CrowBodyVaneGeometryUniforms(
      counts: SIMD4<UInt32>(
        UInt32(batch.topology.axialSections),
        UInt32(batch.topology.widthSections),
        0,
        UInt32(batch.vertexCount)
      ),
      selection: SIMD4<Float>(batch.projectedPixelsPerMeter, 0, 0, 0)
    )
    encoder.setVertexBuffer(batch.morphologyBuffer, offset: 0, index: 0)
    encoder.setVertexBuffer(
      gular ? visibility.gularWorkBuffer : visibility.workBuffer,
      offset: 0,
      index: 1
    )
    encoder.setVertexBytes(
      &uniforms,
      length: MemoryLayout<CrowBodyVaneGeometryUniforms>.stride,
      index: 2
    )
    encoder.setVertexBuffer(batch.poseBuffer, offset: 0, index: 4)
    encoder.setVertexBuffer(batch.neckTransformBuffer, offset: 0, index: 5)
  }

  func cranialVisibleRecordCount(for frame: CrowCranialVisibilityFrame) -> Int {
    Int(
      frame.countBuffer.contents().bindMemory(
        to: UInt32.self,
        capacity: crowCranialVisibilityCounterCount
      )[CrowBodyVaneRecords.productionTopologies.count]
    )
  }

  func gularVisibleRecordCount(for frame: CrowCranialVisibilityFrame) -> Int {
    Int(
      frame.countBuffer.contents().bindMemory(
        to: UInt32.self,
        capacity: crowCranialVisibilityCounterCount
      )[CrowBodyVaneRecords.productionTopologies.count + 1]
    )
  }

  func cranialFrustumVisibleRecordCount(
    for frame: CrowCranialVisibilityFrame
  ) -> Int {
    cranialVisibilityCounter(
      frame, index: CrowBodyVaneRecords.productionTopologies.count + 2
    )
  }

  func gularFrustumVisibleRecordCount(
    for frame: CrowCranialVisibilityFrame
  ) -> Int {
    cranialVisibilityCounter(
      frame, index: CrowBodyVaneRecords.productionTopologies.count + 3
    )
  }

  func cranialOcclusionCulledRecordCount(
    for frame: CrowCranialVisibilityFrame
  ) -> Int {
    cranialVisibilityCounter(
      frame, index: CrowBodyVaneRecords.productionTopologies.count + 4
    )
  }

  func cranialOcclusionTestedRecordCount(
    for frame: CrowCranialVisibilityFrame
  ) -> Int {
    cranialVisibilityCounter(
      frame, index: CrowBodyVaneRecords.productionTopologies.count + 5
    )
  }

  func gularOcclusionCulledRecordCount(
    for frame: CrowCranialVisibilityFrame
  ) -> Int {
    cranialVisibilityCounter(
      frame, index: CrowBodyVaneRecords.productionTopologies.count + 6
    )
  }

  func gularOcclusionTestedRecordCount(
    for frame: CrowCranialVisibilityFrame
  ) -> Int {
    cranialVisibilityCounter(
      frame, index: CrowBodyVaneRecords.productionTopologies.count + 7
    )
  }

  func cranialVisibleRecordIndices(
    for frame: CrowCranialVisibilityFrame
  ) -> [UInt32] {
    let count = cranialVisibleRecordCount(for: frame)
    let pointer = frame.workBuffer.contents().bindMemory(
      to: UInt32.self,
      capacity: CrowBodyVaneRecords.cranialMorphologyRecordCount
    )
    return Array(UnsafeBufferPointer(start: pointer, count: count))
  }

  func gularVisibleRecordIndices(
    for frame: CrowCranialVisibilityFrame
  ) -> [UInt32] {
    let count = gularVisibleRecordCount(for: frame)
    let pointer = frame.gularWorkBuffer.contents().bindMemory(
      to: UInt32.self,
      capacity: CrowBodyVaneRecords.cranialMorphologyRecordCount
    )
    return Array(UnsafeBufferPointer(start: pointer, count: count))
  }

  func cranialExpandedVertexCount(for frame: CrowCranialVisibilityFrame) -> Int {
    let arguments = frame.indirectDrawBuffer.contents().bindMemory(
      to: DrawPrimitivesIndirectArguments.self,
      capacity: CrowBodyVaneRecords.productionTopologies.count + 1
    )
    return (0..<CrowBodyVaneRecords.productionTopologies.count).reduce(0) {
      $0 + Int(arguments[$1].vertexCount) * Int(arguments[$1].instanceCount)
    }
  }

  func gularExpandedVertexCount(for frame: CrowCranialVisibilityFrame) -> Int {
    let argument = frame.indirectDrawBuffer.contents().advanced(
      by: CrowBodyVaneRecords.productionTopologies.count
        * MemoryLayout<DrawPrimitivesIndirectArguments>.stride
    ).bindMemory(to: DrawPrimitivesIndirectArguments.self, capacity: 1).pointee
    return Int(argument.vertexCount) * Int(argument.instanceCount)
  }

  private func cranialVisibilityCounter(
    _ frame: CrowCranialVisibilityFrame,
    index: Int
  ) -> Int {
    precondition(index >= 0 && index < crowCranialVisibilityCounterCount)
    return Int(
      frame.countBuffer.contents().bindMemory(
        to: UInt32.self,
        capacity: crowCranialVisibilityCounterCount
      )[index]
    )
  }

  private static func cranialVisibilityUniforms(
    viewProjection: simd_float4x4,
    projectedPixelsPerMeter: Float,
    previousViewProjection: simd_float4x4,
    occlusionViewport: SIMD2<Int>,
    occlusionEnabled: Bool
  ) -> CrowCranialVisibilityUniforms {
    let row0 = SIMD4<Float>(
      viewProjection.columns.0.x, viewProjection.columns.1.x,
      viewProjection.columns.2.x, viewProjection.columns.3.x
    )
    let row1 = SIMD4<Float>(
      viewProjection.columns.0.y, viewProjection.columns.1.y,
      viewProjection.columns.2.y, viewProjection.columns.3.y
    )
    let row2 = SIMD4<Float>(
      viewProjection.columns.0.z, viewProjection.columns.1.z,
      viewProjection.columns.2.z, viewProjection.columns.3.z
    )
    let row3 = SIMD4<Float>(
      viewProjection.columns.0.w, viewProjection.columns.1.w,
      viewProjection.columns.2.w, viewProjection.columns.3.w
    )
    func plane(_ value: SIMD4<Float>) -> SIMD4<Float> {
      let length = simd_length(SIMD3<Float>(value.x, value.y, value.z))
      return length > 1e-12 ? value / length : value
    }
    return CrowCranialVisibilityUniforms(
      leftPlane: plane(row3 + row0),
      rightPlane: plane(row3 - row0),
      bottomPlane: plane(row3 + row1),
      topPlane: plane(row3 - row1),
      nearPlane: plane(row2),
      farPlane: plane(row3 - row2),
      selection: SIMD4<Float>(projectedPixelsPerMeter, 0.0015, 0, 0),
      counts: SIMD4<UInt32>(
        UInt32(CrowBodyVaneRecords.cranialMorphologyBase),
        UInt32(CrowBodyVaneRecords.cranialMorphologyRecordCount),
        UInt32(CrowBodyVaneRecords.productionTopologies.count),
        0x8
      ),
      previousViewProjection: previousViewProjection,
      occlusionViewportBiasAndEnabled: SIMD4<Float>(
        Float(occlusionViewport.x),
        Float(occlusionViewport.y),
        CrowVentralBarbCurveRecords.previousDepthBias,
        occlusionEnabled ? 1 : 0
      )
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
    Int(
      topologyCounts(for: frame)[
        CrowBodyVaneRecords.productionTopologies.count
      ]
    )
  }

  func expandedVertexCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    frame.batches.reduce(0) {
      $0 + Int(drawArguments(for: $1).vertexCount)
        * Int(drawArguments(for: $1).instanceCount)
    }
  }

  func activeVentralRecordCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    frame.batches.indices.reduce(0) { partial, topologyIndex in
      partial + selectedRecordIndices(for: frame, topologyIndex: topologyIndex)
        .count {
          Int($0) >= CrowBodyVaneRecords.bodyMorphologyRecordCount
            && Int($0) < CrowBodyVaneRecords.bodyMorphologyRecordCount
              + CrowBodyVaneRecords.ventralMorphologyRecordCount
        }
    }
  }

  func expandedVentralVertexCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    frame.batches.enumerated().reduce(0) { partial, pair in
      let selected = selectedRecordIndices(
        for: frame,
        topologyIndex: pair.offset
      ).count {
        Int($0) >= CrowBodyVaneRecords.bodyMorphologyRecordCount
          && Int($0) < CrowBodyVaneRecords.bodyMorphologyRecordCount
            + CrowBodyVaneRecords.ventralMorphologyRecordCount
      }
      return partial + selected * pair.element.vertexCount
    }
  }

  func activeFemoralRecordCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    let base = CrowBodyVaneRecords.bodyMorphologyRecordCount
      + CrowBodyVaneRecords.ventralMorphologyRecordCount
    let end = base + CrowBodyVaneRecords.femoralMorphologyRecordCount
    return frame.batches.indices.reduce(0) { partial, topologyIndex in
      partial + selectedRecordIndices(for: frame, topologyIndex: topologyIndex)
        .count { Int($0) >= base && Int($0) < end }
    }
  }

  func expandedFemoralVertexCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    let base = CrowBodyVaneRecords.bodyMorphologyRecordCount
      + CrowBodyVaneRecords.ventralMorphologyRecordCount
    let end = base + CrowBodyVaneRecords.femoralMorphologyRecordCount
    return frame.batches.enumerated().reduce(0) { partial, pair in
      let selected = selectedRecordIndices(
        for: frame,
        topologyIndex: pair.offset
      ).count { Int($0) >= base && Int($0) < end }
      return partial + selected * pair.element.vertexCount
    }
  }

  func activeCruralRecordCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    let base = CrowBodyVaneRecords.bodyMorphologyRecordCount
      + CrowBodyVaneRecords.ventralMorphologyRecordCount
      + CrowBodyVaneRecords.femoralMorphologyRecordCount
    let end = base + CrowBodyVaneRecords.cruralMorphologyRecordCount
    return frame.batches.indices.reduce(0) { partial, topologyIndex in
      partial + selectedRecordIndices(for: frame, topologyIndex: topologyIndex)
        .count { Int($0) >= base && Int($0) < end }
    }
  }

  func expandedCruralVertexCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    let base = CrowBodyVaneRecords.bodyMorphologyRecordCount
      + CrowBodyVaneRecords.ventralMorphologyRecordCount
      + CrowBodyVaneRecords.femoralMorphologyRecordCount
    let end = base + CrowBodyVaneRecords.cruralMorphologyRecordCount
    return frame.batches.enumerated().reduce(0) { partial, pair in
      let selected = selectedRecordIndices(
        for: frame,
        topologyIndex: pair.offset
      ).count { Int($0) >= base && Int($0) < end }
      return partial + selected * pair.element.vertexCount
    }
  }

  func activeThroatBridgeRecordCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    let base = CrowBodyVaneRecords.bodyMorphologyRecordCount
      + CrowBodyVaneRecords.ventralMorphologyRecordCount
      + CrowBodyVaneRecords.femoralMorphologyRecordCount
      + CrowBodyVaneRecords.cruralMorphologyRecordCount
    let end = base + CrowBodyVaneRecords.throatBridgeMorphologyRecordCount
    return frame.batches.indices.reduce(0) { partial, topologyIndex in
      partial + selectedRecordIndices(for: frame, topologyIndex: topologyIndex)
        .count { Int($0) >= base && Int($0) < end }
    }
  }

  func expandedThroatBridgeVertexCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    let base = CrowBodyVaneRecords.bodyMorphologyRecordCount
      + CrowBodyVaneRecords.ventralMorphologyRecordCount
      + CrowBodyVaneRecords.femoralMorphologyRecordCount
      + CrowBodyVaneRecords.cruralMorphologyRecordCount
    let end = base + CrowBodyVaneRecords.throatBridgeMorphologyRecordCount
    return frame.batches.enumerated().reduce(0) { partial, pair in
      let selected = selectedRecordIndices(
        for: frame,
        topologyIndex: pair.offset
      ).count { Int($0) >= base && Int($0) < end }
      return partial + selected * pair.element.vertexCount
    }
  }

  func activeCranialRecordCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    let base = CrowBodyVaneRecords.bodyMorphologyRecordCount
      + CrowBodyVaneRecords.ventralMorphologyRecordCount
      + CrowBodyVaneRecords.femoralMorphologyRecordCount
      + CrowBodyVaneRecords.cruralMorphologyRecordCount
      + CrowBodyVaneRecords.throatBridgeMorphologyRecordCount
    return frame.batches.indices.reduce(0) { partial, topologyIndex in
      partial + selectedRecordIndices(for: frame, topologyIndex: topologyIndex)
        .count { Int($0) >= base }
    }
  }

  func expandedCranialVertexCount(for frame: CrowBodyVaneGeometryFrame) -> Int {
    let base = CrowBodyVaneRecords.bodyMorphologyRecordCount
      + CrowBodyVaneRecords.ventralMorphologyRecordCount
      + CrowBodyVaneRecords.femoralMorphologyRecordCount
      + CrowBodyVaneRecords.cruralMorphologyRecordCount
      + CrowBodyVaneRecords.throatBridgeMorphologyRecordCount
    return frame.batches.enumerated().reduce(0) { partial, pair in
      let selected = selectedRecordIndices(
        for: frame,
        topologyIndex: pair.offset
      ).count { Int($0) >= base }
      return partial + selected * pair.element.vertexCount
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
    let count = CrowBodyVaneRecords.productionTopologies.count + 1
    let pointer = topologyCountBuffers[frame.slot].contents().bindMemory(
      to: UInt32.self,
      capacity: count
    )
    return Array(UnsafeBufferPointer(start: pointer, count: count))
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

  // Keep the temporary SIMD arrays alive across their shared-buffer copies.
  // Inlining this block into the large release encoder has previously exposed
  // an optimizer lifetime bug before the Metal command is committed.
  @inline(never)
  private func writePoseInputs(
    slot: Int,
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    currentNeckPose: CrowStandingNeckPose?,
    previousNeckPose: CrowStandingNeckPose?,
    cranialRadii: SIMD3<Float>?,
    currentCranialBreathingScale: Float?,
    previousCranialBreathingScale: Float?,
    currentFemoralPose: CrowFemoralVanePoseSample?,
    previousFemoralPose: CrowFemoralVanePoseSample?,
    currentDeployment: Float,
    previousDeployment: Float,
    currentBodyContourPhase: Float?,
    previousBodyContourPhase: Float?
  ) -> Int {
    var pose = CrowBodyVanePoseUniforms(
      currentBodyCenterAndDeployment: SIMD4<Float>(
        currentBodyCenter,
        currentDeployment
      ),
      previousBodyCenterAndDeployment: SIMD4<Float>(
        previousBodyCenter,
        previousDeployment
      ),
      currentCranialRadiiAndBreathing: SIMD4<Float>(
        cranialRadii ?? .zero,
        currentCranialBreathingScale ?? 1
      ),
      previousCranialRadiiAndBreathing: SIMD4<Float>(
        cranialRadii ?? .zero,
        previousCranialBreathingScale ?? 1
      ),
      currentNeckTranslationAndYaw: SIMD4<Float>(
        currentNeckPose?.translation ?? .zero,
        currentNeckPose?.yawRadians ?? 0
      ),
      currentNeckPitchRollAndActive: SIMD4<Float>(
        currentNeckPose?.pitchRadians ?? 0,
        currentNeckPose?.rollRadians ?? 0,
        currentNeckPose == nil ? 0 : 1,
        0
      ),
      previousNeckTranslationAndYaw: SIMD4<Float>(
        previousNeckPose?.translation ?? .zero,
        previousNeckPose?.yawRadians ?? 0
      ),
      previousNeckPitchRollAndActive: SIMD4<Float>(
        previousNeckPose?.pitchRadians ?? 0,
        previousNeckPose?.rollRadians ?? 0,
        previousNeckPose == nil ? 0 : 1,
        0
      ),
      currentBodyContourPhaseAndActive: SIMD4<Float>(
        currentBodyContourPhase ?? 0,
        currentBodyContourPhase == nil ? 0 : 1,
        0,
        0
      ),
      previousBodyContourPhaseAndActive: SIMD4<Float>(
        previousBodyContourPhase ?? 0,
        previousBodyContourPhase == nil ? 0 : 1,
        0,
        0
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
    let throatBridgeTransforms = CrowBodyVaneRecords.throatBridgeTransforms(
      current: currentNeckPose,
      previous: previousNeckPose
    )
    throatBridgeTransforms.withUnsafeBytes { bytes in
      if let baseAddress = bytes.baseAddress, !bytes.isEmpty {
        memcpy(
          neckTransformBuffers[slot].contents().advanced(
            by: neckTransforms.count
              * MemoryLayout<CrowBodyVaneNeckTransformGPU>.stride
          ),
          baseAddress,
          bytes.count
        )
      }
    }
    let limbPoseValues = [
      SIMD4<Float>(
        currentFemoralPose?.leftHip ?? .zero,
        currentFemoralPose == nil ? 0 : 1
      ),
      SIMD4<Float>(currentFemoralPose?.leftHock ?? .zero, 0),
      SIMD4<Float>(
        currentFemoralPose?.rightHip ?? .zero,
        currentFemoralPose == nil ? 0 : 1
      ),
      SIMD4<Float>(currentFemoralPose?.rightHock ?? .zero, 0),
      SIMD4<Float>(
        previousFemoralPose?.leftHip ?? .zero,
        previousFemoralPose == nil ? 0 : 1
      ),
      SIMD4<Float>(previousFemoralPose?.leftHock ?? .zero, 0),
      SIMD4<Float>(
        previousFemoralPose?.rightHip ?? .zero,
        previousFemoralPose == nil ? 0 : 1
      ),
      SIMD4<Float>(previousFemoralPose?.rightHock ?? .zero, 0),
    ]
    limbPoseValues.withUnsafeBytes { bytes in
      if let baseAddress = bytes.baseAddress, !bytes.isEmpty {
        memcpy(
          neckTransformBuffers[slot].contents().advanced(by: neckTransforms.count
            * MemoryLayout<CrowBodyVaneNeckTransformGPU>.stride
            + throatBridgeTransforms.count
            * MemoryLayout<CrowBodyVaneNeckTransformGPU>.stride),
          baseAddress,
          bytes.count
        )
      }
    }
    return MemoryLayout<CrowBodyVanePoseUniforms>.stride
      + neckTransforms.count * MemoryLayout<CrowBodyVaneNeckTransformGPU>.stride
      + throatBridgeTransforms.count
      * MemoryLayout<CrowBodyVaneNeckTransformGPU>.stride
      + limbPoseValues.count * MemoryLayout<SIMD4<Float>>.stride
  }

  private func ensureDetailSegmentCapacity(
    projectedPixelsPerMeter: Float
  ) throws {
    let requiredCapacity = maximumMorphologyLength * projectedPixelsPerMeter >= 480
      ? 167 : 43
    guard requiredCapacity > detailSegmentCapacityPerRecord else { return }
    detailSegmentBuffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(
        length: Self.detailSegmentBufferLength(
          bodyCapacity: requiredCapacity
        )
      )
    }
    detailSegmentCapacityPerRecord = requiredCapacity
    detailSegmentBufferAllocationCount += Self.bufferedFrameCount
  }

  private static func detailSegmentBufferLength(
    bodyCapacity: Int
  ) -> Int {
    CrowBodyVaneRecords.bodyTractMorphologyRecordCount * bodyCapacity
      * MemoryLayout<CrowBodyDetailSegmentGPU>.stride
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
  static let bodyTractMorphologyRecordCount = 3_212
  static let bodyContourMorphologyRecordCount = CrowBodyContourShingles.radialCount
    * CrowBodyContourShingles.axialCount
  static let bodyMorphologyRecordCount = bodyTractMorphologyRecordCount
    + bodyContourMorphologyRecordCount
  static let ventralMorphologyRecordCount = 1_304
  static let femoralMorphologyRecordCount = 2
    * CrowFemoralPlumage.rowCount * CrowFemoralPlumage.courseCount
  static let cruralMorphologyRecordCount = 2
    * CrowLegPlumage.radialCount * CrowLegPlumage.stationCount
  static let throatBridgeMorphologyRecordCount = 2
    * CrowThroatBridgeFeathers.rowCount * CrowThroatBridgeFeathers.columnCount
  static let cranialMorphologyBase = bodyMorphologyRecordCount
    + ventralMorphologyRecordCount
    + femoralMorphologyRecordCount
    + cruralMorphologyRecordCount
    + throatBridgeMorphologyRecordCount
  static let cranialMorphologyRecordCount = CrowCranialFeatherTracts
    .morphologySamples().count
  static let gularMorphologyRecordCount = CrowCranialFeatherTracts
    .morphologySamples().count { $0.region == .throat }
  /// Body topologies stay first. Because body morphology precedes ventral
  /// morphology, compact body work remains a prefix of the shared work list;
  /// body-only rachis/detail buffers can therefore retain their original
  /// capacity while limb-only bins remain vane-only.
  static let productionTopologies: [CrowBodyVaneTopology] = [
    CrowBodyVaneTopology(axialSections: 3, widthSections: 1),
    CrowBodyVaneTopology(axialSections: 4, widthSections: 1),
    CrowBodyVaneTopology(axialSections: 6, widthSections: 5),
    CrowBodyVaneTopology(axialSections: 8, widthSections: 5),
    CrowBodyVaneTopology(axialSections: 10, widthSections: 5),
    CrowBodyVaneTopology(axialSections: 12, widthSections: 5),
    CrowBodyVaneTopology(axialSections: 16, widthSections: 7),
    CrowBodyVaneTopology(axialSections: 24, widthSections: 9),
    CrowBodyVaneTopology(axialSections: 7, widthSections: 3),
    CrowBodyVaneTopology(axialSections: 11, widthSections: 5),
    CrowBodyVaneTopology(axialSections: 8, widthSections: 3),
    CrowBodyVaneTopology(axialSections: 6, widthSections: 3),
  ]

  static func rachisSections(for topology: CrowBodyVaneTopology) -> Int {
    switch topology.axialSections {
    case ...4: 0
    case 5...8: 4
    case 9...12: 8
    case 13...20: 12
    default: 18
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
    case 5...8: 43
    case 9...12: 41
    default: 167
    }
  }

  static func detailVerticesPerInstance(
    for topology: CrowBodyVaneTopology
  ) -> Int {
    detailSegmentCount(for: topology) * 18
  }

  static func morphologyRecords() -> [CrowBodyVaneMorphologyGPU] {
    CrowBodyFeatherTracts.samples(
      appliesCervicalTerminalFlow: false
    ).enumerated().map { index, sample in
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

  /// Dense roof-tile body coverage joins the same immutable GPU inventory as
  /// tract vanes. Its CPU underlayer/detail oracle remains separately owned
  /// until it too has an equivalent retained expansion path.
  static func bodyContourMorphologyRecords() -> [CrowBodyVaneMorphologyGPU] {
    CrowBodyContourShingles.samples().enumerated().map { index, shingle in
      let material = shingle.materialVariation
      let identity = SIMD4<UInt32>(
        0x0100,
        UInt32(shingle.radialIndex),
        UInt32(shingle.axialIndex),
        shingle.surfaceFeatherClass
      )
      return CrowBodyVaneMorphologyGPU(
        rootAndRootWidth: SIMD4<Float>(shingle.rootOffset, shingle.rootWidthMeters),
        tipAndMaximumWidth: SIMD4<Float>(shingle.tipOffset, shingle.maximumWidthMeters),
        normalAndCamber: SIMD4<Float>(shingle.planeNormal, shingle.camberMeters),
        sweepAsymmetryAndRipple: SIMD4<Float>(
          shingle.lateralSweepMeters, shingle.vaneAsymmetry,
          shingle.edgeRippleAmplitude, shingle.edgeRipplePhase
        ),
        envelopeAndTaper: SIMD4<Float>(
          shingle.edgeRippleCycles, 0.32, 0.015, 3.2
        ),
        color: SIMD4<Float>(
          0.006 * (1 + 0.10 * material),
          0.009 * (1 + 0.075 * material),
          0.016 * (1 + 0.055 * material),
          0.14 + 0.012 * material
        ),
        morphology: SIMD4<Float>(
          shingle.pennaceousStartFraction, 4,
          Float(shingle.radialIndex), Float(shingle.axialIndex)
        ),
        identity: SIMD4<UInt32>(
          0x0100_0000 | UInt32(index), stableHash(identity),
          shingle.transverseCamberRatio.bitPattern, shingle.surfaceFeatherClass
        )
      )
    }
  }

  static func bodyVaneMorphologyRecords() -> [CrowBodyVaneMorphologyGPU] {
    morphologyRecords() + bodyContourMorphologyRecords()
  }

  /// The production inventory retains both dorsal/body contour vanes and the
  /// complete bilateral pectoral/abdominal vane owner. Ventral records use a
  /// separate identity namespace and share only the procedural vane raster;
  /// their rachis and barb hierarchy remain owned by the dedicated retained
  /// ventral curve systems.
  static func retainedMorphologyRecords() -> [CrowBodyVaneMorphologyGPU] {
    bodyVaneMorphologyRecords() + ventralMorphologyRecords()
      + femoralMorphologyRecords()
      + cruralMorphologyRecords()
      + throatBridgeMorphologyRecords()
      + cranialMorphologyRecords()
  }

  static func ventralMorphologyRecords() -> [CrowBodyVaneMorphologyGPU] {
    CrowVentralFeatherTracts.samples().enumerated().map { index, sample in
      CrowBodyVaneMorphologyGPU(
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
          0.015,
          3.2
        ),
        color: ventralColor(for: sample),
        morphology: SIMD4<Float>(
          sample.pennaceousStartFraction,
          sample.lodReferenceLengthMeters,
          Float(sample.row),
          Float(sample.column)
        ),
        identity: SIMD4<UInt32>(
          0x0300_0000 | UInt32(index),
          stableHash(ventralIdentity(of: sample)),
          (CrowVentralFeatherTracts.transverseCamberRatio
            * CrowVentralFeatherTracts.transverseCamberScale(for: sample))
            .bitPattern,
          sample.surfaceFeatherClass
        )
      )
    }
  }

  static func femoralMorphologyRecords() -> [CrowBodyVaneMorphologyGPU] {
    [-Float(1), Float(1)].flatMap { side in
      CrowFemoralPlumage.morphologySamples(side: side)
    }.enumerated().map { index, sample in
      CrowBodyVaneMorphologyGPU(
        rootAndRootWidth: SIMD4<Float>(
          sample.rootSurfaceOffset,
          sample.rootWidthRatio
        ),
        tipAndMaximumWidth: SIMD4<Float>(
          sample.localNormal,
          sample.maximumWidthScale
        ),
        normalAndCamber: SIMD4<Float>(
          sample.targetFraction,
          sample.targetRadiusMeters,
          sample.tipRadialLiftMeters,
          sample.tipTangentialSweepMeters
        ),
        sweepAsymmetryAndRipple: SIMD4<Float>(
          sample.lateralSweepRatio,
          sample.vaneAsymmetry,
          sample.edgeRippleAmplitude,
          sample.edgeRipplePhase
        ),
        envelopeAndTaper: SIMD4<Float>(
          sample.edgeRippleCycles,
          CrowFemoralPlumage.visibleRootEnvelopeRatio,
          0.015,
          3.2
        ),
        color: femoralColor(for: sample),
        morphology: SIMD4<Float>(
          0,
          CrowFemoralPlumage.topologyLODReferenceLengthMeters,
          sample.lengthScale,
          sample.camberMeters
        ),
        identity: SIMD4<UInt32>(
          0x0400_0000 | UInt32(index),
          stableHash(femoralIdentity(of: sample)),
          1,
          CrowFemoralPlumage.surfaceFeatherClass
        )
      )
    }
  }

  static func cruralMorphologyRecords() -> [CrowBodyVaneMorphologyGPU] {
    [-Float(1), Float(1)].flatMap { side in
      CrowLegPlumage.morphologySamples(side: side)
    }.enumerated().map { index, sample in
      CrowBodyVaneMorphologyGPU(
        rootAndRootWidth: SIMD4<Float>(
          sample.rootFraction,
          sample.theta,
          sample.tipFraction,
          sample.rootWidthMeters
        ),
        tipAndMaximumWidth: SIMD4<Float>(
          sample.tipAngularSweep,
          sample.tipRadialLiftMeters,
          sample.side,
          sample.maximumWidthMeters
        ),
        normalAndCamber: SIMD4<Float>(0, 0, 0, sample.camberMeters),
        sweepAsymmetryAndRipple: SIMD4<Float>(
          sample.lateralSweepMeters,
          sample.vaneAsymmetry,
          sample.edgeRippleAmplitude,
          sample.edgeRipplePhase
        ),
        envelopeAndTaper: SIMD4<Float>(
          sample.edgeRippleCycles,
          CrowLegPlumage.visibleRootEnvelopeRatio,
          0.015,
          3.2
        ),
        color: cruralColor(for: sample),
        morphology: SIMD4<Float>(
          0,
          CrowLegPlumage.topologyLODReferenceLengthMeters,
          Float(sample.radialIndex),
          Float(sample.stationIndex)
        ),
        identity: SIMD4<UInt32>(
          0x0500_0000 | UInt32(index),
          stableHash(cruralIdentity(of: sample)),
          1,
          CrowLegPlumage.surfaceFeatherClass
        )
      )
    }
  }

  static func throatBridgeMorphologyRecords() -> [CrowBodyVaneMorphologyGPU] {
    CrowThroatBridgeFeathers.morphologySamples().enumerated().map { index, sample in
      let material = sample.materialVariation
      return CrowBodyVaneMorphologyGPU(
        rootAndRootWidth: SIMD4<Float>(sample.rootOffset, sample.rootWidthMeters),
        tipAndMaximumWidth: SIMD4<Float>(sample.tipOffset, sample.maximumWidthMeters),
        normalAndCamber: SIMD4<Float>(sample.planeNormal, sample.camberMeters),
        sweepAsymmetryAndRipple: SIMD4<Float>(
          0,
          0.035 * material,
          0.018 + 0.008 * abs(material),
          Float.pi * (material + 1)
        ),
        envelopeAndTaper: SIMD4<Float>(
          1.5,
          CrowThroatBridgeFeathers.visibleRootEnvelopeRatio,
          0.015,
          3.2
        ),
        color: throatBridgeColor(for: sample),
        morphology: SIMD4<Float>(
          CrowThroatBridgeFeathers.pennaceousStartFraction,
          simd_distance(sample.rootOffset, sample.tipOffset),
          Float(sample.column),
          Float(sample.row)
        ),
        identity: SIMD4<UInt32>(
          0x0600_0000 | UInt32(index),
          stableHash(throatBridgeIdentity(of: sample)),
          Float(0.12).bitPattern,
          sample.surfaceFeatherClass
        )
      )
    }
  }

  static func cranialMorphologyRecords() -> [CrowBodyVaneMorphologyGPU] {
    CrowCranialFeatherTracts.morphologySamples().enumerated().map { index, sample in
      let ring = sample.ring
      let previous = sample.previousRing
      let next = sample.nextRing
      let material = sample.materialIdentity
      let gularBlend = CrowCranialFeatherTracts.gularBridgeMaterialBlend(
        region: sample.region,
        ring: ring
      )
      return CrowBodyVaneMorphologyGPU(
        rootAndRootWidth: SIMD4<Float>(
          ring.axialFraction,
          ring.verticalFraction,
          ring.halfWidthFraction,
          ring.dorsalRadiusFraction
        ),
        tipAndMaximumWidth: SIMD4<Float>(
          ring.ventralRadiusFraction,
          previous.axialFraction,
          previous.verticalFraction,
          previous.halfWidthFraction
        ),
        normalAndCamber: SIMD4<Float>(
          previous.dorsalRadiusFraction,
          previous.ventralRadiusFraction,
          next.axialFraction,
          next.verticalFraction
        ),
        sweepAsymmetryAndRipple: SIMD4<Float>(
          next.halfWidthFraction,
          next.dorsalRadiusFraction,
          next.ventralRadiusFraction,
          sample.thetaRadians
        ),
        envelopeAndTaper: SIMD4<Float>(
          CrowCranialFeatherTracts.axialLength(for: sample),
          (0.00055 + (sample.region == .nape ? 0.00020 : 0))
            * (1 + 0.08 * material),
          sample.directionIdentity,
          Float(sample.region.rawValue)
        ),
        color: SIMD4<Float>(
          0.006 * (1 + 0.08 * material),
          0.009 * (1 + 0.06 * material),
          0.015 * (1 + 0.04 * material),
          0.14 + CrowCranialFeatherTracts.gularBridgeMaterialTagScale
            * gularBlend
        ),
        morphology: SIMD4<Float>(
          0,
          CrowCranialFeatherTracts.lodReferenceLengthMeters(for: sample),
          Float(sample.axialIndex),
          Float(sample.angularIndex)
        ),
        identity: SIMD4<UInt32>(
          0x0700_0000 | UInt32(index),
          stableHash(cranialIdentity(of: sample)),
          Float(0.18).bitPattern,
          CrowCranialFeatherTracts.surfaceFeatherClass(for: sample.region)
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

  static func retainedGroupedMorphologyIndices(
    projectedPixelsPerMeter: Float,
    femoralActive: Bool = true,
    cruralActive: Bool = true,
    throatBridgeActive: Bool = true,
    cranialActive: Bool = true
  ) -> [CrowBodyVaneTopology: [Int]] {
    var grouped = groupedMorphologyIndices(
      projectedPixelsPerMeter: projectedPixelsPerMeter
    )
    for (index, sample) in CrowBodyContourShingles.samples().enumerated()
    where isVisible(sample, projectedPixelsPerMeter: projectedPixelsPerMeter) {
      grouped[
        topology(for: sample, projectedPixelsPerMeter: projectedPixelsPerMeter),
        default: []
      ].append(bodyTractMorphologyRecordCount + index)
    }
    let bodyCount = bodyMorphologyRecordCount
    for (index, sample) in CrowVentralFeatherTracts.samples().enumerated()
    where isVisible(sample, projectedPixelsPerMeter: projectedPixelsPerMeter) {
      grouped[
        topology(for: sample, projectedPixelsPerMeter: projectedPixelsPerMeter),
        default: []
      ].append(bodyCount + index)
    }
    if femoralActive && projectedPixelsPerMeter >= 1_400 {
      let femoralBase = bodyCount + ventralMorphologyRecordCount
      let femoralTopology = limbTopology(
        referenceLengthMeters: CrowFemoralPlumage.topologyLODReferenceLengthMeters,
        projectedPixelsPerMeter: projectedPixelsPerMeter,
        isCrural: false
      )
      grouped[femoralTopology, default: []].append(
        contentsOf: (0..<femoralMorphologyRecordCount).map {
          femoralBase + $0
        }
      )
    }
    if cruralActive && projectedPixelsPerMeter >= 1_400 {
      let cruralBase = bodyCount + ventralMorphologyRecordCount
        + femoralMorphologyRecordCount
      let cruralTopology = limbTopology(
        referenceLengthMeters: CrowLegPlumage.topologyLODReferenceLengthMeters,
        projectedPixelsPerMeter: projectedPixelsPerMeter,
        isCrural: true
      )
      grouped[cruralTopology, default: []].append(
        contentsOf: (0..<cruralMorphologyRecordCount).map {
          cruralBase + $0
        }
      )
    }
    if throatBridgeActive && projectedPixelsPerMeter >= 1_400 {
      let throatBase = bodyCount + ventralMorphologyRecordCount
        + femoralMorphologyRecordCount + cruralMorphologyRecordCount
      for (index, record) in throatBridgeMorphologyRecords().enumerated() {
        let throatTopology = limbTopology(
          referenceLengthMeters: record.morphology.y,
          projectedPixelsPerMeter: projectedPixelsPerMeter,
          isCrural: false
        )
        grouped[throatTopology, default: []].append(throatBase + index)
      }
    }
    if cranialActive && projectedPixelsPerMeter >= 1_400 {
      let cranialBase = bodyCount + ventralMorphologyRecordCount
        + femoralMorphologyRecordCount + cruralMorphologyRecordCount
        + throatBridgeMorphologyRecordCount
      for (index, sample) in CrowCranialFeatherTracts.morphologySamples().enumerated() {
        grouped[
          cranialTopology(
            for: sample,
            projectedPixelsPerMeter: projectedPixelsPerMeter
          ),
          default: []
        ].append(cranialBase + index)
      }
    }
    return grouped
  }

  private static func cranialTopology(
    for sample: CrowCranialFeatherMorphology,
    projectedPixelsPerMeter: Float
  ) -> CrowBodyVaneTopology {
    let tessellation = CrowFeatherCoverageLOD.tessellation(
      lengthMeters: CrowCranialFeatherTracts.lodReferenceLengthMeters(for: sample),
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      baseAxialSections: sample.region == .nape ? 6 : 5
    )
    return CrowBodyVaneTopology(
      axialSections: tessellation.axialSections,
      widthSections: tessellation.widthSections
    )
  }

  private static func limbTopology(
    referenceLengthMeters: Float,
    projectedPixelsPerMeter: Float,
    isCrural: Bool
  ) -> CrowBodyVaneTopology {
    let projectedLength = max(
      0,
      referenceLengthMeters * projectedPixelsPerMeter
    )
    if projectedLength >= 1_920 {
      return CrowBodyVaneTopology(axialSections: 24, widthSections: 9)
    }
    if projectedLength >= 480 {
      return CrowBodyVaneTopology(axialSections: 16, widthSections: 7)
    }
    if projectedLength >= 120 {
      return CrowBodyVaneTopology(
        axialSections: isCrural ? 12 : 11,
        widthSections: 5
      )
    }
    if projectedLength >= 24 {
      return CrowBodyVaneTopology(
        axialSections: isCrural ? 8 : 7,
        widthSections: 3
      )
    }
    return CrowBodyVaneTopology(axialSections: 4, widthSections: 1)
  }

  static func neckTransforms(
    current: CrowStandingNeckPose?,
    previous: CrowStandingNeckPose?
  ) -> [CrowBodyVaneNeckTransformGPU] {
    transforms(for: current) + transforms(for: previous)
  }

  static func throatBridgeTransforms(
    current: CrowStandingNeckPose?,
    previous: CrowStandingNeckPose?
  ) -> [CrowBodyVaneNeckTransformGPU] {
    throatBridgeTransforms(for: current) + throatBridgeTransforms(for: previous)
  }

  private static func transforms(
    for pose: CrowStandingNeckPose?
  ) -> [CrowBodyVaneNeckTransformGPU] {
    return (0..<CrowBodyFeatherTracts.cervicalColumnCount).map { column in
      let axial = Float(column)
        / Float(CrowBodyFeatherTracts.cervicalColumnCount - 1)
      let coupling = 0.10 + 0.78 * axial
      return transform(for: pose, coupling: coupling)
    }
  }

  private static func throatBridgeTransforms(
    for pose: CrowStandingNeckPose?
  ) -> [CrowBodyVaneNeckTransformGPU] {
    (0..<CrowThroatBridgeFeathers.columnCount).map { column in
      transform(
        for: pose,
        coupling: CrowThroatBridgeFeathers.neckCoupling(column: column)
      )
    }
  }

  private static func transform(
    for pose: CrowStandingNeckPose?,
    coupling: Float
  ) -> CrowBodyVaneNeckTransformGPU {
    guard let pose else {
      return CrowBodyVaneNeckTransformGPU(
        row0: SIMD4<Float>(1, 0, 0, 0),
        row1: SIMD4<Float>(0, 1, 0, 0),
        row2: SIMD4<Float>(0, 0, 1, 0)
      )
    }
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

  static func retainedTemporalRecords(
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    currentNeckPose: CrowStandingNeckPose?,
    previousNeckPose: CrowStandingNeckPose?,
    cranialRadii: SIMD3<Float>? = nil,
    currentCranialBreathingScale: Float? = nil,
    previousCranialBreathingScale: Float? = nil,
    currentFemoralPose: CrowFemoralVanePoseSample? = nil,
    previousFemoralPose: CrowFemoralVanePoseSample? = nil,
    currentDeployment: Float,
    previousDeployment: Float
  ) -> [CrowBodyVaneRecordGPU] {
    temporalRecords(
      currentBodyCenter: currentBodyCenter,
      previousBodyCenter: previousBodyCenter,
      currentNeckPose: currentNeckPose,
      previousNeckPose: previousNeckPose,
      currentDeployment: currentDeployment,
      previousDeployment: previousDeployment
    ) + bodyContourTemporalRecords(
      currentBodyCenter: currentBodyCenter,
      previousBodyCenter: previousBodyCenter
    ) + ventralTemporalRecords(
      currentBodyCenter: currentBodyCenter,
      previousBodyCenter: previousBodyCenter
    ) + femoralTemporalRecords(
      currentPose: currentFemoralPose,
      previousPose: previousFemoralPose
    ) + cruralTemporalRecords(
      currentPose: currentFemoralPose,
      previousPose: previousFemoralPose
    ) + throatBridgeTemporalRecords(
      currentBodyCenter: currentBodyCenter,
      previousBodyCenter: previousBodyCenter,
      currentNeckPose: currentNeckPose,
      previousNeckPose: previousNeckPose
    ) + cranialTemporalRecords(
      currentBodyCenter: currentBodyCenter,
      previousBodyCenter: previousBodyCenter,
      cranialRadii: cranialRadii,
      currentBreathingScale: currentCranialBreathingScale,
      previousBreathingScale: previousCranialBreathingScale,
      currentNeckPose: currentNeckPose,
      previousNeckPose: previousNeckPose
    )
  }

  /// Static contour samples fill the retained temporal inventory so every
  /// later feather family keeps its canonical offset. Their live phase-based
  /// compliance is reconstructed by Metal from the shared pose uniforms.
  static func bodyContourTemporalRecords(
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>
  ) -> [CrowBodyVaneRecordGPU] {
    bodyContourMorphologyRecords().map { morphology in
      CrowBodyVaneRecordGPU(
        currentRootAndRootWidth: SIMD4<Float>(
          currentBodyCenter + morphology.rootAndRootWidth.xyz,
          morphology.rootAndRootWidth.w
        ),
        currentTipAndMaximumWidth: SIMD4<Float>(
          currentBodyCenter + morphology.tipAndMaximumWidth.xyz,
          morphology.tipAndMaximumWidth.w
        ),
        previousRootAndCurrentCamber: SIMD4<Float>(
          previousBodyCenter + morphology.rootAndRootWidth.xyz,
          morphology.normalAndCamber.w
        ),
        previousTipAndPreviousCamber: SIMD4<Float>(
          previousBodyCenter + morphology.tipAndMaximumWidth.xyz,
          morphology.normalAndCamber.w
        ),
        currentNormalAndTransverseCamber: SIMD4<Float>(
          morphology.normalAndCamber.xyz,
          Float(bitPattern: morphology.identity.z)
        ),
        previousNormalAndTransverseCamber: SIMD4<Float>(
          morphology.normalAndCamber.xyz,
          Float(bitPattern: morphology.identity.z)
        ),
        sweepAsymmetryAndRipple: morphology.sweepAsymmetryAndRipple,
        envelopeAndTaper: morphology.envelopeAndTaper,
        color: morphology.color,
        morphology: morphology.morphology,
        identity: morphology.identity
      )
    }
  }

  static func femoralTemporalRecords(
    currentPose: CrowFemoralVanePoseSample?,
    previousPose: CrowFemoralVanePoseSample?
  ) -> [CrowBodyVaneRecordGPU] {
    let currentPose = currentPose ?? .inactive
    let previousPose = previousPose ?? .inactive
    let currentFeet = [
      (currentPose.rightHip, currentPose.rightHock),
      (currentPose.leftHip, currentPose.leftHock),
    ]
    let previousFeet = [
      (previousPose.rightHip, previousPose.rightHock),
      (previousPose.leftHip, previousPose.leftHock),
    ]
    var records: [CrowBodyVaneRecordGPU] = []
    records.reserveCapacity(femoralMorphologyRecordCount)
    for (sideIndex, pair) in zip(currentFeet, previousFeet).enumerated() {
      let side: Float = sideIndex == 0 ? -1 : 1
      let morphologies = CrowFemoralPlumage.morphologySamples(side: side)
      for (localIndex, morphology) in morphologies.enumerated() {
        records.append(
          femoralRecord(
            morphology: morphology,
            currentBodyCenter: currentPose.bodyCenter,
            previousBodyCenter: previousPose.bodyCenter,
            currentHip: pair.0.0,
            currentHock: pair.0.1,
            previousHip: pair.1.0,
            previousHock: pair.1.1,
            inventoryIndex: sideIndex * CrowFemoralPlumage.rowCount
              * CrowFemoralPlumage.courseCount + localIndex
          )
        )
      }
    }
    return records
  }

  static func cruralTemporalRecords(
    currentPose: CrowFemoralVanePoseSample?,
    previousPose: CrowFemoralVanePoseSample?
  ) -> [CrowBodyVaneRecordGPU] {
    let currentPose = currentPose ?? .inactive
    let previousPose = previousPose ?? .inactive
    let currentFeet = [
      (currentPose.rightHip, currentPose.rightHock),
      (currentPose.leftHip, currentPose.leftHock),
    ]
    let previousFeet = [
      (previousPose.rightHip, previousPose.rightHock),
      (previousPose.leftHip, previousPose.leftHock),
    ]
    var records: [CrowBodyVaneRecordGPU] = []
    records.reserveCapacity(cruralMorphologyRecordCount)
    for (sideIndex, pair) in zip(currentFeet, previousFeet).enumerated() {
      let side: Float = sideIndex == 0 ? -1 : 1
      let morphologies = CrowLegPlumage.morphologySamples(side: side)
      for (localIndex, morphology) in morphologies.enumerated() {
        records.append(
          cruralRecord(
            morphology: morphology,
            currentHip: pair.0.0,
            currentHock: pair.0.1,
            previousHip: pair.1.0,
            previousHock: pair.1.1,
            inventoryIndex: sideIndex * CrowLegPlumage.radialCount
              * CrowLegPlumage.stationCount + localIndex
          )
        )
      }
    }
    return records
  }

  static func throatBridgeTemporalRecords(
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    currentNeckPose: CrowStandingNeckPose?,
    previousNeckPose: CrowStandingNeckPose?
  ) -> [CrowBodyVaneRecordGPU] {
    CrowThroatBridgeFeathers.morphologySamples().enumerated().map { index, morphology in
      throatBridgeRecord(
        morphology: morphology,
        currentBodyCenter: currentBodyCenter,
        previousBodyCenter: previousBodyCenter,
        currentNeckPose: currentNeckPose,
        previousNeckPose: previousNeckPose,
        inventoryIndex: index
      )
    }
  }

  static func cranialTemporalRecords(
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    cranialRadii: SIMD3<Float>?,
    currentBreathingScale: Float?,
    previousBreathingScale: Float?,
    currentNeckPose: CrowStandingNeckPose?,
    previousNeckPose: CrowStandingNeckPose?
  ) -> [CrowBodyVaneRecordGPU] {
    let radii = cranialRadii ?? .zero
    let currentCenter = currentBodyCenter
      + CrowCranialAnatomy.showcaseCenterOffsetMeters
    let previousCenter = previousBodyCenter
      + CrowCranialAnatomy.showcaseCenterOffsetMeters
    let morphologyRecords = cranialMorphologyRecords()
    return CrowCranialFeatherTracts.morphologySamples().enumerated().map {
      index, morphology in
      let current = CrowCranialFeatherTracts.feather(
        morphology: morphology,
        center: currentCenter,
        radii: radii,
        breathingScale: currentBreathingScale ?? 1
      )
      let previous = CrowCranialFeatherTracts.feather(
        morphology: morphology,
        center: previousCenter,
        radii: radii,
        breathingScale: previousBreathingScale ?? 1
      )
      return cranialRecord(
        current: current,
        previous: previous,
        morphology: morphologyRecords[index]
      )
    }
  }

  static func ventralTemporalRecords(
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>
  ) -> [CrowBodyVaneRecordGPU] {
    CrowVentralFeatherTracts.samples().enumerated().map { index, sample in
      ventralRecord(
        sample: sample,
        currentBodyCenter: currentBodyCenter,
        previousBodyCenter: previousBodyCenter,
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

  static func retainedGroupedRecords(
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    currentNeckPose: CrowStandingNeckPose?,
    previousNeckPose: CrowStandingNeckPose?,
    cranialRadii: SIMD3<Float>? = nil,
    currentCranialBreathingScale: Float? = nil,
    previousCranialBreathingScale: Float? = nil,
    currentFemoralPose: CrowFemoralVanePoseSample? = nil,
    previousFemoralPose: CrowFemoralVanePoseSample? = nil,
    currentDeployment: Float,
    previousDeployment: Float,
    projectedPixelsPerMeter: Float
  ) -> [CrowBodyVaneTopology: [CrowBodyVaneRecordGPU]] {
    let records = retainedTemporalRecords(
      currentBodyCenter: currentBodyCenter,
      previousBodyCenter: previousBodyCenter,
      currentNeckPose: currentNeckPose,
      previousNeckPose: previousNeckPose,
      cranialRadii: cranialRadii,
      currentCranialBreathingScale: currentCranialBreathingScale,
      previousCranialBreathingScale: previousCranialBreathingScale,
      currentFemoralPose: currentFemoralPose,
      previousFemoralPose: previousFemoralPose,
      currentDeployment: currentDeployment,
      previousDeployment: previousDeployment
    )
    return retainedGroupedMorphologyIndices(
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      femoralActive: currentFemoralPose != nil && previousFemoralPose != nil,
      cruralActive: currentFemoralPose != nil && previousFemoralPose != nil,
      cranialActive: cranialRadii != nil
        && currentCranialBreathingScale != nil
        && previousCranialBreathingScale != nil
    ).mapValues { indices in indices.map { records[$0] } }
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
    let length = sample.lodReferenceLengthMeters
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

  static func isVisible(
    _ sample: CrowBodyContourShingle,
    projectedPixelsPerMeter: Float
  ) -> Bool {
    if projectedPixelsPerMeter >= 1_400 { return true }
    if projectedPixelsPerMeter >= 900 {
      return (sample.radialIndex + sample.axialIndex).isMultiple(of: 2)
    }
    return sample.radialIndex.isMultiple(of: 2)
      && sample.axialIndex.isMultiple(of: 2)
  }

  static func topology(
    for sample: CrowBodyContourShingle,
    projectedPixelsPerMeter: Float
  ) -> CrowBodyVaneTopology {
    let tessellation = CrowFeatherCoverageLOD.tessellation(
      lengthMeters: sample.referenceLengthMeters,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      baseAxialSections: 8
    )
    return CrowBodyVaneTopology(
      axialSections: tessellation.axialSections,
      widthSections: max(
        tessellation.widthSections,
        CrowFeatherCoverageLOD.bodyTractMinimumWidthSections(
          lengthMeters: sample.referenceLengthMeters,
          projectedPixelsPerMeter: projectedPixelsPerMeter
        )
      )
    )
  }

  static func isVisible(
    _ sample: CrowVentralFeatherTractSample,
    projectedPixelsPerMeter: Float
  ) -> Bool {
    projectedPixelsPerMeter >= 1_400
  }

  static func topology(
    for sample: CrowVentralFeatherTractSample,
    projectedPixelsPerMeter: Float
  ) -> CrowBodyVaneTopology {
    let tessellation = CrowFeatherCoverageLOD.tessellation(
      lengthMeters: sample.lodReferenceLengthMeters,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      baseAxialSections: 7
    )
    return CrowBodyVaneTopology(
      axialSections: tessellation.axialSections,
      widthSections: tessellation.widthSections
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
    let point = center + widthAxis * (signedWidth * localWidth)
      + normal * (localWidth * transverse * max(0, 1 - signedWidth * signedWidth))
    return point + bodyTractContourSetOffset(
      record: record,
      axial: t,
      signedWidth: signedWidth,
      normal: normal,
      widthAxis: widthAxis
    )
  }

  /// A deterministic, root-locked surface set breaks the uniform body-shell
  /// highlight at close range. It is an estimated visual relaxation rather
  /// than a measured stiffness value; the maximum displacement is below
  /// 0.36 mm and uses the immutable record identity only.
  static func bodyTractContourSetOffset(
    record: CrowBodyVaneRecordGPU,
    axial: Float,
    signedWidth: Float,
    normal: SIMD3<Float>,
    widthAxis: SIMD3<Float>
  ) -> SIMD3<Float> {
    guard (record.identity.x & 0xFF00_0000) == 0x0200_0000 else { return .zero }
    let baseLift: Float
    switch Int(record.morphology.y) {
    case Int(CrowBodyFeatherTractRegion.cervical.rawValue): baseLift = 0.00019
    case Int(CrowBodyFeatherTractRegion.mantle.rawValue): baseLift = 0.00026
    case Int(CrowBodyFeatherTractRegion.humeral.rawValue): baseLift = 0.00030
    default: baseLift = 0.00034
    }
    let t = min(max(axial, 0), 1)
    let distal = pow(t, 1.55)
    let edgeEnvelope = 1 - 0.26 * signedWidth * signedWidth
    let identityPhase = 2 * Float.pi
      * Float(record.identity.y & 0x0000_FFFF) / Float(0x0000_FFFF)
    let phase = identityPhase + 0.37 * record.morphology.z
      + 0.19 * record.morphology.w
    let normalLift = baseLift * (0.72 + 0.28 * sin(phase))
    let lateralSet = 0.20 * baseLift * cos(phase) * signedWidth
    return distal * edgeEnvelope * (normal * normalLift + widthAxis * lateralSet)
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
    let point = root + (tip - root) * axial
      + widthAxis * (record.sweepAsymmetryAndRipple.x * sin(.pi * axial))
      + normal
        * (camber * sin(.pi * axial) + retainedTransverse * halfWidth + 0.00012)
    return point + bodyTractContourSetOffset(
      record: record,
      axial: axial,
      signedWidth: 0,
      normal: normal,
      widthAxis: widthAxis
    )
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
    if (record.identity.x & 0xFF00_0000) == 0x0100_0000 {
      return SIMD4<Float>(0.010, 0.014, 0.022, 0.14)
    }
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
    appendBodyPlumulaceousSegments(
      record: record,
      frame: frame,
      identityFirst: identityFirst,
      identitySecond: identitySecond,
      to: &result
    )
    precondition(result.count == detailSegmentCount(for: topology))
    return result
  }

  private static func appendBodyPlumulaceousSegments(
    record: CrowBodyVaneRecordGPU,
    frame: BodyDetailFrame,
    identityFirst: Int,
    identitySecond: Int,
    to result: inout [BodyDetailSegment]
  ) {
    for pair in 0..<3 {
      for side: Float in [-1, 1] {
        let identity = sin(
          Float(identityFirst + 1) * 15.317
            + Float(identitySecond + 1) * 39.173
            + Float(pair + 1) * 7.139
            + side * 1.913
        )
        let startAxial = 0.045 + 0.025 * Float(pair) + 0.008 * identity
        let endAxial = 0.235 + 0.035 * Float(pair) + 0.012 * identity
        let reach = 0.44 + 0.06 * identity
        var previous = bodyPlumulaceousNode(
          record: record,
          frame: frame,
          side: side,
          startAxial: startAxial,
          endAxial: endAxial,
          reach: reach,
          identity: identity,
          fraction: 0
        )
        for section in 0..<3 {
          let firstFraction = Float(section) / 3
          let secondFraction = Float(section + 1) / 3
          let next = bodyPlumulaceousNode(
            record: record,
            frame: frame,
            side: side,
            startAxial: startAxial,
            endAxial: endAxial,
            reach: reach,
            identity: identity,
            fraction: secondFraction
          )
          result.append(
            BodyDetailSegment(
              kind: .plumulaceousBarb,
              start: previous,
              end: next,
              startRadiusMeters: 0.000032 - 0.000024 * firstFraction,
              endRadiusMeters: 0.000032 - 0.000024 * secondFraction
            )
          )
          previous = next
        }
      }
    }
  }

  private static func bodyPlumulaceousNode(
    record: CrowBodyVaneRecordGPU,
    frame: BodyDetailFrame,
    side: Float,
    startAxial: Float,
    endAxial: Float,
    reach: Float,
    identity: Float,
    fraction: Float
  ) -> SIMD3<Float> {
    let axial = startAxial + (endAxial - startAxial) * fraction
    let lateral = 0.04 + reach * pow(fraction, 0.78)
    let inset = -0.00025 + 0.00018 * fraction
      + 0.00008 * sin(.pi * fraction) * (0.60 + 0.40 * identity)
    return bodyDetailCenter(record: record, frame: frame, axial: axial)
      + side * frame.widthAxis
        * detailHalfWidth(record: record, axial: axial, signedWidth: side)
        * lateral
      + frame.normal * inset
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
    let point = frame.root + (frame.tip - frame.root) * axial
      + frame.widthAxis
        * (record.sweepAsymmetryAndRipple.x * sin(.pi * axial))
      + frame.normal
        * (frame.camber * sin(.pi * axial)
          + frame.transverseCamber
            * detailHalfWidth(record: record, axial: axial, signedWidth: 0)
          + 0.00012)
    return point + bodyTractContourSetOffset(
      record: record,
      axial: axial,
      signedWidth: 0,
      normal: frame.normal,
      widthAxis: frame.widthAxis
    )
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
    case .plumulaceousBarb:
      return SIMD4<Float>(0.0045, 0.0068, 0.0118, 0.12)
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

  private static func ventralRecord(
    sample: CrowVentralFeatherTractSample,
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    inventoryIndex: Int
  ) -> CrowBodyVaneRecordGPU {
    let transverseCamber = CrowVentralFeatherTracts.transverseCamberRatio
      * CrowVentralFeatherTracts.transverseCamberScale(for: sample)
    return CrowBodyVaneRecordGPU(
      currentRootAndRootWidth: SIMD4<Float>(
        currentBodyCenter + sample.rootOffset, sample.rootWidthMeters
      ),
      currentTipAndMaximumWidth: SIMD4<Float>(
        currentBodyCenter + sample.tipOffset, sample.maximumWidthMeters
      ),
      previousRootAndCurrentCamber: SIMD4<Float>(
        previousBodyCenter + sample.rootOffset, sample.camberMeters
      ),
      previousTipAndPreviousCamber: SIMD4<Float>(
        previousBodyCenter + sample.tipOffset, sample.camberMeters
      ),
      currentNormalAndTransverseCamber: SIMD4<Float>(
        sample.planeNormal, transverseCamber
      ),
      previousNormalAndTransverseCamber: SIMD4<Float>(
        sample.planeNormal, transverseCamber
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
        0.015,
        3.2
      ),
      color: ventralColor(for: sample),
      morphology: SIMD4<Float>(
        sample.pennaceousStartFraction,
        sample.lodReferenceLengthMeters,
        Float(sample.row),
        Float(sample.column)
      ),
      identity: SIMD4<UInt32>(
        0x0300_0000 | UInt32(inventoryIndex),
        stableHash(ventralIdentity(of: sample)),
        1,
        sample.surfaceFeatherClass
      )
    )
  }

  private static func femoralRecord(
    morphology: CrowFemoralPlumageMorphology,
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    currentHip: SIMD3<Float>,
    currentHock: SIMD3<Float>,
    previousHip: SIMD3<Float>,
    previousHock: SIMD3<Float>,
    inventoryIndex: Int
  ) -> CrowBodyVaneRecordGPU {
    let current = CrowFemoralPlumage.feather(
      morphology: morphology,
      bodyCenter: currentBodyCenter,
      hip: currentHip,
      hock: currentHock
    )
    let previous = CrowFemoralPlumage.feather(
      morphology: morphology,
      bodyCenter: previousBodyCenter,
      hip: previousHip,
      hock: previousHock
    )
    return CrowBodyVaneRecordGPU(
      currentRootAndRootWidth: SIMD4<Float>(
        current.root, current.rootWidthMeters
      ),
      currentTipAndMaximumWidth: SIMD4<Float>(
        current.tip, current.maximumWidthMeters
      ),
      previousRootAndCurrentCamber: SIMD4<Float>(
        previous.root, current.camberMeters
      ),
      previousTipAndPreviousCamber: SIMD4<Float>(
        previous.tip, previous.camberMeters
      ),
      currentNormalAndTransverseCamber: SIMD4<Float>(
        current.planeNormal, 0.12
      ),
      previousNormalAndTransverseCamber: SIMD4<Float>(
        previous.planeNormal, 0.12
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
        0.015,
        3.2
      ),
      color: femoralColor(for: morphology),
      morphology: SIMD4<Float>(
        0,
        CrowFemoralPlumage.topologyLODReferenceLengthMeters,
        Float(current.row),
        Float(current.course)
      ),
      identity: SIMD4<UInt32>(
        0x0400_0000 | UInt32(inventoryIndex),
        stableHash(femoralIdentity(of: morphology)),
        1,
        CrowFemoralPlumage.surfaceFeatherClass
      )
    )
  }

  private static func cruralRecord(
    morphology: CrowLegPlumageMorphology,
    currentHip: SIMD3<Float>,
    currentHock: SIMD3<Float>,
    previousHip: SIMD3<Float>,
    previousHock: SIMD3<Float>,
    inventoryIndex: Int
  ) -> CrowBodyVaneRecordGPU {
    let current = CrowLegPlumage.feather(
      morphology: morphology,
      hip: currentHip,
      hock: currentHock
    )
    let previous = CrowLegPlumage.feather(
      morphology: morphology,
      hip: previousHip,
      hock: previousHock
    )
    return CrowBodyVaneRecordGPU(
      currentRootAndRootWidth: SIMD4<Float>(
        current.root, current.rootWidthMeters
      ),
      currentTipAndMaximumWidth: SIMD4<Float>(
        current.tip, current.maximumWidthMeters
      ),
      previousRootAndCurrentCamber: SIMD4<Float>(
        previous.root, current.camberMeters
      ),
      previousTipAndPreviousCamber: SIMD4<Float>(
        previous.tip, previous.camberMeters
      ),
      currentNormalAndTransverseCamber: SIMD4<Float>(
        current.planeNormal, 0.08
      ),
      previousNormalAndTransverseCamber: SIMD4<Float>(
        previous.planeNormal, 0.08
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
        0.015,
        3.2
      ),
      color: cruralColor(for: morphology),
      morphology: SIMD4<Float>(
        0,
        CrowLegPlumage.topologyLODReferenceLengthMeters,
        Float(current.radialIndex),
        Float(current.stationIndex)
      ),
      identity: SIMD4<UInt32>(
        0x0500_0000 | UInt32(inventoryIndex),
        stableHash(cruralIdentity(of: morphology)),
        1,
        CrowLegPlumage.surfaceFeatherClass
      )
    )
  }

  private static func cranialRecord(
    current: CrowCranialFeatherSample,
    previous: CrowCranialFeatherSample,
    morphology: CrowBodyVaneMorphologyGPU
  ) -> CrowBodyVaneRecordGPU {
    CrowBodyVaneRecordGPU(
      currentRootAndRootWidth: SIMD4<Float>(
        current.root,
        current.rootWidthMeters
      ),
      currentTipAndMaximumWidth: SIMD4<Float>(
        current.tip,
        current.maximumWidthMeters
      ),
      previousRootAndCurrentCamber: SIMD4<Float>(
        previous.root,
        current.camberMeters
      ),
      previousTipAndPreviousCamber: SIMD4<Float>(
        previous.tip,
        previous.camberMeters
      ),
      currentNormalAndTransverseCamber: SIMD4<Float>(
        current.planeNormal,
        0.18
      ),
      previousNormalAndTransverseCamber: SIMD4<Float>(
        previous.planeNormal,
        0.18
      ),
      sweepAsymmetryAndRipple: .zero,
      envelopeAndTaper: SIMD4<Float>(1.5, 0.32, 0.015, 3.2),
      color: morphology.color,
      morphology: morphology.morphology,
      identity: morphology.identity
    )
  }

  private static func throatBridgeRecord(
    morphology: CrowThroatBridgeMorphology,
    currentBodyCenter: SIMD3<Float>,
    previousBodyCenter: SIMD3<Float>,
    currentNeckPose: CrowStandingNeckPose?,
    previousNeckPose: CrowStandingNeckPose?,
    inventoryIndex: Int
  ) -> CrowBodyVaneRecordGPU {
    let current = CrowThroatBridgeFeathers.feather(
      morphology: morphology,
      neckPose: currentNeckPose
    )
    let previous = CrowThroatBridgeFeathers.feather(
      morphology: morphology,
      neckPose: previousNeckPose
    )
    let material = morphology.materialVariation
    return CrowBodyVaneRecordGPU(
      currentRootAndRootWidth: SIMD4<Float>(
        currentBodyCenter + current.rootOffset,
        current.rootWidthMeters
      ),
      currentTipAndMaximumWidth: SIMD4<Float>(
        currentBodyCenter + current.tipOffset,
        current.maximumWidthMeters
      ),
      previousRootAndCurrentCamber: SIMD4<Float>(
        previousBodyCenter + previous.rootOffset,
        current.camberMeters
      ),
      previousTipAndPreviousCamber: SIMD4<Float>(
        previousBodyCenter + previous.tipOffset,
        previous.camberMeters
      ),
      currentNormalAndTransverseCamber: SIMD4<Float>(current.planeNormal, 0.12),
      previousNormalAndTransverseCamber: SIMD4<Float>(previous.planeNormal, 0.12),
      sweepAsymmetryAndRipple: SIMD4<Float>(
        0,
        0.035 * material,
        0.018 + 0.008 * abs(material),
        Float.pi * (material + 1)
      ),
      envelopeAndTaper: SIMD4<Float>(
        1.5,
        CrowThroatBridgeFeathers.visibleRootEnvelopeRatio,
        0.015,
        3.2
      ),
      color: throatBridgeColor(for: morphology),
      morphology: SIMD4<Float>(
        CrowThroatBridgeFeathers.pennaceousStartFraction,
        simd_distance(morphology.rootOffset, morphology.tipOffset),
        Float(morphology.column),
        Float(morphology.row)
      ),
      identity: SIMD4<UInt32>(
        0x0600_0000 | UInt32(inventoryIndex),
        stableHash(throatBridgeIdentity(of: morphology)),
        Float(0.12).bitPattern,
        morphology.surfaceFeatherClass
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

  private static func ventralColor(
    for sample: CrowVentralFeatherTractSample
  ) -> SIMD4<Float> {
    let material = sample.materialVariation
    return SIMD4<Float>(
      0.006 * (1 + 0.08 * material),
      0.009 * (1 + 0.06 * material),
      0.016 * (1 + 0.04 * material),
      0.15 + 0.008 * material
    )
  }

  private static func femoralColor(
    for sample: CrowFemoralPlumageMorphology
  ) -> SIMD4<Float> {
    let base = SIMD4<Float>(0.010, 0.014, 0.022, 0.16)
    let body = SIMD4<Float>(0.006, 0.009, 0.016, 0.15)
    let blended = base + sample.bodyMaterialBlend * (body - base)
    let material = sample.materialVariation
    return SIMD4<Float>(
      blended.x * (1 + 0.08 * material),
      blended.y * (1 + 0.06 * material),
      blended.z * (1 + 0.04 * material),
      blended.w + 0.008 * material
    )
  }

  private static func cruralColor(
    for sample: CrowLegPlumageMorphology
  ) -> SIMD4<Float> {
    let base = SIMD4<Float>(0.010, 0.014, 0.022, 0.16)
    let body = SIMD4<Float>(0.006, 0.009, 0.016, 0.15)
    let blended = base + sample.bodyMaterialBlend * (body - base)
    let material = sample.materialVariation
    return SIMD4<Float>(
      blended.x * (1 + 0.08 * material),
      blended.y * (1 + 0.06 * material),
      blended.z * (1 + 0.04 * material),
      blended.w + 0.008 * material
    )
  }

  private static func throatBridgeColor(
    for sample: CrowThroatBridgeMorphology
  ) -> SIMD4<Float> {
    let material = sample.materialVariation
    return SIMD4<Float>(
      0.0058 * (1 + 0.10 * material),
      0.0088 * (1 + 0.075 * material),
      0.0158 * (1 + 0.05 * material),
      0.145 + 0.010 * material
    )
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

  private static func ventralIdentity(
    of sample: CrowVentralFeatherTractSample
  ) -> SIMD4<UInt32> {
    SIMD4<UInt32>(
      0x0300 | UInt32(sample.region.rawValue),
      sample.side < 0 ? 0 : 1,
      UInt32(sample.row),
      UInt32(sample.column)
    )
  }

  private static func femoralIdentity(
    of sample: CrowFemoralPlumageMorphology
  ) -> SIMD4<UInt32> {
    SIMD4<UInt32>(
      0x0400,
      sample.side < 0 ? 0 : 1,
      UInt32(sample.row),
      UInt32(sample.course)
    )
  }

  private static func cruralIdentity(
    of sample: CrowLegPlumageMorphology
  ) -> SIMD4<UInt32> {
    SIMD4<UInt32>(
      0x0500,
      sample.side < 0 ? 0 : 1,
      UInt32(sample.radialIndex),
      UInt32(sample.stationIndex)
    )
  }

  private static func throatBridgeIdentity(
    of sample: CrowThroatBridgeMorphology
  ) -> SIMD4<UInt32> {
    SIMD4<UInt32>(
      0x0600,
      sample.side < 0 ? 0 : 1,
      UInt32(sample.row),
      UInt32(sample.column)
    )
  }

  private static func cranialIdentity(
    of sample: CrowCranialFeatherMorphology
  ) -> SIMD4<UInt32> {
    SIMD4<UInt32>(
      0x0700 | UInt32(sample.region.rawValue),
      UInt32(sample.axialIndex),
      UInt32(sample.angularIndex),
      0
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
