import Foundation
import Metal

struct CrowShowcaseFrame {
  let displayTexture: MTLTexture
  let hdrColorTexture: MTLTexture
  let albedoMaterialTexture: MTLTexture
  let normalCoverageTexture: MTLTexture
  let motionTexture: MTLTexture
  let metricDepthTexture: MTLTexture
  let identityTexture: MTLTexture

  func audit(frameIndex: Int) -> CrowShowcaseAOVFrameAudit {
    let width = hdrColorTexture.width
    let height = hdrColorTexture.height
    let pixelCount = width * height
    let hdr = Self.halfValues(texture: hdrColorTexture, componentCount: 4)
    let albedo = Self.halfValues(texture: albedoMaterialTexture, componentCount: 4)
    let normals = Self.halfValues(texture: normalCoverageTexture, componentCount: 4)
    let motion = Self.halfValues(texture: motionTexture, componentCount: 2)
    let depth = Self.floatValues(texture: metricDepthTexture)
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
      let allFinite =
        hdrPixel.allSatisfy(\.isFinite)
        && albedoPixel.allSatisfy(\.isFinite)
        && normalPixel.allSatisfy(\.isFinite)
        && motionX.isFinite && motionY.isFinite && depthValue.isFinite
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
    }
    if !minimumFullyCoveredDepthMeters.isFinite { minimumFullyCoveredDepthMeters = 0 }
    return CrowShowcaseAOVFrameAudit(
      frameIndex: frameIndex,
      width: width,
      height: height,
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
      birdCentroidYPixels: birdYTotal / Float(max(birdPixelCount, 1)),
      supportCentroidYPixels: supportYTotal / Float(max(supportPixelCount, 1))
    )
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
}

struct CrowShowcaseAOVFrameAudit: Codable, Equatable {
  let frameIndex: Int
  let width: Int
  let height: Int
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
  let birdCentroidYPixels: Float
  let supportCentroidYPixels: Float
}

struct CrowShowcaseAOVAuditReport: Codable, Equatable {
  let schemaVersion: Int
  let colorSpace: String
  let motionConvention: String
  let depthConvention: String
  let formats: [String: String]
  let frames: [CrowShowcaseAOVFrameAudit]

  init(frames: [CrowShowcaseAOVFrameAudit]) {
    schemaVersion = 1
    colorSpace = "scene-linear extended range; display output is tone mapped separately"
    motionConvention =
      "current pixel to previous pixel in upper-left-origin pixel units; MetalFX scale 1"
    depthConvention = "Euclidean camera-to-surface distance in meters; background is zero"
    formats = [
      "hdrColor": "rgba16Float",
      "albedoMaterial": "rgba16Float",
      "normalCoverage": "rgba16Float",
      "motion": "rg16Float",
      "metricDepth": "r32Float",
      "identity": "rgba32Uint",
      "display": "bgra8Unorm_srgb",
    ]
    self.frames = frames
  }
}
