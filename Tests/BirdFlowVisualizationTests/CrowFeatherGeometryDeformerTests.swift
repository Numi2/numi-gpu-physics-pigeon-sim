import BirdFlowMetal
import Metal
import Testing
import simd

@testable import BirdFlowVisualization

@Test("persistent crow feather templates deform on Metal with temporal parity")
func crowFeatherTemplateGPUDeformationMatchesCPUReference() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let asset = try BirdRealityAssetLoader.load(
    assetURL: root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-reality-v1.json"
    ),
    repositoryRootURL: root
  )
  let surface = try MeasuredBirdSurfaceSequenceLoader.load(
    manifestURL: root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"
    )
  )
  let backend = try VisualizationBackend(device: device)
  let rootDeformer = try CrowFeatherRootDeformer(
    backend: backend,
    dataset: surface,
    asset: asset
  )
  let geometryDeformer = try CrowFeatherGeometryDeformer(
    backend: backend,
    featherCount: asset.feathers.count
  )

  #expect(MemoryLayout<CrowFeatherTemplateVertexGPU>.stride == 16)
  #expect(MemoryLayout<CrowFeatherVertexGPU>.stride == 96)
  #expect(MemoryLayout<CrowFeatherGeometryUniforms>.stride == 32)
  #expect(geometryDeformer.vertexCount == 54 * 12 * 6)

  let body = surface.components.first { $0.partIdentifier == 1 }!
  var referenceBodyCenter = SIMD3<Float>.zero
  for index in body.vertexOffset..<(body.vertexOffset + body.vertexCount) {
    referenceBodyCenter += surface.vertex(frame: 0, index: index)
  }
  referenceBodyCenter /= Float(body.vertexCount)
  let renderOffset = -referenceBodyCenter
  let phases: [(Float, Float)] = [
    (0, 0),
    (0.271, 0.249),
    (0.503, 0.481),
    (0.997, 0.975),
  ]
  var maximumRadialExtent: Float = 0
  var maximumBilateralSpan: Float = 0

  for (current, previous) in phases {
    guard let commandBuffer = backend.queue.makeCommandBuffer() else {
      Issue.record("unable to allocate crow feather geometry command buffer")
      return
    }
    let rootFrame = try rootDeformer.encode(
      currentPhase: current,
      previousPhase: previous,
      commandBuffer: commandBuffer
    )
    let geometryFrame = try geometryDeformer.encode(
      rootFrame: rootFrame,
      renderOffset: renderOffset,
      commandBuffer: commandBuffer,
      auditReadback: true
    )
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    #expect(commandBuffer.status == .completed)

    let actual = geometryDeformer.vertices(for: geometryFrame)
    let expected = geometryDeformer.referenceVertices(
      roots: rootDeformer.referenceStates(
        currentPhase: current,
        previousPhase: previous
      ),
      renderOffset: renderOffset
    )
    let expectedPositions = expected.map {
      SIMD3<Float>($0.position.x, $0.position.y, $0.position.z)
    }
    maximumRadialExtent = max(
      maximumRadialExtent,
      expectedPositions.map(simd_length).max() ?? 0
    )
    if let minimumY = expectedPositions.map(\.y).min(),
      let maximumY = expectedPositions.map(\.y).max()
    {
      maximumBilateralSpan = max(maximumBilateralSpan, maximumY - minimumY)
    }
    #expect(actual.count == expected.count)
    var maximumPositionDifference: Float = 0
    var maximumNormalDifference: Float = 0
    var maximumColorDifference: Float = 0
    var maximumPreviousPositionDifference: Float = 0
    var maximumParameterDifference: Float = 0
    for (gpu, cpu) in zip(actual, expected) {
      maximumPositionDifference = max(
        maximumPositionDifference,
        simd_length(gpu.position - cpu.position)
      )
      maximumNormalDifference = max(
        maximumNormalDifference,
        simd_length(gpu.normal - cpu.normal)
      )
      maximumColorDifference = max(
        maximumColorDifference,
        simd_length(gpu.color - cpu.color)
      )
      maximumPreviousPositionDifference = max(
        maximumPreviousPositionDifference,
        simd_length(gpu.previousPosition - cpu.previousPosition)
      )
      maximumParameterDifference = max(
        maximumParameterDifference,
        simd_length(gpu.parameters - cpu.parameters)
      )
      #expect(gpu.identity == cpu.identity)
    }
    #expect(maximumPositionDifference < 3e-6)
    #expect(maximumNormalDifference < 1e-5)
    #expect(maximumColorDifference < 2e-7)
    #expect(maximumPreviousPositionDifference < 3e-6)
    #expect(maximumParameterDifference < 2e-7)
  }
  #expect(maximumRadialExtent < 0.75)
  #expect(maximumBilateralSpan < 1.10)

  let movingRoots = rootDeformer.referenceStates(
    currentPhase: 0.503,
    previousPhase: 0.481
  )
  let movingVertices = geometryDeformer.referenceVertices(
    roots: movingRoots,
    renderOffset: renderOffset
  )
  #expect(Set(movingVertices.map { $0.identity.y }).count == 54)
  #expect(movingVertices.allSatisfy { $0.parameters.x >= 0 && $0.parameters.x <= 1 })
  #expect(movingVertices.contains { $0.parameters.y == -1 })
  #expect(movingVertices.contains { $0.parameters.y == 1 })
  #expect(
    movingVertices.contains {
      simd_length(
        SIMD3<Float>($0.position.x, $0.position.y, $0.position.z)
          - SIMD3<Float>(
            $0.previousPosition.x,
            $0.previousPosition.y,
            $0.previousPosition.z
          )
      ) > 1e-5
    }
  )
  #expect(
    movingVertices.allSatisfy {
      $0.position.x.isFinite && $0.position.y.isFinite && $0.position.z.isFinite
    }
  )
}
