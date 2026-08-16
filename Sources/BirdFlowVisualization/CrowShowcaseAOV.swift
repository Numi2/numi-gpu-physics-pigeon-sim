import Foundation
import Metal

struct CrowShowcaseFrame {
  let displayTexture: MTLTexture
  let hdrColorTexture: MTLTexture
  let albedoMaterialTexture: MTLTexture
  let normalCoverageTexture: MTLTexture
  let motionTexture: MTLTexture
  let metricDepthTexture: MTLTexture
  let deviceDepthReadbackBuffer: MTLBuffer?
  let identityTexture: MTLTexture
  let reconstructionMode: String
  let historyReset: Bool
  let jitter: SIMD2<Float>
  let reactiveMaskEnabled: Bool
  let gpuDurationMilliseconds: Double
  let allocatedRenderTargetBytes: Int

  func audit(
    frameIndex: Int,
    nativeReference: CrowShowcaseFrame? = nil
  ) -> CrowShowcaseAOVFrameAudit {
    let width = hdrColorTexture.width
    let height = hdrColorTexture.height
    let pixelCount = width * height
    let hdr = Self.halfValues(texture: hdrColorTexture, componentCount: 4)
    let albedo = Self.halfValues(texture: albedoMaterialTexture, componentCount: 4)
    let normals = Self.halfValues(texture: normalCoverageTexture, componentCount: 4)
    let motion = Self.halfValues(texture: motionTexture, componentCount: 2)
    let depth = Self.floatValues(texture: metricDepthTexture)
    guard let deviceDepthReadbackBuffer else {
      preconditionFailure("crow AOV audit requested without device-depth readback")
    }
    let deviceDepth = Self.floatValues(
      buffer: deviceDepthReadbackBuffer,
      count: pixelCount
    )
    let identity = Self.uintValues(texture: identityTexture, componentCount: 4)

    var finitePixelCount = 0
    var aboveOneHDRPixelCount = 0
    var activeIdentityPixelCount = 0
    var fullyCoveredAOVPixelCount = 0
    var movingActivePixelCount = 0
    var maximumHDRComponent: Float = 0
    var maximumMotionPixels: Float = 0
    var maximumNormalUnitError: Float = 0
    var minimumFullyCoveredDepthMeters = Float.infinity
    var maximumFullyCoveredDepthMeters: Float = 0
    var minimumFullyCoveredDeviceDepth = Float.infinity
    var maximumFullyCoveredDeviceDepth: Float = 0
    var birdYTotal: Float = 0
    var birdPixelCount = 0
    var supportYTotal: Float = 0
    var supportPixelCount = 0
    var featherHashes: Set<UInt32> = []

    for pixel in 0..<pixelCount {
      let hdrOffset = pixel * 4
      let motionOffset = pixel * 2
      let identityOffset = pixel * 4
      let hdrPixel = hdr[hdrOffset..<(hdrOffset + 4)]
      let albedoPixel = albedo[hdrOffset..<(hdrOffset + 4)]
      let normalPixel = normals[hdrOffset..<(hdrOffset + 4)]
      let motionX = motion[motionOffset]
      let motionY = motion[motionOffset + 1]
      let depthValue = depth[pixel]
      let deviceDepthValue = deviceDepth[pixel]
      let allFinite =
        hdrPixel.allSatisfy(\.isFinite)
        && albedoPixel.allSatisfy(\.isFinite)
        && normalPixel.allSatisfy(\.isFinite)
        && motionX.isFinite && motionY.isFinite && depthValue.isFinite
        && deviceDepthValue.isFinite
      if allFinite { finitePixelCount += 1 }
      let hdrMaximum = hdrPixel.prefix(3).max() ?? 0
      maximumHDRComponent = max(maximumHDRComponent, hdrMaximum)
      if hdrMaximum > 1 { aboveOneHDRPixelCount += 1 }

      let id0 = identity[identityOffset]
      let id1 = identity[identityOffset + 1]
      let id2 = identity[identityOffset + 2]
      let id3 = identity[identityOffset + 3]
      let active = id0 != 0 || id1 != 0 || id2 != 0 || id3 != 0
      if active {
        activeIdentityPixelCount += 1
        if id0 != UInt32.max { featherHashes.insert(id1) }
        if id0 == UInt32.max && id2 == 6 {
          supportYTotal += Float(pixel / width)
          supportPixelCount += 1
        } else {
          birdYTotal += Float(pixel / width)
          birdPixelCount += 1
        }
      }
      // normal.w is resolved geometric coverage. Restrict vector-length,
      // motion, and metric-depth assertions to pixels covered by every MSAA
      // sample; boundary pixels intentionally contain filtered values.
      guard normalPixel[normalPixel.index(normalPixel.startIndex, offsetBy: 3)] > 0.999 else {
        continue
      }
      fullyCoveredAOVPixelCount += 1
      let speed = hypot(motionX, motionY)
      maximumMotionPixels = max(maximumMotionPixels, speed)
      if speed > 0.01 { movingActivePixelCount += 1 }
      let nx = normals[hdrOffset]
      let ny = normals[hdrOffset + 1]
      let nz = normals[hdrOffset + 2]
      maximumNormalUnitError = max(
        maximumNormalUnitError,
        abs(sqrt(nx * nx + ny * ny + nz * nz) - 1)
      )
      minimumFullyCoveredDepthMeters = min(minimumFullyCoveredDepthMeters, depthValue)
      maximumFullyCoveredDepthMeters = max(maximumFullyCoveredDepthMeters, depthValue)
      minimumFullyCoveredDeviceDepth = min(
        minimumFullyCoveredDeviceDepth,
        deviceDepthValue
      )
      maximumFullyCoveredDeviceDepth = max(
        maximumFullyCoveredDeviceDepth,
        deviceDepthValue
      )
    }
    if !minimumFullyCoveredDepthMeters.isFinite { minimumFullyCoveredDepthMeters = 0 }
    if !minimumFullyCoveredDeviceDepth.isFinite { minimumFullyCoveredDeviceDepth = 0 }
    let parity = nativeReference.map {
      Self.displayError(
        displayTexture,
        identity: identityTexture,
        reference: $0.displayTexture,
        referenceIdentity: $0.identityTexture
      )
    }
    return CrowShowcaseAOVFrameAudit(
      frameIndex: frameIndex,
      width: width,
      height: height,
      outputWidth: displayTexture.width,
      outputHeight: displayTexture.height,
      reconstructionMode: reconstructionMode,
      historyReset: historyReset,
      jitterOffsetX: jitter.x,
      jitterOffsetY: jitter.y,
      reactiveMaskEnabled: reactiveMaskEnabled,
      renderScaleX: Float(displayTexture.width) / Float(width),
      renderScaleY: Float(displayTexture.height) / Float(height),
      gpuDurationMilliseconds: gpuDurationMilliseconds,
      nativeReferenceGPUDurationMilliseconds: nativeReference?.gpuDurationMilliseconds,
      allocatedRenderTargetBytes: allocatedRenderTargetBytes,
      nativeReferenceAllocatedRenderTargetBytes:
        nativeReference?.allocatedRenderTargetBytes,
      finitePixelCount: finitePixelCount,
      aboveOneHDRPixelCount: aboveOneHDRPixelCount,
      activeIdentityPixelCount: activeIdentityPixelCount,
      fullyCoveredAOVPixelCount: fullyCoveredAOVPixelCount,
      visibleFeatherIdentityCount: featherHashes.count,
      movingFullyCoveredPixelCount: movingActivePixelCount,
      maximumHDRComponent: maximumHDRComponent,
      maximumMotionPixels: maximumMotionPixels,
      maximumNormalUnitError: maximumNormalUnitError,
      minimumFullyCoveredDepthMeters: minimumFullyCoveredDepthMeters,
      maximumFullyCoveredDepthMeters: maximumFullyCoveredDepthMeters,
      minimumFullyCoveredDeviceDepth: minimumFullyCoveredDeviceDepth,
      maximumFullyCoveredDeviceDepth: maximumFullyCoveredDeviceDepth,
      birdCentroidYPixels: birdYTotal / Float(max(birdPixelCount, 1)),
      supportCentroidYPixels: supportYTotal / Float(max(supportPixelCount, 1)),
      nativeFullFrameDisplayRMSE: parity?.fullFrameRMSE,
      nativeForegroundDisplayRMSE: parity?.foregroundRMSE,
      nativeDisplayMaximumError: parity?.maximum,
      nativeBirdSilhouetteIntersectionOverUnion: parity?.silhouetteIntersectionOverUnion,
      nativeForegroundGradientEnergyRatio: parity?.foregroundGradientEnergyRatio
    )
  }

  private static func displayError(
    _ texture: MTLTexture,
    identity: MTLTexture,
    reference: MTLTexture,
    referenceIdentity: MTLTexture
  ) -> (
    fullFrameRMSE: Float,
    foregroundRMSE: Float,
    maximum: Float,
    silhouetteIntersectionOverUnion: Float,
    foregroundGradientEnergyRatio: Float
  ) {
    precondition(texture.width == reference.width && texture.height == reference.height)
    let values = byteValues(texture: texture)
    let referenceValues = byteValues(texture: reference)
    let identities = uintValues(texture: identity, componentCount: 4)
    let referenceIdentities = uintValues(texture: referenceIdentity, componentCount: 4)
    var squaredError: Float = 0
    var foregroundSquaredError: Float = 0
    var maximumError: Float = 0
    var componentCount = 0
    var foregroundComponentCount = 0
    var silhouetteIntersection = 0
    var silhouetteUnion = 0
    var currentBirdMask = [Bool](
      repeating: false,
      count: texture.width * texture.height
    )
    var referenceBirdMask = currentBirdMask
    for pixel in 0..<(texture.width * texture.height) {
      let offset = pixel * 4
      let x = pixel % texture.width
      let y = pixel / texture.width
      let sourceX = min(identity.width - 1, x * identity.width / texture.width)
      let sourceY = min(identity.height - 1, y * identity.height / texture.height)
      let identityOffset = (sourceY * identity.width + sourceX) * 4
      let currentBird = birdIdentity(identities, offset: identityOffset)
      let referenceBird = birdIdentity(referenceIdentities, offset: offset)
      currentBirdMask[pixel] = currentBird
      referenceBirdMask[pixel] = referenceBird
      if currentBird || referenceBird { silhouetteUnion += 1 }
      if currentBird && referenceBird { silhouetteIntersection += 1 }
      for component in 0..<3 {
        let error =
          abs(
            Float(values[offset + component])
              - Float(referenceValues[offset + component])
          ) / 255
        squaredError += error * error
        if currentBird || referenceBird {
          foregroundSquaredError += error * error
          foregroundComponentCount += 1
        }
        maximumError = max(maximumError, error)
        componentCount += 1
      }
    }
    var currentGradientEnergy: Float = 0
    var referenceGradientEnergy: Float = 0
    for y in 1..<texture.height {
      for x in 1..<texture.width {
        let pixel = y * texture.width + x
        let left = pixel - 1
        let above = pixel - texture.width
        guard currentBirdMask[pixel] || referenceBirdMask[pixel] else { continue }
        let currentLuminance = luminance(values, pixel: pixel)
        let referenceLuminance = luminance(referenceValues, pixel: pixel)
        currentGradientEnergy +=
          abs(currentLuminance - luminance(values, pixel: left))
          + abs(currentLuminance - luminance(values, pixel: above))
        referenceGradientEnergy +=
          abs(
            referenceLuminance - luminance(referenceValues, pixel: left)
          ) + abs(referenceLuminance - luminance(referenceValues, pixel: above))
      }
    }
    return (
      sqrt(squaredError / Float(max(componentCount, 1))),
      sqrt(foregroundSquaredError / Float(max(foregroundComponentCount, 1))),
      maximumError,
      Float(silhouetteIntersection) / Float(max(silhouetteUnion, 1)),
      currentGradientEnergy / max(referenceGradientEnergy, 1e-8)
    )
  }

  private static func luminance(_ values: [UInt8], pixel: Int) -> Float {
    let offset = pixel * 4
    let blue = Float(values[offset]) / 255
    let green = Float(values[offset + 1]) / 255
    let red = Float(values[offset + 2]) / 255
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue
  }

  private static func birdIdentity(_ values: [UInt32], offset: Int) -> Bool {
    let id0 = values[offset]
    let id1 = values[offset + 1]
    let id2 = values[offset + 2]
    let id3 = values[offset + 3]
    let active = id0 != 0 || id1 != 0 || id2 != 0 || id3 != 0
    let support = id0 == UInt32.max && id2 == 6
    return active && !support
  }

  private static func halfValues(
    texture: MTLTexture,
    componentCount: Int
  ) -> [Float] {
    var bits = [UInt16](
      repeating: 0,
      count: texture.width * texture.height * componentCount
    )
    texture.getBytes(
      &bits,
      bytesPerRow: texture.width * componentCount * MemoryLayout<UInt16>.stride,
      from: MTLRegionMake2D(0, 0, texture.width, texture.height),
      mipmapLevel: 0
    )
    return bits.map { Float(Float16(bitPattern: $0)) }
  }

  private static func floatValues(texture: MTLTexture) -> [Float] {
    var values = [Float](repeating: 0, count: texture.width * texture.height)
    texture.getBytes(
      &values,
      bytesPerRow: texture.width * MemoryLayout<Float>.stride,
      from: MTLRegionMake2D(0, 0, texture.width, texture.height),
      mipmapLevel: 0
    )
    return values
  }

  private static func floatValues(buffer: MTLBuffer, count: Int) -> [Float] {
    let pointer = buffer.contents().bindMemory(to: Float.self, capacity: count)
    return Array(UnsafeBufferPointer(start: pointer, count: count))
  }

  private static func uintValues(
    texture: MTLTexture,
    componentCount: Int
  ) -> [UInt32] {
    var values = [UInt32](
      repeating: 0,
      count: texture.width * texture.height * componentCount
    )
    texture.getBytes(
      &values,
      bytesPerRow: texture.width * componentCount * MemoryLayout<UInt32>.stride,
      from: MTLRegionMake2D(0, 0, texture.width, texture.height),
      mipmapLevel: 0
    )
    return values
  }

  private static func byteValues(texture: MTLTexture) -> [UInt8] {
    var values = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
    texture.getBytes(
      &values,
      bytesPerRow: texture.width * 4,
      from: MTLRegionMake2D(0, 0, texture.width, texture.height),
      mipmapLevel: 0
    )
    return values
  }
}

struct CrowShowcaseAOVFrameAudit: Codable, Equatable {
  let frameIndex: Int
  let width: Int
  let height: Int
  let outputWidth: Int
  let outputHeight: Int
  let reconstructionMode: String
  let historyReset: Bool
  let jitterOffsetX: Float
  let jitterOffsetY: Float
  let reactiveMaskEnabled: Bool
  let renderScaleX: Float
  let renderScaleY: Float
  let gpuDurationMilliseconds: Double
  let nativeReferenceGPUDurationMilliseconds: Double?
  let allocatedRenderTargetBytes: Int
  let nativeReferenceAllocatedRenderTargetBytes: Int?
  let finitePixelCount: Int
  let aboveOneHDRPixelCount: Int
  let activeIdentityPixelCount: Int
  let fullyCoveredAOVPixelCount: Int
  let visibleFeatherIdentityCount: Int
  let movingFullyCoveredPixelCount: Int
  let maximumHDRComponent: Float
  let maximumMotionPixels: Float
  let maximumNormalUnitError: Float
  let minimumFullyCoveredDepthMeters: Float
  let maximumFullyCoveredDepthMeters: Float
  let minimumFullyCoveredDeviceDepth: Float
  let maximumFullyCoveredDeviceDepth: Float
  let birdCentroidYPixels: Float
  let supportCentroidYPixels: Float
  let nativeFullFrameDisplayRMSE: Float?
  let nativeForegroundDisplayRMSE: Float?
  let nativeDisplayMaximumError: Float?
  let nativeBirdSilhouetteIntersectionOverUnion: Float?
  let nativeForegroundGradientEnergyRatio: Float?
}

struct CrowShowcaseAOVAuditReport: Codable, Equatable {
  let schemaVersion: Int
  let colorSpace: String
  let motionConvention: String
  let depthConvention: String
  let formats: [String: String]
  let frames: [CrowShowcaseAOVFrameAudit]

  init(frames: [CrowShowcaseAOVFrameAudit]) {
    schemaVersion = 2
    colorSpace = "scene-linear extended range; display output is tone mapped separately"
    motionConvention =
      "current pixel to previous pixel in upper-left-origin pixel units; MetalFX scale 1"
    depthConvention =
      "metric depth is Euclidean meters with background zero; device depth is 0 near, 1 far"
    formats = [
      "hdrColor": "rgba16Float",
      "albedoMaterial": "rgba16Float",
      "normalCoverage": "rgba16Float",
      "motion": "rg16Float",
      "metricDepth": "r32Float",
      "deviceDepth": "depth32Float",
      "identity": "rgba32Uint",
      "display": "bgra8Unorm_srgb",
    ]
    self.frames = frames
  }
}
