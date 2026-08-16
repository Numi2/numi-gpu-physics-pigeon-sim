import AppKit
import BirdFlowMetal
import CoreText
import CryptoKit
import Foundation
import Metal
import simd

enum CrowShowcasePresentation: String {
  case wingbeat
  case standing
}

/// Native Metal presentation of an explicitly estimated American-crow model.
///
/// The measured Deetjen dove contributes only a deformation scaffold. Crow
/// morphometrics, added anatomy, feather geometry, timing, and material response
/// are decoded from a separate hybrid profile so a render can never silently
/// become a measured-crow claim.
public enum CrowShowcaseCapture {
  public struct Arguments {
    let outputDirectory: URL
    let width: Int
    let height: Int
    let frameCount: Int
    let surfaceManifestURL: URL
    let surfaceGenerationAuditURL: URL
    let crowProfileURL: URL
    let realityAssetURL: URL
    let standingReferenceURL: URL
    let aovAuditURL: URL?
    let presentation: CrowShowcasePresentation

    public init(commandLine: [String]) throws {
      func value(after flag: String) throws -> String? {
        guard let index = commandLine.firstIndex(of: flag) else { return nil }
        guard index + 1 < commandLine.count else {
          throw CaptureError.invalidArguments("\(flag) requires a value")
        }
        return commandLine[index + 1]
      }
      func positiveInteger(after flag: String, default fallback: Int) throws -> Int {
        guard let raw = try value(after: flag) else { return fallback }
        guard let parsed = Int(raw), parsed > 0 else {
          throw CaptureError.invalidArguments("\(flag) requires a positive integer")
        }
        return parsed
      }

      guard let output = try value(after: "--capture-crow-frames") else {
        throw CaptureError.invalidArguments(
          "--capture-crow-frames requires an output directory"
        )
      }
      outputDirectory = URL(fileURLWithPath: output, isDirectory: true)
      width = try positiveInteger(after: "--capture-width", default: 1600)
      height = try positiveInteger(after: "--capture-height", default: 900)
      frameCount = try positiveInteger(after: "--capture-frames", default: 48)
      guard frameCount >= 2 else {
        throw CaptureError.invalidArguments("--capture-frames must be at least 2")
      }
      surfaceManifestURL = URL(
        fileURLWithPath:
          try value(after: "--capture-crow-surface-manifest")
          ?? value(after: "--capture-crow-dove-manifest")
          ?? "ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"
      )
      surfaceGenerationAuditURL = URL(
        fileURLWithPath:
          try value(after: "--capture-crow-surface-generation-audit")
          ?? "ValidationArtifacts/american-crow-hybrid-surface-generation-v1.json"
      )
      crowProfileURL = URL(
        fileURLWithPath: try value(after: "--capture-crow-profile")
          ?? "ValidationInputs/american-crow-hybrid-visual-v1.json"
      )
      realityAssetURL = URL(
        fileURLWithPath: try value(after: "--capture-crow-reality-asset")
          ?? "ValidationInputs/american-crow-hybrid-reality-v1.json"
      )
      standingReferenceURL = URL(
        fileURLWithPath: try value(after: "--capture-crow-standing-reference")
          ?? "ValidationInputs/american-crow-standing-reference-v1.json"
      )
      aovAuditURL = try value(after: "--capture-crow-aov-audit").map {
        URL(fileURLWithPath: $0)
      }
      let presentationValue =
        try value(after: "--capture-crow-presentation")
        ?? CrowShowcasePresentation.wingbeat.rawValue
      guard
        let parsedPresentation = CrowShowcasePresentation(
          rawValue: presentationValue
        )
      else {
        throw CaptureError.invalidArguments(
          "--capture-crow-presentation requires wingbeat or standing"
        )
      }
      presentation = parsedPresentation
    }
  }

  enum CaptureError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case invalidProfile(String)
    case metalUnavailable

    var description: String {
      switch self {
      case .invalidArguments(let message), .invalidProfile(let message):
        return message
      case .metalUnavailable:
        return "American-crow capture requires an Apple Metal device"
      }
    }
  }

  public static func run(_ arguments: Arguments) throws {
    let profileData = try Data(contentsOf: arguments.crowProfileURL)
    let profile = try JSONDecoder().decode(CrowVisualProfile.self, from: profileData)
    try profile.validate()
    if arguments.presentation == .standing {
      let standingData = try Data(contentsOf: arguments.standingReferenceURL)
      let standingReference = try JSONDecoder().decode(
        CrowStandingReference.self,
        from: standingData
      )
      try standingReference.validate()
    }
    let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
      manifestURL: arguments.surfaceManifestURL
    )
    let motion: any CrowShowcaseMotion
    let realityAsset: BirdRealityAsset?
    if dataset.scientificTier == "estimated-hybrid-complete-surface" {
      let profileDirectory = arguments.crowProfileURL.standardizedFileURL
        .deletingLastPathComponent()
      let repositoryRoot =
        profileDirectory.lastPathComponent
          == "ValidationInputs"
        ? profileDirectory.deletingLastPathComponent()
        : URL(
          fileURLWithPath: FileManager.default.currentDirectoryPath,
          isDirectory: true
        )
      let loadedRealityAsset = try BirdRealityAssetLoader.load(
        assetURL: arguments.realityAssetURL,
        repositoryRootURL: repositoryRoot
      )
      let auditData = try Data(contentsOf: arguments.surfaceGenerationAuditURL)
      let audit = try JSONDecoder().decode(
        CrowSurfaceGenerationAudit.self,
        from: auditData
      )
      let generationChecksPassed = audit.checks
        .filter { $0.key != "quantitativeForceAcceptanceReady" }
        .allSatisfy { $0.value }
      guard dataset.datasetIdentifier == profile.simulationSurface.datasetIdentifier,
        dataset.manifestSHA256 == audit.manifestSHA256,
        sha256(profileData) == audit.crowProfileSHA256,
        dataset.completeBirdSurfaceReady,
        dataset.metalReplayReady,
        !dataset.quantitativeForceAcceptanceReady,
        generationChecksPassed,
        audit.checks["quantitativeForceAcceptanceReady"] == false
      else {
        throw CaptureError.invalidProfile(
          "estimated crow surface does not match its profile and generation locks"
        )
      }
      guard
        loadedRealityAsset.physicsBinding.surfaceDatasetIdentifier
          == dataset.datasetIdentifier,
        loadedRealityAsset.physicsBinding.surfaceManifestSHA256
          == dataset.manifestSHA256,
        loadedRealityAsset.feathers.filter({
          $0.featherClass == .primary && $0.side == .left
        }).count == profile.visualTransform.primaryFeatherCountPerWing,
        loadedRealityAsset.feathers.filter({
          $0.featherClass == .secondary && $0.side == .left
        }).count == profile.visualTransform.secondaryFeatherCountPerWing,
        loadedRealityAsset.feathers.filter({
          $0.featherClass == .tail
        }).count == profile.visualTransform.tailFeatherCount
      else {
        throw CaptureError.invalidProfile(
          "bird-reality asset does not match the crow surface or feather inventory"
        )
      }
      motion = EstimatedCrowSurfaceMotion(dataset: dataset)
      realityAsset = loadedRealityAsset
    } else {
      guard dataset.datasetIdentifier == profile.doveScaffold.datasetIdentifier,
        dataset.manifestSHA256 == profile.doveScaffold.manifestSHA256
      else {
        throw CaptureError.invalidProfile(
          "crow profile dove dataset does not match the loaded surface"
        )
      }
      motion = MeasuredDovePresentationLoop(dataset: dataset)
      realityAsset = nil
    }
    guard let device = MTLCreateSystemDefaultDevice() else {
      throw CaptureError.metalUnavailable
    }

    let renderer = try CrowShowcaseRenderer(
      device: device,
      dataset: dataset,
      profile: profile,
      motion: motion,
      realityAsset: realityAsset,
      presentation: arguments.presentation
    )
    try FileManager.default.createDirectory(
      at: arguments.outputDirectory,
      withIntermediateDirectories: true
    )
    var aovAudits: [CrowShowcaseAOVFrameAudit] = []

    for frameIndex in 0..<arguments.frameCount {
      let phase =
        frameIndex == arguments.frameCount - 1
        ? Float.zero
        : Float(frameIndex) / Float(arguments.frameCount - 1)
      let orbit = 2 * Float.pi * phase
      var camera = CameraState()
      if arguments.presentation == .standing {
        camera.target = SIMD3<Float>(0.015, 0, -0.055)
        camera.distance = 0.55 * (1 + 0.004 * cos(orbit))
        camera.yaw = 0.36 + 0.012 * sin(orbit)
        camera.pitch = 0.075 + 0.006 * cos(orbit)
      } else {
        camera.target = SIMD3<Float>(-0.018, 0, 0.020)
        camera.distance = 1.05 * (1 + 0.010 * cos(orbit))
        camera.yaw = -1.06 + 0.024 * sin(orbit)
        camera.pitch = 0.18 + 0.012 * cos(orbit)
      }
      let rendered = try renderer.render(
        phase: phase,
        camera: camera,
        width: arguments.width,
        height: arguments.height
      )
      let png = try ReadmeShowcaseCapture.pngData(
        texture: rendered.displayTexture,
        width: arguments.width,
        height: arguments.height
      ) { graphics in
        drawOverlay(
          graphics,
          width: arguments.width,
          height: arguments.height,
          profile: profile,
          phase: phase,
          presentation: arguments.presentation,
          sourceDescription: arguments.presentation == .standing
            ? "Estimated grounded pose / qualitative public-video anatomy reference"
            : motion.sourceDescription(phase: phase)
        )
      }
      let output = arguments.outputDirectory.appendingPathComponent(
        String(format: "frame-%03d.png", frameIndex)
      )
      try png.write(to: output, options: .atomic)
      if arguments.aovAuditURL != nil {
        aovAudits.append(rendered.audit(frameIndex: frameIndex))
      }
      print(
        "captured estimated American crow \(arguments.presentation.rawValue) "
          + "\(frameIndex + 1)/\(arguments.frameCount)"
      )
    }
    if let auditURL = arguments.aovAuditURL {
      let report = CrowShowcaseAOVAuditReport(frames: aovAudits)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      try FileManager.default.createDirectory(
        at: auditURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try encoder.encode(report).write(to: auditURL, options: .atomic)
    }
  }

  private static func drawOverlay(
    _ graphics: CGContext,
    width: Int,
    height: Int,
    profile: CrowVisualProfile,
    phase: Float,
    presentation: CrowShowcasePresentation,
    sourceDescription: String
  ) {
    graphics.saveGState()
    graphics.textMatrix = .identity
    let scale = CGFloat(height) / 900
    let margin = 42 * scale
    let titleFont = CTFontCreateWithName("AvenirNext-DemiBold" as CFString, 25 * scale, nil)
    let detailFont = CTFontCreateWithName("AvenirNext-Medium" as CFString, 12.5 * scale, nil)
    let labelFont = CTFontCreateWithName("AvenirNext-DemiBold" as CFString, 10.5 * scale, nil)
    let white = CGColor(red: 0.91, green: 0.95, blue: 1, alpha: 0.94)
    let cool = CGColor(red: 0.49, green: 0.73, blue: 0.94, alpha: 0.92)
    let muted = CGColor(red: 0.67, green: 0.74, blue: 0.80, alpha: 0.84)
    let warning = CGColor(red: 0.96, green: 0.63, blue: 0.26, alpha: 0.96)

    drawText(
      "AMERICAN CROW",
      at: CGPoint(x: margin, y: CGFloat(height) - 62 * scale),
      font: titleFont,
      color: white,
      graphics: graphics,
      tracking: 1.4 * scale
    )
    drawText(
      "CORVUS BRACHYRHYNCHOS  /  ESTIMATED HYBRID V1",
      at: CGPoint(x: margin, y: CGFloat(height) - 84 * scale),
      font: labelFont,
      color: warning,
      graphics: graphics,
      tracking: 0.9 * scale
    )
    let selected = profile.selectedCrowEstimate
    let dimensions =
      presentation == .standing
      ? String(
        format: "%.2f m length   %.0f g selected mass   %.0f mm tarsus   QUIET STANCE",
        selected.totalLengthMeters,
        selected.bodyMassKilograms * 1000,
        selected.tarsusLengthMeters * 1000
      )
      : String(
        format: "%.2f m wingspan   %.2f m length   %.0f g selected mass   %.1f Hz display",
        selected.wingspanMeters,
        selected.totalLengthMeters,
        selected.bodyMassKilograms * 1000,
        selected.presentationWingbeatFrequencyHertz
      )
    drawText(
      dimensions,
      at: CGPoint(x: margin, y: 50 * scale),
      font: detailFont,
      color: cool,
      graphics: graphics
    )
    drawText(
      sourceDescription,
      at: CGPoint(x: margin, y: 31 * scale),
      font: labelFont,
      color: muted,
      graphics: graphics
    )
    drawText(
      String(format: "PHASE %03.0f%%", phase * 100),
      at: CGPoint(x: CGFloat(width) - 136 * scale, y: 37 * scale),
      font: labelFont,
      color: muted,
      graphics: graphics,
      tracking: 0.8 * scale
    )
    graphics.restoreGState()
  }

  private static func drawText(
    _ text: String,
    at position: CGPoint,
    font: CTFont,
    color: CGColor,
    graphics: CGContext,
    tracking: CGFloat = 0
  ) {
    let line = CTLineCreateWithAttributedString(
      NSAttributedString(
        string: text,
        attributes: [
          NSAttributedString.Key(kCTFontAttributeName as String): font,
          NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
          NSAttributedString.Key(kCTKernAttributeName as String): tracking,
        ]
      )
    )
    graphics.textPosition = position
    CTLineDraw(line, graphics)
  }

  private static func sha256(_ data: Data) -> String {
    SHA256.hash(data: data)
      .map { String(format: "%02x", $0) }
      .joined()
  }
}

private protocol CrowShowcaseMotion: MeasuredDoveMotion {
  func sourceDescription(phase: Float) -> String
}

extension MeasuredDovePresentationLoop: CrowShowcaseMotion {
  func sourceDescription(phase: Float) -> String {
    sourceFrameCoordinate(phase: phase).map {
      "Deetjen dove deformation scaffold / source frame \(String(format: "%.1f", $0))"
    } ?? "Deetjen dove deformation scaffold / Hermite presentation closure"
  }
}

private struct EstimatedCrowSurfaceMotion: CrowShowcaseMotion {
  let dataset: MeasuredBirdSurfaceSequence

  func point(phase: Float, vertexIndex: Int) -> DoveLoopPoint {
    let time = wrappedPhase(phase) * dataset.frameTimesSeconds.last!
    let state = dataset.state(timeSeconds: time, vertexIndex: vertexIndex)
    return DoveLoopPoint(
      position: state.positionMeters,
      velocity: state.velocityMetersPerSecond
    )
  }

  func phase(offsetBy seconds: Float, from phase: Float) -> Float {
    wrappedPhase(phase + seconds / dataset.frameTimesSeconds.last!)
  }

  func sourceDescription(phase: Float) -> String {
    let coordinate = wrappedPhase(phase) * Float(dataset.frameCount - 1)
    return "Estimated-hybrid solver surface / frame \(String(format: "%.1f", coordinate))"
  }

  private func wrappedPhase(_ phase: Float) -> Float {
    let remainder = phase.truncatingRemainder(dividingBy: 1)
    return remainder >= 0 ? remainder : remainder + 1
  }
}

private struct CrowSurfaceGenerationAudit: Decodable {
  let manifestSHA256: String
  let crowProfileSHA256: String
  let checks: [String: Bool]
}

private struct CrowStandingReference: Decodable {
  struct PoseParameters: Decodable {
    let footSeparationMeters: Float
    let supportHeightRelativeToBodyCenterMeters: Float
    let maximumBodySwayMeters: Float
    let maximumAnkleTravelMeters: Float
    let forwardToeCountPerFoot: Int
    let rearToeCountPerFoot: Int
  }

  let schemaVersion: Int
  let referenceIdentifier: String
  let referenceURL: String
  let referencePostIdentifier: String
  let evidenceClass: String
  let redistributionPolicy: String
  let qualitativeObservations: [String]
  let exclusions: [String]
  let poseParameters: PoseParameters

  func validate() throws {
    guard schemaVersion == 1,
      referenceIdentifier == "american-crow-standing-qualitative-v1",
      referenceURL.hasPrefix("https://x.com/"),
      referencePostIdentifier == "2088717365177672110",
      evidenceClass == "single-view-qualitative-appearance-reference",
      redistributionPolicy.contains("no image or video bytes"),
      qualitativeObservations.count >= 5,
      exclusions.count >= 5,
      abs(
        poseParameters.footSeparationMeters
          - 2 * CrowStandingPose.footHalfSeparationMeters
      ) < 1e-7,
      abs(
        poseParameters.supportHeightRelativeToBodyCenterMeters
          - CrowStandingPose.supportHeightRelativeToBodyCenter
      ) < 1e-7,
      poseParameters.maximumBodySwayMeters <= 0.003,
      poseParameters.maximumAnkleTravelMeters <= 0.0015,
      poseParameters.forwardToeCountPerFoot == 3,
      poseParameters.rearToeCountPerFoot == 1
    else {
      throw CrowShowcaseCapture.CaptureError.invalidProfile(
        "standing crow reference contract is invalid"
      )
    }
  }
}

private struct CrowVisualProfile: Decodable {
  struct DoveScaffold: Decodable {
    let datasetIdentifier: String
    let manifestSHA256: String
  }

  struct SelectedEstimate: Decodable {
    let bodyMassKilograms: Float
    let totalLengthMeters: Float
    let wingspanMeters: Float
    let foldedWingChordMeters: Float
    let tailLengthMeters: Float
    let billLengthMeters: Float
    let tarsusLengthMeters: Float
    let presentationWingbeatFrequencyHertz: Float
  }

  struct VisualTransform: Decodable {
    let bodyScaleXYZ: [Float]
    let wingScaleXYZ: [Float]
    let tailScaleXYZ: [Float]
    let headRadiusXYZMeters: [Float]
    let billLengthMeters: Float
    let primaryFeatherCountPerWing: Int
    let secondaryFeatherCountPerWing: Int
    let tailFeatherCount: Int
    let contourFeatherRows: Int
    let plumageBaseLinearRGB: [Float]
    let plumageCoolSheenLinearRGB: [Float]
    let plumageVioletSheenLinearRGB: [Float]
  }

  struct SimulationSurface: Decodable {
    let datasetIdentifier: String
    let manifestPath: String
    let generationAuditPath: String
  }

  let schemaVersion: Int
  let modelIdentifier: String
  let taxon: String
  let evidenceClass: String
  let excludedClaims: [String]
  let doveScaffold: DoveScaffold
  let selectedCrowEstimate: SelectedEstimate
  let visualTransform: VisualTransform
  let simulationSurface: SimulationSurface
  let antiFabricationRule: String

  func validate() throws {
    guard schemaVersion == 1,
      modelIdentifier == "american-crow-hybrid-visual-v1",
      taxon == "Corvus brachyrhynchos",
      evidenceClass == "estimated-hybrid-visual-model",
      excludedClaims.count >= 5,
      !antiFabricationRule.isEmpty,
      doveScaffold.manifestSHA256.count == 64,
      simulationSurface.datasetIdentifier
        == "american-crow-estimated-hybrid-complete-surface-v1",
      !simulationSurface.manifestPath.isEmpty,
      !simulationSurface.generationAuditPath.isEmpty
    else {
      throw CrowShowcaseCapture.CaptureError.invalidProfile(
        "crow profile identity or evidence boundary is invalid"
      )
    }
    let dimensions = [
      selectedCrowEstimate.bodyMassKilograms,
      selectedCrowEstimate.totalLengthMeters,
      selectedCrowEstimate.wingspanMeters,
      selectedCrowEstimate.foldedWingChordMeters,
      selectedCrowEstimate.tailLengthMeters,
      selectedCrowEstimate.billLengthMeters,
      selectedCrowEstimate.tarsusLengthMeters,
      selectedCrowEstimate.presentationWingbeatFrequencyHertz,
      visualTransform.billLengthMeters,
    ]
    guard dimensions.allSatisfy({ $0.isFinite && $0 > 0 }),
      visualTransform.bodyScaleXYZ.count == 3,
      visualTransform.wingScaleXYZ.count == 3,
      visualTransform.tailScaleXYZ.count == 3,
      visualTransform.headRadiusXYZMeters.count == 3,
      visualTransform.plumageBaseLinearRGB.count == 3,
      visualTransform.plumageCoolSheenLinearRGB.count == 3,
      visualTransform.plumageVioletSheenLinearRGB.count == 3,
      visualTransform.primaryFeatherCountPerWing >= 7,
      visualTransform.secondaryFeatherCountPerWing >= 7,
      visualTransform.tailFeatherCount >= 10
    else {
      throw CrowShowcaseCapture.CaptureError.invalidProfile(
        "crow profile dimensions or feather counts are invalid"
      )
    }
  }
}

private final class CrowShowcaseRenderer {
  private let backend: VisualizationBackend
  private let meshBuilder: CrowMeshBuilder
  private let surfaceAOVPipeline: MTLRenderPipelineState
  private let backgroundAOVPipeline: MTLRenderPipelineState
  private let featherAOVPipeline: MTLRenderPipelineState?
  private let surfaceIdentityPipeline: MTLRenderPipelineState
  private let featherIdentityPipeline: MTLRenderPipelineState?
  private let toneMapPipeline: MTLRenderPipelineState
  private let depthState: MTLDepthStencilState
  private let sampleCount: Int
  private let featherRootDeformer: (any CrowFeatherRootDeforming)?
  private let featherGeometryDeformer: CrowFeatherGeometryDeformer?
  private let featherRenderOffset: SIMD3<Float>
  private var previousPhase: Float?
  private var previousCamera: CameraState?

  init(
    device: MTLDevice,
    dataset: MeasuredBirdSurfaceSequence,
    profile: CrowVisualProfile,
    motion: any CrowShowcaseMotion,
    realityAsset: BirdRealityAsset?,
    presentation: CrowShowcasePresentation
  ) throws {
    let createdBackend = try VisualizationBackend(device: device)
    backend = createdBackend
    let createdMeshBuilder = CrowMeshBuilder(
      dataset: dataset,
      profile: profile,
      motion: motion,
      realityAsset: realityAsset,
      presentation: presentation
    )
    meshBuilder = createdMeshBuilder
    if let realityAsset {
      switch presentation {
      case .wingbeat:
        featherRootDeformer = try CrowFeatherRootDeformer(
          backend: createdBackend,
          dataset: dataset,
          asset: realityAsset
        )
      case .standing:
        featherRootDeformer = try CrowStandingFeatherRootDeformer(
          backend: createdBackend,
          asset: realityAsset,
          referenceBodyCenter: createdMeshBuilder.referenceSurfaceBodyCenter
        )
      }
    } else {
      featherRootDeformer = nil
    }
    featherGeometryDeformer = try realityAsset.map {
      try CrowFeatherGeometryDeformer(
        backend: createdBackend,
        featherCount: $0.feathers.count
      )
    }
    featherRenderOffset = createdMeshBuilder.featherRenderOffset
    let createdSampleCount = device.supportsTextureSampleCount(4) ? 4 : 1
    sampleCount = createdSampleCount
    let aovFormats: [MTLPixelFormat] = [
      .rgba16Float,
      .rgba16Float,
      .rgba16Float,
      .rg16Float,
      .r32Float,
    ]
    surfaceAOVPipeline = try backend.render(
      vertex: "crowSurfaceAOVVertex",
      fragment: "showcaseCrowAOVFragment",
      colorFormats: aovFormats,
      sampleCount: createdSampleCount
    )
    featherAOVPipeline = try realityAsset.map { _ in
      try createdBackend.render(
        vertex: "crowFeatherAOVVertex",
        fragment: "showcaseCrowAOVFragment",
        colorFormats: aovFormats,
        sampleCount: createdSampleCount
      )
    }
    backgroundAOVPipeline = try backend.render(
      vertex: "showcaseBackgroundVertex",
      fragment: "showcaseCrowBackgroundAOVFragment",
      colorFormats: aovFormats,
      sampleCount: createdSampleCount
    )
    surfaceIdentityPipeline = try backend.render(
      vertex: "crowSurfaceAOVVertex",
      fragment: "showcaseCrowIdentityFragment",
      colorFormat: .rgba32Uint
    )
    featherIdentityPipeline = try realityAsset.map { _ in
      try createdBackend.render(
        vertex: "crowFeatherAOVVertex",
        fragment: "showcaseCrowIdentityFragment",
        colorFormat: .rgba32Uint
      )
    }
    toneMapPipeline = try backend.render(
      vertex: "showcasePostVertex",
      fragment: "showcaseCrowToneMapFragment",
      colorFormats: [.bgra8Unorm_srgb, .rgba16Float],
      depthFormat: .invalid
    )
    let depth = MTLDepthStencilDescriptor()
    depth.depthCompareFunction = .less
    depth.isDepthWriteEnabled = true
    guard let state = device.makeDepthStencilState(descriptor: depth) else {
      throw VisualizationError.pipeline("crow depth state")
    }
    depthState = state
  }

  func render(
    phase: Float,
    camera: CameraState,
    width: Int,
    height: Int
  ) throws -> CrowShowcaseFrame {
    let priorPhase = previousPhase ?? phase
    let vertices = meshBuilder.vertices(phase: phase)
    let previousVertices = meshBuilder.vertices(phase: priorPhase)
    guard vertices.count == previousVertices.count else {
      throw VisualizationError.pipeline("crow temporal surface topology")
    }
    let temporalVertices = zip(vertices, previousVertices).enumerated().map {
      index, pair in
      CrowSurfaceTemporalVertexGPU(
        position: pair.0.position,
        previousPosition: pair.1.position,
        normal: pair.0.normal,
        albedoAndMaterial: pair.0.color,
        identity: SIMD4<UInt32>(
          UInt32.max,
          UInt32(index / 3 + 1),
          Self.surfaceMaterialCode(pair.0.color.w),
          0
        )
      )
    }
    let byteCount =
      MemoryLayout<CrowSurfaceTemporalVertexGPU>.stride
      * temporalVertices.count
    let buffer = try backend.buffer(length: byteCount, shared: true)
    temporalVertices.withUnsafeBytes { bytes in
      _ = memcpy(buffer.contents(), bytes.baseAddress!, bytes.count)
    }

    let formats: [MTLPixelFormat] = [
      .rgba16Float,
      .rgba16Float,
      .rgba16Float,
      .rg16Float,
      .r32Float,
    ]
    let bytesPerPixel = [8, 8, 8, 4, 4]
    let resolvedAOVs = try formats.enumerated().map { index, format in
      try makeTexture(
        format: format,
        width: width,
        height: height,
        sampleCount: 1,
        storageMode: .shared,
        usage: [.renderTarget, .shaderRead],
        estimatedBytes: width * height * bytesPerPixel[index]
      )
    }
    let renderAOVs: [MTLTexture]
    if sampleCount == 1 {
      renderAOVs = resolvedAOVs
    } else {
      renderAOVs = try formats.enumerated().map { index, format in
        try makeTexture(
          format: format,
          width: width,
          height: height,
          sampleCount: sampleCount,
          storageMode: .private,
          usage: .renderTarget,
          estimatedBytes: width * height * bytesPerPixel[index] * sampleCount
        )
      }
    }

    let depth = try makeTexture(
      format: .depth32Float,
      width: width,
      height: height,
      sampleCount: sampleCount,
      storageMode: .private,
      usage: .renderTarget,
      estimatedBytes: width * height * 4 * sampleCount
    )
    let identity = try makeTexture(
      format: .rgba32Uint,
      width: width,
      height: height,
      sampleCount: 1,
      storageMode: .shared,
      usage: [.renderTarget, .shaderRead],
      estimatedBytes: width * height * 16
    )
    let identityDepth = try makeTexture(
      format: .depth32Float,
      width: width,
      height: height,
      sampleCount: 1,
      storageMode: .private,
      usage: .renderTarget,
      estimatedBytes: width * height * 4
    )
    let display = try makeTexture(
      format: .bgra8Unorm_srgb,
      width: width,
      height: height,
      sampleCount: 1,
      storageMode: .shared,
      usage: [.renderTarget, .shaderRead],
      estimatedBytes: width * height * 4
    )
    let normalizedNormal = try makeTexture(
      format: .rgba16Float,
      width: width,
      height: height,
      sampleCount: 1,
      storageMode: .shared,
      usage: [.renderTarget, .shaderRead],
      estimatedBytes: width * height * 8
    )
    guard let commandBuffer = backend.queue.makeCommandBuffer() else {
      throw VisualizationError.pipeline("crow command buffer")
    }
    let rootFrame = try featherRootDeformer?.encode(
      currentPhase: phase,
      previousPhase: priorPhase,
      commandBuffer: commandBuffer,
      auditReadback: false
    )
    let featherFrame: CrowFeatherGeometryFrame?
    if let rootFrame, let featherGeometryDeformer {
      featherFrame = try featherGeometryDeformer.encode(
        rootFrame: rootFrame,
        renderOffset: featherRenderOffset,
        commandBuffer: commandBuffer
      )
    } else {
      featherFrame = nil
    }

    let pass = MTLRenderPassDescriptor()
    for index in formats.indices {
      pass.colorAttachments[index].texture = renderAOVs[index]
      pass.colorAttachments[index].loadAction = .clear
      pass.colorAttachments[index].clearColor = MTLClearColorMake(0, 0, 0, 0)
      if sampleCount > 1 {
        pass.colorAttachments[index].resolveTexture = resolvedAOVs[index]
        pass.colorAttachments[index].storeAction = .multisampleResolve
      } else {
        pass.colorAttachments[index].storeAction = .store
      }
    }
    pass.depthAttachment.texture = depth
    pass.depthAttachment.loadAction = .clear
    pass.depthAttachment.storeAction = .dontCare
    pass.depthAttachment.clearDepth = 1
    let currentCamera = camera.uniforms(
      aspect: Float(width) / Float(height),
      ribbonWidth: 0.001
    )
    let priorCamera = (previousCamera ?? camera).uniforms(
      aspect: Float(width) / Float(height),
      ribbonWidth: 0.001
    )
    var cameraUniforms = CrowTemporalCameraUniforms(
      viewProjection: currentCamera.viewProjection,
      previousViewProjection: priorCamera.viewProjection,
      eyeAndWidth: currentCamera.eyeAndWidth,
      viewportAndInverse: SIMD4<Float>(
        Float(width),
        Float(height),
        1 / Float(width),
        1 / Float(height)
      )
    )
    var backgroundOptions = SIMD4<Float>(
      phase,
      Float(width) / Float(height),
      0,
      0
    )
    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
      throw VisualizationError.pipeline("crow AOV render encoder")
    }
    encoder.label = "Estimated American crow HDR and temporal AOVs"
    encoder.setCullMode(.none)
    encoder.setRenderPipelineState(backgroundAOVPipeline)
    encoder.setFragmentBytes(
      &backgroundOptions,
      length: MemoryLayout<SIMD4<Float>>.stride,
      index: 0
    )
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.setDepthStencilState(depthState)
    encoder.setRenderPipelineState(surfaceAOVPipeline)
    encoder.setVertexBuffer(buffer, offset: 0, index: 0)
    encoder.setVertexBytes(
      &cameraUniforms,
      length: MemoryLayout<CrowTemporalCameraUniforms>.stride,
      index: 1
    )
    encoder.setFragmentBytes(
      &cameraUniforms,
      length: MemoryLayout<CrowTemporalCameraUniforms>.stride,
      index: 0
    )
    encoder.drawPrimitives(
      type: .triangle,
      vertexStart: 0,
      vertexCount: temporalVertices.count
    )
    if let featherFrame, let featherAOVPipeline {
      encoder.setRenderPipelineState(featherAOVPipeline)
      encoder.setVertexBuffer(featherFrame.outputBuffer, offset: 0, index: 0)
      encoder.setVertexBytes(
        &cameraUniforms,
        length: MemoryLayout<CrowTemporalCameraUniforms>.stride,
        index: 1
      )
      encoder.setFragmentBytes(
        &cameraUniforms,
        length: MemoryLayout<CrowTemporalCameraUniforms>.stride,
        index: 0
      )
      encoder.drawPrimitives(
        type: .triangle,
        vertexStart: 0,
        vertexCount: featherFrame.vertexCount
      )
    }
    encoder.endEncoding()

    let identityPass = MTLRenderPassDescriptor()
    identityPass.colorAttachments[0].texture = identity
    identityPass.colorAttachments[0].loadAction = .clear
    identityPass.colorAttachments[0].storeAction = .store
    identityPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
    identityPass.depthAttachment.texture = identityDepth
    identityPass.depthAttachment.loadAction = .clear
    identityPass.depthAttachment.storeAction = .dontCare
    identityPass.depthAttachment.clearDepth = 1
    guard
      let identityEncoder = commandBuffer.makeRenderCommandEncoder(
        descriptor: identityPass
      )
    else {
      throw VisualizationError.pipeline("crow identity render encoder")
    }
    identityEncoder.label = "Exact crow identity AOV"
    identityEncoder.setCullMode(.none)
    identityEncoder.setDepthStencilState(depthState)
    identityEncoder.setRenderPipelineState(surfaceIdentityPipeline)
    identityEncoder.setVertexBuffer(buffer, offset: 0, index: 0)
    identityEncoder.setVertexBytes(
      &cameraUniforms,
      length: MemoryLayout<CrowTemporalCameraUniforms>.stride,
      index: 1
    )
    identityEncoder.drawPrimitives(
      type: .triangle,
      vertexStart: 0,
      vertexCount: temporalVertices.count
    )
    if let featherFrame, let featherIdentityPipeline {
      identityEncoder.setRenderPipelineState(featherIdentityPipeline)
      identityEncoder.setVertexBuffer(featherFrame.outputBuffer, offset: 0, index: 0)
      identityEncoder.setVertexBytes(
        &cameraUniforms,
        length: MemoryLayout<CrowTemporalCameraUniforms>.stride,
        index: 1
      )
      identityEncoder.drawPrimitives(
        type: .triangle,
        vertexStart: 0,
        vertexCount: featherFrame.vertexCount
      )
    }
    identityEncoder.endEncoding()

    let toneMapPass = MTLRenderPassDescriptor()
    toneMapPass.colorAttachments[0].texture = display
    toneMapPass.colorAttachments[0].loadAction = .dontCare
    toneMapPass.colorAttachments[0].storeAction = .store
    toneMapPass.colorAttachments[1].texture = normalizedNormal
    toneMapPass.colorAttachments[1].loadAction = .dontCare
    toneMapPass.colorAttachments[1].storeAction = .store
    guard
      let toneMapEncoder = commandBuffer.makeRenderCommandEncoder(
        descriptor: toneMapPass
      )
    else {
      throw VisualizationError.pipeline("crow tone-map encoder")
    }
    toneMapEncoder.label = "Crow linear-HDR display tone map"
    toneMapEncoder.setRenderPipelineState(toneMapPipeline)
    toneMapEncoder.setFragmentTexture(resolvedAOVs[0], index: 0)
    toneMapEncoder.setFragmentTexture(resolvedAOVs[2], index: 1)
    toneMapEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    toneMapEncoder.endEncoding()

    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    guard commandBuffer.status == .completed else {
      throw VisualizationError.shader(
        commandBuffer.error?.localizedDescription ?? "crow render failed"
      )
    }
    previousPhase = phase
    previousCamera = camera
    return CrowShowcaseFrame(
      displayTexture: display,
      hdrColorTexture: resolvedAOVs[0],
      albedoMaterialTexture: resolvedAOVs[1],
      normalCoverageTexture: normalizedNormal,
      motionTexture: resolvedAOVs[3],
      metricDepthTexture: resolvedAOVs[4],
      identityTexture: identity
    )
  }

  private func makeTexture(
    format: MTLPixelFormat,
    width: Int,
    height: Int,
    sampleCount: Int,
    storageMode: MTLStorageMode,
    usage: MTLTextureUsage,
    estimatedBytes: Int
  ) throws -> MTLTexture {
    let descriptor = MTLTextureDescriptor()
    descriptor.textureType = sampleCount > 1 ? .type2DMultisample : .type2D
    descriptor.pixelFormat = format
    descriptor.width = width
    descriptor.height = height
    descriptor.sampleCount = sampleCount
    descriptor.storageMode = storageMode
    descriptor.usage = usage
    guard let texture = backend.device.makeTexture(descriptor: descriptor) else {
      throw VisualizationError.allocation(estimatedBytes)
    }
    return texture
  }

  private static func surfaceMaterialCode(_ material: Float) -> UInt32 {
    if material > 0.90 { return 6 }
    if material > 0.72 { return 5 }
    if material > 0.48 { return 4 }
    if material > 0.24 { return 3 }
    return 2
  }
}

private struct CrowMeshBuilder {
  private let dataset: MeasuredBirdSurfaceSequence
  private let profile: CrowVisualProfile
  private let motion: any CrowShowcaseMotion
  private let surfaceIsEstimatedCrow: Bool
  private let referenceBodyCenter: SIMD3<Float>
  private let vertexPartIdentifiers: [UInt8]
  private let persistentFeathers: [BirdRealityFeather]
  private let presentation: CrowShowcasePresentation

  var referenceSurfaceBodyCenter: SIMD3<Float> { referenceBodyCenter }

  var featherRenderOffset: SIMD3<Float> {
    surfaceIsEstimatedCrow ? -referenceBodyCenter : .zero
  }

  init(
    dataset: MeasuredBirdSurfaceSequence,
    profile: CrowVisualProfile,
    motion: any CrowShowcaseMotion,
    realityAsset: BirdRealityAsset?,
    presentation: CrowShowcasePresentation
  ) {
    self.dataset = dataset
    self.profile = profile
    self.motion = motion
    self.presentation = presentation
    persistentFeathers = realityAsset?.feathers ?? []
    surfaceIsEstimatedCrow =
      dataset.scientificTier == "estimated-hybrid-complete-surface"
    let body = dataset.components.first { $0.partIdentifier == 1 }!
    var center = SIMD3<Float>.zero
    for index in body.vertexOffset..<(body.vertexOffset + body.vertexCount) {
      center += motion.point(phase: 0, vertexIndex: index).position
    }
    referenceBodyCenter = center / Float(body.vertexCount)
    var parts = [UInt8](repeating: 0, count: dataset.vertexCount)
    for component in dataset.components {
      let end = component.vertexOffset + component.vertexCount
      for index in component.vertexOffset..<end {
        parts[index] = component.partIdentifier
      }
    }
    vertexPartIdentifiers = parts
  }

  func vertices(phase: Float) -> [ColoredVertex] {
    let states = (0..<dataset.vertexCount).map {
      transformedPoint(phase: phase, vertexIndex: $0)
    }
    var vertices: [ColoredVertex] = []
    vertices.reserveCapacity(48_000)
    let bodyIndices = componentIndices(partIdentifier: 1)
    let bodyPoints = bodyIndices.map { states[$0] }
    let bodyCenter = presentation == .standing ? SIMD3<Float>.zero : average(bodyPoints)
    let bodyBounds = bounds(bodyPoints)
    if !persistentFeathers.isEmpty && presentation == .wingbeat {
      appendMeasuredScaffold(
        states,
        includedPartIdentifiers: [2, 3, 4],
        to: &vertices
      )
    }
    appendCrowAnatomy(
      bodyCenter: bodyCenter,
      bodyBounds: bodyBounds,
      phase: phase,
      to: &vertices
    )
    if presentation == .wingbeat {
      appendWingFeathers(
        states: states,
        bodyCenter: bodyCenter,
        left: true,
        to: &vertices
      )
      appendWingFeathers(
        states: states,
        bodyCenter: bodyCenter,
        left: false,
        to: &vertices
      )
      appendTailFeathers(
        states: states,
        bodyCenter: bodyCenter,
        to: &vertices
      )
    }
    return vertices
  }

  private func transformedPoint(phase: Float, vertexIndex: Int) -> SIMD3<Float> {
    let point =
      motion.point(phase: phase, vertexIndex: vertexIndex).position
      - referenceBodyCenter
    if surfaceIsEstimatedCrow { return point }
    let transform = profile.visualTransform
    let rawScale: [Float]
    switch vertexPartIdentifiers[vertexIndex] {
    case 2, 3: rawScale = transform.wingScaleXYZ
    case 4: rawScale = transform.tailScaleXYZ
    default: rawScale = transform.bodyScaleXYZ
    }
    let scale = SIMD3<Float>(rawScale[0], rawScale[1], rawScale[2])
    return point * scale
  }

  private func appendMeasuredScaffold(
    _ states: [SIMD3<Float>],
    includedPartIdentifiers: Set<UInt8>,
    to vertices: inout [ColoredVertex]
  ) {
    var smoothNormals = [SIMD3<Float>](
      repeating: .zero,
      count: dataset.vertexCount
    )
    for triangleIndex in 0..<dataset.triangleCount {
      let triangle = dataset.triangle(triangleIndex)
      let indices = [Int(triangle.x), Int(triangle.y), Int(triangle.z)]
      let weighted = simd_cross(
        states[indices[1]] - states[indices[0]],
        states[indices[2]] - states[indices[0]]
      )
      for index in indices { smoothNormals[index] += weighted }
    }
    for triangleIndex in 0..<dataset.triangleCount {
      let part = dataset.trianglePartIdentifiers[triangleIndex]
      guard includedPartIdentifiers.contains(part) else { continue }
      let triangle = dataset.triangle(triangleIndex)
      let indices = [Int(triangle.x), Int(triangle.y), Int(triangle.z)]
      let points = indices.map { states[$0] }
      let color: SIMD4<Float>
      switch part {
      case 2:
        color = SIMD4<Float>(0.008, 0.011, 0.018, 0.12)
      case 3:
        color = SIMD4<Float>(0.007, 0.010, 0.017, 0.12)
      case 4:
        color = SIMD4<Float>(0.006, 0.008, 0.014, 0.12)
      default:
        color = SIMD4<Float>(0.008, 0.010, 0.015, 0.12)
      }
      for (corner, point) in points.enumerated() {
        let normal = safeNormalize(
          smoothNormals[indices[corner]],
          fallback: faceNormal(points[0], points[1], points[2])
        )
        vertices.append(vertex(point, normal: normal, color: color))
      }
    }
  }

  private func appendCrowAnatomy(
    bodyCenter: SIMD3<Float>,
    bodyBounds: (minimum: SIMD3<Float>, maximum: SIMD3<Float>),
    phase: Float,
    to vertices: inout [ColoredVertex]
  ) {
    let standingPose =
      presentation == .standing
      ? CrowStandingPose.sample(phase: phase, referenceBodyCenter: bodyCenter)
      : nil
    let posedBodyCenter = standingPose?.bodyCenter ?? bodyCenter
    appendCrowBodyLoft(
      center: posedBodyCenter,
      verticalScale: presentation == .standing ? 1.22 : 1,
      to: &vertices
    )
    let radiiRaw = profile.visualTransform.headRadiusXYZMeters
    let radii =
      SIMD3<Float>(radiiRaw[0], radiiRaw[1], radiiRaw[2])
      * SIMD3<Float>(0.96, 0.92, 0.94)
    let breathing = 1 + 0.012 * sin(2 * Float.pi * phase)
    let headCenter =
      posedBodyCenter + SIMD3<Float>(0.146, 0, 0.032)
      + (standingPose?.headOffset ?? .zero)
    appendEllipsoid(
      center: headCenter,
      radii: radii * SIMD3<Float>(breathing, 1, breathing),
      latitudeCount: 18,
      longitudeCount: 30,
      color: SIMD4<Float>(0.005, 0.007, 0.011, 0.16),
      to: &vertices
    )
    appendBill(center: headCenter, to: &vertices)
    appendEyes(center: headCenter, headRadii: radii, to: &vertices)
    if presentation == .wingbeat {
      appendFacialBristles(center: headCenter, to: &vertices)
      appendHeadContourFeathers(center: headCenter, radii: radii, to: &vertices)
    }
    appendBodyContourFeathers(bodyCenter: posedBodyCenter, to: &vertices)
    if let standingPose {
      appendFoldedWingCoverts(bodyCenter: posedBodyCenter, to: &vertices)
      appendStandingLegsAndFeet(standingPose, to: &vertices)
      appendStandingSupport(height: standingPose.supportHeight, to: &vertices)
    }
    _ = bodyBounds
  }

  private func appendCrowBodyLoft(
    center: SIMD3<Float>,
    verticalScale: Float,
    to vertices: inout [ColoredVertex]
  ) {
    struct Ring {
      let x: Float
      let z: Float
      let radiusY: Float
      let radiusZ: Float
    }
    let rings: [Ring] = [
      Ring(x: -0.180, z: 0.000, radiusY: 0.009, radiusZ: 0.014),
      Ring(x: -0.158, z: -0.002, radiusY: 0.032, radiusZ: 0.041),
      Ring(x: -0.116, z: -0.006, radiusY: 0.052, radiusZ: 0.059),
      Ring(x: -0.060, z: -0.010, radiusY: 0.064, radiusZ: 0.070),
      Ring(x: 0.002, z: -0.008, radiusY: 0.068, radiusZ: 0.073),
      Ring(x: 0.060, z: 0.000, radiusY: 0.063, radiusZ: 0.067),
      Ring(x: 0.108, z: 0.014, radiusY: 0.054, radiusZ: 0.057),
      Ring(x: 0.145, z: 0.028, radiusY: 0.044, radiusZ: 0.047),
      Ring(x: 0.174, z: 0.033, radiusY: 0.033, radiusZ: 0.037),
      Ring(x: 0.194, z: 0.031, radiusY: 0.017, radiusZ: 0.023),
    ]
    let segments = 48
    var positions: [SIMD3<Float>] = []
    positions.reserveCapacity(rings.count * segments)
    for ring in rings {
      for segment in 0..<segments {
        let theta = 2 * Float.pi * Float(segment) / Float(segments)
        positions.append(
          center
            + SIMD3<Float>(
              ring.x,
              cos(theta) * ring.radiusY,
              verticalScale * (ring.z + sin(theta) * ring.radiusZ)
            )
        )
      }
    }
    var normals = [SIMD3<Float>](repeating: .zero, count: positions.count)
    var triangles: [SIMD3<Int>] = []
    for ring in 0..<(rings.count - 1) {
      for segment in 0..<segments {
        let next = (segment + 1) % segments
        let a = ring * segments + segment
        let b = (ring + 1) * segments + segment
        let c = (ring + 1) * segments + next
        let d = ring * segments + next
        triangles.append(SIMD3<Int>(a, b, c))
        triangles.append(SIMD3<Int>(a, c, d))
      }
    }
    for triangle in triangles {
      let weighted = simd_cross(
        positions[triangle.y] - positions[triangle.x],
        positions[triangle.z] - positions[triangle.x]
      )
      normals[triangle.x] += weighted
      normals[triangle.y] += weighted
      normals[triangle.z] += weighted
    }
    let color = SIMD4<Float>(0.006, 0.008, 0.013, 0.10)
    for triangle in triangles {
      for index in [triangle.x, triangle.y, triangle.z] {
        vertices.append(
          vertex(
            positions[index],
            normal: safeNormalize(normals[index], fallback: SIMD3<Float>(0, 0, 1)),
            color: color
          )
        )
      }
    }
  }

  private func appendBodyContourFeathers(
    bodyCenter: SIMD3<Float>,
    to vertices: inout [ColoredVertex]
  ) {
    let color = SIMD4<Float>(0.012, 0.017, 0.029, 0.17)
    for side: Float in [-1, 1] {
      for row in 0..<7 {
        let angle = -0.92 + 1.84 * Float(row) / 6
        for column in 0..<9 {
          let fraction = Float(column) / 8
          let x = bodyCenter.x + 0.092 - 0.230 * fraction
          let longitudinal = (x - bodyCenter.x + 0.020) / 0.155
          let envelope = sqrt(max(0.10, 1 - longitudinal * longitudinal))
          let radiusY = 0.064 * envelope
          let radiusZ = 0.070 * envelope
          let stagger: Float = row.isMultiple(of: 2) ? 0 : 0.007
          let root = SIMD3<Float>(
            x - stagger,
            bodyCenter.y + side * radiusY * cos(angle),
            bodyCenter.z - 0.008 + radiusZ * sin(angle)
          )
          appendFeatherBlade(
            root: root,
            tip: root + SIMD3<Float>(-0.027 - 0.007 * fraction, 0, -0.004),
            planeNormal: safeNormalize(
              SIMD3<Float>(0, side * cos(angle), sin(angle)),
              fallback: SIMD3<Float>(0, side, 0)
            ),
            rootWidth: 0.0042,
            maximumWidth: 0.0072,
            color: color,
            sections: 6,
            camber: 0.0018,
            to: &vertices
          )
        }
      }
    }
  }

  private func appendHeadContourFeathers(
    center: SIMD3<Float>,
    radii: SIMD3<Float>,
    to vertices: inout [ColoredVertex]
  ) {
    let color = SIMD4<Float>(0.010, 0.014, 0.024, 0.18)
    for side: Float in [-1, 1] {
      for row in 0..<4 {
        let angle = -0.62 + 1.24 * Float(row) / 3
        for column in 0..<5 {
          let fraction = Float(column) / 4
          let root =
            center
            + SIMD3<Float>(
              0.025 - 0.054 * fraction,
              side * radii.y * 0.98 * cos(angle),
              radii.z * 0.78 * sin(angle)
            )
          appendFeatherBlade(
            root: root,
            tip: root + SIMD3<Float>(-0.014 - 0.006 * fraction, 0, -0.0015),
            planeNormal: safeNormalize(
              SIMD3<Float>(0.12, side * cos(angle), sin(angle)),
              fallback: SIMD3<Float>(0, side, 0)
            ),
            rootWidth: 0.0024,
            maximumWidth: 0.0041,
            color: color,
            sections: 5,
            camber: 0.001,
            to: &vertices
          )
        }
      }
    }
  }

  private func appendBill(
    center: SIMD3<Float>,
    to vertices: inout [ColoredVertex]
  ) {
    let length = profile.visualTransform.billLengthMeters
    let base = center + SIMD3<Float>(0.038, 0, -0.001)
    let color = SIMD4<Float>(0.018, 0.021, 0.027, 0.58)
    let stationCount = 9
    let radialCount = 14
    var positions: [SIMD3<Float>] = []
    positions.reserveCapacity(stationCount * radialCount)
    for station in 0..<stationCount {
      let t = Float(station) / Float(stationCount - 1)
      let taper = pow(max(1 - t, 0), 0.72)
      let centerLine =
        base
        + SIMD3<Float>(
          length * t,
          0,
          0.002 * (1 - t) - 0.016 * t * t
        )
      let halfWidth = 0.0135 * taper + 0.0007
      let halfHeight = 0.0110 * taper + 0.0006
      for radial in 0..<radialCount {
        let angle = 2 * Float.pi * Float(radial) / Float(radialCount)
        positions.append(
          centerLine
            + SIMD3<Float>(
              0,
              cos(angle) * halfWidth,
              sin(angle) * halfHeight
            )
        )
      }
    }
    for station in 0..<(stationCount - 1) {
      for radial in 0..<radialCount {
        let next = (radial + 1) % radialCount
        let a = station * radialCount + radial
        let b = (station + 1) * radialCount + radial
        let c = (station + 1) * radialCount + next
        let d = station * radialCount + next
        appendQuad(
          positions[a], positions[b], positions[c], positions[d],
          color: color,
          to: &vertices
        )
      }
    }
    let nostrilColor = SIMD4<Float>(0.002, 0.002, 0.003, 0.68)
    for side: Float in [-1, 1] {
      appendEllipsoid(
        center: base + SIMD3<Float>(0.012, side * 0.0148, 0.0065),
        radii: SIMD3<Float>(0.0055, 0.0013, 0.0026),
        latitudeCount: 6,
        longitudeCount: 10,
        color: nostrilColor,
        to: &vertices
      )
    }
  }

  private func appendEyes(
    center: SIMD3<Float>,
    headRadii: SIMD3<Float>,
    to vertices: inout [ColoredVertex]
  ) {
    for side: Float in [-1, 1] {
      let eyeCenter = center + SIMD3<Float>(0.022, side * headRadii.y * 0.91, 0.011)
      appendEllipsoid(
        center: eyeCenter,
        radii: SIMD3<Float>(0.0048, 0.0022, 0.0048),
        latitudeCount: 12,
        longitudeCount: 18,
        color: SIMD4<Float>(0.004, 0.003, 0.002, 0.82),
        to: &vertices
      )
      appendEllipsoid(
        center: eyeCenter + SIMD3<Float>(0.0012, side * 0.0023, 0.0010),
        radii: SIMD3<Float>(0.0016, 0.0006, 0.0016),
        latitudeCount: 8,
        longitudeCount: 12,
        color: SIMD4<Float>(0.022, 0.010, 0.004, 0.82),
        to: &vertices
      )
    }
  }

  private func appendFacialBristles(
    center: SIMD3<Float>,
    to vertices: inout [ColoredVertex]
  ) {
    let color = SIMD4<Float>(0.003, 0.004, 0.006, 0.12)
    for side: Float in [-1, 1] {
      for index in 0..<6 {
        let fraction = Float(index) / 5
        let root =
          center
          + SIMD3<Float>(
            0.031 + 0.008 * fraction,
            side * (0.014 + 0.016 * fraction),
            0.016 - 0.024 * fraction
          )
        let tip =
          root
          + SIMD3<Float>(
            0.012 + 0.006 * fraction,
            side * 0.004,
            0.002 - 0.004 * fraction
          )
        appendFeatherBlade(
          root: root,
          tip: tip,
          planeNormal: SIMD3<Float>(0, side, 0.1),
          rootWidth: 0.0012,
          maximumWidth: 0.0018,
          color: color,
          sections: 4,
          to: &vertices
        )
      }
    }
  }

  private func appendFoldedWingCoverts(
    bodyCenter: SIMD3<Float>,
    to vertices: inout [ColoredVertex]
  ) {
    for side: Float in [-1, 1] {
      for row in 0..<4 {
        let rowFraction = Float(row) / 3
        for index in 0..<8 {
          let fraction = Float(index) / 7
          let root =
            bodyCenter
            + SIMD3<Float>(
              0.092 - 0.198 * fraction - 0.010 * rowFraction,
              side * (0.056 + 0.002 * rowFraction),
              0.018 - 0.065 * fraction + 0.005 * rowFraction
            )
          let length = 0.036 + 0.018 * fraction + 0.005 * rowFraction
          appendFeatherBlade(
            root: root,
            tip: root + SIMD3<Float>(-length, -side * 0.002, -0.010),
            planeNormal: SIMD3<Float>(0.04, side, 0.10),
            rootWidth: 0.0055,
            maximumWidth: 0.0095 + 0.002 * fraction,
            color: SIMD4<Float>(0.011, 0.016, 0.027, 0.18),
            sections: 6,
            camber: 0.002,
            to: &vertices
          )
        }
      }
    }
  }

  private func appendStandingLegsAndFeet(
    _ pose: CrowStandingPoseSample,
    to vertices: inout [ColoredVertex]
  ) {
    let featheredLeg = SIMD4<Float>(0.010, 0.014, 0.022, 0.16)
    let keratin = SIMD4<Float>(0.048, 0.053, 0.061, 0.58)
    let claw = SIMD4<Float>(0.010, 0.012, 0.016, 0.64)
    for foot in [pose.leftFoot, pose.rightFoot] {
      appendTaperedTube(
        from: foot.hip,
        to: foot.hock,
        startRadius: 0.012,
        endRadius: 0.0065,
        color: featheredLeg,
        radialSegments: 12,
        to: &vertices
      )
      appendTaperedTube(
        from: foot.hock,
        to: foot.ankle,
        startRadius: 0.0042,
        endRadius: 0.0033,
        color: keratin,
        radialSegments: 10,
        to: &vertices
      )
      for ring in 1...6 {
        let fraction = Float(ring) / 7
        let center = foot.hock + (foot.ankle - foot.hock) * fraction
        appendTaperedTube(
          from: center - safeNormalize(
            foot.ankle - foot.hock,
            fallback: SIMD3<Float>(0, 0, -1)
          ) * 0.0008,
          to: center + safeNormalize(
            foot.ankle - foot.hock,
            fallback: SIMD3<Float>(0, 0, -1)
          ) * 0.0008,
          startRadius: 0.0040,
          endRadius: 0.0040,
          color: SIMD4<Float>(0.050, 0.054, 0.061, 0.60),
          radialSegments: 10,
          to: &vertices
        )
      }
      for digit in 0..<4 {
        let joint = foot.digitJoints[digit]
        let tip = foot.digitTips[digit]
        appendTaperedTube(
          from: foot.ankle,
          to: joint,
          startRadius: 0.0030,
          endRadius: 0.0025,
          color: keratin,
          radialSegments: 8,
          to: &vertices
        )
        appendTaperedTube(
          from: joint,
          to: tip,
          startRadius: 0.0025,
          endRadius: 0.0016,
          color: keratin,
          radialSegments: 8,
          to: &vertices
        )
        let direction = safeNormalize(tip - joint, fallback: SIMD3<Float>(1, 0, 0))
        let clawTip = tip + direction * 0.005 + SIMD3<Float>(0, 0, -0.0022)
        appendTaperedTube(
          from: tip,
          to: clawTip,
          startRadius: 0.0014,
          endRadius: 0.00025,
          color: claw,
          radialSegments: 7,
          to: &vertices
        )
      }
    }
  }

  private func appendStandingSupport(
    height: Float,
    to vertices: inout [ColoredVertex]
  ) {
    let x0: Float = -0.065
    let x1: Float = 0.070
    let y0: Float = -0.215
    let y1: Float = 0.215
    let z0 = height - 0.018
    let z1 = height
    let color = SIMD4<Float>(0.055, 0.061, 0.070, 0.94)
    appendQuad(
      SIMD3<Float>(x0, y0, z1), SIMD3<Float>(x1, y0, z1),
      SIMD3<Float>(x1, y1, z1), SIMD3<Float>(x0, y1, z1),
      color: color, to: &vertices
    )
    appendQuad(
      SIMD3<Float>(x1, y0, z0), SIMD3<Float>(x0, y0, z0),
      SIMD3<Float>(x0, y1, z0), SIMD3<Float>(x1, y1, z0),
      color: color, to: &vertices
    )
    for face in [
      (
        SIMD3<Float>(x0, y0, z0), SIMD3<Float>(x1, y0, z0),
        SIMD3<Float>(x1, y0, z1), SIMD3<Float>(x0, y0, z1)
      ),
      (
        SIMD3<Float>(x1, y1, z0), SIMD3<Float>(x0, y1, z0),
        SIMD3<Float>(x0, y1, z1), SIMD3<Float>(x1, y1, z1)
      ),
      (
        SIMD3<Float>(x0, y1, z0), SIMD3<Float>(x0, y0, z0),
        SIMD3<Float>(x0, y0, z1), SIMD3<Float>(x0, y1, z1)
      ),
      (
        SIMD3<Float>(x1, y0, z0), SIMD3<Float>(x1, y1, z0),
        SIMD3<Float>(x1, y1, z1), SIMD3<Float>(x1, y0, z1)
      ),
    ] {
      appendQuad(face.0, face.1, face.2, face.3, color: color, to: &vertices)
    }
  }

  private func appendTaperedTube(
    from start: SIMD3<Float>,
    to end: SIMD3<Float>,
    startRadius: Float,
    endRadius: Float,
    color: SIMD4<Float>,
    radialSegments: Int,
    to vertices: inout [ColoredVertex]
  ) {
    let axis = safeNormalize(end - start, fallback: SIMD3<Float>(0, 0, 1))
    let helper: SIMD3<Float> =
      abs(axis.z) < 0.82
      ? SIMD3<Float>(0, 0, 1)
      : SIMD3<Float>(0, 1, 0)
    let first = safeNormalize(simd_cross(axis, helper), fallback: SIMD3<Float>(1, 0, 0))
    let second = safeNormalize(simd_cross(axis, first), fallback: SIMD3<Float>(0, 1, 0))
    for index in 0..<radialSegments {
      let next = (index + 1) % radialSegments
      let angle0 = 2 * Float.pi * Float(index) / Float(radialSegments)
      let angle1 = 2 * Float.pi * Float(next) / Float(radialSegments)
      let radial0 = cos(angle0) * first + sin(angle0) * second
      let radial1 = cos(angle1) * first + sin(angle1) * second
      appendQuad(
        start + startRadius * radial0,
        start + startRadius * radial1,
        end + endRadius * radial1,
        end + endRadius * radial0,
        color: color,
        to: &vertices
      )
    }
  }

  private func appendWingFeathers(
    states: [SIMD3<Float>],
    bodyCenter: SIMD3<Float>,
    left: Bool,
    to vertices: inout [ColoredVertex]
  ) {
    let part: UInt8 = left ? 2 : 3
    let points = componentIndices(partIdentifier: part).map { states[$0] }
    guard !points.isEmpty else { return }
    let measuredSpanDirection = symmetrizedWingSpanDirection(
      states: states,
      bodyCenter: bodyCenter,
      left: left
    )
    let spanDirection = safeNormalize(
      0.70 * measuredSpanDirection + 0.48 * SIMD3<Float>(0, left ? 1 : -1, 0),
      fallback: SIMD3<Float>(0, left ? 1 : -1, 0)
    )
    let root = bodyCenter + SIMD3<Float>(0.015, left ? 0.067 : -0.067, 0.038)
    let span = spanDirection * 0.420
    let forward = SIMD3<Float>(1, 0, 0)
    let planeNormal = safeNormalize(
      simd_cross(forward, spanDirection),
      fallback: SIMD3<Float>(0, 0, 1)
    )
    if persistentFeathers.isEmpty {
      let assetPrimaries = persistentFeathers.filter {
        $0.featherClass == .primary
          && $0.side == (left ? .left : .right)
      }
      let primaryCount =
        assetPrimaries.isEmpty
        ? profile.visualTransform.primaryFeatherCountPerWing
        : assetPrimaries.count
      for index in 0..<primaryCount {
        let f = Float(index) / Float(max(primaryCount - 1, 1))
        let featherRoot =
          root + span * (0.44 + 0.027 * Float(index))
          - forward * (0.020 + 0.010 * (1 - f))
        let proceduralTip =
          root + span * (0.72 + 0.33 * f)
          - forward * (0.145 - 0.112 * f)
          + planeNormal * (0.008 * sin(Float.pi * f))
        let assetFeather = assetPrimaries.isEmpty ? nil : assetPrimaries[index]
        let featherTip =
          assetFeather.map {
            featherRoot + safeNormalize(
              proceduralTip - featherRoot,
              fallback: spanDirection
            ) * $0.lengthMeters
          } ?? proceduralTip
        let shade = 0.008 + 0.004 * f
        appendFeatherBlade(
          root: featherRoot,
          tip: featherTip,
          planeNormal: planeNormal,
          rootWidth: 0.58
            * (assetFeather?.maximumWidthMeters
              ?? (0.019 - 0.004 * f)),
          maximumWidth: assetFeather?.maximumWidthMeters
            ?? (0.019 - 0.004 * f),
          color: SIMD4<Float>(shade, shade * 1.20, shade * 1.48, 0.25),
          sections: 9,
          camber: 0.012 * (0.4 + f),
          to: &vertices
        )
      }
      let assetSecondaries = persistentFeathers.filter {
        $0.featherClass == .secondary
          && $0.side == (left ? .left : .right)
      }
      let secondaryCount =
        assetSecondaries.isEmpty
        ? profile.visualTransform.secondaryFeatherCountPerWing
        : assetSecondaries.count
      for index in 0..<secondaryCount {
        let f = Float(index) / Float(max(secondaryCount - 1, 1))
        let featherRoot = root + span * (0.08 + 0.50 * f) + forward * 0.005
        let proceduralTip =
          root + span * (0.13 + 0.55 * f)
          - forward * (0.105 + 0.014 * sin(Float.pi * f))
        let assetFeather = assetSecondaries.isEmpty ? nil : assetSecondaries[index]
        let featherTip =
          assetFeather.map {
            featherRoot + safeNormalize(
              proceduralTip - featherRoot,
              fallback: spanDirection
            ) * $0.lengthMeters
          } ?? proceduralTip
        appendFeatherBlade(
          root: featherRoot,
          tip: featherTip,
          planeNormal: planeNormal,
          rootWidth: 0.52 * (assetFeather?.maximumWidthMeters ?? 0.020),
          maximumWidth: assetFeather?.maximumWidthMeters ?? 0.020,
          color: SIMD4<Float>(0.008, 0.012, 0.019, 0.22),
          sections: 8,
          camber: 0.008,
          to: &vertices
        )
      }
    }
    for row in 0..<3 {
      for index in 0..<9 {
        let f = Float(index) / 8
        let rowFraction = Float(row) / 2
        let featherRoot =
          root + span * (0.07 + 0.48 * f + 0.018 * rowFraction)
          + forward * (0.030 - 0.012 * rowFraction)
        let featherTip =
          root + span * (0.16 + 0.50 * f)
          - forward * (0.028 + 0.030 * rowFraction)
          + planeNormal * (0.006 * (1 - rowFraction))
        appendFeatherBlade(
          root: featherRoot,
          tip: featherTip,
          planeNormal: planeNormal,
          rootWidth: 0.010,
          maximumWidth: 0.018 - 0.003 * rowFraction,
          color: SIMD4<Float>(
            0.014 + 0.003 * rowFraction,
            0.019 + 0.004 * rowFraction,
            0.032 + 0.006 * rowFraction,
            0.18
          ),
          sections: 7,
          camber: 0.007,
          to: &vertices
        )
      }
    }
  }

  private func symmetrizedWingSpanDirection(
    states: [SIMD3<Float>],
    bodyCenter: SIMD3<Float>,
    left: Bool
  ) -> SIMD3<Float> {
    func spanDirection(partIdentifier: UInt8) -> SIMD3<Float> {
      let wingPoints = componentIndices(partIdentifier: partIdentifier).map { states[$0] }
      let root = wingPoints.min {
        distanceSquared($0, bodyCenter) < distanceSquared($1, bodyCenter)
      }!
      let tip = wingPoints.max {
        distanceSquared($0, root) < distanceSquared($1, root)
      }!
      return safeNormalize(
        tip - root,
        fallback: SIMD3<Float>(0, partIdentifier == 2 ? 1 : -1, 0)
      )
    }
    let leftDirection = spanDirection(partIdentifier: 2)
    let rightDirection = spanDirection(partIdentifier: 3)
    let symmetric = SIMD3<Float>(
      0.5 * (leftDirection.x + rightDirection.x),
      (left ? 1 : -1) * 0.5 * (abs(leftDirection.y) + abs(rightDirection.y)),
      0.5 * (leftDirection.z + rightDirection.z)
    )
    return safeNormalize(
      symmetric,
      fallback: SIMD3<Float>(0, left ? 1 : -1, 0)
    )
  }

  private func appendTailFeathers(
    states: [SIMD3<Float>],
    bodyCenter: SIMD3<Float>,
    to vertices: inout [ColoredVertex]
  ) {
    _ = states
    let root = bodyCenter + SIMD3<Float>(-0.125, 0, 0.005)
    let axis = SIMD3<Float>(-0.190, 0, -0.018)
    let assetRectrices = persistentFeathers.filter {
      $0.featherClass == .tail
    }
    if !assetRectrices.isEmpty { return }
    let count =
      assetRectrices.isEmpty
      ? profile.visualTransform.tailFeatherCount
      : assetRectrices.count
    for index in 0..<count {
      let f = Float(index) / Float(max(count - 1, 1))
      let lateral = (f - 0.5) * 0.145
      let central = 1 - abs(2 * f - 1)
      let assetFeather = assetRectrices.isEmpty ? nil : assetRectrices[index]
      let featherRoot = root + SIMD3<Float>(0, lateral * 0.24, 0.006 * central)
      let proceduralTip =
        root + axis * (0.96 + 0.02 * central)
        + SIMD3<Float>(
          -0.002 * central,
          lateral,
          (f - 0.5) * 0.036 - 0.003 * abs(2 * f - 1)
        )
      let featherTip =
        assetFeather.map {
          featherRoot + safeNormalize(
            proceduralTip - featherRoot,
            fallback: SIMD3<Float>(-1, 0, 0)
          ) * $0.lengthMeters
        } ?? proceduralTip
      appendFeatherBlade(
        root: featherRoot,
        tip: featherTip,
        planeNormal: SIMD3<Float>(0, -1, 0.12),
        rootWidth: 0.57 * (assetFeather?.maximumWidthMeters ?? 0.021),
        maximumWidth: assetFeather?.maximumWidthMeters ?? 0.021,
        color: SIMD4<Float>(0.011, 0.016, 0.029, 0.23),
        sections: 9,
        camber: 0.006,
        to: &vertices
      )
    }
  }

  private func appendFeatherBlade(
    root: SIMD3<Float>,
    tip: SIMD3<Float>,
    planeNormal: SIMD3<Float>,
    rootWidth: Float,
    maximumWidth: Float,
    color: SIMD4<Float>,
    sections: Int,
    camber: Float = 0,
    to vertices: inout [ColoredVertex]
  ) {
    let direction = safeNormalize(tip - root, fallback: SIMD3<Float>(1, 0, 0))
    let normal = safeNormalize(planeNormal, fallback: SIMD3<Float>(0, 0, 1))
    let widthAxis = safeNormalize(
      simd_cross(normal, direction),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    var left: [SIMD3<Float>] = []
    var right: [SIMD3<Float>] = []
    for index in 0...sections {
      let t = Float(index) / Float(sections)
      let bodyEnvelope = 0.32 + 0.68 * pow(max(sin(Float.pi * t), 0), 0.58)
      let tipTaper = 1 - 0.985 * pow(t, 3.2)
      let envelope = bodyEnvelope * tipTaper
      let width = (rootWidth * (1 - t) + maximumWidth * t) * envelope
      let center = root + (tip - root) * t + normal * (camber * sin(Float.pi * t))
      left.append(center - widthAxis * width)
      right.append(center + widthAxis * width)
    }
    for index in 0..<sections {
      appendQuad(
        left[index], right[index], right[index + 1], left[index + 1],
        color: color,
        to: &vertices
      )
    }
  }

  private func appendEllipsoid(
    center: SIMD3<Float>,
    radii: SIMD3<Float>,
    latitudeCount: Int,
    longitudeCount: Int,
    color: SIMD4<Float>,
    to vertices: inout [ColoredVertex]
  ) {
    func sample(_ latitude: Int, _ longitude: Int) -> (SIMD3<Float>, SIMD3<Float>) {
      let v = Float(latitude) / Float(latitudeCount)
      let u = Float(longitude) / Float(longitudeCount)
      let phi = (v - 0.5) * Float.pi
      let theta = u * 2 * Float.pi
      let unit = SIMD3<Float>(
        cos(phi) * cos(theta),
        cos(phi) * sin(theta),
        sin(phi)
      )
      return (
        center + unit * radii,
        safeNormalize(unit / radii, fallback: SIMD3<Float>(0, 0, 1))
      )
    }
    for latitude in 0..<latitudeCount {
      for longitude in 0..<longitudeCount {
        let a = sample(latitude, longitude)
        let b = sample(latitude, longitude + 1)
        let c = sample(latitude + 1, longitude + 1)
        let d = sample(latitude + 1, longitude)
        vertices.append(vertex(a.0, normal: a.1, color: color))
        vertices.append(vertex(b.0, normal: b.1, color: color))
        vertices.append(vertex(c.0, normal: c.1, color: color))
        vertices.append(vertex(a.0, normal: a.1, color: color))
        vertices.append(vertex(c.0, normal: c.1, color: color))
        vertices.append(vertex(d.0, normal: d.1, color: color))
      }
    }
  }

  private func appendTriangle(
    _ a: SIMD3<Float>,
    _ b: SIMD3<Float>,
    _ c: SIMD3<Float>,
    color: SIMD4<Float>,
    to vertices: inout [ColoredVertex]
  ) {
    let normal = faceNormal(a, b, c)
    vertices.append(vertex(a, normal: normal, color: color))
    vertices.append(vertex(b, normal: normal, color: color))
    vertices.append(vertex(c, normal: normal, color: color))
  }

  private func appendQuad(
    _ a: SIMD3<Float>,
    _ b: SIMD3<Float>,
    _ c: SIMD3<Float>,
    _ d: SIMD3<Float>,
    color: SIMD4<Float>,
    to vertices: inout [ColoredVertex]
  ) {
    appendTriangle(a, b, c, color: color, to: &vertices)
    appendTriangle(a, c, d, color: color, to: &vertices)
  }

  private func componentIndices(partIdentifier: UInt8) -> Range<Int> {
    let component = dataset.components.first { $0.partIdentifier == partIdentifier }!
    return component.vertexOffset..<(component.vertexOffset + component.vertexCount)
  }

  private func average(_ points: [SIMD3<Float>]) -> SIMD3<Float> {
    points.reduce(SIMD3<Float>.zero, +) / Float(max(points.count, 1))
  }

  private func bounds(
    _ points: [SIMD3<Float>]
  ) -> (minimum: SIMD3<Float>, maximum: SIMD3<Float>) {
    var minimum = SIMD3<Float>(repeating: .infinity)
    var maximum = SIMD3<Float>(repeating: -.infinity)
    for point in points {
      minimum = simd_min(minimum, point)
      maximum = simd_max(maximum, point)
    }
    return (minimum, maximum)
  }

  private func faceNormal(
    _ a: SIMD3<Float>,
    _ b: SIMD3<Float>,
    _ c: SIMD3<Float>
  ) -> SIMD3<Float> {
    safeNormalize(simd_cross(b - a, c - a), fallback: SIMD3<Float>(0, 0, 1))
  }

  private func safeNormalize(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    simd_length_squared(value) > 1e-14 ? simd_normalize(value) : fallback
  }

  private func distanceSquared(
    _ a: SIMD3<Float>,
    _ b: SIMD3<Float>
  ) -> Float {
    simd_length_squared(a - b)
  }

  private func vertex(
    _ position: SIMD3<Float>,
    normal: SIMD3<Float>,
    color: SIMD4<Float>
  ) -> ColoredVertex {
    ColoredVertex(
      position: SIMD4<Float>(position, 1),
      normal: SIMD4<Float>(normal, 0),
      color: color
    )
  }
}
