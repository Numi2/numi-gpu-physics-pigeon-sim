import Metal

/// Prior-frame max-device-depth hierarchy for conservative occlusion tests.
///
/// Device depth clears to one. Max reduction therefore propagates any uncovered
/// background through the hierarchy and makes the classifier fail open.
final class CrowOcclusionDepthPyramid {
  private let backend: VisualizationBackend
  private let copyPipeline: MTLComputePipelineState
  private let reducePipeline: MTLComputePipelineState
  private let levelViews: [MTLTexture]

  let texture: MTLTexture
  let width: Int
  let height: Int
  let allocatedBytes: Int

  init(backend: VisualizationBackend, width: Int, height: Int) throws {
    precondition(width > 0 && height > 0)
    self.backend = backend
    self.width = width
    self.height = height
    copyPipeline = try backend.compute("copyCrowDeviceDepthToOcclusionLevel")
    reducePipeline = try backend.compute("reduceCrowOcclusionDepthMax")

    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .r32Float,
      width: width,
      height: height,
      mipmapped: true
    )
    descriptor.storageMode = .private
    descriptor.usage = [.shaderRead, .shaderWrite, .pixelFormatView]
    guard let texture = backend.device.makeTexture(descriptor: descriptor) else {
      throw VisualizationError.allocation(
        Self.byteCount(width: width, height: height)
      )
    }
    texture.label = "Crow previous-frame max-depth hierarchy"
    self.texture = texture
    var views: [MTLTexture] = []
    for level in 0..<texture.mipmapLevelCount {
      guard
        let view = texture.makeTextureView(
          pixelFormat: .r32Float,
          textureType: .type2D,
          levels: level..<(level + 1),
          slices: 0..<1
        )
      else {
        throw VisualizationError.pipeline("crow occlusion depth mip view")
      }
      views.append(view)
    }
    levelViews = views
    allocatedBytes = Self.byteCount(width: width, height: height)
  }

  func encode(deviceDepth: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
    guard deviceDepth.width == width, deviceDepth.height == height else {
      throw VisualizationError.pipeline("crow occlusion depth dimensions")
    }
    guard let copy = commandBuffer.makeComputeCommandEncoder() else {
      throw VisualizationError.pipeline("crow occlusion depth copy encoder")
    }
    copy.label = "Copy resolved crow depth into occlusion hierarchy"
    copy.setTexture(deviceDepth, index: 0)
    copy.setTexture(levelViews[0], index: 1)
    backend.dispatch2D(
      copy,
      pipeline: copyPipeline,
      width: width,
      height: height
    )
    copy.endEncoding()

    for level in 1..<levelViews.count {
      guard let reduce = commandBuffer.makeComputeCommandEncoder() else {
        throw VisualizationError.pipeline("crow occlusion depth reduce encoder")
      }
      reduce.label = "Reduce crow max depth level \(level)"
      reduce.setTexture(levelViews[level - 1], index: 0)
      reduce.setTexture(levelViews[level], index: 1)
      backend.dispatch2D(
        reduce,
        pipeline: reducePipeline,
        width: levelViews[level].width,
        height: levelViews[level].height
      )
      reduce.endEncoding()
    }
  }

  private static func byteCount(width: Int, height: Int) -> Int {
    var total = 0
    var levelWidth = width
    var levelHeight = height
    while true {
      total += levelWidth * levelHeight * MemoryLayout<Float>.stride
      if levelWidth == 1 && levelHeight == 1 { return total }
      levelWidth = max(1, levelWidth / 2)
      levelHeight = max(1, levelHeight / 2)
    }
  }
}
