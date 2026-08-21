import BirdFlowMetal
import Metal
import Testing
import simd

@testable import BirdFlowVisualization

@Test("live underwing coverts retain bilateral identity and temporal morphology")
func liveUnderwingCovertRootBufferContract() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let surface = try MeasuredBirdSurfaceSequenceLoader.load(
    manifestURL: root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"
    )
  )
  let backend = try VisualizationBackend(device: device)
  let covertRoots = try CrowLiveWingCovertRootBuffer(
    backend: backend,
    dataset: surface
  )
  let firstFrame = Array(surface.verticesMeters.prefix(surface.vertexCount))
  let previousFrame = firstFrame.map { $0 + SIMD3<Float>(0.001, -0.002, 0.003) }
  let frame = try covertRoots.upload(
    currentStates: firstFrame,
    previousStates: previousFrame,
    currentDeployment: 1,
    previousDeployment: 0.25
  )
  let states = covertRoots.states(for: frame)

  #expect(MemoryLayout<CrowFeatherRootStateGPU>.stride == 128)
  #expect(covertRoots.featherCount == 216)
  #expect(states.count == 216)
  #expect(Set(states.map(\.identity.y)).count == 216)
  #expect(states.filter { $0.identity.w & 255 == 12 }.count == 162)
  #expect(states.filter { $0.identity.w & 255 == 13 }.count == 54)
  #expect(states.filter { ($0.identity.w >> 8) & 255 == 1 }.count == 108)
  #expect(states.filter { ($0.identity.w >> 8) & 255 == 2 }.count == 108)
  #expect(states.allSatisfy { $0.currentPositionAndLength.w > 0 })
  #expect(states.allSatisfy { $0.previousMorphology.x > 0 })
  #expect(states.allSatisfy {
    $0.previousMorphology.x < $0.currentPositionAndLength.w
  })
  #expect(states.allSatisfy {
    $0.previousMorphology.y < $0.previousPositionAndWidth.w
  })
  #expect(states.allSatisfy {
    abs(simd_length(SIMD3<Float>(
      $0.currentDirectionAndRachis.x,
      $0.currentDirectionAndRachis.y,
      $0.currentDirectionAndRachis.z
    )) - 1) < 2e-6
  })

  let collapsed = covertRoots.referenceStates(
    currentStates: firstFrame,
    previousStates: firstFrame,
    currentDeployment: 0,
    previousDeployment: 0
  )
  #expect(collapsed.allSatisfy { $0.currentPositionAndLength.w == 0 })
  #expect(collapsed.allSatisfy { $0.previousPositionAndWidth.w == 0 })
  #expect(collapsed.allSatisfy { $0.currentDirectionAndRachis.w == 0 })
  #expect(collapsed.allSatisfy { $0.previousDirectionAndCamber.w == 0 })
  #expect(collapsed.allSatisfy { $0.previousMorphology == .zero })
}

@Test("live covert canonical templates match Metal and expose resolved rachis and barbs")
func liveUnderwingCovertGeometryMatchesMetal() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let surface = try MeasuredBirdSurfaceSequenceLoader.load(
    manifestURL: root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"
    )
  )
  let backend = try VisualizationBackend(device: device)
  let covertRoots = try CrowLiveWingCovertRootBuffer(
    backend: backend,
    dataset: surface
  )
  let geometry = try CrowFeatherGeometryDeformer(
    backend: backend,
    featherCount: covertRoots.featherCount,
    gpuSelectedDetailDensity: true
  )
  let states = Array(surface.verticesMeters.prefix(surface.vertexCount))
  guard let commandBuffer = backend.queue.makeCommandBuffer() else {
    Issue.record("unable to allocate live covert command buffer")
    return
  }
  let roots = try covertRoots.upload(
    currentStates: states,
    previousStates: states,
    currentDeployment: 1,
    previousDeployment: 1
  )
  let frame = try geometry.encode(
    rootFrame: roots,
    renderOffset: .zero,
    projectedPixelsPerMeter: 1_600,
    commandBuffer: commandBuffer,
    auditReadback: true
  )
  commandBuffer.commit()
  commandBuffer.waitUntilCompleted()
  #expect(commandBuffer.status == .completed)

  let actual = geometry.vertices(for: frame)
  let expected = geometry.referenceVertices(
    roots: covertRoots.states(for: roots),
    renderOffset: .zero,
    projectedPixelsPerMeter: 1_600
  )
  #expect(actual.count == 216 * (48 * 8 * 6 + 24 * 6 + 20 * 2 * 6))
  #expect(actual.count == expected.count)
  var maximumPositionDifference: Float = 0
  var maximumPreviousPositionDifference: Float = 0
  for (gpu, cpu) in zip(actual, expected) {
    maximumPositionDifference = max(
      maximumPositionDifference,
      simd_length(gpu.position - cpu.position)
    )
    maximumPreviousPositionDifference = max(
      maximumPreviousPositionDifference,
      simd_length(gpu.previousPosition - cpu.previousPosition)
    )
    #expect(gpu.identity == cpu.identity)
  }
  #expect(maximumPositionDifference < 3e-6)
  #expect(maximumPreviousPositionDifference < 3e-6)
  #expect(actual.contains { $0.parameters.w == 1 })
  #expect(actual.contains { $0.parameters.w == 2 })
  #expect(geometry.drawArguments(for: frame).vertexCount == UInt32(actual.count))
  #expect(actual.allSatisfy {
    let featherClass = $0.identity.w & 255
    return featherClass == 12 || featherClass == 13
  })
}

@Test("GPU selects complete live covert detail prefixes for indirect compute and draw")
func liveCovertGPUSelectsCompleteIndirectDetailPrefixes() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let surface = try MeasuredBirdSurfaceSequenceLoader.load(
    manifestURL: root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"
    )
  )
  let backend = try VisualizationBackend(device: device)
  let covertRoots = try CrowLiveWingCovertRootBuffer(
    backend: backend,
    dataset: surface
  )
  let geometry = try CrowFeatherGeometryDeformer(
    backend: backend,
    featherCount: covertRoots.featherCount,
    gpuSelectedDetailDensity: true
  )
  let states = Array(surface.verticesMeters.prefix(surface.vertexCount))
  let expectedVertexCounts = [
    (pixelsPerMeter: Float(900), vertexCount: 216 * 48 * 8 * 6),
    (pixelsPerMeter: Float(1_100), vertexCount: 216 * (48 * 8 * 6 + 24 * 6)),
    (
      pixelsPerMeter: Float(1_600),
      vertexCount: 216 * (48 * 8 * 6 + 24 * 6 + 20 * 2 * 6)
    ),
  ]

  for expected in expectedVertexCounts {
    guard let commandBuffer = backend.queue.makeCommandBuffer() else {
      Issue.record("unable to allocate indirect covert command buffer")
      return
    }
    let roots = try covertRoots.upload(
      currentStates: states,
      previousStates: states,
      currentDeployment: 1,
      previousDeployment: 1
    )
    let frame = try geometry.encode(
      rootFrame: roots,
      renderOffset: .zero,
      projectedPixelsPerMeter: expected.pixelsPerMeter,
      commandBuffer: commandBuffer
    )
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    #expect(commandBuffer.status == .completed)
    let arguments = geometry.drawArguments(for: frame)
    #expect(arguments.vertexCount == UInt32(expected.vertexCount))
    #expect(arguments.instanceCount == 1)
    #expect(arguments.vertexStart == 0)
    #expect(arguments.baseInstance == 0)
    #expect(expected.vertexCount.isMultiple(of: 3 * covertRoots.featherCount))
  }

  guard let prefixCommandBuffer = backend.queue.makeCommandBuffer() else {
    Issue.record("unable to allocate covert prefix-audit command buffer")
    return
  }
  let prefixRoots = try covertRoots.upload(
    currentStates: states,
    previousStates: states,
    currentDeployment: 1,
    previousDeployment: 1
  )
  let prefixFrame = try geometry.encode(
    rootFrame: prefixRoots,
    renderOffset: .zero,
    projectedPixelsPerMeter: 1_100,
    commandBuffer: prefixCommandBuffer,
    auditReadback: true
  )
  prefixCommandBuffer.commit()
  prefixCommandBuffer.waitUntilCompleted()
  #expect(prefixCommandBuffer.status == .completed)
  let vertices = geometry.vertices(for: prefixFrame)
  let vaneVertexCount = 216 * 48 * 8 * 6
  let rachisVertexCount = 216 * 24 * 6
  let vanePrefix = vertices.prefix(vaneVertexCount)
  let rachisPrefix = vertices[
    vaneVertexCount..<(vaneVertexCount + rachisVertexCount)
  ]
  #expect(vanePrefix.allSatisfy { $0.parameters.w == 0 })
  #expect(rachisPrefix.allSatisfy { $0.parameters.w == 1 })
  #expect(Set(vanePrefix.map { $0.identity.y }).count == 216)
  #expect(Set(rachisPrefix.map { $0.identity.y }).count == 216)
}
