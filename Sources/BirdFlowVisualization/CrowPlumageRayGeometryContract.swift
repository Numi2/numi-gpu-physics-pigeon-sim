import Metal

/// The single future ray-input layout for expanded retained feather curves.
///
/// The current renderer rasterizes these curves procedurally from compact work
/// records. The audit expansion uses exactly the same records and writes
/// triangle-major `CrowFeatherVertexGPU` values. Keeping this contract tied to
/// that output prevents a future acceleration structure from drifting into a
/// second approximation of the crow's visible plumage.
enum CrowPlumageRayGeometryContract {
  /// The first field in `CrowFeatherVertexGPU` is a SIMD4 position. Float4 is
  /// intentional: it matches the live expansion output rather than repacking
  /// it into an unverified ray-only buffer.
  static let positionFormat: MTLAttributeFormat = .float4
  static let vertexStride = MemoryLayout<CrowFeatherVertexGPU>.stride
  static let positionOffset = 0
  static let authority =
    "expanded-retained-curve-ribbons-from-canonical-compact-work"

  enum ContractError: Error, Equatable {
    case nonTriangleVertexCount(Int)
    case insufficientVertexStorage(requiredBytes: Int, availableBytes: Int)
  }

  /// Creates a triangle geometry descriptor for a completed GPU expansion.
  /// This does not build or query an acceleration structure and must not be
  /// used as an indication that ray visibility is enabled. A future build must
  /// preserve this exact output and satisfy the separate AOV-parity gate.
  static func triangleGeometryDescriptor(
    vertexBuffer: MTLBuffer,
    vertexCount: Int
  ) throws -> MTLAccelerationStructureTriangleGeometryDescriptor {
    guard vertexCount >= 0, vertexCount.isMultiple(of: 3) else {
      throw ContractError.nonTriangleVertexCount(vertexCount)
    }
    let requiredBytes = vertexCount * vertexStride
    guard requiredBytes <= vertexBuffer.length else {
      throw ContractError.insufficientVertexStorage(
        requiredBytes: requiredBytes,
        availableBytes: vertexBuffer.length
      )
    }
    let descriptor = MTLAccelerationStructureTriangleGeometryDescriptor()
    descriptor.vertexBuffer = vertexBuffer
    descriptor.vertexBufferOffset = positionOffset
    descriptor.vertexFormat = positionFormat
    descriptor.vertexStride = vertexStride
    descriptor.triangleCount = vertexCount / 3
    return descriptor
  }
}

/// Retains the resources for one explicit-curve ribbon acceleration-structure
/// build. It is an experimental compute-only utility: no production render
/// pass queries this structure, and the raster/AOV authorities remain intact.
struct CrowPlumageRayGeometryBuild {
  let accelerationStructure: MTLAccelerationStructure
  let accelerationStructureSize: Int
  let buildScratchBufferSize: Int
  private let scratchBuffer: MTLBuffer

  enum BuildError: Error, Equatable {
    case rayTracingUnsupported
    case accelerationStructureAllocation(Int)
    case scratchBufferAllocation(Int)
    case commandEncoderUnavailable
  }

  /// Encodes a bottom-level acceleration-structure build over the exact
  /// triangle ribbons produced from retained crow curve work. The caller must
  /// keep the returned value alive until the command buffer completes.
  static func encode(
    on device: MTLDevice,
    vertexBuffer: MTLBuffer,
    vertexCount: Int,
    commandBuffer: MTLCommandBuffer
  ) throws -> Self {
    guard device.supportsRaytracing else {
      throw BuildError.rayTracingUnsupported
    }
    let triangles = try CrowPlumageRayGeometryContract.triangleGeometryDescriptor(
      vertexBuffer: vertexBuffer,
      vertexCount: vertexCount
    )
    triangles.opaque = false
    let descriptor = MTLPrimitiveAccelerationStructureDescriptor()
    descriptor.geometryDescriptors = [triangles]
    let sizes = device.accelerationStructureSizes(descriptor: descriptor)
    guard let accelerationStructure = device.makeAccelerationStructure(
      size: sizes.accelerationStructureSize
    ) else {
      throw BuildError.accelerationStructureAllocation(
        sizes.accelerationStructureSize
      )
    }
    guard let scratchBuffer = device.makeBuffer(
      length: sizes.buildScratchBufferSize,
      options: .storageModePrivate
    ) else {
      throw BuildError.scratchBufferAllocation(sizes.buildScratchBufferSize)
    }
    guard let encoder = commandBuffer.makeAccelerationStructureCommandEncoder()
    else {
      throw BuildError.commandEncoderUnavailable
    }
    encoder.label = "Experimental retained crow curve-ribbon AS build"
    encoder.build(
      accelerationStructure: accelerationStructure,
      descriptor: descriptor,
      scratchBuffer: scratchBuffer,
      scratchBufferOffset: 0
    )
    encoder.endEncoding()
    return Self(
      accelerationStructure: accelerationStructure,
      accelerationStructureSize: sizes.accelerationStructureSize,
      buildScratchBufferSize: sizes.buildScratchBufferSize,
      scratchBuffer: scratchBuffer
    )
  }
}
