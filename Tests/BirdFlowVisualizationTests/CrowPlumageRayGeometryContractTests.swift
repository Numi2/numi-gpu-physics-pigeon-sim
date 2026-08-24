import Metal
import simd
import Testing

@testable import BirdFlowVisualization

@Test("expanded crow curve ribbons have one ray-input layout")
func crowPlumageRayGeometryContractMatchesExpandedVertices() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let vertexCount = 24
  guard let buffer = device.makeBuffer(
    length: vertexCount * MemoryLayout<CrowFeatherVertexGPU>.stride,
    options: .storageModeShared
  ) else {
    Issue.record("unable to allocate ray geometry test buffer")
    return
  }

  let descriptor = try CrowPlumageRayGeometryContract.triangleGeometryDescriptor(
    vertexBuffer: buffer,
    vertexCount: vertexCount
  )

  #expect(CrowPlumageRayGeometryContract.authority
    == "expanded-retained-curve-ribbons-from-canonical-compact-work")
  #expect(CrowPlumageRayGeometryContract.positionFormat == .float4)
  #expect(CrowPlumageRayGeometryContract.positionOffset == 0)
  #expect(
    CrowPlumageRayGeometryContract.vertexStride
      == MemoryLayout<CrowFeatherVertexGPU>.stride
  )
  #expect(descriptor.vertexBuffer === buffer)
  #expect(descriptor.vertexBufferOffset == 0)
  #expect(descriptor.vertexFormat == .float4)
  #expect(descriptor.vertexStride == MemoryLayout<CrowFeatherVertexGPU>.stride)
  #expect(descriptor.triangleCount == vertexCount / 3)
}

@Test("crow ray-input layout rejects incomplete triangle ribbons")
func crowPlumageRayGeometryContractRejectsInvalidStorage() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  guard let buffer = device.makeBuffer(length: 96, options: .storageModeShared)
  else {
    Issue.record("unable to allocate ray geometry test buffer")
    return
  }

  do {
    _ = try CrowPlumageRayGeometryContract.triangleGeometryDescriptor(
      vertexBuffer: buffer,
      vertexCount: 5
    )
    Issue.record("a non-triangle vertex count unexpectedly succeeded")
  } catch let error as CrowPlumageRayGeometryContract.ContractError {
    #expect(error == .nonTriangleVertexCount(5))
  }

  do {
    _ = try CrowPlumageRayGeometryContract.triangleGeometryDescriptor(
      vertexBuffer: buffer,
      vertexCount: 3
    )
    Issue.record("undersized vertex storage unexpectedly succeeded")
  } catch let error as CrowPlumageRayGeometryContract.ContractError {
    #expect(error == .insufficientVertexStorage(requiredBytes: 288, availableBytes: 96))
  }
}

@Test("Metal builds an experimental retained crow curve-ribbon structure")
func metalBuildsCrowPlumageRayGeometryWithoutEnablingVisibility() throws {
  guard let device = MTLCreateSystemDefaultDevice(), device.supportsRaytracing
  else { return }
  let vertexCount = 3
  guard let buffer = device.makeBuffer(
    length: vertexCount * MemoryLayout<CrowFeatherVertexGPU>.stride,
    options: .storageModeShared
  ) else {
    Issue.record("unable to allocate ray geometry test buffer")
    return
  }
  let vertices = buffer.contents().bindMemory(
    to: CrowFeatherVertexGPU.self,
    capacity: vertexCount
  )
  vertices[0] = rayVertex(position: SIMD3<Float>(-0.02, -0.02, 0))
  vertices[1] = rayVertex(position: SIMD3<Float>(0.02, -0.02, 0))
  vertices[2] = rayVertex(position: SIMD3<Float>(0, 0.02, 0))
  let queue = try #require(device.makeCommandQueue())
  let commandBuffer = try #require(queue.makeCommandBuffer())
  let build = try CrowPlumageRayGeometryBuild.encode(
    on: device,
    vertexBuffer: buffer,
    vertexCount: vertexCount,
    commandBuffer: commandBuffer
  )
  commandBuffer.commit()
  commandBuffer.waitUntilCompleted()

  #expect(commandBuffer.status == .completed)
  #expect(build.accelerationStructureSize > 0)
  #expect(build.buildScratchBufferSize > 0)
  #expect(build.accelerationStructure.label == nil)
  #expect(
    CrowPlumageRayVisibilityCapability.current(on: device)
      .experimentalRayVisibilityEnabled == false
  )
}

@Test("Metal builds from the actual retained crow curve expansion")
func metalBuildsExpandedCrowCurveRibbonsWithoutRayAuthority() throws {
  guard let device = MTLCreateSystemDefaultDevice(), device.supportsRaytracing
  else { return }
  let backend = try VisualizationBackend(device: device)
  let record = CrowVentralRachisCurveRecords.records()[0]
  let deformer = try CrowVentralBarbGeometryDeformer(
    backend: backend,
    records: [record]
  )
  let expansion = try #require(backend.queue.makeCommandBuffer())
  let frame = try deformer.encode(
    currentBodyCenter: SIMD3<Float>(0.014, -0.023, 0.5),
    previousBodyCenter: SIMD3<Float>(-0.009, 0.018, 0.47),
    projectedPixelsPerMeter: 10_000,
    viewProjection: matrix_identity_float4x4,
    commandBuffer: expansion,
    auditReadback: true
  )
  expansion.commit()
  expansion.waitUntilCompleted()
  #expect(expansion.status == .completed)
  let vertexCount = Int(deformer.drawArguments(for: frame).vertexCount)
  #expect(vertexCount == frame.vertexCount)
  #expect(vertexCount.isMultiple(of: 3))

  let buildCommand = try #require(backend.queue.makeCommandBuffer())
  let build = try CrowPlumageRayGeometryBuild.encode(
    on: device,
    vertexBuffer: frame.outputBuffer,
    vertexCount: vertexCount,
    commandBuffer: buildCommand
  )
  buildCommand.commit()
  buildCommand.waitUntilCompleted()

  #expect(buildCommand.status == .completed)
  #expect(build.accelerationStructureSize > 0)
  #expect(
    CrowPlumageRayVisibilityCapability.current(on: device)
      .experimentalRayVisibilityEnabled == false
  )
}

private func rayVertex(position: SIMD3<Float>) -> CrowFeatherVertexGPU {
  CrowFeatherVertexGPU(
    position: SIMD4<Float>(position, 1),
    normal: SIMD4<Float>(0, 0, 1, 0),
    color: SIMD4<Float>(0.01, 0.01, 0.012, 1),
    previousPosition: SIMD4<Float>(position, 1),
    identity: .zero,
    parameters: .zero
  )
}
