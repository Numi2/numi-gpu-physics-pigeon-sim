import Metal
import Testing
import simd

@testable import BirdFlowVisualization

private func ventralLODReferenceLength(
  _ record: CrowVentralRachisCurveRecordGPU
) -> Float {
  let retained = record.lateralSweepAndReserved.y
  return retained > 0
    ? retained
    : simd_distance(
      xyz(record.rootAndPennaceousStart),
      xyz(record.tipAndCamber)
    )
}

@Test("ventral barb curves activate only at resolvable projected size")
func ventralBarbCurvesActivateAtResolvableProjectedSize() {
  let allRecords = CrowVentralRachisCurveRecords.records()
  let ordinaryWork = CrowVentralBarbCurveRecords.segmentWork(
    records: allRecords,
    projectedPixelsPerMeter: 1_600
  )
  #expect(Set(ordinaryWork.map { $0.indices.x }).count == 776)
  #expect(ordinaryWork.count == 776 * 10 * 2 * 4)
  #expect(
    ordinaryWork.allSatisfy {
      CrowVentralBarbCurveRecords.unpackPairCount($0) == 10
    })
  #expect(
    CrowVentralBarbCurveRecords.activeCloseRecordIndices(
      records: allRecords,
      projectedPixelsPerMeter: 1_600
    ).isEmpty
  )
  let closeupWork = CrowVentralBarbCurveRecords.segmentWork(
    records: allRecords,
    projectedPixelsPerMeter: 14_440
  )
  #expect(Set(closeupWork.map { $0.indices.x }).count == 776)
  #expect(
    CrowVentralBarbCurveRecords.activeCloseRecordIndices(
      records: allRecords,
      projectedPixelsPerMeter: 14_440
    ).count == 746
  )
  #expect(closeupWork.count == 432_096)
  #expect(closeupWork.count * 24 == 10_370_304)

  let record = CrowVentralRachisCurveRecords.records()[0]
  let length = ventralLODReferenceLength(record)
  let belowAggregate = CrowVentralBarbCurveRecords.segmentWork(
    records: [record],
    projectedPixelsPerMeter: 39 / length
  )
  #expect(belowAggregate.isEmpty)
  let aggregate = CrowVentralBarbCurveRecords.segmentWork(
    records: [record],
    projectedPixelsPerMeter: 41 / length
  )
  #expect(aggregate.count == 10 * 2 * 4)
  #expect(
    aggregate.allSatisfy {
      CrowVentralBarbCurveRecords.unpackPairCount($0) == 10
    })
  let belowClose = CrowVentralBarbCurveRecords.segmentWork(
    records: [record],
    projectedPixelsPerMeter: 479 / length
  )
  #expect(belowClose.count == 10 * 2 * 4)
  let work = CrowVentralBarbCurveRecords.segmentWork(
    records: [record],
    projectedPixelsPerMeter: 481 / length
  )
  #expect(work.count == 72 * 2 * 4)
  #expect(
    work.allSatisfy {
      CrowVentralBarbCurveRecords.unpackPairCount($0) == 72
        && CrowVentralBarbCurveRecords.unpackIntervalCount($0) == 4
    })
  #expect(Set(work.map { $0.indices }).count == work.count)

  let raw = CrowFeatherMesostructure.segments(
    for: CrowVentralFeatherTracts.samples().first(
      where: CrowVentralFeatherTracts.retainsCrownRachis
    )!,
    projectedPixelsPerMeter: 20_000,
    transverseCamberRatio: 0
  )
  let fallback = CrowVentralBarbCurveRecords.surfaceFallbackSegments(
    for: CrowVentralFeatherTracts.samples().first(
      where: CrowVentralFeatherTracts.retainsCrownRachis
    )!,
    projectedPixelsPerMeter: 20_000
  )
  #expect(raw.contains { $0.kind == .barb })
  #expect(raw.contains { $0.kind == .barbule })
  #expect(raw.contains { $0.kind == .edgeBarbGroup })
  #expect(
    CrowVentralBarbCurveRecords.surfaceFallbackSegments(
      for: CrowVentralFeatherTracts.samples().first(
        where: CrowVentralFeatherTracts.retainsCrownRachis
      )!,
      projectedPixelsPerMeter: 20_000,
      explicitCurvesEnabled: false
    ) == raw
  )
  #expect(fallback.allSatisfy { $0.kind != .barb && $0.kind != .barbule })
  #expect(fallback.contains { $0.kind == .rachis })
  #expect(fallback.allSatisfy { $0.kind != .edgeBarbGroup })
  let showcaseFallback = CrowVentralBarbCurveRecords.surfaceFallbackSegments(
    for: CrowVentralFeatherTracts.samples().first(
      where: CrowVentralFeatherTracts.retainsCrownRachis
    )!,
    projectedPixelsPerMeter: 1_600
  )
  #expect(showcaseFallback.allSatisfy { $0.kind != .edgeBarbGroup })

  let boundary = CrowVentralFeatherTracts.samples().first {
    !CrowVentralFeatherTracts.retainsCrownRachis($0)
  }!
  let boundarySegments = CrowFeatherMesostructure.segments(
    for: boundary,
    projectedPixelsPerMeter: 20_000,
    transverseCamberRatio: 0
  )
  #expect(
    CrowVentralBarbCurveRecords.surfaceFallbackSegments(
      for: boundary,
      projectedPixelsPerMeter: 20_000
    ) == boundarySegments
  )
}

@Test("ventral barbules activate independently and remain inside their vane")
func ventralBarbulesActivateInsideOwnedVane() {
  let record = CrowVentralRachisCurveRecords.records()[0]
  let length = ventralLODReferenceLength(record)
  let barbOnly = CrowVentralBarbCurveRecords.segmentWork(
    records: [record],
    projectedPixelsPerMeter: 799 / length
  )
  #expect(barbOnly.count == 72 * 2 * 4)
  #expect(barbOnly.allSatisfy { !CrowVentralBarbCurveRecords.isBarbule($0) })

  let detailed = CrowVentralBarbCurveRecords.segmentWork(
    records: [record],
    projectedPixelsPerMeter: 801 / length
  )
  let barbuleWork = detailed.filter(CrowVentralBarbCurveRecords.isBarbule)
  #expect(detailed.count == 72 * 2 * (4 + 2 * 6))
  #expect(barbuleWork.count == 72 * 2 * 2 * 6)
  #expect(Set(detailed.map(\.indices)).count == detailed.count)

  for pairIndex in [0, 35, 71] {
    for sideIndex in 0..<2 {
      for branchIndex in 0..<2 {
        for barbuleIndex in [0, 5] {
          let work = barbuleWork.first {
            Int($0.indices.y) == pairIndex
              && CrowVentralBarbCurveRecords.unpackSideIndex($0) == sideIndex
              && CrowVentralBarbCurveRecords.unpackBarbuleBranchIndex($0)
                == branchIndex
              && CrowVentralBarbCurveRecords.unpackBarbuleIndex($0)
                == barbuleIndex
          }!
          let segment = CrowVentralBarbCurveRecords.segment(
            record: record,
            work: work
          )
          #expect(segment.kind == .barbule)
          #expect(allFinite(segment.start) && allFinite(segment.end))
          #expect(segment.startRadiusMeters > segment.endRadiusMeters)
          #expect(simd_distance(segment.start, segment.end) > 0.00005)
          for endpoint: Float in [0, 1] {
            let coordinates = CrowVentralBarbCurveRecords.barbuleVaneCoordinates(
              record: record,
              work: work,
              segmentFraction: endpoint
            )
            #expect(coordinates.x >= record.rootAndPennaceousStart.w)
            #expect(coordinates.x <= 0.96)
            #expect(abs(coordinates.y) <= 0.93 + 1e-6)
          }
        }
      }
    }
  }

  let lower = barbuleWork.first {
    CrowVentralBarbCurveRecords.unpackBarbuleBranchIndex($0) == 0
      && CrowVentralBarbCurveRecords.unpackBarbuleIndex($0) == 2
  }!
  let upper = barbuleWork.first {
    CrowVentralBarbCurveRecords.unpackBarbuleBranchIndex($0) == 1
      && CrowVentralBarbCurveRecords.unpackBarbuleIndex($0) == 2
  }!
  let lowerOcclusion = CrowVentralBarbCurveRecords.barbuleLocalOcclusion(
    work: lower
  )
  let upperOcclusion = CrowVentralBarbCurveRecords.barbuleLocalOcclusion(
    work: upper
  )
  #expect(lowerOcclusion >= 0.82 && lowerOcclusion <= 0.90)
  #expect(upperOcclusion >= 0.93 && upperOcclusion <= 0.98)
  #expect(lowerOcclusion < upperOcclusion)
}

@Test("ventral barb intervals form connected crown-following curves")
func ventralBarbIntervalsFormConnectedCrownCurves() {
  let records = CrowVentralRachisCurveRecords.records()
  for record in records.prefix(8) {
    let length = ventralLODReferenceLength(record)
    let work = CrowVentralBarbCurveRecords.segmentWork(
      records: [record],
      projectedPixelsPerMeter: 481 / length
    )
    for sideIndex in 0..<2 {
      for pairIndex in [0, 35, 71] {
        let selected = work.filter {
          Int($0.indices.y) == pairIndex
            && CrowVentralBarbCurveRecords.unpackSideIndex($0) == sideIndex
        }
        #expect(selected.count == 4)
        let segments = selected.map {
          CrowVentralBarbCurveRecords.segment(record: record, work: $0)
        }
        for index in 0..<(segments.count - 1) {
          #expect(simd_distance(segments[index].end, segments[index + 1].start) < 2e-8)
          #expect(
            abs(
              segments[index].endRadiusMeters
                - segments[index + 1].startRadiusMeters
            ) < 1e-10
          )
        }
        #expect(
          segments.allSatisfy {
            allFinite($0.start) && allFinite($0.end)
              && $0.startRadiusMeters > $0.endRadiusMeters
          })
        #expect(
          simd_distance(segments.first!.start, segments.last!.end)
            > 0.25 * record.widthsEnvelopeAndAsymmetry.y
        )
      }
    }
  }
}

@Test("ventral barb visibility bounds enclose explicit curve geometry")
func ventralBarbVisibilityBoundsEncloseCurveGeometry() {
  let bodyCenter = SIMD3<Float>(0.031, -0.027, 0.044)
  for record in CrowVentralRachisCurveRecords.records() {
    let bounds = CrowVentralBarbCurveRecords.boundingSphere(
      record: record,
      bodyCenter: bodyCenter
    )
    #expect(bounds.radius.isFinite && bounds.radius > 0)
    let work = CrowVentralBarbCurveRecords.segmentWork(
      records: [record],
      projectedPixelsPerMeter: 30_000
    )
    for selected in work where [0, 35, 71].contains(Int(selected.indices.y)) {
      for fraction: Float in [0, 0.25, 0.5, 0.75, 1] {
        let point =
          CrowVentralBarbCurveRecords.point(
            record: record,
            work: selected,
            curveFraction: fraction
          ) + bodyCenter
        #expect(simd_distance(point, bounds.center) <= bounds.radius + 1e-7)
      }
    }
  }
}

@Test("Metal expands retained ventral barb intervals into temporal tubes")
func metalExpandsRetainedVentralBarbIntervals() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let record = CrowVentralRachisCurveRecords.records()[0]
  let records = [record]
  let length = ventralLODReferenceLength(record)
  let projectedPixelsPerMeter: Float = 481 / length
  let work = CrowVentralBarbCurveRecords.segmentWork(
    records: records,
    projectedPixelsPerMeter: projectedPixelsPerMeter
  )
  let deformer = try CrowVentralBarbGeometryDeformer(
    backend: backend,
    records: records
  )
  let currentCenter = SIMD3<Float>(0.014, -0.023, 0.5)
  let previousCenter = SIMD3<Float>(-0.009, 0.018, -0.026)
  let commandBuffer = try #require(backend.queue.makeCommandBuffer())
  let frame = try deformer.encode(
    currentBodyCenter: currentCenter,
    previousBodyCenter: previousCenter,
    projectedPixelsPerMeter: projectedPixelsPerMeter,
    viewProjection: matrix_identity_float4x4,
    commandBuffer: commandBuffer,
    auditReadback: true
  )
  commandBuffer.commit()
  commandBuffer.waitUntilCompleted()
  #expect(commandBuffer.status == .completed)
  #expect(frame.vertexCount == 72 * 2 * 4 * 24)
  #expect(deformer.compactedRecordCount(for: frame) == 1)
  #expect(deformer.segmentWork(for: frame) == work)
  #expect(deformer.drawArguments(for: frame).vertexCount == UInt32(frame.vertexCount))
  #expect(
    deformer.meshDispatchDimensions(for: frame)
      == SIMD3<UInt32>(UInt32(work.count), 1, 1)
  )
  let vertices = deformer.vertices(for: frame)
  for workIndex in [0, work.count - 1] {
    let segment = CrowVentralBarbCurveRecords.segment(
      record: record,
      work: work[workIndex]
    )
    let expected = tubeVertices(
      segment: segment,
      currentCenter: currentCenter,
      previousCenter: previousCenter
    )
    let base = workIndex * 24
    for (gpu, oracle) in zip(vertices[base..<(base + 24)], expected) {
      #expect(simd_distance(xyz(gpu.position), oracle.position) < 4e-7)
      #expect(simd_distance(xyz(gpu.previousPosition), oracle.previousPosition) < 4e-7)
      #expect(simd_distance(xyz(gpu.normal), oracle.normal) < 5e-5)
      #expect(gpu.identity.x == UInt32.max)
      #expect(gpu.identity.z == 3)
      #expect(gpu.identity.w == 7)
    }
  }
}

@Test("Metal emits stable procedural barbules with CPU endpoint parity")
func metalEmitsStableProceduralBarbules() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let record = CrowVentralRachisCurveRecords.records()[0]
  let length = ventralLODReferenceLength(record)
  let projectedPixelsPerMeter: Float = 801 / length
  let expectedWork = CrowVentralBarbCurveRecords.segmentWork(
    records: [record],
    projectedPixelsPerMeter: projectedPixelsPerMeter
  )
  let deformer = try CrowVentralBarbGeometryDeformer(
    backend: backend,
    records: [record]
  )
  let currentCenter = SIMD3<Float>(0.014, -0.023, 0.5)
  let previousCenter = SIMD3<Float>(-0.009, 0.018, 0.47)
  let commandBuffer = try #require(backend.queue.makeCommandBuffer())
  let frame = try deformer.encode(
    currentBodyCenter: currentCenter,
    previousBodyCenter: previousCenter,
    projectedPixelsPerMeter: projectedPixelsPerMeter,
    viewProjection: matrix_identity_float4x4,
    commandBuffer: commandBuffer,
    auditReadback: true
  )
  commandBuffer.commit()
  commandBuffer.waitUntilCompleted()
  #expect(commandBuffer.status == .completed)
  #expect(deformer.segmentWork(for: frame) == expectedWork)
  let counts = deformer.visibilityCounts(for: frame)
  #expect(counts.postOcclusionVisible == 1)
  #expect(counts.postOcclusionBarbuleVisible == 1)
  #expect(counts.frustumBarbuleVisible == 1)
  #expect(counts.emittedWorkCount == UInt32(expectedWork.count))
  #expect(
    deformer.drawArguments(for: frame).vertexCount
      == UInt32(expectedWork.count * 24)
  )
  #expect(
    deformer.meshDispatchDimensions(for: frame)
      == SIMD3<UInt32>(UInt32(expectedWork.count), 1, 1)
  )

  let vertices = deformer.vertices(for: frame)
  let selectedIndices = [
    expectedWork.firstIndex(where: CrowVentralBarbCurveRecords.isBarbule)!,
    expectedWork.indices.last!,
  ]
  var primitiveIdentifiers: Set<UInt32> = []
  for workIndex in selectedIndices {
    let segment = CrowVentralBarbCurveRecords.segment(
      record: record,
      work: expectedWork[workIndex]
    )
    let expected = tubeVertices(
      segment: segment,
      currentCenter: currentCenter,
      previousCenter: previousCenter
    )
    let base = workIndex * 24
    for (gpu, oracle) in zip(vertices[base..<(base + 24)], expected) {
      #expect(simd_distance(xyz(gpu.position), oracle.position) < 5e-7)
      #expect(simd_distance(xyz(gpu.previousPosition), oracle.previousPosition) < 5e-7)
      #expect(simd_distance(xyz(gpu.normal), oracle.normal) < 1e-4)
      #expect(gpu.identity.x == UInt32.max)
      #expect(gpu.identity.z == 4)
      #expect(gpu.identity.w == 7)
      #expect(abs(gpu.parameters.y) <= 0.93 + 1e-6)
      primitiveIdentifiers.insert(gpu.identity.y)
    }
  }
  #expect(primitiveIdentifiers.count == 16)
}

@Test("Metal deterministically compacts visible ventral barb records")
func metalCompactsVisibleVentralBarbRecords() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  var records = Array(CrowVentralRachisCurveRecords.records().prefix(4))
  for index in records.indices {
    let translation =
      index < 2
      ? SIMD3<Float>(0, 0, 0.5) : SIMD3<Float>(3, 0, 0.5)
    records[index].rootAndPennaceousStart = translated(
      records[index].rootAndPennaceousStart,
      by: translation
    )
    records[index].tipAndCamber = translated(
      records[index].tipAndCamber,
      by: translation
    )
  }
  let projectedPixelsPerMeter: Float = 30_000
  let visibility = CrowVentralBarbCurveRecords.visibilityUniforms(
    viewProjection: matrix_identity_float4x4,
    currentBodyCenter: .zero,
    projectedPixelsPerMeter: projectedPixelsPerMeter,
    recordCount: records.count
  )
  #expect(
    CrowVentralBarbCurveRecords.visibleRecordIndices(
      records: records,
      uniforms: visibility
    ) == [0, 1]
  )

  let deformer = try CrowVentralBarbGeometryDeformer(
    backend: backend,
    records: records
  )
  let commandBuffer = try #require(backend.queue.makeCommandBuffer())
  let frame = try deformer.encode(
    currentBodyCenter: .zero,
    previousBodyCenter: .zero,
    projectedPixelsPerMeter: projectedPixelsPerMeter,
    viewProjection: matrix_identity_float4x4,
    commandBuffer: commandBuffer,
    auditReadback: true
  )
  commandBuffer.commit()
  commandBuffer.waitUntilCompleted()
  #expect(commandBuffer.status == .completed)
  #expect(deformer.compactedRecordCount(for: frame) == 2)
  #expect(
    deformer.visibilityCounts(for: frame)
      == CrowVentralBarbVisibilityCounts(
        postOcclusionVisible: 2,
        frustumVisible: 2,
        occlusionCulled: 0,
        occlusionTested: 0,
        postOcclusionBarbuleVisible: 2,
        frustumBarbuleVisible: 2,
        emittedWorkCount: 2 * 72 * 2 * (4 + 2 * 6),
        reserved: 0
      )
  )
  let expectedWork = CrowVentralBarbCurveRecords.segmentWork(
    records: Array(records.prefix(2)),
    projectedPixelsPerMeter: projectedPixelsPerMeter
  )
  #expect(deformer.segmentWork(for: frame) == expectedWork)
  #expect(
    deformer.drawArguments(for: frame).vertexCount
      == UInt32(expectedWork.count * 24)
  )
  #expect(deformer.vertices(for: frame).count == expectedWork.count * 24)

  let dormantPixelsPerMeter = 39 / records.map(ventralLODReferenceLength).max()!
  let dormantCommand = try #require(backend.queue.makeCommandBuffer())
  let dormantFrame = try deformer.encode(
    currentBodyCenter: .zero,
    previousBodyCenter: .zero,
    projectedPixelsPerMeter: dormantPixelsPerMeter,
    viewProjection: matrix_identity_float4x4,
    commandBuffer: dormantCommand
  )
  dormantCommand.commit()
  dormantCommand.waitUntilCompleted()
  #expect(dormantCommand.status == .completed)
  #expect(deformer.compactedRecordCount(for: dormantFrame) == 0)
  #expect(
    deformer.visibilityCounts(for: dormantFrame)
      == CrowVentralBarbVisibilityCounts(
        postOcclusionVisible: 0,
        frustumVisible: 0,
        occlusionCulled: 0,
        occlusionTested: 0,
        postOcclusionBarbuleVisible: 0,
        frustumBarbuleVisible: 0,
        emittedWorkCount: 0,
        reserved: 0
      )
  )
  #expect(deformer.drawArguments(for: dormantFrame).vertexCount == 0)
  #expect(deformer.meshDispatchDimensions(for: dormantFrame) == .zero)
}

@Test("capability-gated ventral mesh pipeline compiles on supported Metal GPUs")
func capabilityGatedVentralMeshPipelineCompiles() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  guard backend.supportsMeshShaders else { return }
  _ = try backend.meshRender(
    mesh: "crowVentralBarbAOVMesh",
    fragment: "showcaseCrowIdentityFragment",
    colorFormats: [.rgba32Uint],
    maximumThreadsPerMeshThreadgroup: 8
  )
  #expect(backend.supportsMeshShaders)
}

@Test("isolated indexed mesh tubes match vertex raster ownership")
func isolatedIndexedMeshTubesMatchVertexRasterOwnership() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  guard backend.supportsMeshShaders else { return }
  let allRecords = CrowVentralRachisCurveRecords.records()
  let records = CrowVentralBarbCurveRecords.activeRecordIndices(
    records: allRecords,
    projectedPixelsPerMeter: 14_440
  ).map { allRecords[Int($0)] }
  let deformer = try CrowVentralBarbGeometryDeformer(
    backend: backend,
    records: records
  )
  let prepare = try #require(backend.queue.makeCommandBuffer())
  let frame = try deformer.encode(
    currentBodyCenter: SIMD3<Float>(0, 0, 0.5),
    previousBodyCenter: SIMD3<Float>(0, 0, 0.5),
    projectedPixelsPerMeter: 14_440,
    viewProjection: matrix_identity_float4x4,
    commandBuffer: prepare
  )
  prepare.commit()
  prepare.waitUntilCompleted()
  #expect(prepare.status == .completed)
  #expect(deformer.compactedRecordCount(for: frame) == records.count)
  #expect(
    deformer.visibilityCounts(for: frame).emittedWorkCount == 432_096
  )
  #expect(
    deformer.meshDispatchDimensions(for: frame) == SIMD3<UInt32>(4_096, 106, 1)
  )

  let width = 512
  let height = 512
  var camera = CrowTemporalCameraUniforms(
    viewProjection: matrix_identity_float4x4,
    previousViewProjection: matrix_identity_float4x4,
    eyeAndWidth: SIMD4<Float>(0, 0, 0, Float(width)),
    viewportAndInverse: SIMD4<Float>(Float(width), Float(height), 1, 0),
    plumageFilm: .zero,
    plumageComplexIndices: .zero,
    plumageMelanin: .zero,
    plumageCortex: .zero,
    plumageVisibilityShape: .zero,
    plumageVisibilityLayout: .zero
  )
  let vertexPipeline = try backend.render(
    vertex: "crowVentralBarbAOVVertex",
    fragment: "showcaseCrowIdentityFragment",
    colorFormat: .rgba32Uint
  )
  let meshPipeline = try backend.meshRender(
    mesh: "crowVentralBarbAOVMesh",
    fragment: "showcaseCrowIdentityFragment",
    colorFormats: [.rgba32Uint],
    maximumThreadsPerMeshThreadgroup: 8
  )
  let depthDescriptor = MTLDepthStencilDescriptor()
  depthDescriptor.depthCompareFunction = .less
  depthDescriptor.isDepthWriteEnabled = true
  let depthState = try #require(
    device.makeDepthStencilState(descriptor: depthDescriptor)
  )

  func render(mesh: Bool) throws -> [UInt32] {
    let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba32Uint,
      width: width,
      height: height,
      mipmapped: false
    )
    colorDescriptor.storageMode = .shared
    colorDescriptor.usage = .renderTarget
    let color = try #require(device.makeTexture(descriptor: colorDescriptor))
    let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .depth32Float,
      width: width,
      height: height,
      mipmapped: false
    )
    depthTextureDescriptor.storageMode = .private
    depthTextureDescriptor.usage = .renderTarget
    let depth = try #require(
      device.makeTexture(descriptor: depthTextureDescriptor)
    )
    let command = try #require(backend.queue.makeCommandBuffer())
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = color
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    pass.depthAttachment.texture = depth
    pass.depthAttachment.loadAction = .clear
    pass.depthAttachment.storeAction = .dontCare
    pass.depthAttachment.clearDepth = 1
    let encoder = try #require(
      command.makeRenderCommandEncoder(descriptor: pass)
    )
    encoder.setCullMode(.none)
    encoder.setDepthStencilState(depthState)
    if mesh {
      encoder.setRenderPipelineState(meshPipeline)
      deformer.bindMeshRenderResources(for: frame, encoder: encoder)
      encoder.setMeshBytes(
        &camera,
        length: MemoryLayout<CrowTemporalCameraUniforms>.stride,
        index: 3
      )
      encoder.drawMeshThreadgroups(
        indirectBuffer: try #require(frame.indirectMeshDispatchBuffer),
        indirectBufferOffset: 0,
        threadsPerObjectThreadgroup: MTLSize(width: 1, height: 1, depth: 1),
        threadsPerMeshThreadgroup: MTLSize(width: 8, height: 1, depth: 1)
      )
    } else {
      encoder.setRenderPipelineState(vertexPipeline)
      deformer.bindRenderResources(for: frame, encoder: encoder)
      encoder.setVertexBytes(
        &camera,
        length: MemoryLayout<CrowTemporalCameraUniforms>.stride,
        index: 3
      )
      encoder.drawPrimitives(
        type: .triangle,
        indirectBuffer: frame.indirectDrawBuffer,
        indirectBufferOffset: 0
      )
    }
    encoder.endEncoding()
    command.commit()
    command.waitUntilCompleted()
    #expect(command.status == .completed)
    var values = [UInt32](repeating: 0, count: width * height * 4)
    color.getBytes(
      &values,
      bytesPerRow: width * 4 * MemoryLayout<UInt32>.stride,
      from: MTLRegionMake2D(0, 0, width, height),
      mipmapLevel: 0
    )
    return values
  }

  let vertex = try render(mesh: false)
  let mesh = try render(mesh: true)
  let activePixels = stride(from: 0, to: vertex.count, by: 4).count {
    vertex[$0] != 0 || vertex[$0 + 1] != 0 || vertex[$0 + 2] != 0
      || vertex[$0 + 3] != 0
  }
  let differingComponents = zip(vertex, mesh).count { $0 != $1 }
  #expect(activePixels > 0)
  #expect(differingComponents == 0)
}

@Test("production ventral barbs pull vertices without materialized output")
func productionVentralBarbsAvoidMaterializedVertexOutput() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let record = CrowVentralRachisCurveRecords.records()[0]
  let length = ventralLODReferenceLength(record)
  let deformer = try CrowVentralBarbGeometryDeformer(
    backend: backend,
    records: [record]
  )
  let commandBuffer = try #require(backend.queue.makeCommandBuffer())
  let frame = try deformer.encode(
    currentBodyCenter: SIMD3<Float>(0, 0, 0.5),
    previousBodyCenter: SIMD3<Float>(0, 0, 0.5),
    projectedPixelsPerMeter: 481 / length,
    viewProjection: matrix_identity_float4x4,
    commandBuffer: commandBuffer
  )
  commandBuffer.commit()
  commandBuffer.waitUntilCompleted()
  #expect(commandBuffer.status == .completed)
  #expect(deformer.compactedRecordCount(for: frame) == 1)
  #expect(deformer.drawArguments(for: frame).vertexCount == UInt32(frame.vertexCount))
  #expect(frame.outputBuffer.length == 16)
  #expect(!frame.readbackReady)
}

@Test("previous max depth conservatively culls retained ventral barbs")
func previousMaxDepthCullsRetainedVentralBarbs() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  var record = CrowVentralRachisCurveRecords.records()[0]
  let translation = SIMD3<Float>(0, 0, 0.5)
  record.rootAndPennaceousStart = translated(
    record.rootAndPennaceousStart,
    by: translation
  )
  record.tipAndCamber = translated(record.tipAndCamber, by: translation)

  func classify(depth: Float) throws -> CrowVentralBarbVisibilityCounts {
    let deformer = try CrowVentralBarbGeometryDeformer(
      backend: backend,
      records: [record]
    )
    let pyramid = try constantDepthPyramid(
      device: device,
      width: 64,
      height: 64,
      depth: depth
    )
    let commandBuffer = try #require(backend.queue.makeCommandBuffer())
    let frame = try deformer.encode(
      currentBodyCenter: .zero,
      previousBodyCenter: .zero,
      projectedPixelsPerMeter: 30_000,
      viewProjection: matrix_identity_float4x4,
      previousViewProjection: matrix_identity_float4x4,
      previousDepthPyramid: pyramid,
      occlusionViewport: SIMD2<Int>(64, 64),
      commandBuffer: commandBuffer
    )
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    #expect(commandBuffer.status == .completed)
    return deformer.visibilityCounts(for: frame)
  }

  let occluded = try classify(depth: 0.2)
  #expect(occluded.frustumVisible == 1)
  #expect(occluded.occlusionTested == 1)
  #expect(occluded.occlusionCulled == 1)
  #expect(occluded.postOcclusionVisible == 0)

  let background = try classify(depth: 1)
  #expect(background.frustumVisible == 1)
  #expect(background.occlusionTested == 1)
  #expect(background.occlusionCulled == 0)
  #expect(background.postOcclusionVisible == 1)
}

@Test("crow max-depth hierarchy propagates uncovered depth")
func crowMaxDepthHierarchyPropagatesDepth() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let width = 16
  let height = 8
  let descriptor = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .depth32Float,
    width: width,
    height: height,
    mipmapped: false
  )
  descriptor.storageMode = .private
  descriptor.usage = [.renderTarget, .shaderRead]
  let depth = try #require(device.makeTexture(descriptor: descriptor))
  let pyramid = try CrowOcclusionDepthPyramid(
    backend: backend,
    width: width,
    height: height
  )
  let commandBuffer = try #require(backend.queue.makeCommandBuffer())
  let pass = MTLRenderPassDescriptor()
  pass.depthAttachment.texture = depth
  pass.depthAttachment.loadAction = .clear
  pass.depthAttachment.storeAction = .store
  pass.depthAttachment.clearDepth = 0.375
  let render = try #require(commandBuffer.makeRenderCommandEncoder(descriptor: pass))
  render.endEncoding()
  try pyramid.encode(deviceDepth: depth, commandBuffer: commandBuffer)
  let readback = try backend.buffer(length: MemoryLayout<Float>.stride, shared: true)
  let blit = try #require(commandBuffer.makeBlitCommandEncoder())
  blit.copy(
    from: pyramid.texture,
    sourceSlice: 0,
    sourceLevel: pyramid.texture.mipmapLevelCount - 1,
    sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
    sourceSize: MTLSize(width: 1, height: 1, depth: 1),
    to: readback,
    destinationOffset: 0,
    destinationBytesPerRow: MemoryLayout<Float>.stride,
    destinationBytesPerImage: MemoryLayout<Float>.stride
  )
  blit.endEncoding()
  commandBuffer.commit()
  commandBuffer.waitUntilCompleted()
  #expect(commandBuffer.status == .completed)
  let reduced = readback.contents().load(as: Float.self)
  #expect(abs(reduced - 0.375) < 1e-7)
}

private struct BarbTubeVertexOracle {
  let position: SIMD3<Float>
  let previousPosition: SIMD3<Float>
  let normal: SIMD3<Float>
}

private func constantDepthPyramid(
  device: MTLDevice,
  width: Int,
  height: Int,
  depth: Float
) throws -> MTLTexture {
  let descriptor = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .r32Float,
    width: width,
    height: height,
    mipmapped: true
  )
  descriptor.storageMode = .shared
  descriptor.usage = .shaderRead
  let texture = try #require(device.makeTexture(descriptor: descriptor))
  for level in 0..<texture.mipmapLevelCount {
    let levelWidth = max(1, width >> level)
    let levelHeight = max(1, height >> level)
    let values = [Float](repeating: depth, count: levelWidth * levelHeight)
    values.withUnsafeBytes { bytes in
      texture.replace(
        region: MTLRegionMake2D(0, 0, levelWidth, levelHeight),
        mipmapLevel: level,
        withBytes: bytes.baseAddress!,
        bytesPerRow: levelWidth * MemoryLayout<Float>.stride
      )
    }
  }
  return texture
}

private func tubeVertices(
  segment: CrowFeatherMesostructureSegment,
  currentCenter: SIMD3<Float>,
  previousCenter: SIMD3<Float>
) -> [BarbTubeVertexOracle] {
  let axis = normalized(
    segment.end - segment.start,
    fallback: SIMD3<Float>(0, 0, 1)
  )
  let helper: SIMD3<Float> =
    abs(axis.z) < 0.82
    ? SIMD3<Float>(0, 0, 1) : SIMD3<Float>(0, 1, 0)
  let first = normalized(
    simd_cross(axis, helper),
    fallback: SIMD3<Float>(1, 0, 0)
  )
  let second = normalized(
    simd_cross(axis, first),
    fallback: SIMD3<Float>(0, 1, 0)
  )
  var result: [BarbTubeVertexOracle] = []
  for radialIndex in 0..<4 {
    let next = (radialIndex + 1) % 4
    let angle0 = 2 * Float.pi * Float(radialIndex) / 4
    let angle1 = 2 * Float.pi * Float(next) / 4
    let radial0 = cos(angle0) * first + sin(angle0) * second
    let radial1 = cos(angle1) * first + sin(angle1) * second
    let points = [
      segment.start + segment.startRadiusMeters * radial0,
      segment.start + segment.startRadiusMeters * radial1,
      segment.end + segment.endRadiusMeters * radial1,
      segment.end + segment.endRadiusMeters * radial0,
    ]
    for corners in [[0, 1, 2], [0, 2, 3]] {
      let normal = normalized(
        simd_cross(
          points[corners[1]] - points[corners[0]],
          points[corners[2]] - points[corners[0]]
        ),
        fallback: SIMD3<Float>(0, 0, 1)
      )
      for corner in corners {
        result.append(
          BarbTubeVertexOracle(
            position: points[corner] + currentCenter,
            previousPosition: points[corner] + previousCenter,
            normal: normal
          )
        )
      }
    }
  }
  return result
}

private func xyz(_ value: SIMD4<Float>) -> SIMD3<Float> {
  SIMD3<Float>(value.x, value.y, value.z)
}

private func translated(
  _ value: SIMD4<Float>,
  by translation: SIMD3<Float>
) -> SIMD4<Float> {
  SIMD4<Float>(xyz(value) + translation, value.w)
}

private func allFinite(_ value: SIMD3<Float>) -> Bool {
  value.x.isFinite && value.y.isFinite && value.z.isFinite
}

private func normalized(
  _ value: SIMD3<Float>,
  fallback: SIMD3<Float>
) -> SIMD3<Float> {
  simd_length_squared(value) > 1e-24 ? simd_normalize(value) : fallback
}
