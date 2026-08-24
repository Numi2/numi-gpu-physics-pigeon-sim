import Metal
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
