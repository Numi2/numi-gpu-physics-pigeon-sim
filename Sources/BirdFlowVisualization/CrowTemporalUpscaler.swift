import Metal
import MetalFX

/// Persistent MetalFX ownership for the crow capture. The native renderer
/// remains available as a parity oracle; requesting this path fails closed on
/// devices or scale factors MetalFX does not support.
final class CrowTemporalUpscaler {
  let inputWidth: Int
  let inputHeight: Int
  let outputWidth: Int
  let outputHeight: Int
  let usesReactiveMask: Bool

  private let scaler: any MTLFXTemporalScaler

  init(
    device: MTLDevice,
    inputWidth: Int,
    inputHeight: Int,
    outputWidth: Int,
    outputHeight: Int
  ) throws {
    guard MTLFXTemporalScalerDescriptor.supportsDevice(device) else {
      throw VisualizationError.pipeline("MetalFX temporal scaling unsupported")
    }
    let horizontalScale = Float(outputWidth) / Float(inputWidth)
    let verticalScale = Float(outputHeight) / Float(inputHeight)
    let minimumScale = MTLFXTemporalScalerDescriptor.supportedInputContentMinScale(
      device: device
    )
    let maximumScale = MTLFXTemporalScalerDescriptor.supportedInputContentMaxScale(
      device: device
    )
    guard horizontalScale >= minimumScale, horizontalScale <= maximumScale,
      verticalScale >= minimumScale, verticalScale <= maximumScale
    else {
      throw VisualizationError.pipeline(
        "MetalFX temporal scale outside device range \(minimumScale)...\(maximumScale)"
      )
    }

    let descriptor = MTLFXTemporalScalerDescriptor()
    descriptor.colorTextureFormat = .rgba16Float
    descriptor.depthTextureFormat = .depth32Float
    descriptor.motionTextureFormat = .rg16Float
    descriptor.outputTextureFormat = .rgba16Float
    descriptor.inputWidth = inputWidth
    descriptor.inputHeight = inputHeight
    descriptor.outputWidth = outputWidth
    descriptor.outputHeight = outputHeight
    descriptor.isAutoExposureEnabled = false
    descriptor.requiresSynchronousInitialization = true
    let reactiveMaskEnabled: Bool
    if #available(macOS 14.4, *) {
      descriptor.isReactiveMaskTextureEnabled = true
      descriptor.reactiveMaskTextureFormat = .r8Unorm
      reactiveMaskEnabled = true
    } else {
      reactiveMaskEnabled = false
    }
    guard let createdScaler = descriptor.makeTemporalScaler(device: device) else {
      throw VisualizationError.pipeline("MetalFX temporal scaler creation")
    }
    scaler = createdScaler
    self.inputWidth = inputWidth
    self.inputHeight = inputHeight
    self.outputWidth = outputWidth
    self.outputHeight = outputHeight
    usesReactiveMask = reactiveMaskEnabled
  }

  var outputTextureUsage: MTLTextureUsage {
    scaler.outputTextureUsage.union(.shaderRead)
  }

  var reactiveMaskTextureUsage: MTLTextureUsage {
    scaler.reactiveTextureUsage.union(.renderTarget)
  }

  func encode(
    commandBuffer: MTLCommandBuffer,
    color: MTLTexture,
    depth: MTLTexture,
    motion: MTLTexture,
    reactiveMask: MTLTexture?,
    output: MTLTexture,
    jitter: SIMD2<Float>,
    reset: Bool
  ) {
    scaler.inputContentWidth = inputWidth
    scaler.inputContentHeight = inputHeight
    scaler.colorTexture = color
    scaler.depthTexture = depth
    scaler.motionTexture = motion
    if #available(macOS 14.4, *) {
      scaler.reactiveMaskTexture = reactiveMask
    }
    scaler.outputTexture = output
    scaler.jitterOffsetX = jitter.x
    scaler.jitterOffsetY = jitter.y
    scaler.motionVectorScaleX = 1
    scaler.motionVectorScaleY = 1
    scaler.isDepthReversed = false
    scaler.reset = reset
    scaler.encode(commandBuffer: commandBuffer)
  }
}
