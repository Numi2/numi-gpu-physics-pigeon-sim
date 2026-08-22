import Metal
import Testing
import simd

@testable import BirdFlowVisualization

@Test("ventral barb curves activate only at resolvable projected size")
func ventralBarbCurvesActivateAtResolvableProjectedSize() {
  let allRecords = CrowVentralRachisCurveRecords.records()
  let ordinaryWork = CrowVentralBarbCurveRecords.segmentWork(
    records: allRecords,
    projectedPixelsPerMeter: 1_600
  )
  #expect(ordinaryWork.isEmpty)
  let closeupWork = CrowVentralBarbCurveRecords.segmentWork(
    records: allRecords,
    projectedPixelsPerMeter: 14_440
  )
  #expect(Set(closeupWork.map { $0.indices.x }).count == 746)
  #expect(closeupWork.count == 429_696)
  #expect(closeupWork.count * 24 == 10_312_704)

  let record = CrowVentralRachisCurveRecords.records()[0]
  let length = simd_distance(
    xyz(record.rootAndPennaceousStart),
    xyz(record.tipAndCamber)
  )
  let below = CrowVentralBarbCurveRecords.segmentWork(
    records: [record],
    projectedPixelsPerMeter: 479 / length
  )
  #expect(below.isEmpty)
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
  #expect(showcaseFallback.contains { $0.kind == .edgeBarbGroup })

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

@Test("ventral barb intervals form connected crown-following curves")
func ventralBarbIntervalsFormConnectedCrownCurves() {
  let records = CrowVentralRachisCurveRecords.records()
  for record in records.prefix(8) {
    let length = simd_distance(
      xyz(record.rootAndPennaceousStart),
      xyz(record.tipAndCamber)
    )
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
  let length = simd_distance(
    xyz(record.rootAndPennaceousStart),
    xyz(record.tipAndCamber)
  )
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

  let dormantCommand = try #require(backend.queue.makeCommandBuffer())
  let dormantFrame = try deformer.encode(
    currentBodyCenter: .zero,
    previousBodyCenter: .zero,
    projectedPixelsPerMeter: 1_600,
    viewProjection: matrix_identity_float4x4,
    commandBuffer: dormantCommand
  )
  dormantCommand.commit()
  dormantCommand.waitUntilCompleted()
  #expect(dormantCommand.status == .completed)
  #expect(deformer.compactedRecordCount(for: dormantFrame) == 0)
  #expect(deformer.drawArguments(for: dormantFrame).vertexCount == 0)
}

@Test("production ventral barbs pull vertices without materialized output")
func productionVentralBarbsAvoidMaterializedVertexOutput() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let record = CrowVentralRachisCurveRecords.records()[0]
  let length = simd_distance(
    xyz(record.rootAndPennaceousStart),
    xyz(record.tipAndCamber)
  )
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

private struct BarbTubeVertexOracle {
  let position: SIMD3<Float>
  let previousPosition: SIMD3<Float>
  let normal: SIMD3<Float>
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
