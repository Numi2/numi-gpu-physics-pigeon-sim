import Testing
import Metal
import simd

@testable import BirdFlowVisualization

@Test("ventral crown rachises retain compact stable analytic records")
func ventralCrownRachisesRetainCompactStableRecords() {
  let records = CrowVentralRachisCurveRecords.records()
  #expect(records == CrowVentralRachisCurveRecords.records())
  #expect(records.count == 776)
  #expect(MemoryLayout<CrowVentralRachisCurveRecordGPU>.stride == 112)
  #expect(CrowVentralRachisCurveRecords.verticesPerCurveInterval == 24)
  #expect(CrowVentralRachisCurveRecords.maximumRachisSectionCount == 12)
  #expect(Set(records.map(\.identity)).count == records.count)
  #expect(
    CrowVentralRachisCurveRecords.segmentWork(
      records: records,
      projectedPixelsPerMeter: 1_399
    ).isEmpty
  )
  let showcaseWork = CrowVentralRachisCurveRecords.segmentWork(
    records: records,
    projectedPixelsPerMeter: 1_600
  )
  #expect(showcaseWork.count == 776 * 4)
  #expect(showcaseWork.allSatisfy { $0.indices.z == 4 })
  let futureWork = CrowVentralRachisCurveRecords.segmentWork(
    records: records,
    projectedPixelsPerMeter: 20_000
  )
  #expect(futureWork.count == 776 * 12)
  #expect(futureWork.allSatisfy { $0.indices.z == 12 })
}

@Test("retained ventral curves reproduce the established crown shaft oracle")
func retainedVentralCurvesReproduceEstablishedCrownShaft() {
  let eligible = CrowVentralFeatherTracts.samples().filter(
    CrowVentralFeatherTracts.retainsCrownRachis
  )
  let records = CrowVentralRachisCurveRecords.records()
  #expect(eligible.count == records.count)
  for (feather, record) in zip(eligible, records) {
    let expected = CrowVentralRachisCurveRecords.crownSegments(
      for: feather,
      projectedPixelsPerMeter: 1_600
    )
    let retained = (0..<4).map {
      CrowVentralRachisCurveRecords.segment(
        record: record,
        intervalIndex: $0,
        intervalCount: 4
      )
    }
    #expect(expected.count == retained.count)
    for (lhs, rhs) in zip(expected, retained) {
      #expect(lhs.kind == rhs.kind)
      #expect(simd_distance(lhs.start, rhs.start) < 2e-7)
      #expect(simd_distance(lhs.end, rhs.end) < 2e-7)
      #expect(abs(lhs.startRadiusMeters - rhs.startRadiusMeters) < 1e-9)
      #expect(abs(lhs.endRadiusMeters - rhs.endRadiusMeters) < 1e-9)
    }
  }
}

@Test("Metal expands retained ventral curves into the temporal tube oracle")
func metalExpandsRetainedVentralCurvesIntoTemporalTubeOracle() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let deformer = try CrowVentralRachisGeometryDeformer(backend: backend)
  let currentCenter = SIMD3<Float>(0.013, -0.021, 0.034)
  let previousCenter = SIMD3<Float>(-0.008, 0.017, -0.025)
  let commandBuffer = try #require(backend.queue.makeCommandBuffer())
  let frame = try deformer.encode(
    currentBodyCenter: currentCenter,
    previousBodyCenter: previousCenter,
    projectedPixelsPerMeter: 1_600,
    commandBuffer: commandBuffer,
    auditReadback: true
  )
  commandBuffer.commit()
  commandBuffer.waitUntilCompleted()
  #expect(commandBuffer.status == .completed)
  #expect(frame.vertexCount == 776 * 4 * 24)
  let vertices = deformer.vertices(for: frame)
  let records = deformer.recordsForTesting()
  for (recordIndex, intervalIndex) in [(0, 0), (records.count - 1, 3)] {
    let segment = CrowVentralRachisCurveRecords.segment(
      record: records[recordIndex],
      intervalIndex: intervalIndex,
      intervalCount: 4
    )
    let expected = tubeVertices(
      segment: segment,
      currentCenter: currentCenter,
      previousCenter: previousCenter
    )
    let base = (recordIndex * 4 + intervalIndex) * 24
    for (gpu, oracle) in zip(vertices[base..<(base + 24)], expected) {
      #expect(simd_distance(xyz(gpu.position), oracle.position) < 3e-7)
      #expect(simd_distance(xyz(gpu.previousPosition), oracle.previousPosition) < 3e-7)
      #expect(simd_distance(xyz(gpu.normal), oracle.normal) < 5e-6)
      #expect(gpu.identity.x == UInt32.max)
      #expect(gpu.identity.z == 2)
      #expect(gpu.identity.w == 7)
      #expect(gpu.parameters == SIMD4<Float>(0.5, 0, 0, 0))
    }
  }

  let futureCommandBuffer = try #require(backend.queue.makeCommandBuffer())
  let futureFrame = try deformer.encode(
    currentBodyCenter: currentCenter,
    previousBodyCenter: previousCenter,
    projectedPixelsPerMeter: 20_000,
    commandBuffer: futureCommandBuffer,
    auditReadback: true
  )
  futureCommandBuffer.commit()
  futureCommandBuffer.waitUntilCompleted()
  #expect(futureCommandBuffer.status == .completed)
  #expect(futureFrame.vertexCount == 776 * 12 * 24)
  let futureVertices = deformer.vertices(for: futureFrame)
  let lastRecordIndex = records.count - 1
  let futureSegment = CrowVentralRachisCurveRecords.segment(
    record: records[lastRecordIndex],
    intervalIndex: 11,
    intervalCount: 12
  )
  let futureExpected = tubeVertices(
    segment: futureSegment,
    currentCenter: currentCenter,
    previousCenter: previousCenter
  )
  let futureBase = (lastRecordIndex * 12 + 11) * 24
  for (gpu, oracle) in zip(
    futureVertices[futureBase..<(futureBase + 24)],
    futureExpected
  ) {
    #expect(simd_distance(xyz(gpu.position), oracle.position) < 3e-7)
    #expect(simd_distance(xyz(gpu.previousPosition), oracle.previousPosition) < 3e-7)
    #expect(simd_distance(xyz(gpu.normal), oracle.normal) < 8e-6)
  }
}

private struct TubeVertexOracle {
  let position: SIMD3<Float>
  let previousPosition: SIMD3<Float>
  let normal: SIMD3<Float>
}

private func tubeVertices(
  segment: CrowFeatherMesostructureSegment,
  currentCenter: SIMD3<Float>,
  previousCenter: SIMD3<Float>
) -> [TubeVertexOracle] {
  let axis = normalized(
    segment.end - segment.start,
    fallback: SIMD3<Float>(0, 0, 1)
  )
  let helper: SIMD3<Float> = abs(axis.z) < 0.82
    ? SIMD3<Float>(0, 0, 1) : SIMD3<Float>(0, 1, 0)
  let first = normalized(
    simd_cross(axis, helper),
    fallback: SIMD3<Float>(1, 0, 0)
  )
  let second = normalized(
    simd_cross(axis, first),
    fallback: SIMD3<Float>(0, 1, 0)
  )
  var result: [TubeVertexOracle] = []
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
          TubeVertexOracle(
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

private func normalized(
  _ value: SIMD3<Float>,
  fallback: SIMD3<Float>
) -> SIMD3<Float> {
  simd_length_squared(value) > 1e-14 ? simd_normalize(value) : fallback
}
