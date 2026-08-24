import Foundation
import Metal

struct CrowCranialVisibilityMetrics {
  var retainedCapacityBytes = 0
  var occlusionDepthBytes = 0
  var occlusionMode = "inactive"
  var candidateRecordCount = 0
  var frustumVisibleRecordCount = 0
  var visibleRecordCount = 0
  var occlusionTestedRecordCount = 0
  var occlusionCulledRecordCount = 0
  var rasterVertexInvocationCount = 0
  var gularCandidateRecordCount = 0
  var gularFrustumVisibleRecordCount = 0
  var gularVisibleRecordCount = 0
  var gularOcclusionTestedRecordCount = 0
  var gularOcclusionCulledRecordCount = 0
  var gularRasterVertexInvocationCount = 0
}

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
  let plumageRayVisibilityCapability: CrowPlumageRayVisibilityCapability
  let plumageRayGeometryAuditRequested: Bool
  let plumageRayGeometryBuildSucceeded: Bool
  let plumageRayGeometryTriangleCount: Int
  let plumageRayGeometryAccelerationStructureBytes: Int
  let plumageRayGeometryBuildScratchBytes: Int
  let plumageRayGeometryProbeAttempted: Bool
  let plumageRayGeometryProbeHit: Bool
  let plumageRayGeometryProbePrimitiveIndex: Int
  let plumageRayGeometryProbeDistanceMeters: Float
  let plumageRayGeometryProbeRayCount: Int
  let plumageRayGeometryProbeHitCount: Int
  let plumageRasterRaySampleCount: Int
  let plumageRasterRayHitCount: Int
  let plumageRasterRayIdentityParityCount: Int
  let plumageRasterRayRachisOwnerParityCount: Int
  let plumageRasterRayDepthParityCount: Int
  let plumageFullImageRayAuditRequested: Bool
  let plumageFullImageRaySampleCount: Int
  let plumageFullImageRayHitCount: Int
  let plumageFullImageRayRachisOwnerParityCount: Int
  let plumageFullImageRayDepthParityCount: Int
  let historyReset: Bool
  let jitter: SIMD2<Float>
  let reactiveMaskEnabled: Bool
  let gpuDurationMilliseconds: Double
  let allocatedRenderTargetBytes: Int
  let bodyVaneMorphologyRecordCount: Int
  let bodyVaneMorphologyRecordBytes: Int
  let bodyVaneSelectedMorphologyRecordCount: Int
  let bodyVaneBatchCount: Int
  let bodyVaneSelectedMorphologyRecordBytes: Int
  let bodyVaneRetainedMorphologyCapacityBytes: Int
  let bodyVanePoseInputBytes: Int
  let bodyVaneRetainedPoseCapacityBytes: Int
  let bodyVaneRetainedIndirectDrawBytes: Int
  let bodyVaneMorphologyBufferAllocationCount: Int
  let bodyVaneRasterVertexInvocationCount: Int
  let bodyVaneVertexGenerationMode: String
  let cranialVisibilityMetrics: CrowCranialVisibilityMetrics
  let ventralVaneMorphologyRecordCount: Int
  let ventralVaneMorphologyRecordBytes: Int
  let ventralVaneSelectedMorphologyRecordCount: Int
  let ventralVaneRasterVertexInvocationCount: Int
  let ventralVaneEliminatedCPUSurfaceVertexBytes: Int
  let ventralVaneVertexGenerationMode: String
  let ventralBarbCandidateRecordCount: Int
  let ventralBarbCloseCandidateRecordCount: Int
  let ventralBarbuleCandidateRecordCount: Int
  let ventralBarbFrustumVisibleRecordCount: Int
  let ventralBarbVisibleRecordCount: Int
  let ventralBarbuleFrustumVisibleRecordCount: Int
  let ventralBarbuleVisibleRecordCount: Int
  let ventralBarbOcclusionTestedRecordCount: Int
  let ventralBarbOcclusionCulledRecordCount: Int
  let ventralBarbOcclusionDepthBytes: Int
  let ventralBarbOcclusionMode: String
  let ventralBarbExpandedVertexCount: Int
  let ventralBarbRasterVertexInvocationCount: Int
  let ventralBarbuleExpandedVertexCount: Int
  let ventralBarbOutputCapacityBytes: Int
  let ventralBarbVertexGenerationMode: String

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
    var ventralBarbuleVisiblePixelCount = 0
    var fullyCoveredAOVPixelCount = 0
    var fullyCoveredActiveIdentityPixelCount = 0
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
    var persistentFeatherVisiblePixels: [SIMD4<UInt32>: Int] = [:]
    var persistentFeatherFullyCoveredPixels: [SIMD4<UInt32>: Int] = [:]
    var persistentFeatherMinimumX: [SIMD4<UInt32>: Int] = [:]
    var persistentFeatherMaximumX: [SIMD4<UInt32>: Int] = [:]
    var persistentFeatherMinimumY: [SIMD4<UInt32>: Int] = [:]
    var persistentFeatherMaximumY: [SIMD4<UInt32>: Int] = [:]
    var persistentFeatherXTotal: [SIMD4<UInt32>: Int] = [:]
    var persistentFeatherYTotal: [SIMD4<UInt32>: Int] = [:]
    var persistentFeatherPrimitiveVisiblePixels: [SIMD4<UInt32>: Int] = [:]
    var persistentFeatherPrimitiveFullyCoveredPixels: [SIMD4<UInt32>: Int] = [:]
    var bodyVaneVisiblePixels: [SIMD4<UInt32>: Int] = [:]
    var bodyVaneFullyCoveredPixels: [SIMD4<UInt32>: Int] = [:]
    var bodyVaneMinimumX: [SIMD4<UInt32>: Int] = [:]
    var bodyVaneMaximumX: [SIMD4<UInt32>: Int] = [:]
    var bodyVaneMinimumY: [SIMD4<UInt32>: Int] = [:]
    var bodyVaneMaximumY: [SIMD4<UInt32>: Int] = [:]
    var bodyVaneXTotal: [SIMD4<UInt32>: Int] = [:]
    var bodyVaneYTotal: [SIMD4<UInt32>: Int] = [:]
    var wingSurfaceCellVisiblePixels: [UInt32: Int] = [:]
    var wingSurfaceCellFullyCoveredPixels: [UInt32: Int] = [:]
    var wingSurfaceCellMinimumX: [UInt32: Int] = [:]
    var wingSurfaceCellMaximumX: [UInt32: Int] = [:]
    var wingSurfaceCellMinimumY: [UInt32: Int] = [:]
    var wingSurfaceCellMaximumY: [UInt32: Int] = [:]
    var wingSurfaceCellXTotal: [UInt32: Int] = [:]
    var wingSurfaceCellYTotal: [UInt32: Int] = [:]
    var wingCovertVisiblePixels: [UInt32: Int] = [:]
    var wingCovertFullyCoveredPixels: [UInt32: Int] = [:]
    var wingCovertMinimumX: [UInt32: Int] = [:]
    var wingCovertMaximumX: [UInt32: Int] = [:]
    var wingCovertMinimumY: [UInt32: Int] = [:]
    var wingCovertMaximumY: [UInt32: Int] = [:]
    var wingCovertXTotal: [UInt32: Int] = [:]
    var wingCovertYTotal: [UInt32: Int] = [:]
    var visibleFeatherClassPixelCounts = [Int](repeating: 0, count: 32)
    var fullyCoveredFeatherClassPixelCounts = [Int](repeating: 0, count: 32)
    var birdMask = [Bool](repeating: false, count: pixelCount)
    var featherClassCodes = [UInt8](repeating: 0, count: pixelCount)
    var linearLuminances = [Float](repeating: 0, count: pixelCount)
    var surfacePrimitiveIdentifiers = [UInt32](repeating: 0, count: pixelCount)
    var packedSurfaceIdentities = [UInt32](repeating: 0, count: pixelCount)

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
      linearLuminances[pixel] =
        0.2126 * hdr[hdrOffset]
        + 0.7152 * hdr[hdrOffset + 1]
        + 0.0722 * hdr[hdrOffset + 2]
      maximumHDRComponent = max(maximumHDRComponent, hdrMaximum)
      if hdrMaximum > 1 { aboveOneHDRPixelCount += 1 }

      let id0 = identity[identityOffset]
      let id1 = identity[identityOffset + 1]
      let id2 = identity[identityOffset + 2]
      let id3 = identity[identityOffset + 3]
      let active = id0 != 0 || id1 != 0 || id2 != 0 || id3 != 0
      birdMask[pixel] = Self.birdIdentity(identity, offset: identityOffset)
      featherClassCodes[pixel] = UInt8(truncatingIfNeeded: id3 & 255)
      surfacePrimitiveIdentifiers[pixel] = id0 == UInt32.max ? id1 : 0
      packedSurfaceIdentities[pixel] = id3
      if active {
        activeIdentityPixelCount += 1
        if id0 == UInt32.max && id2 == 4 {
          ventralBarbuleVisiblePixelCount += 1
        }
        let featherClass = Int(min(id3 & 255, 31))
        visibleFeatherClassPixelCounts[featherClass] += 1
        if id0 != UInt32.max { featherHashes.insert(id1) }
        if id0 != UInt32.max && (1...3).contains(id3 & 255) {
          let physicsSurfacePartIdentifier = id2 & 0x00ff_ffff
          let detailKind = id2 >> 24
          let featherIdentity = SIMD4(id0, id1, physicsSurfacePartIdentifier, id3)
          let primitiveIdentity = SIMD4(id0, id1, detailKind, id3)
          persistentFeatherVisiblePixels[featherIdentity, default: 0] += 1
          persistentFeatherPrimitiveVisiblePixels[primitiveIdentity, default: 0] += 1
          let x = pixel % width
          let y = pixel / width
          persistentFeatherMinimumX[featherIdentity] = min(
            persistentFeatherMinimumX[featherIdentity] ?? x,
            x
          )
          persistentFeatherMaximumX[featherIdentity] = max(
            persistentFeatherMaximumX[featherIdentity] ?? x,
            x
          )
          persistentFeatherMinimumY[featherIdentity] = min(
            persistentFeatherMinimumY[featherIdentity] ?? y,
            y
          )
          persistentFeatherMaximumY[featherIdentity] = max(
            persistentFeatherMaximumY[featherIdentity] ?? y,
            y
          )
          persistentFeatherXTotal[featherIdentity, default: 0] += x
          persistentFeatherYTotal[featherIdentity, default: 0] += y
        }
        if id0 & 0xff00_0000 == 0x0200_0000
          || id0 & 0xff00_0000 == 0x0300_0000
          || id0 & 0xff00_0000 == 0x0400_0000
          || id0 & 0xff00_0000 == 0x0500_0000
          || id0 & 0xff00_0000 == 0x0600_0000
          || id0 & 0xff00_0000 == 0x0700_0000
        {
          let bodyVaneIdentity = SIMD4(id0, id1, id2, id3)
          bodyVaneVisiblePixels[bodyVaneIdentity, default: 0] += 1
          let x = pixel % width
          let y = pixel / width
          bodyVaneMinimumX[bodyVaneIdentity] = min(
            bodyVaneMinimumX[bodyVaneIdentity] ?? x,
            x
          )
          bodyVaneMaximumX[bodyVaneIdentity] = max(
            bodyVaneMaximumX[bodyVaneIdentity] ?? x,
            x
          )
          bodyVaneMinimumY[bodyVaneIdentity] = min(
            bodyVaneMinimumY[bodyVaneIdentity] ?? y,
            y
          )
          bodyVaneMaximumY[bodyVaneIdentity] = max(
            bodyVaneMaximumY[bodyVaneIdentity] ?? y,
            y
          )
          bodyVaneXTotal[bodyVaneIdentity, default: 0] += x
          bodyVaneYTotal[bodyVaneIdentity, default: 0] += y
        }
        if id0 == UInt32.max
          && CrowWingSurfaceCellIdentity.isPacked(
            id3,
            surfaceMaterialCode: id2
          )
        {
          wingSurfaceCellVisiblePixels[id3, default: 0] += 1
          let x = pixel % width
          let y = pixel / width
          wingSurfaceCellMinimumX[id3] = min(wingSurfaceCellMinimumX[id3] ?? x, x)
          wingSurfaceCellMaximumX[id3] = max(wingSurfaceCellMaximumX[id3] ?? x, x)
          wingSurfaceCellMinimumY[id3] = min(wingSurfaceCellMinimumY[id3] ?? y, y)
          wingSurfaceCellMaximumY[id3] = max(wingSurfaceCellMaximumY[id3] ?? y, y)
          wingSurfaceCellXTotal[id3, default: 0] += x
          wingSurfaceCellYTotal[id3, default: 0] += y
        }
        if id0 == UInt32.max && CrowWingCovertIdentity.isPacked(id3) {
          wingCovertVisiblePixels[id3, default: 0] += 1
          let x = pixel % width
          let y = pixel / width
          wingCovertMinimumX[id3] = min(wingCovertMinimumX[id3] ?? x, x)
          wingCovertMaximumX[id3] = max(wingCovertMaximumX[id3] ?? x, x)
          wingCovertMinimumY[id3] = min(wingCovertMinimumY[id3] ?? y, y)
          wingCovertMaximumY[id3] = max(wingCovertMaximumY[id3] ?? y, y)
          wingCovertXTotal[id3, default: 0] += x
          wingCovertYTotal[id3, default: 0] += y
        }
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
      if active {
        fullyCoveredActiveIdentityPixelCount += 1
        let featherClass = Int(min(id3 & 255, 31))
        fullyCoveredFeatherClassPixelCounts[featherClass] += 1
        if id0 != UInt32.max && (1...3).contains(id3 & 255) {
          let featherIdentity = SIMD4(id0, id1, id2 & 0x00ff_ffff, id3)
          let primitiveIdentity = SIMD4(id0, id1, id2 >> 24, id3)
          persistentFeatherFullyCoveredPixels[featherIdentity, default: 0] += 1
          persistentFeatherPrimitiveFullyCoveredPixels[primitiveIdentity, default: 0] += 1
        }
        if id0 & 0xff00_0000 == 0x0200_0000
          || id0 & 0xff00_0000 == 0x0300_0000
          || id0 & 0xff00_0000 == 0x0400_0000
          || id0 & 0xff00_0000 == 0x0500_0000
          || id0 & 0xff00_0000 == 0x0600_0000
          || id0 & 0xff00_0000 == 0x0700_0000
        {
          bodyVaneFullyCoveredPixels[SIMD4(id0, id1, id2, id3), default: 0] += 1
        }
        if id0 == UInt32.max
          && CrowWingSurfaceCellIdentity.isPacked(
            id3,
            surfaceMaterialCode: id2
          )
        {
          wingSurfaceCellFullyCoveredPixels[id3, default: 0] += 1
        }
        if id0 == UInt32.max && CrowWingCovertIdentity.isPacked(id3) {
          wingCovertFullyCoveredPixels[id3, default: 0] += 1
        }
      }
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
    let silhouetteHoles = Self.silhouetteHoles(
      birdMask: birdMask,
      featherClassCodes: featherClassCodes,
      surfacePrimitiveIdentifiers: surfacePrimitiveIdentifiers,
      packedSurfaceIdentities: packedSurfaceIdentities,
      width: width,
      height: height
    )
    let exteriorSilhouetteSlotRuns = Self.exteriorSilhouetteSlotRuns(
      birdMask: birdMask,
      featherClassCodes: featherClassCodes,
      surfacePrimitiveIdentifiers: surfacePrimitiveIdentifiers,
      packedSurfaceIdentities: packedSurfaceIdentities,
      width: width,
      height: height
    )
    let featherClassLuminanceAudits = Self.featherClassLuminanceAudits(
      birdMask: birdMask,
      featherClassCodes: featherClassCodes,
      linearLuminances: linearLuminances,
      width: width,
      height: height
    )
    let featherClassBoundaryAudits = Self.featherClassBoundaryAudits(
      birdMask: birdMask,
      featherClassCodes: featherClassCodes,
      linearLuminances: linearLuminances,
      width: width,
      height: height
    )
    let parity = nativeReference.map {
      Self.displayError(
        displayTexture,
        identity: identityTexture,
        reference: $0.displayTexture,
        referenceIdentity: $0.identityTexture
      )
    }
    let persistentFeatherIdentities = persistentFeatherVisiblePixels.map {
      identity, visiblePixelCount in
      CrowPersistentFeatherIdentityAudit(
        featherIndex: identity.x,
        stableIdentifierHash: identity.y,
        physicsSurfacePartIdentifier: identity.z,
        packedIdentity: identity.w,
        visiblePixelCount: visiblePixelCount,
        fullyCoveredPixelCount: persistentFeatherFullyCoveredPixels[identity, default: 0],
        minimumX: persistentFeatherMinimumX[identity, default: 0],
        maximumX: persistentFeatherMaximumX[identity, default: 0],
        minimumY: persistentFeatherMinimumY[identity, default: 0],
        maximumY: persistentFeatherMaximumY[identity, default: 0],
        centroidX: Float(persistentFeatherXTotal[identity, default: 0])
          / Float(visiblePixelCount),
        centroidY: Float(persistentFeatherYTotal[identity, default: 0])
          / Float(visiblePixelCount)
      )
    }.sorted {
      ($0.featherClass, $0.sideCode, $0.order, $0.stableIdentifierHash)
        < ($1.featherClass, $1.sideCode, $1.order, $1.stableIdentifierHash)
    }
    let persistentFeatherPrimitives = persistentFeatherPrimitiveVisiblePixels.map {
      identity, visiblePixelCount in
      CrowPersistentFeatherPrimitiveAudit(
        featherIndex: identity.x,
        stableIdentifierHash: identity.y,
        packedIdentity: identity.w,
        detailKind: identity.z,
        visiblePixelCount: visiblePixelCount,
        fullyCoveredPixelCount:
          persistentFeatherPrimitiveFullyCoveredPixels[identity, default: 0]
      )
    }.sorted {
      ($0.featherClass, $0.sideCode, $0.order, $0.detailKind, $0.stableIdentifierHash)
        < ($1.featherClass, $1.sideCode, $1.order, $1.detailKind, $1.stableIdentifierHash)
    }
    let bodyVaneSamples = CrowBodyFeatherTracts.samples(
      appliesCervicalTerminalFlow: false
    )
    let ventralVaneSamples = CrowVentralFeatherTracts.samples()
    let femoralVaneSamples = [-Float(1), Float(1)].flatMap {
      CrowFemoralPlumage.morphologySamples(side: $0)
    }
    let cruralVaneSamples = [-Float(1), Float(1)].flatMap {
      CrowLegPlumage.morphologySamples(side: $0)
    }
    let throatBridgeVaneSamples = CrowThroatBridgeFeathers.morphologySamples()
    let cranialVaneSamples = CrowCranialFeatherTracts.morphologySamples()
    let bodyVaneIdentities = bodyVaneVisiblePixels.compactMap {
      identity, visiblePixelCount -> CrowBodyVaneIdentityAudit? in
      let inventoryIndex = Int(identity.x & 0x00ff_ffff)
      let familyCode = UInt8((identity.x >> 24) & 0xff)
      let regionCode: UInt8
      let sideCode: UInt8
      let row: Int
      let column: Int
      if familyCode == 2 && bodyVaneSamples.indices.contains(inventoryIndex) {
        let sample = bodyVaneSamples[inventoryIndex]
        regionCode = sample.region.rawValue
        sideCode = sample.side < 0 ? 0 : 1
        row = sample.row
        column = sample.column
      } else if familyCode == 3
        && ventralVaneSamples.indices.contains(inventoryIndex)
      {
        let sample = ventralVaneSamples[inventoryIndex]
        regionCode = sample.region.rawValue
        sideCode = sample.side < 0 ? 0 : 1
        row = sample.row
        column = sample.column
      } else if familyCode == 4
        && femoralVaneSamples.indices.contains(inventoryIndex)
      {
        let sample = femoralVaneSamples[inventoryIndex]
        regionCode = 4
        sideCode = sample.side < 0 ? 0 : 1
        row = sample.row
        column = sample.course
      } else if familyCode == 5
        && cruralVaneSamples.indices.contains(inventoryIndex)
      {
        let sample = cruralVaneSamples[inventoryIndex]
        regionCode = 5
        sideCode = sample.side < 0 ? 0 : 1
        row = sample.radialIndex
        column = sample.stationIndex
      } else if familyCode == 6
        && throatBridgeVaneSamples.indices.contains(inventoryIndex)
      {
        let sample = throatBridgeVaneSamples[inventoryIndex]
        regionCode = 6
        sideCode = sample.side < 0 ? 0 : 1
        row = sample.row
        column = sample.column
      } else if familyCode == 7
        && cranialVaneSamples.indices.contains(inventoryIndex)
      {
        let sample = cranialVaneSamples[inventoryIndex]
        regionCode = 7 + sample.region.rawValue
        sideCode = cos(sample.thetaRadians) < 0 ? 0 : 1
        row = sample.axialIndex
        column = sample.angularIndex
      } else {
        return nil
      }
      return CrowBodyVaneIdentityAudit(
        familyCode: familyCode,
        inventoryIndex: inventoryIndex,
        stableIdentifierHash: identity.y,
        physicsSurfacePartIdentifier: identity.z,
        featherClassCode: identity.w & 255,
        regionCode: regionCode,
        sideCode: sideCode,
        row: row,
        column: column,
        visiblePixelCount: visiblePixelCount,
        fullyCoveredPixelCount: bodyVaneFullyCoveredPixels[identity, default: 0],
        minimumX: bodyVaneMinimumX[identity, default: 0],
        maximumX: bodyVaneMaximumX[identity, default: 0],
        minimumY: bodyVaneMinimumY[identity, default: 0],
        maximumY: bodyVaneMaximumY[identity, default: 0],
        centroidX: Float(bodyVaneXTotal[identity, default: 0])
          / Float(visiblePixelCount),
        centroidY: Float(bodyVaneYTotal[identity, default: 0])
          / Float(visiblePixelCount)
      )
    }.sorted { ($0.familyCode, $0.inventoryIndex) < ($1.familyCode, $1.inventoryIndex) }
    let wingSurfaceCellIdentities = wingSurfaceCellVisiblePixels.map {
      identity, visiblePixelCount in
      CrowWingSurfaceCellIdentityAudit(
        packedIdentity: identity,
        visiblePixelCount: visiblePixelCount,
        fullyCoveredPixelCount: wingSurfaceCellFullyCoveredPixels[identity, default: 0],
        minimumX: wingSurfaceCellMinimumX[identity, default: 0],
        maximumX: wingSurfaceCellMaximumX[identity, default: 0],
        minimumY: wingSurfaceCellMinimumY[identity, default: 0],
        maximumY: wingSurfaceCellMaximumY[identity, default: 0],
        centroidX: Float(wingSurfaceCellXTotal[identity, default: 0])
          / Float(visiblePixelCount),
        centroidY: Float(wingSurfaceCellYTotal[identity, default: 0])
          / Float(visiblePixelCount)
      )
    }.sorted {
      ($0.partIdentifier, $0.spanIndex, $0.chordIndex, $0.upperTriangle ? 1 : 0)
        < ($1.partIdentifier, $1.spanIndex, $1.chordIndex, $1.upperTriangle ? 1 : 0)
    }
    let wingCovertIdentities = wingCovertVisiblePixels.map {
      identity, visiblePixelCount in
      CrowWingCovertIdentityAudit(
        packedIdentity: identity,
        visiblePixelCount: visiblePixelCount,
        fullyCoveredPixelCount: wingCovertFullyCoveredPixels[identity, default: 0],
        minimumX: wingCovertMinimumX[identity, default: 0],
        maximumX: wingCovertMaximumX[identity, default: 0],
        minimumY: wingCovertMinimumY[identity, default: 0],
        maximumY: wingCovertMaximumY[identity, default: 0],
        centroidX: Float(wingCovertXTotal[identity, default: 0])
          / Float(visiblePixelCount),
        centroidY: Float(wingCovertYTotal[identity, default: 0])
          / Float(visiblePixelCount)
      )
    }.sorted {
      ($0.sideCode, $0.chordIndex, $0.spanIndex)
        < ($1.sideCode, $1.chordIndex, $1.spanIndex)
    }
    return CrowShowcaseAOVFrameAudit(
      frameIndex: frameIndex,
      width: width,
      height: height,
      outputWidth: displayTexture.width,
      outputHeight: displayTexture.height,
      reconstructionMode: reconstructionMode,
      plumageSurfaceVisibilityAuthority:
        plumageRayVisibilityCapability.surfaceVisibilityAuthority,
      plumageExplicitCurveVisibilityAuthority:
        plumageRayVisibilityCapability.explicitCurveVisibilityAuthority,
      plumageComputeRayTracingSupported:
        plumageRayVisibilityCapability.computeRayTracingSupported,
      plumageRenderRayTracingSupported:
        plumageRayVisibilityCapability.renderRayTracingSupported,
      plumageExperimentalRayVisibilityEnabled:
        plumageRayVisibilityCapability.experimentalRayVisibilityEnabled,
      plumageRayVisibilityEnablementGate:
        plumageRayVisibilityCapability.enablementGate,
      plumageRayGeometryAuditRequested: plumageRayGeometryAuditRequested,
      plumageRayGeometryBuildSucceeded: plumageRayGeometryBuildSucceeded,
      plumageRayGeometryTriangleCount: plumageRayGeometryTriangleCount,
      plumageRayGeometryAccelerationStructureBytes:
        plumageRayGeometryAccelerationStructureBytes,
      plumageRayGeometryBuildScratchBytes: plumageRayGeometryBuildScratchBytes,
      plumageRayGeometryProbeAttempted: plumageRayGeometryProbeAttempted,
      plumageRayGeometryProbeHit: plumageRayGeometryProbeHit,
      plumageRayGeometryProbePrimitiveIndex:
        plumageRayGeometryProbePrimitiveIndex,
      plumageRayGeometryProbeDistanceMeters:
        plumageRayGeometryProbeDistanceMeters,
      plumageRayGeometryProbeRayCount: plumageRayGeometryProbeRayCount,
      plumageRayGeometryProbeHitCount: plumageRayGeometryProbeHitCount,
      plumageRasterRaySampleCount: plumageRasterRaySampleCount,
      plumageRasterRayHitCount: plumageRasterRayHitCount,
      plumageRasterRayIdentityParityCount: plumageRasterRayIdentityParityCount,
      plumageRasterRayRachisOwnerParityCount:
        plumageRasterRayRachisOwnerParityCount,
      plumageRasterRayDepthParityCount: plumageRasterRayDepthParityCount,
      plumageFullImageRayAuditRequested: plumageFullImageRayAuditRequested,
      plumageFullImageRaySampleCount: plumageFullImageRaySampleCount,
      plumageFullImageRayHitCount: plumageFullImageRayHitCount,
      plumageFullImageRayRachisOwnerParityCount:
        plumageFullImageRayRachisOwnerParityCount,
      plumageFullImageRayDepthParityCount: plumageFullImageRayDepthParityCount,
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
      bodyVaneMorphologyRecordCount: bodyVaneMorphologyRecordCount,
      bodyVaneMorphologyRecordBytes: bodyVaneMorphologyRecordBytes,
      bodyVaneSelectedMorphologyRecordCount:
        bodyVaneSelectedMorphologyRecordCount,
      bodyVaneBatchCount: bodyVaneBatchCount,
      bodyVaneSelectedMorphologyRecordBytes:
        bodyVaneSelectedMorphologyRecordBytes,
      bodyVaneRetainedMorphologyCapacityBytes:
        bodyVaneRetainedMorphologyCapacityBytes,
      bodyVanePoseInputBytes: bodyVanePoseInputBytes,
      bodyVaneRetainedPoseCapacityBytes: bodyVaneRetainedPoseCapacityBytes,
      bodyVaneRetainedIndirectDrawBytes: bodyVaneRetainedIndirectDrawBytes,
      bodyVaneMorphologyBufferAllocationCount:
        bodyVaneMorphologyBufferAllocationCount,
      bodyVaneRasterVertexInvocationCount: bodyVaneRasterVertexInvocationCount,
      bodyVaneVertexGenerationMode: bodyVaneVertexGenerationMode,
      cranialVisibilityRetainedCapacityBytes:
        cranialVisibilityMetrics.retainedCapacityBytes,
      cranialVisibilityOcclusionDepthBytes:
        cranialVisibilityMetrics.occlusionDepthBytes,
      cranialVisibilityOcclusionMode: cranialVisibilityMetrics.occlusionMode,
      cranialVaneCandidateRecordCount:
        cranialVisibilityMetrics.candidateRecordCount,
      cranialVaneFrustumVisibleRecordCount:
        cranialVisibilityMetrics.frustumVisibleRecordCount,
      cranialVaneVisibleRecordCount:
        cranialVisibilityMetrics.visibleRecordCount,
      cranialVaneOcclusionTestedRecordCount:
        cranialVisibilityMetrics.occlusionTestedRecordCount,
      cranialVaneOcclusionCulledRecordCount:
        cranialVisibilityMetrics.occlusionCulledRecordCount,
      cranialVaneRasterVertexInvocationCount:
        cranialVisibilityMetrics.rasterVertexInvocationCount,
      gularDetailCandidateRecordCount:
        cranialVisibilityMetrics.gularCandidateRecordCount,
      gularDetailFrustumVisibleRecordCount:
        cranialVisibilityMetrics.gularFrustumVisibleRecordCount,
      gularDetailVisibleRecordCount:
        cranialVisibilityMetrics.gularVisibleRecordCount,
      gularDetailOcclusionTestedRecordCount:
        cranialVisibilityMetrics.gularOcclusionTestedRecordCount,
      gularDetailOcclusionCulledRecordCount:
        cranialVisibilityMetrics.gularOcclusionCulledRecordCount,
      gularDetailRasterVertexInvocationCount:
        cranialVisibilityMetrics.gularRasterVertexInvocationCount,
      ventralVaneMorphologyRecordCount: ventralVaneMorphologyRecordCount,
      ventralVaneMorphologyRecordBytes: ventralVaneMorphologyRecordBytes,
      ventralVaneSelectedMorphologyRecordCount:
        ventralVaneSelectedMorphologyRecordCount,
      ventralVaneRasterVertexInvocationCount:
        ventralVaneRasterVertexInvocationCount,
      ventralVaneEliminatedCPUSurfaceVertexBytes:
        ventralVaneEliminatedCPUSurfaceVertexBytes,
      ventralVaneVertexGenerationMode: ventralVaneVertexGenerationMode,
      ventralBarbCandidateRecordCount: ventralBarbCandidateRecordCount,
      ventralBarbCloseCandidateRecordCount:
        ventralBarbCloseCandidateRecordCount,
      ventralBarbuleCandidateRecordCount: ventralBarbuleCandidateRecordCount,
      ventralBarbFrustumVisibleRecordCount: ventralBarbFrustumVisibleRecordCount,
      ventralBarbVisibleRecordCount: ventralBarbVisibleRecordCount,
      ventralBarbuleFrustumVisibleRecordCount:
        ventralBarbuleFrustumVisibleRecordCount,
      ventralBarbuleVisibleRecordCount: ventralBarbuleVisibleRecordCount,
      ventralBarbOcclusionTestedRecordCount: ventralBarbOcclusionTestedRecordCount,
      ventralBarbOcclusionCulledRecordCount: ventralBarbOcclusionCulledRecordCount,
      ventralBarbOcclusionDepthBytes: ventralBarbOcclusionDepthBytes,
      ventralBarbOcclusionMode: ventralBarbOcclusionMode,
      ventralBarbExpandedVertexCount: ventralBarbExpandedVertexCount,
      ventralBarbRasterVertexInvocationCount:
        ventralBarbRasterVertexInvocationCount,
      ventralBarbuleExpandedVertexCount: ventralBarbuleExpandedVertexCount,
      ventralBarbuleVisiblePixelCount: ventralBarbuleVisiblePixelCount,
      ventralBarbOutputCapacityBytes: ventralBarbOutputCapacityBytes,
      ventralBarbVertexGenerationMode: ventralBarbVertexGenerationMode,
      finitePixelCount: finitePixelCount,
      aboveOneHDRPixelCount: aboveOneHDRPixelCount,
      activeIdentityPixelCount: activeIdentityPixelCount,
      fullyCoveredAOVPixelCount: fullyCoveredAOVPixelCount,
      fullyCoveredActiveIdentityPixelCount: fullyCoveredActiveIdentityPixelCount,
      visibleFeatherIdentityCount: featherHashes.count,
      persistentFeatherIdentities: persistentFeatherIdentities,
      persistentFeatherPrimitives: persistentFeatherPrimitives,
      bodyVaneIdentities: bodyVaneIdentities,
      wingSurfaceCellIdentities: wingSurfaceCellIdentities,
      wingCovertIdentities: wingCovertIdentities,
      visibleFeatherClassPixelCounts: visibleFeatherClassPixelCounts,
      fullyCoveredFeatherClassPixelCounts: fullyCoveredFeatherClassPixelCounts,
      featherClassLuminanceAudits: featherClassLuminanceAudits,
      featherClassBoundaryAudits: featherClassBoundaryAudits,
      enclosedBirdSilhouetteHolePixelCount: silhouetteHoles.pixelCount,
      enclosedBirdSilhouetteHoleComponentCount: silhouetteHoles.componentCount,
      largestEnclosedBirdSilhouetteHolePixelCount:
        silhouetteHoles.largestComponentPixelCount,
      largestEnclosedBirdSilhouetteHoleMinimumX: silhouetteHoles.minimumX,
      largestEnclosedBirdSilhouetteHoleMaximumX: silhouetteHoles.maximumX,
      largestEnclosedBirdSilhouetteHoleMinimumY: silhouetteHoles.minimumY,
      largestEnclosedBirdSilhouetteHoleMaximumY: silhouetteHoles.maximumY,
      largestEnclosedBirdSilhouetteHoleCentroidX: silhouetteHoles.centroidX,
      largestEnclosedBirdSilhouetteHoleCentroidY: silhouetteHoles.centroidY,
      largestEnclosedBirdSilhouetteHoleAdjacentFeatherClassMask:
        silhouetteHoles.adjacentFeatherClassMask,
      largestEnclosedBirdSilhouetteHoleAdjacentSurfacePrimitives:
        silhouetteHoles.adjacentSurfacePrimitives,
      largestEnclosedBirdSilhouetteHoleAdjacentPackedIdentities:
        silhouetteHoles.adjacentPackedIdentities,
      expectedLowerBodyAperturePixelCount:
        silhouetteHoles.expectedLowerBodyAperturePixelCount,
      expectedLowerBodyApertureComponentCount:
        silhouetteHoles.expectedLowerBodyApertureComponentCount,
      largestExpectedLowerBodyAperturePixelCount:
        silhouetteHoles.largestExpectedLowerBodyAperturePixelCount,
      exteriorBirdSilhouetteSlotRuns: exteriorSilhouetteSlotRuns,
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

  /// Summarizes scene-linear brightness by semantic feather class. The
  /// right/down neighbor census counts every same-class edge once and exposes
  /// repeated high-frequency vane highlights without depending on a target
  /// photograph or display tone mapping.
  static func featherClassLuminanceAudits(
    birdMask: [Bool],
    featherClassCodes: [UInt8],
    linearLuminances: [Float],
    width: Int,
    height: Int
  ) -> [CrowFeatherClassLuminanceAudit] {
    let pixelCount = width * height
    precondition(width >= 0 && height >= 0 && birdMask.count == pixelCount)
    precondition(featherClassCodes.count == pixelCount)
    precondition(linearLuminances.count == pixelCount)

    var counts = [Int](repeating: 0, count: 32)
    var sums = [Double](repeating: 0, count: 32)
    var squaredSums = [Double](repeating: 0, count: 32)
    var maxima = [Float](repeating: 0, count: 32)
    var maximumX = [Int](repeating: 0, count: 32)
    var maximumY = [Int](repeating: 0, count: 32)
    var neighborCounts = [Int](repeating: 0, count: 32)
    var neighborDifferenceSums = [Double](repeating: 0, count: 32)

    for pixel in 0..<pixelCount where birdMask[pixel] {
      let featherClass = Int(min(featherClassCodes[pixel], 31))
      let luminance = linearLuminances[pixel]
      counts[featherClass] += 1
      sums[featherClass] += Double(luminance)
      squaredSums[featherClass] += Double(luminance * luminance)
      let x = pixel % width
      let y = pixel / width
      if luminance > maxima[featherClass] {
        maxima[featherClass] = luminance
        maximumX[featherClass] = x
        maximumY[featherClass] = y
      }
      if x + 1 < width {
        let neighbor = pixel + 1
        if birdMask[neighbor] && featherClassCodes[neighbor] == featherClassCodes[pixel] {
          neighborCounts[featherClass] += 1
          neighborDifferenceSums[featherClass] +=
            Double(abs(luminance - linearLuminances[neighbor]))
        }
      }
      if y + 1 < height {
        let neighbor = pixel + width
        if birdMask[neighbor] && featherClassCodes[neighbor] == featherClassCodes[pixel] {
          neighborCounts[featherClass] += 1
          neighborDifferenceSums[featherClass] +=
            Double(abs(luminance - linearLuminances[neighbor]))
        }
      }
    }

    return (0..<counts.count).compactMap { featherClass in
      let count = counts[featherClass]
      guard count > 0 else { return nil }
      let mean = sums[featherClass] / Double(count)
      let variance = max(0, squaredSums[featherClass] / Double(count) - mean * mean)
      return CrowFeatherClassLuminanceAudit(
        featherClassCode: UInt8(featherClass),
        pixelCount: count,
        meanLinearLuminance: Float(mean),
        standardDeviationLinearLuminance: Float(sqrt(variance)),
        maximumLinearLuminance: maxima[featherClass],
        maximumLinearLuminanceX: maximumX[featherClass],
        maximumLinearLuminanceY: maximumY[featherClass],
        meanSameClassNeighborAbsoluteLuminanceDifference:
          neighborCounts[featherClass] > 0
          ? Float(
            neighborDifferenceSums[featherClass]
              / Double(neighborCounts[featherClass])
          )
          : 0
      )
    }
  }

  /// Retains every right/down cross-class edge once. Ordered class pairs make
  /// material handoffs localizable without storing a target image or mistaking
  /// within-tract barb contrast for a region boundary.
  static func featherClassBoundaryAudits(
    birdMask: [Bool],
    featherClassCodes: [UInt8],
    linearLuminances: [Float],
    width: Int,
    height: Int
  ) -> [CrowFeatherClassBoundaryAudit] {
    let pixelCount = width * height
    precondition(width >= 0 && height >= 0 && birdMask.count == pixelCount)
    precondition(featherClassCodes.count == pixelCount)
    precondition(linearLuminances.count == pixelCount)

    struct Accumulator {
      var edgeCount = 0
      var luminanceDifferenceSum: Double = 0
      var signedLuminanceDifferenceSum: Double = 0
      var maximumLuminanceDifference: Float = 0
      var maximumX = 0
      var maximumY = 0
      var minimumX = Int.max
      var maximumBoundaryX = 0
      var minimumY = Int.max
      var maximumBoundaryY = 0
    }
    var accumulators: [UInt16: Accumulator] = [:]

    func accumulate(_ firstPixel: Int, _ secondPixel: Int, atX x: Int, y: Int) {
      let firstClass = min(featherClassCodes[firstPixel], 31)
      let secondClass = min(featherClassCodes[secondPixel], 31)
      guard firstClass != secondClass else { return }
      let lower = min(firstClass, secondClass)
      let upper = max(firstClass, secondClass)
      let key = UInt16(lower) << 8 | UInt16(upper)
      let difference = abs(
        linearLuminances[firstPixel] - linearLuminances[secondPixel]
      )
      let signedDifference =
        firstClass == lower
        ? linearLuminances[firstPixel] - linearLuminances[secondPixel]
        : linearLuminances[secondPixel] - linearLuminances[firstPixel]
      var accumulator = accumulators[key] ?? Accumulator()
      accumulator.edgeCount += 1
      accumulator.luminanceDifferenceSum += Double(difference)
      accumulator.signedLuminanceDifferenceSum += Double(signedDifference)
      accumulator.minimumX = min(accumulator.minimumX, x)
      accumulator.maximumBoundaryX = max(accumulator.maximumBoundaryX, x)
      accumulator.minimumY = min(accumulator.minimumY, y)
      accumulator.maximumBoundaryY = max(accumulator.maximumBoundaryY, y)
      if difference > accumulator.maximumLuminanceDifference {
        accumulator.maximumLuminanceDifference = difference
        accumulator.maximumX = x
        accumulator.maximumY = y
      }
      accumulators[key] = accumulator
    }

    for pixel in 0..<pixelCount where birdMask[pixel] {
      let x = pixel % width
      let y = pixel / width
      if x + 1 < width, birdMask[pixel + 1] {
        accumulate(pixel, pixel + 1, atX: x, y: y)
      }
      if y + 1 < height, birdMask[pixel + width] {
        accumulate(pixel, pixel + width, atX: x, y: y)
      }
    }

    return accumulators.map { key, accumulator in
      CrowFeatherClassBoundaryAudit(
        firstFeatherClassCode: UInt8(key >> 8),
        secondFeatherClassCode: UInt8(key & 255),
        edgeCount: accumulator.edgeCount,
        minimumX: accumulator.minimumX,
        maximumX: accumulator.maximumBoundaryX,
        minimumY: accumulator.minimumY,
        maximumY: accumulator.maximumBoundaryY,
        meanAbsoluteLinearLuminanceDifference: Float(
          accumulator.luminanceDifferenceSum / Double(accumulator.edgeCount)
        ),
        meanLowerMinusUpperLinearLuminanceDifference: Float(
          accumulator.signedLuminanceDifferenceSum / Double(accumulator.edgeCount)
        ),
        maximumAbsoluteLinearLuminanceDifference:
          accumulator.maximumLuminanceDifference,
        maximumDifferenceX: accumulator.maximumX,
        maximumDifferenceY: accumulator.maximumY
      )
    }.sorted {
      ($0.firstFeatherClassCode, $0.secondFeatherClassCode)
        < ($1.firstFeatherClassCode, $1.secondFeatherClassCode)
    }
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

  private static func silhouetteExterior(
    birdMask: [Bool],
    width: Int,
    height: Int
  ) -> (
    minimumX: Int,
    maximumX: Int,
    minimumY: Int,
    maximumY: Int,
    exterior: [Bool]
  )? {
    guard width > 0, height > 0 else { return nil }
    let birdPixels = birdMask.indices.filter { birdMask[$0] }
    guard let first = birdPixels.first else { return nil }
    var minimumX = first % width
    var maximumX = minimumX
    var minimumY = first / width
    var maximumY = minimumY
    for pixel in birdPixels.dropFirst() {
      let x = pixel % width
      let y = pixel / width
      minimumX = min(minimumX, x)
      maximumX = max(maximumX, x)
      minimumY = min(minimumY, y)
      maximumY = max(maximumY, y)
    }

    var exterior = [Bool](repeating: false, count: birdMask.count)
    var queue: [Int] = []
    func enqueueExterior(_ x: Int, _ y: Int) {
      let pixel = y * width + x
      guard !birdMask[pixel], !exterior[pixel] else { return }
      exterior[pixel] = true
      queue.append(pixel)
    }
    for x in minimumX...maximumX {
      enqueueExterior(x, minimumY)
      enqueueExterior(x, maximumY)
    }
    for y in minimumY...maximumY {
      enqueueExterior(minimumX, y)
      enqueueExterior(maximumX, y)
    }
    var head = 0
    while head < queue.count {
      let pixel = queue[head]
      head += 1
      let x = pixel % width
      let y = pixel / width
      for offsetY in -1...1 {
        for offsetX in -1...1 where offsetX != 0 || offsetY != 0 {
          let neighborX = x + offsetX
          let neighborY = y + offsetY
          guard neighborX >= minimumX, neighborX <= maximumX,
            neighborY >= minimumY, neighborY <= maximumY
          else { continue }
          enqueueExterior(neighborX, neighborY)
        }
      }
    }
    return (minimumX, maximumX, minimumY, maximumY, exterior)
  }

  /// Reports exterior-connected background runs bracketed by bird ownership
  /// along image rows or columns. Unlike enclosed-hole counts, these runs keep
  /// shoulder, axillary, and feather-course slots visible to an audit even
  /// when they open diagonally onto the surrounding background. Runs are
  /// evidence for localization, not an assertion that every concavity is a
  /// defect; boundary class and primitive owners are retained explicitly.
  static func exteriorSilhouetteSlotRuns(
    birdMask: [Bool],
    featherClassCodes: [UInt8] = [],
    surfacePrimitiveIdentifiers: [UInt32] = [],
    packedSurfaceIdentities: [UInt32] = [],
    width: Int,
    height: Int
  ) -> [CrowExteriorSilhouetteSlotRunAudit] {
    precondition(width >= 0 && height >= 0 && birdMask.count == width * height)
    precondition(featherClassCodes.isEmpty || featherClassCodes.count == birdMask.count)
    precondition(
      surfacePrimitiveIdentifiers.isEmpty
        || surfacePrimitiveIdentifiers.count == birdMask.count
    )
    precondition(
      packedSurfaceIdentities.isEmpty
        || packedSurfaceIdentities.count == birdMask.count
    )
    guard
      let silhouette = silhouetteExterior(
        birdMask: birdMask,
        width: width,
        height: height
      )
    else { return [] }

    func classCode(_ pixel: Int) -> UInt8 {
      featherClassCodes.isEmpty ? 0 : featherClassCodes[pixel]
    }
    func primitive(_ pixel: Int) -> UInt32 {
      surfacePrimitiveIdentifiers.isEmpty ? 0 : surfacePrimitiveIdentifiers[pixel]
    }
    func packedIdentity(_ pixel: Int) -> UInt32 {
      packedSurfaceIdentities.isEmpty ? 0 : packedSurfaceIdentities[pixel]
    }
    var runs: [CrowExteriorSilhouetteSlotRunAudit] = []
    for y in silhouette.minimumY...silhouette.maximumY {
      var x = silhouette.minimumX
      while x <= silhouette.maximumX {
        guard !birdMask[y * width + x] else {
          x += 1
          continue
        }
        let startX = x
        while x <= silhouette.maximumX && !birdMask[y * width + x] { x += 1 }
        let endX = x - 1
        guard startX > silhouette.minimumX, x <= silhouette.maximumX,
          silhouette.exterior[y * width + startX]
        else { continue }
        let firstBoundary = y * width + startX - 1
        let secondBoundary = y * width + x
        runs.append(
          CrowExteriorSilhouetteSlotRunAudit(
            axis: "horizontal",
            pixelCount: endX - startX + 1,
            minimumX: startX,
            maximumX: endX,
            minimumY: y,
            maximumY: y,
            firstBoundaryFeatherClassCode: classCode(firstBoundary),
            secondBoundaryFeatherClassCode: classCode(secondBoundary),
            firstBoundarySurfacePrimitiveIdentifier: primitive(firstBoundary),
            secondBoundarySurfacePrimitiveIdentifier: primitive(secondBoundary),
            firstBoundaryPackedIdentity: packedIdentity(firstBoundary),
            secondBoundaryPackedIdentity: packedIdentity(secondBoundary)
          )
        )
      }
    }
    for x in silhouette.minimumX...silhouette.maximumX {
      var y = silhouette.minimumY
      while y <= silhouette.maximumY {
        guard !birdMask[y * width + x] else {
          y += 1
          continue
        }
        let startY = y
        while y <= silhouette.maximumY && !birdMask[y * width + x] { y += 1 }
        let endY = y - 1
        guard startY > silhouette.minimumY, y <= silhouette.maximumY,
          silhouette.exterior[startY * width + x]
        else { continue }
        let firstBoundary = (startY - 1) * width + x
        let secondBoundary = y * width + x
        runs.append(
          CrowExteriorSilhouetteSlotRunAudit(
            axis: "vertical",
            pixelCount: endY - startY + 1,
            minimumX: x,
            maximumX: x,
            minimumY: startY,
            maximumY: endY,
            firstBoundaryFeatherClassCode: classCode(firstBoundary),
            secondBoundaryFeatherClassCode: classCode(secondBoundary),
            firstBoundarySurfacePrimitiveIdentifier: primitive(firstBoundary),
            secondBoundarySurfacePrimitiveIdentifier: primitive(secondBoundary),
            firstBoundaryPackedIdentity: packedIdentity(firstBoundary),
            secondBoundaryPackedIdentity: packedIdentity(secondBoundary)
          )
        )
      }
    }
    let sortedRuns = runs.sorted {
      if $0.pixelCount != $1.pixelCount {
        return $0.pixelCount > $1.pixelCount
      }
      if $0.axis != $1.axis { return $0.axis < $1.axis }
      return ($0.minimumY, $0.minimumX, $0.maximumY, $0.maximumX)
        < ($1.minimumY, $1.minimumX, $1.maximumY, $1.maximumX)
    }
    var pairCounts: [UInt32: Int] = [:]
    var selected: [CrowExteriorSilhouetteSlotRunAudit] = []
    for run in sortedRuns {
      let axisCode: UInt32 = run.axis == "vertical" ? 1 : 0
      let pairKey =
        (axisCode << 16)
        | (UInt32(run.firstBoundaryFeatherClassCode) << 8)
        | UInt32(run.secondBoundaryFeatherClassCode)
      guard pairCounts[pairKey, default: 0] < 4 else { continue }
      pairCounts[pairKey, default: 0] += 1
      selected.append(run)
      if selected.count == 128 { break }
    }
    return selected
  }

  /// Finds background components enclosed by the bird identity silhouette.
  /// Eight-connected exterior flooding is deliberately conservative: a
  /// diagonal path to open background is not reported as an anatomical hole.
  static func silhouetteHoles(
    birdMask: [Bool],
    featherClassCodes: [UInt8] = [],
    surfacePrimitiveIdentifiers: [UInt32] = [],
    packedSurfaceIdentities: [UInt32] = [],
    width: Int,
    height: Int
  ) -> CrowSilhouetteHoleAudit {
    precondition(width >= 0 && height >= 0 && birdMask.count == width * height)
    precondition(featherClassCodes.isEmpty || featherClassCodes.count == birdMask.count)
    precondition(
      surfacePrimitiveIdentifiers.isEmpty
        || surfacePrimitiveIdentifiers.count == birdMask.count
    )
    precondition(
      packedSurfaceIdentities.isEmpty
        || packedSurfaceIdentities.count == birdMask.count
    )
    guard
      let silhouette = silhouetteExterior(
        birdMask: birdMask,
        width: width,
        height: height
      )
    else { return .zero }
    let minimumX = silhouette.minimumX
    let maximumX = silhouette.maximumX
    let minimumY = silhouette.minimumY
    let maximumY = silhouette.maximumY
    let exterior = silhouette.exterior

    var visited = exterior
    var total = 0
    var components = 0
    var largest = 0
    var apertureTotal = 0
    var apertureComponents = 0
    var largestAperture = 0
    var largestMinimumX = 0
    var largestMaximumX = 0
    var largestMinimumY = 0
    var largestMaximumY = 0
    var largestCentroidX: Float = 0
    var largestCentroidY: Float = 0
    var largestAdjacentClassMask: UInt32 = 0
    var largestAdjacentSurfacePrimitives: [CrowSilhouetteSurfacePrimitiveReference] = []
    var largestAdjacentPackedIdentities: [UInt32] = []
    for y in minimumY...maximumY {
      for x in minimumX...maximumX {
        let start = y * width + x
        guard !birdMask[start], !visited[start] else { continue }
        var componentQueue = [start]
        visited[start] = true
        var componentHead = 0
        var componentSize = 0
        var componentMinimumX = x
        var componentMaximumX = x
        var componentMinimumY = y
        var componentMaximumY = y
        var componentXTotal = 0
        var componentYTotal = 0
        var adjacentClassMask: UInt32 = 0
        var adjacentSurfacePrimitives: Set<CrowSilhouetteSurfacePrimitiveReference> = []
        var adjacentPackedIdentities: Set<UInt32> = []
        while componentHead < componentQueue.count {
          let pixel = componentQueue[componentHead]
          componentHead += 1
          componentSize += 1
          let pixelX = pixel % width
          let pixelY = pixel / width
          componentMinimumX = min(componentMinimumX, pixelX)
          componentMaximumX = max(componentMaximumX, pixelX)
          componentMinimumY = min(componentMinimumY, pixelY)
          componentMaximumY = max(componentMaximumY, pixelY)
          componentXTotal += pixelX
          componentYTotal += pixelY
          for offsetY in -1...1 {
            for offsetX in -1...1 where offsetX != 0 || offsetY != 0 {
              let neighborX = pixelX + offsetX
              let neighborY = pixelY + offsetY
              guard neighborX >= minimumX, neighborX <= maximumX,
                neighborY >= minimumY, neighborY <= maximumY
              else { continue }
              let neighbor = neighborY * width + neighborX
              if birdMask[neighbor] {
                let classCode =
                  featherClassCodes.isEmpty
                  ? 0
                  : min(UInt32(featherClassCodes[neighbor]), 31)
                adjacentClassMask |= 1 << classCode
                if !surfacePrimitiveIdentifiers.isEmpty {
                  let identifier = surfacePrimitiveIdentifiers[neighbor]
                  if identifier != 0 {
                    adjacentSurfacePrimitives.insert(
                      CrowSilhouetteSurfacePrimitiveReference(
                        identifier: identifier,
                        featherClassCode: UInt8(classCode)
                      )
                    )
                  }
                }
                if !packedSurfaceIdentities.isEmpty {
                  let packedIdentity = packedSurfaceIdentities[neighbor]
                  if packedIdentity != 0 {
                    adjacentPackedIdentities.insert(packedIdentity)
                  }
                }
                continue
              }
              guard !birdMask[neighbor], !visited[neighbor] else { continue }
              visited[neighbor] = true
              componentQueue.append(neighbor)
            }
          }
        }
        let componentWidth = componentMaximumX - componentMinimumX + 1
        let componentHeight = componentMaximumY - componentMinimumY + 1
        let birdHeight = maximumY - minimumY + 1
        // A planted crow legitimately encloses background between its two
        // legs and between spread digits. Keep those scale-aware lower-body
        // apertures separate from plumage or body-shell defects.
        let pedalSurfaceMask: UInt32 =
          1
          << CrowFootAnatomy.surfaceIdentityClassCode
        let lowerBodyBoundaryMask: UInt32 =
          (1 << 0) | (1 << 7) | pedalSurfaceMask
        let boundedOnlyByBodyAndLegPlumage =
          adjacentClassMask != 0
          && adjacentClassMask & ~lowerBodyBoundaryMask == 0
        let legFeatherBounded = adjacentClassMask & (1 << 7) != 0
        let tallInterLegAspect = componentHeight * 2 >= 3 * componentWidth
        // A high camera elevation foreshortens the planted inter-leg opening
        // into a wider triangle. Accept that projection only when semantic
        // leg/femoral plumage actually bounds it; body-only slots remain
        // defects under the stricter tall-aperture rule.
        let elevatedInterLegAspect =
          legFeatherBounded && componentHeight * 3 >= 2 * componentWidth
        let scaleAwareInterLegHeight =
          (tallInterLegAspect && componentHeight >= max(4, birdHeight / 8))
          || (elevatedInterLegAspect
            && componentHeight >= max(4, birdHeight / 24))
        let expectedInterLegAperture =
          boundedOnlyByBodyAndLegPlumage
          && componentMinimumY >= minimumY + birdHeight / 2
          && scaleAwareInterLegHeight
          && componentSize >= max(8, birdHeight / 2)
        let expectedPedalAperture =
          boundedOnlyByBodyAndLegPlumage
          && componentMinimumY >= minimumY + 9 * birdHeight / 10
          && componentWidth >= componentHeight
          && componentSize >= 2
        let expectedElevatedPedalAperture =
          legFeatherBounded
          && boundedOnlyByBodyAndLegPlumage
          && componentMinimumY >= minimumY + birdHeight / 2
          && componentWidth >= componentHeight
          && componentSize >= 2
          && componentSize <= birdHeight
        // During takeoff the articulated toes retract across the ventral wing
        // projection. A compact component explicitly bounded by pedal keratin,
        // leg plumage, and wing coverts is anatomical negative space rather
        // than a missing body or feather surface.
        let retractedPedalBoundaryMask =
          lowerBodyBoundaryMask | (1 << 4)
          | (1 << CrowFlightWingBodyIntegration.underwingCovertSurfaceFeatherClass)
          | (1
            << CrowFlightWingBodyIntegration
            .underwingPrimaryCovertSurfaceFeatherClass)
        let boundedByRetractedPedalSurfaces =
          adjacentClassMask & pedalSurfaceMask != 0
          && legFeatherBounded
          && adjacentClassMask & ~retractedPedalBoundaryMask == 0
        let compactRetractedPedalBounds = max(4, birdHeight / 8)
        let expectedRetractedPedalAperture =
          boundedByRetractedPedalSurfaces
          && componentMinimumY >= minimumY + birdHeight / 2
          && componentWidth <= compactRetractedPedalBounds
          && componentHeight <= compactRetractedPedalBounds
          && componentSize >= 2
          && componentSize <= birdHeight
        let expectedLowerBodyAperture =
          expectedInterLegAperture || expectedPedalAperture
          || expectedElevatedPedalAperture
          || expectedRetractedPedalAperture
        if expectedLowerBodyAperture {
          apertureTotal += componentSize
          apertureComponents += 1
          largestAperture = max(largestAperture, componentSize)
          continue
        }
        total += componentSize
        components += 1
        if componentSize > largest {
          largest = componentSize
          largestMinimumX = componentMinimumX
          largestMaximumX = componentMaximumX
          largestMinimumY = componentMinimumY
          largestMaximumY = componentMaximumY
          largestCentroidX = Float(componentXTotal) / Float(componentSize)
          largestCentroidY = Float(componentYTotal) / Float(componentSize)
          largestAdjacentClassMask = adjacentClassMask
          largestAdjacentSurfacePrimitives = Array(
            adjacentSurfacePrimitives.sorted {
              $0.identifier == $1.identifier
                ? $0.featherClassCode < $1.featherClassCode
                : $0.identifier < $1.identifier
            }.prefix(16)
          )
          largestAdjacentPackedIdentities = Array(
            adjacentPackedIdentities.sorted().prefix(32)
          )
        }
      }
    }
    return CrowSilhouetteHoleAudit(
      pixelCount: total,
      componentCount: components,
      largestComponentPixelCount: largest,
      minimumX: largestMinimumX,
      maximumX: largestMaximumX,
      minimumY: largestMinimumY,
      maximumY: largestMaximumY,
      centroidX: largestCentroidX,
      centroidY: largestCentroidY,
      adjacentFeatherClassMask: largestAdjacentClassMask,
      adjacentSurfacePrimitives: largestAdjacentSurfacePrimitives,
      adjacentPackedIdentities: largestAdjacentPackedIdentities,
      expectedLowerBodyAperturePixelCount: apertureTotal,
      expectedLowerBodyApertureComponentCount: apertureComponents,
      largestExpectedLowerBodyAperturePixelCount: largestAperture
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

struct CrowSilhouetteHoleAudit: Equatable {
  let pixelCount: Int
  let componentCount: Int
  let largestComponentPixelCount: Int
  let minimumX: Int
  let maximumX: Int
  let minimumY: Int
  let maximumY: Int
  let centroidX: Float
  let centroidY: Float
  let adjacentFeatherClassMask: UInt32
  let adjacentSurfacePrimitives: [CrowSilhouetteSurfacePrimitiveReference]
  let adjacentPackedIdentities: [UInt32]
  let expectedLowerBodyAperturePixelCount: Int
  let expectedLowerBodyApertureComponentCount: Int
  let largestExpectedLowerBodyAperturePixelCount: Int

  static let zero = CrowSilhouetteHoleAudit(
    pixelCount: 0,
    componentCount: 0,
    largestComponentPixelCount: 0,
    minimumX: 0,
    maximumX: 0,
    minimumY: 0,
    maximumY: 0,
    centroidX: 0,
    centroidY: 0,
    adjacentFeatherClassMask: 0,
    adjacentSurfacePrimitives: [],
    adjacentPackedIdentities: [],
    expectedLowerBodyAperturePixelCount: 0,
    expectedLowerBodyApertureComponentCount: 0,
    largestExpectedLowerBodyAperturePixelCount: 0
  )
}

struct CrowSilhouetteSurfacePrimitiveReference: Codable, Equatable, Hashable {
  let identifier: UInt32
  let featherClassCode: UInt8
}

struct CrowExteriorSilhouetteSlotRunAudit: Codable, Equatable {
  let axis: String
  let pixelCount: Int
  let minimumX: Int
  let maximumX: Int
  let minimumY: Int
  let maximumY: Int
  let firstBoundaryFeatherClassCode: UInt8
  let secondBoundaryFeatherClassCode: UInt8
  let firstBoundarySurfacePrimitiveIdentifier: UInt32
  let secondBoundarySurfacePrimitiveIdentifier: UInt32
  let firstBoundaryPackedIdentity: UInt32
  let secondBoundaryPackedIdentity: UInt32
}

struct CrowFeatherClassLuminanceAudit: Codable, Equatable {
  let featherClassCode: UInt8
  let pixelCount: Int
  let meanLinearLuminance: Float
  let standardDeviationLinearLuminance: Float
  let maximumLinearLuminance: Float
  let maximumLinearLuminanceX: Int
  let maximumLinearLuminanceY: Int
  let meanSameClassNeighborAbsoluteLuminanceDifference: Float
}

struct CrowFeatherClassBoundaryAudit: Codable, Equatable {
  let firstFeatherClassCode: UInt8
  let secondFeatherClassCode: UInt8
  let edgeCount: Int
  let minimumX: Int
  let maximumX: Int
  let minimumY: Int
  let maximumY: Int
  let meanAbsoluteLinearLuminanceDifference: Float
  /// Signed mean with the lower class code first, independent of image-edge
  /// direction. Negative means the lower class is darker along this boundary.
  let meanLowerMinusUpperLinearLuminanceDifference: Float
  let maximumAbsoluteLinearLuminanceDifference: Float
  let maximumDifferenceX: Int
  let maximumDifferenceY: Int
}

struct CrowShowcaseAOVFrameAudit: Codable, Equatable {
  let frameIndex: Int
  let width: Int
  let height: Int
  let outputWidth: Int
  let outputHeight: Int
  let reconstructionMode: String
  let plumageSurfaceVisibilityAuthority: String
  let plumageExplicitCurveVisibilityAuthority: String
  let plumageComputeRayTracingSupported: Bool
  let plumageRenderRayTracingSupported: Bool
  let plumageExperimentalRayVisibilityEnabled: Bool
  let plumageRayVisibilityEnablementGate: String
  let plumageRayGeometryAuditRequested: Bool
  let plumageRayGeometryBuildSucceeded: Bool
  let plumageRayGeometryTriangleCount: Int
  let plumageRayGeometryAccelerationStructureBytes: Int
  let plumageRayGeometryBuildScratchBytes: Int
  let plumageRayGeometryProbeAttempted: Bool
  let plumageRayGeometryProbeHit: Bool
  let plumageRayGeometryProbePrimitiveIndex: Int
  let plumageRayGeometryProbeDistanceMeters: Float
  let plumageRayGeometryProbeRayCount: Int
  let plumageRayGeometryProbeHitCount: Int
  let plumageRasterRaySampleCount: Int
  let plumageRasterRayHitCount: Int
  let plumageRasterRayIdentityParityCount: Int
  let plumageRasterRayRachisOwnerParityCount: Int
  let plumageRasterRayDepthParityCount: Int
  let plumageFullImageRayAuditRequested: Bool
  let plumageFullImageRaySampleCount: Int
  let plumageFullImageRayHitCount: Int
  let plumageFullImageRayRachisOwnerParityCount: Int
  let plumageFullImageRayDepthParityCount: Int
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
  let bodyVaneMorphologyRecordCount: Int
  let bodyVaneMorphologyRecordBytes: Int
  let bodyVaneSelectedMorphologyRecordCount: Int
  let bodyVaneBatchCount: Int
  let bodyVaneSelectedMorphologyRecordBytes: Int
  let bodyVaneRetainedMorphologyCapacityBytes: Int
  let bodyVanePoseInputBytes: Int
  let bodyVaneRetainedPoseCapacityBytes: Int
  let bodyVaneRetainedIndirectDrawBytes: Int
  let bodyVaneMorphologyBufferAllocationCount: Int
  let bodyVaneRasterVertexInvocationCount: Int
  let bodyVaneVertexGenerationMode: String
  let cranialVisibilityRetainedCapacityBytes: Int
  let cranialVisibilityOcclusionDepthBytes: Int
  let cranialVisibilityOcclusionMode: String
  let cranialVaneCandidateRecordCount: Int
  let cranialVaneFrustumVisibleRecordCount: Int
  let cranialVaneVisibleRecordCount: Int
  let cranialVaneOcclusionTestedRecordCount: Int
  let cranialVaneOcclusionCulledRecordCount: Int
  let cranialVaneRasterVertexInvocationCount: Int
  let gularDetailCandidateRecordCount: Int
  let gularDetailFrustumVisibleRecordCount: Int
  let gularDetailVisibleRecordCount: Int
  let gularDetailOcclusionTestedRecordCount: Int
  let gularDetailOcclusionCulledRecordCount: Int
  let gularDetailRasterVertexInvocationCount: Int
  let ventralVaneMorphologyRecordCount: Int
  let ventralVaneMorphologyRecordBytes: Int
  let ventralVaneSelectedMorphologyRecordCount: Int
  let ventralVaneRasterVertexInvocationCount: Int
  let ventralVaneEliminatedCPUSurfaceVertexBytes: Int
  let ventralVaneVertexGenerationMode: String
  let ventralBarbCandidateRecordCount: Int
  /// Candidate records promoted from the 40-pixel aggregate tier to the
  /// independently gated 480-pixel close tier.
  let ventralBarbCloseCandidateRecordCount: Int
  let ventralBarbuleCandidateRecordCount: Int
  let ventralBarbFrustumVisibleRecordCount: Int
  let ventralBarbVisibleRecordCount: Int
  let ventralBarbuleFrustumVisibleRecordCount: Int
  let ventralBarbuleVisibleRecordCount: Int
  let ventralBarbOcclusionTestedRecordCount: Int
  let ventralBarbOcclusionCulledRecordCount: Int
  let ventralBarbOcclusionDepthBytes: Int
  let ventralBarbOcclusionMode: String
  let ventralBarbExpandedVertexCount: Int
  let ventralBarbRasterVertexInvocationCount: Int
  let ventralBarbuleExpandedVertexCount: Int
  let ventralBarbuleVisiblePixelCount: Int
  let ventralBarbOutputCapacityBytes: Int
  let ventralBarbVertexGenerationMode: String
  let finitePixelCount: Int
  let aboveOneHDRPixelCount: Int
  let activeIdentityPixelCount: Int
  let fullyCoveredAOVPixelCount: Int
  let fullyCoveredActiveIdentityPixelCount: Int
  let visibleFeatherIdentityCount: Int
  /// Exact visible-pixel census for the 54 persistent primary, secondary, and
  /// rectrix identities. Procedural surface primitives retain separate AOV
  /// ownership and are intentionally excluded.
  let persistentFeatherIdentities: [CrowPersistentFeatherIdentityAudit]
  /// Visible-pixel survival for each persistent feather's simulated vane,
  /// rachis, and barb geometry. This is decoded from the diagnostic high byte
  /// without changing the stable anatomical identity above.
  let persistentFeatherPrimitives: [CrowPersistentFeatherPrimitiveAudit]
  /// Visible-pixel ownership for every retained body contour vane, rachis, or
  /// contained detail primitive, mapped back to tract region and grid index.
  let bodyVaneIdentities: [CrowBodyVaneIdentityAudit]
  /// Exact visible-pixel census for the fixed 32 by 8 cells of each retained
  /// wing surface. This maps coarse silhouette evidence back to owning
  /// topology without storing an image-space target.
  let wingSurfaceCellIdentities: [CrowWingSurfaceCellIdentityAudit]
  /// Exact visible-pixel and image-bound census for each topology-bound dorsal
  /// covert. Vane, rachis, and barb primitives retain one anatomical owner.
  let wingCovertIdentities: [CrowWingCovertIdentityAudit]
  /// Exact visible identity-AOV pixels binned by the low five class bits.
  let visibleFeatherClassPixelCounts: [Int]
  /// The same 32-bin census restricted to full geometric sample coverage.
  let fullyCoveredFeatherClassPixelCounts: [Int]
  /// Scene-linear luminance distribution and local variation for each visible
  /// bird feather class. Support and environment identities are excluded.
  let featherClassLuminanceAudits: [CrowFeatherClassLuminanceAudit]
  /// Right/down adjacency census for every visible ordered feather-class pair.
  /// Bounds and scene-linear contrast localize material seams without media.
  let featherClassBoundaryAudits: [CrowFeatherClassBoundaryAudit]
  let enclosedBirdSilhouetteHolePixelCount: Int
  let enclosedBirdSilhouetteHoleComponentCount: Int
  let largestEnclosedBirdSilhouetteHolePixelCount: Int
  let largestEnclosedBirdSilhouetteHoleMinimumX: Int
  let largestEnclosedBirdSilhouetteHoleMaximumX: Int
  let largestEnclosedBirdSilhouetteHoleMinimumY: Int
  let largestEnclosedBirdSilhouetteHoleMaximumY: Int
  let largestEnclosedBirdSilhouetteHoleCentroidX: Float
  let largestEnclosedBirdSilhouetteHoleCentroidY: Float
  let largestEnclosedBirdSilhouetteHoleAdjacentFeatherClassMask: UInt32
  let largestEnclosedBirdSilhouetteHoleAdjacentSurfacePrimitives:
    [CrowSilhouetteSurfacePrimitiveReference]
  /// Sorted semantic identities touching the largest enclosed component. This
  /// retains rank/order ownership for procedural feathers whose primitive ID
  /// channel is intentionally zero.
  let largestEnclosedBirdSilhouetteHoleAdjacentPackedIdentities: [UInt32]
  let expectedLowerBodyAperturePixelCount: Int
  let expectedLowerBodyApertureComponentCount: Int
  let largestExpectedLowerBodyAperturePixelCount: Int
  /// Up to 128 longest exterior-connected background runs bracketed by bird
  /// ownership on an image row or column. At most four samples per axis and
  /// ordered boundary-class pair preserve semantic diversity.
  let exteriorBirdSilhouetteSlotRuns: [CrowExteriorSilhouetteSlotRunAudit]
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

struct CrowPersistentFeatherIdentityAudit: Codable, Equatable {
  let featherIndex: UInt32
  let stableIdentifierHash: UInt32
  let physicsSurfacePartIdentifier: UInt32
  let packedIdentity: UInt32
  let visiblePixelCount: Int
  let fullyCoveredPixelCount: Int
  let minimumX: Int
  let maximumX: Int
  let minimumY: Int
  let maximumY: Int
  let centroidX: Float
  let centroidY: Float

  var featherClass: UInt32 { packedIdentity & 255 }
  var sideCode: UInt32 { (packedIdentity >> 8) & 255 }
  var order: UInt32 { (packedIdentity >> 16) & 255 }
  var count: UInt32 { (packedIdentity >> 24) & 255 }
}

struct CrowPersistentFeatherPrimitiveAudit: Codable, Equatable {
  let featherIndex: UInt32
  let stableIdentifierHash: UInt32
  let packedIdentity: UInt32
  /// CrowFeatherVertexGPU.parameters.w: 0 vane, 1 rachis, 2 barb.
  let detailKind: UInt32
  let visiblePixelCount: Int
  let fullyCoveredPixelCount: Int

  var featherClass: UInt32 { packedIdentity & 255 }
  var sideCode: UInt32 { (packedIdentity >> 8) & 255 }
  var order: UInt32 { (packedIdentity >> 16) & 255 }
  var count: UInt32 { (packedIdentity >> 24) & 255 }
}

struct CrowBodyVaneIdentityAudit: Codable, Equatable {
  /// Two identifies dorsal/body contour vanes; three identifies ventral vanes.
  let familyCode: UInt8
  let inventoryIndex: Int
  let stableIdentifierHash: UInt32
  let physicsSurfacePartIdentifier: UInt32
  let featherClassCode: UInt32
  let regionCode: UInt8
  /// Zero is the negative tract side; one is the positive tract side.
  let sideCode: UInt8
  let row: Int
  let column: Int
  let visiblePixelCount: Int
  let fullyCoveredPixelCount: Int
  let minimumX: Int
  let maximumX: Int
  let minimumY: Int
  let maximumY: Int
  let centroidX: Float
  let centroidY: Float
}

enum CrowWingSurfaceCellIdentity {
  static let featherClassCode: UInt32 = 11

  static func pack(
    partIdentifier: UInt8,
    spanIndex: Int,
    chordIndex: Int,
    upperTriangle: Bool
  ) -> UInt32 {
    precondition(partIdentifier == 2 || partIdentifier == 3)
    precondition((0..<CrowFlightWingBodyIntegration.spanCount - 1).contains(spanIndex))
    precondition((0..<CrowFlightWingBodyIntegration.chordCount - 1).contains(chordIndex))
    return featherClassCode
      | UInt32(partIdentifier - 2) << 8
      | UInt32(spanIndex) << 9
      | UInt32(chordIndex) << 15
      | UInt32(upperTriangle ? 1 : 0) << 19
  }

  static func isPacked(_ identity: UInt32) -> Bool {
    identity & 255 == featherClassCode
  }

  /// Class 11 is also the deliberately separate pedal-keratin class. The
  /// retained wing scaffold uses the low-alpha feather material bucket, so an
  /// AOV owner must satisfy both fields before it is decoded as a wing cell.
  static func isPacked(
    _ identity: UInt32,
    surfaceMaterialCode: UInt32
  ) -> Bool {
    surfaceMaterialCode == 2 && isPacked(identity)
  }
}

struct CrowWingSurfaceCellIdentityAudit: Codable, Equatable {
  let packedIdentity: UInt32
  let visiblePixelCount: Int
  let fullyCoveredPixelCount: Int
  let minimumX: Int
  let maximumX: Int
  let minimumY: Int
  let maximumY: Int
  let centroidX: Float
  let centroidY: Float

  var partIdentifier: UInt8 { UInt8((packedIdentity >> 8) & 1) + 2 }
  var spanIndex: Int { Int((packedIdentity >> 9) & 63) }
  var chordIndex: Int { Int((packedIdentity >> 15) & 15) }
  var upperTriangle: Bool { (packedIdentity >> 19) & 1 == 1 }
}

enum CrowWingCovertIdentity {
  static let featherClassCode: UInt32 = 4

  static func pack(left: Bool, chordIndex: Int, spanIndex: Int) -> UInt32 {
    precondition(CrowFlightWingBodyIntegration.covertChordIndices.contains(chordIndex))
    precondition(CrowFlightWingBodyIntegration.covertSpanIndices.contains(spanIndex))
    return featherClassCode
      | UInt32(left ? 1 : 2) << 8
      | UInt32(chordIndex) << 10
      | UInt32(spanIndex) << 14
  }

  static func isPacked(_ identity: UInt32) -> Bool {
    identity > 255 && identity & 255 == featherClassCode
  }
}

struct CrowWingCovertIdentityAudit: Codable, Equatable {
  let packedIdentity: UInt32
  let visiblePixelCount: Int
  let fullyCoveredPixelCount: Int
  let minimumX: Int
  let maximumX: Int
  let minimumY: Int
  let maximumY: Int
  let centroidX: Float
  let centroidY: Float

  var sideCode: Int { Int((packedIdentity >> 8) & 3) }
  var chordIndex: Int { Int((packedIdentity >> 10) & 15) }
  var spanIndex: Int { Int((packedIdentity >> 14) & 63) }
}

struct CrowShowcaseAOVAuditReport: Codable, Equatable {
  let schemaVersion: Int
  let colorSpace: String
  let motionConvention: String
  let depthConvention: String
  let formats: [String: String]
  let frames: [CrowShowcaseAOVFrameAudit]

  init(frames: [CrowShowcaseAOVFrameAudit]) {
    schemaVersion = 37
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
