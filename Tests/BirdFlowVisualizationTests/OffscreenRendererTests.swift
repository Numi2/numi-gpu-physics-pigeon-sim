import AppKit
import BirdFlowCore
import BirdFlowMetal
import ImageIO
import Metal
import MetalFX
import Testing
import simd

@testable import BirdFlowVisualization

private func imagePixelDimensions(_ data: Data) -> (width: Int, height: Int)? {
  guard
    let source = CGImageSourceCreateWithData(data as CFData, nil),
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
      as? [CFString: Any],
    let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
    let height = properties[kCGImagePropertyPixelHeight] as? NSNumber
  else { return nil }
  return (width.intValue, height.intValue)
}

private func bitmapRGBDifference(
  _ firstData: Data,
  _ secondData: Data
) -> (rmse: Double, maximum: Double)? {
  guard let first = NSBitmapImageRep(data: firstData),
    let second = NSBitmapImageRep(data: secondData),
    first.pixelsWide == second.pixelsWide,
    first.pixelsHigh == second.pixelsHigh
  else { return nil }
  var squaredError: Double = 0
  var maximumError: Double = 0
  var sampleCount = 0
  for y in 0..<first.pixelsHigh {
    for x in 0..<first.pixelsWide {
      guard let firstColor = first.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
        let secondColor = second.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
      else { continue }
      for difference in [
        abs(firstColor.redComponent - secondColor.redComponent),
        abs(firstColor.greenComponent - secondColor.greenComponent),
        abs(firstColor.blueComponent - secondColor.blueComponent),
      ] {
        squaredError += difference * difference
        maximumError = max(maximumError, difference)
        sampleCount += 1
      }
    }
  }
  return (
    sqrt(squaredError / Double(max(sampleCount, 1))),
    maximumError
  )
}

@Test("offscreen pressure and slice render is finite and nonempty")
func offscreenViewerProducesPixels() throws {
  guard MTLCreateSystemDefaultDevice() != nil else { return }
  let bird = BirdParameters(
    bodyRadiiMeters: SIMD3<Float>(0.015, 0.011, 0.012),
    massKilograms: 0.025,
    principalInertiaKilogramMetersSquared: SIMD3<Float>(4e-6, 7e-6, 8e-6),
    wingSpanMeters: 0.025,
    wingRootChordMeters: 0.020,
    wingTipChordMeters: 0.012,
    wingThicknessMeters: 0.008,
    wingSweepMeters: 0.004,
    wingRootOffsetMeters: SIMD3<Float>(0, 0.010, 0.003),
    tailLengthMeters: 0.020,
    tailHalfWidthMeters: 0.014,
    tailThicknessMeters: 0.008,
    wingKinematics: WingKinematics(
      frequencyHz: 3,
      strokeAmplitudeRadians: 0.25,
      pitchMeanRadians: 0,
      pitchAmplitudeRadians: 0.15,
      pitchPhaseRadians: 0.4
    )
  )
  let grid = try GridSize(x: 48, y: 48, z: 48)
  let scaling = try LatticeScaling(
    characteristicLengthMeters: bird.wingRootChordMeters,
    characteristicLengthCells: 8,
    referenceSpeedMetersPerSecond: 1,
    targetReynoldsNumber: 100,
    physicalAirDensity: 1.225,
    latticeReferenceSpeed: 0.03
  )
  let configuration = try SimulationConfiguration(
    grid: grid,
    domainOriginMeters: .zero,
    scaling: scaling,
    farFieldVelocityMetersPerSecond: SIMD3<Float>(-1, 0, 0),
    spongeWidthCells: 4,
    spongeStrength: 0.04
  )
  let live = try LiveSimulation(
    configuration: configuration,
    bird: bird,
    initialBodyState: BirdBodyState(
      positionMeters: configuration.domainSizeMeters * 0.5
    ),
    batchSize: 1
  )
  defer { live.stop() }
  let renderer = try MetalVisualizationRenderer(liveSimulation: live)
  var settings = VisualizationSettings()
  settings.showRibbons = false
  settings.showQCriterion = false
  renderer.settings = settings
  var camera = CameraState()
  camera.target = configuration.domainSizeMeters * 0.5
  camera.distance = 0.18
  camera.yaw = -0.7
  camera.pitch = 0.32
  renderer.camera = camera

  let texture = try renderer.renderOffscreen(width: 256, height: 192)
  var pixels = [UInt8](repeating: 0, count: 256 * 192 * 4)
  texture.getBytes(
    &pixels,
    bytesPerRow: 256 * 4,
    from: MTLRegionMake2D(0, 0, 256, 192),
    mipmapLevel: 0
  )
  let first = Array(pixels[0..<4])
  var changed = 0
  for index in stride(from: 0, to: pixels.count, by: 4) {
    if Array(pixels[index..<(index + 4)]) != first { changed += 1 }
  }
  #expect(changed > 200)

  _ = try live.simulation.advance(
    steps: 40,
    batchSize: 20,
    fieldCapture: .required
  )
  let laterTexture = try renderer.renderOffscreen(width: 256, height: 192)
  var laterPixels = [UInt8](repeating: 0, count: pixels.count)
  laterTexture.getBytes(
    &laterPixels,
    bytesPerRow: 256 * 4,
    from: MTLRegionMake2D(0, 0, 256, 192),
    mipmapLevel: 0
  )
  let changedBetweenFrames = zip(pixels, laterPixels).filter {
    $0.0 != $0.1
  }.count
  let diagnostics = renderer.offscreenDiagnostics()
  #expect(changedBetweenFrames > 200)
  #expect(diagnostics.maximumAbsolutePressure.isFinite)
  #expect(diagnostics.maximumQCriterion.isFinite)
  #expect(!diagnostics.qSurfaceOverflow)
}

@Test("measured dove README capture is artifact-locked and seamless")
func measuredDoveShowcaseCaptureClosesLoop() throws {
  guard MTLCreateSystemDefaultDevice() != nil else { return }
  let testFile = URL(fileURLWithPath: #filePath)
  let root = testFile.deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let output = FileManager.default.temporaryDirectory.appendingPathComponent(
    "birdflow-dove-showcase-\(UUID().uuidString)",
    isDirectory: true
  )
  defer { try? FileManager.default.removeItem(at: output) }
  let arguments = try ReadmeShowcaseCapture.Arguments(commandLine: [
    "birdflow-viewer",
    "--capture-readme-frames", output.path,
    "--capture-width", "320",
    "--capture-height", "180",
    "--capture-frames", "2",
    "--capture-dove-manifest",
    root.appendingPathComponent(
      "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
    ).path,
    "--capture-dove-d32-full-window",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-d32-full-window.json"
    ).path,
    "--capture-dove-d32-full-window-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-d32-full-window-audit.json"
    ).path,
    "--capture-dove-d28-d32-refinement",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-d28-d32-refinement.json"
    ).path,
    "--capture-dove-d28-d32-phase-localization",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-d28-d32-phase-localization.json"
    ).path,
    "--capture-dove-d28-d32-phase-localization-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-d28-d32-phase-localization-audit.json"
    ).path,
    "--capture-dove-targeted-boundary-d28",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-targeted-boundary-d28.json"
    ).path,
    "--capture-dove-targeted-boundary-d32",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-targeted-boundary-d32.json"
    ).path,
    "--capture-dove-targeted-boundary-attribution",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-targeted-boundary.json"
    ).path,
    "--capture-dove-targeted-boundary-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-targeted-boundary-audit.json"
    ).path,
    "--capture-dove-reflected-provenance-preregistration",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-reflected-provenance-preregistration.json"
    ).path,
    "--capture-dove-reflected-provenance-d28",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-reflected-provenance-d28.json"
    ).path,
    "--capture-dove-reflected-provenance-d32",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-reflected-provenance-d32.json"
    ).path,
    "--capture-dove-reflected-provenance-attribution",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-reflected-provenance.json"
    ).path,
    "--capture-dove-reflected-provenance-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-reflected-provenance-audit.json"
    ).path,
    "--capture-dove-link-composition-preregistration",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-link-composition-discriminator-preregistration.json"
    ).path,
    "--capture-dove-link-composition-attribution",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-link-composition-discriminator.json"
    ).path,
    "--capture-dove-link-composition-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-link-composition-discriminator-audit.json"
    ).path,
    "--capture-dove-direction-composition-preregistration",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-direction-composition-canonical-preregistration.json"
    ).path,
    "--capture-dove-direction-composition-canonical",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-direction-composition-canonical.json"
    ).path,
    "--capture-dove-direction-composition-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-direction-composition-canonical-audit.json"
    ).path,
    "--capture-dove-link-geometry-report",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-moving-wall-link-geometry.json"
    ).path,
    "--capture-dove-curved-direction-composition-preregistration",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-curved-direction-composition-canonical-preregistration.json"
    ).path,
    "--capture-dove-curved-direction-composition-canonical",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-curved-direction-composition-canonical.json"
    ).path,
    "--capture-dove-curved-direction-composition-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-curved-direction-composition-canonical-audit.json"
    ).path,
    "--capture-dove-fine-direction-composition-preregistration",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-composition-preregistration.json"
    ).path,
    "--capture-dove-fine-direction-composition-census",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-composition-census.json"
    ).path,
    "--capture-dove-fine-direction-composition-discriminator",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-composition-discriminator.json"
    ).path,
    "--capture-dove-fine-direction-composition-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-composition-audit.json"
    ).path,
    "--capture-dove-fine-direction-phase-v1-preregistration",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-phase-window-preregistration-v1-exact-parity.json"
    ).path,
    "--capture-dove-fine-direction-phase-v1-failure",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-phase-window-census-v1-exact-parity-failure.json"
    ).path,
    "--capture-dove-fine-direction-phase-preregistration",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-phase-window-preregistration.json"
    ).path,
    "--capture-dove-fine-direction-phase-census",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-phase-window-census.json"
    ).path,
    "--capture-dove-fine-direction-phase-discriminator",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-phase-window-discriminator.json"
    ).path,
    "--capture-dove-fine-direction-phase-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-phase-window-audit.json"
    ).path,
  ])
  try ReadmeShowcaseCapture.run(arguments)
  let firstData = try Data(
    contentsOf: output.appendingPathComponent("frame-000.png")
  )
  let lastData = try Data(
    contentsOf: output.appendingPathComponent("frame-001.png")
  )
  guard let image = NSBitmapImageRep(data: firstData) else {
    Issue.record("captured measured-dove frame is not a decodable PNG")
    return
  }
  #expect(image.pixelsWide == 320)
  #expect(image.pixelsHigh == 180)
  #expect(firstData == lastData)

  let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
    manifestURL: root.appendingPathComponent(
      "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
    )
  )
  let loop = MeasuredDovePresentationLoop(dataset: dataset)
  #expect(abs(loop.measuredDurationSeconds - 0.094) < 1e-6)
  #expect(abs(loop.periodSeconds - 0.108) < 1e-6)
  let measuredFrames = (0..<100).compactMap { index in
    loop.sourceFrameCoordinate(phase: Float(index) / 100)
  }
  #expect(measuredFrames.first == 27)
  #expect(measuredFrames.allSatisfy { $0 >= 27 && $0 <= 121 })
  #expect(
    zip(measuredFrames, measuredFrames.dropFirst()).allSatisfy {
      $0.0 <= $0.1
    }
  )
  #expect(loop.sourceFrameCoordinate(phase: 0.95) == nil)
  for vertexIndex in [0, 1_443, 1_740, 2_037] {
    let first = loop.point(phase: 0, vertexIndex: vertexIndex)
    let wrapped = loop.point(phase: 1, vertexIndex: vertexIndex)
    #expect(simd_distance(first.position, wrapped.position) < 1e-7)
    #expect(simd_distance(first.velocity, wrapped.velocity) < 1e-5)
  }
  let displayFrameCount = 72
  let stepRMS = (0..<displayFrameCount).map { frame -> Float in
    let phase = Float(frame) / Float(displayFrameCount)
    let nextPhase = Float(frame + 1) / Float(displayFrameCount)
    var squaredDisplacement: Float = 0
    for vertexIndex in 0..<dataset.vertexCount {
      let point = loop.point(phase: phase, vertexIndex: vertexIndex).position
      let next = loop.point(
        phase: nextPhase,
        vertexIndex: vertexIndex
      ).position
      squaredDisplacement += simd_distance_squared(point, next)
    }
    return sqrt(squaredDisplacement / Float(dataset.vertexCount))
  }
  let medianStep = stepRMS.sorted()[displayFrameCount / 2]
  #expect(stepRMS.last! < 1.5 * medianStep)
  #expect(stepRMS.last! <= stepRMS.dropLast().max()!)
}

@Test("estimated American-crow capture is profile-locked and animated")
func estimatedCrowShowcaseCaptureProducesDistinctFrames() throws {
  guard MTLCreateSystemDefaultDevice() != nil else { return }
  let testFile = URL(fileURLWithPath: #filePath)
  let root = testFile.deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let output = FileManager.default.temporaryDirectory.appendingPathComponent(
    "birdflow-crow-showcase-\(UUID().uuidString)",
    isDirectory: true
  )
  defer { try? FileManager.default.removeItem(at: output) }
  let aovAuditURL = output.appendingPathComponent("aov-audit.json")
  let arguments = try CrowShowcaseCapture.Arguments(commandLine: [
    "birdflow-viewer",
    "--capture-crow-frames", output.path,
    "--capture-crow-aov-audit", aovAuditURL.path,
    "--capture-width", "480",
    "--capture-height", "270",
    "--capture-frames", "3",
    "--capture-crow-surface-manifest",
    root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"
    ).path,
    "--capture-crow-surface-generation-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/american-crow-hybrid-surface-generation-v1.json"
    ).path,
    "--capture-crow-profile",
    root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-visual-v1.json"
    ).path,
    "--capture-crow-reality-asset",
    root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-reality-v1.json"
    ).path,
  ])
  try CrowShowcaseCapture.run(arguments)

  let first = try Data(contentsOf: output.appendingPathComponent("frame-000.png"))
  let middle = try Data(contentsOf: output.appendingPathComponent("frame-001.png"))
  let last = try Data(contentsOf: output.appendingPathComponent("frame-002.png"))
  #expect(first.count > 30_000)
  #expect(middle.count > 30_000)
  #expect(last.count > 30_000)
  #expect(first != middle)
  guard let loopDifference = bitmapRGBDifference(first, last) else {
    Issue.record("crow loop endpoints did not decode as bitmap images")
    return
  }
  #expect(loopDifference.rmse < 0.0001)
  #expect(loopDifference.maximum <= 3.0 / 255.0)
  guard let dimensions = imagePixelDimensions(middle) else {
    Issue.record("crow capture did not encode PNG dimensions")
    return
  }
  #expect(dimensions.width == 480)
  #expect(dimensions.height == 270)
  let audit = try JSONDecoder().decode(
    CrowShowcaseAOVAuditReport.self,
    from: Data(contentsOf: aovAuditURL)
  )
  #expect(audit.frames.allSatisfy { $0.reconstructionMode == "native" })
  #expect(audit.frames.allSatisfy { $0.width == 480 && $0.outputWidth == 480 })
  #expect(audit.frames.allSatisfy { $0.nativeFullFrameDisplayRMSE == nil })
}

@Test("Crow capture accepts bounded simulated camera overrides")
func crowCaptureAcceptsBoundedCameraOverrides() throws {
  let arguments = try CrowShowcaseCapture.Arguments(commandLine: [
    "birdflow-viewer",
    "--capture-crow-frames", "/tmp/crow-camera-override-test",
    "--capture-frames", "2",
    "--capture-crow-camera-yaw", "-2.35",
    "--capture-crow-camera-pitch", "-0.31",
    "--capture-crow-camera-distance", "0.035",
    "--capture-crow-camera-target-x", "0.02",
    "--capture-crow-camera-target-y", "0.055",
    "--capture-crow-camera-target-z", "-0.04",
    "--capture-crow-disable-ventral-barb-curves",
  ])
  #expect(arguments.cameraYawRadians == -2.35)
  #expect(arguments.cameraPitchRadians == -0.31)
  #expect(arguments.cameraDistanceMeters == 0.035)
  #expect(arguments.cameraTarget == SIMD3<Float>(0.02, 0.055, -0.04))
  #expect(!arguments.explicitVentralBarbCurvesEnabled)
  #expect(arguments.ventralCurveEmissionMode == .auto)

  let meshArguments = try CrowShowcaseCapture.Arguments(commandLine: [
    "birdflow-viewer",
    "--capture-crow-frames", "/tmp/crow-mesh-emission-test",
    "--capture-frames", "2",
    "--capture-crow-ventral-curve-emission", "mesh",
  ])
  #expect(meshArguments.ventralCurveEmissionMode == .mesh)
  let autoArguments = try CrowShowcaseCapture.Arguments(commandLine: [
    "birdflow-viewer",
    "--capture-crow-frames", "/tmp/crow-auto-emission-test",
    "--capture-frames", "2",
    "--capture-crow-ventral-curve-emission", "auto",
  ])
  #expect(autoArguments.ventralCurveEmissionMode == .auto)

  #expect(throws: CrowShowcaseCapture.CaptureError.self) {
    _ = try CrowShowcaseCapture.Arguments(commandLine: [
      "birdflow-viewer",
      "--capture-crow-frames", "/tmp/crow-camera-override-test",
      "--capture-frames", "2",
      "--capture-crow-camera-pitch", "1.41",
    ])
  }
  #expect(throws: CrowShowcaseCapture.CaptureError.self) {
    _ = try CrowShowcaseCapture.Arguments(commandLine: [
      "birdflow-viewer",
      "--capture-crow-frames", "/tmp/crow-camera-override-test",
      "--capture-frames", "2",
      "--capture-crow-camera-distance", "0.019",
    ])
  }
  #expect(throws: CrowShowcaseCapture.CaptureError.self) {
    _ = try CrowShowcaseCapture.Arguments(commandLine: [
      "birdflow-viewer",
      "--capture-crow-frames", "/tmp/crow-camera-override-test",
      "--capture-frames", "2",
      "--capture-crow-camera-target-x", "0.02",
    ])
  }
  #expect(throws: CrowShowcaseCapture.CaptureError.self) {
    _ = try CrowShowcaseCapture.Arguments(commandLine: [
      "birdflow-viewer",
      "--capture-crow-frames", "/tmp/crow-camera-override-test",
      "--capture-frames", "2",
      "--capture-crow-ventral-curve-emission", "automatic",
    ])
  }
}

@Test("Crow AOV audit measures feather-class linear luminance")
func crowAOVAuditMeasuresFeatherClassLinearLuminance() {
  let audits = CrowShowcaseFrame.featherClassLuminanceAudits(
    birdMask: [true, true, false, true, true, true],
    featherClassCodes: [5, 5, 0, 5, 6, 6],
    linearLuminances: [1, 3, 0, 5, 2, 6],
    width: 3,
    height: 2
  )
  #expect(audits.map(\.featherClassCode) == [5, 6])
  let body = audits[0]
  #expect(body.pixelCount == 3)
  #expect(abs(body.meanLinearLuminance - 3) < 1e-6)
  #expect(abs(body.standardDeviationLinearLuminance - sqrt(8 / 3)) < 1e-5)
  #expect(body.maximumLinearLuminance == 5)
  #expect(body.maximumLinearLuminanceX == 0)
  #expect(body.maximumLinearLuminanceY == 1)
  #expect(abs(body.meanSameClassNeighborAbsoluteLuminanceDifference - 3) < 1e-6)
  let adjacentClass = audits[1]
  #expect(adjacentClass.pixelCount == 2)
  #expect(adjacentClass.meanLinearLuminance == 4)
  #expect(adjacentClass.standardDeviationLinearLuminance == 2)
  #expect(adjacentClass.maximumLinearLuminance == 6)
  #expect(adjacentClass.maximumLinearLuminanceX == 2)
  #expect(adjacentClass.maximumLinearLuminanceY == 1)
  #expect(adjacentClass.meanSameClassNeighborAbsoluteLuminanceDifference == 4)
}

@Test("estimated crow body loft preserves asymmetric anatomical regions")
func estimatedCrowBodyLoftPreservesAnatomicalRegions() {
  let rings = CrowBodyAnatomy.loftRings
  #expect(rings.count >= 10)
  #expect(zip(rings, rings.dropFirst()).allSatisfy { $0.x < $1.x })
  #expect(rings.first!.halfWidth < 0.012)
  let visibleAnterior = rings[CrowBodyAnatomy.visibleAnteriorRingIndex]
  #expect(visibleAnterior.halfWidth > 0.030 && visibleAnterior.halfWidth < 0.035)
  #expect(rings.last!.halfWidth < 0.015)

  let sternum = rings[CrowBodyAnatomy.sternumRingIndex]
  let shoulder = rings[CrowBodyAnatomy.shoulderRingIndex]
  #expect(sternum.ventralRadius > sternum.dorsalRadius)
  #expect(shoulder.z > sternum.z)
  #expect(shoulder.halfWidth > rings[2].halfWidth)

  let neck = CrowBodyAnatomy.neckRingRange.map { rings[$0] }
  #expect(zip(neck, neck.dropFirst()).allSatisfy { $0.halfWidth > $1.halfWidth })
  #expect(zip(neck, neck.dropFirst()).allSatisfy { $0.dorsalRadius > $1.dorsalRadius })
  let sleeve = CrowBodyAnatomy.cervicalSleeveRingRange.map { rings[$0] }
  #expect(zip(sleeve, sleeve.dropFirst()).allSatisfy { $0.halfWidth > $1.halfWidth })
  #expect(rings.last!.x - rings.first!.x < 0.41)
}

@Test("estimated crow cranium bridges nape, crown, and bill")
func estimatedCrowCraniumBridgesNapeCrownAndBill() {
  let rings = CrowCranialAnatomy.loftRings
  let sampled = CrowCranialAnatomy.sampledLoftRings()
  #expect(rings.count >= 7)
  #expect(
    zip(rings, rings.dropFirst()).allSatisfy {
      $0.axialFraction < $1.axialFraction
    }
  )
  #expect(rings.first!.axialFraction < -1)
  #expect(rings.first!.halfWidthFraction > 0.5)
  #expect(rings[2].dorsalRadiusFraction > 1)
  #expect(rings.last!.halfWidthFraction < 0.3)
  #expect(
    sampled.count
      == (rings.count - 1) * CrowCranialAnatomy.renderSubdivisionsPerInterval + 1
  )
  #expect(sampled.first == rings.first)
  #expect(sampled.last == rings.last)
  #expect(
    zip(sampled, sampled.dropFirst()).allSatisfy {
      $0.axialFraction < $1.axialFraction
        && $1.axialFraction - $0.axialFraction < 0.11
    }
  )
  #expect(
    sampled.allSatisfy {
      $0.halfWidthFraction > 0 && $0.dorsalRadiusFraction > 0
        && $0.ventralRadiusFraction > 0
    }
  )

  let radii = SIMD3<Float>(0.045, 0.033, 0.039)
  let vertices = CrowCranialAnatomy.vertices(
    center: SIMD3<Float>(0.164, 0, 0.052),
    radii: radii,
    breathingScale: 1,
    color: SIMD4<Float>(0.006, 0.008, 0.013, 0.10)
  )
  #expect(vertices.count == (sampled.count - 1) * 48 * 6)
  #expect(
    vertices.allSatisfy {
      let normal = SIMD3<Float>($0.normal.x, $0.normal.y, $0.normal.z)
      return normal.x.isFinite && normal.y.isFinite && normal.z.isFinite
        && abs(simd_length(normal) - 1) < 1e-5
    }
  )
}

@Test("crow feather tessellation follows final-output coverage tiers")
func crowFeatherTessellationFollowsProjectedCoverage() {
  let pixelsPerMeter = CrowFeatherCoverageLOD.projectedPixelsPerMeter(
    viewportHeight: 720,
    cameraDistanceMeters: 0.55
  )
  #expect(pixelsPerMeter > 1_400)
  #expect(pixelsPerMeter < 1_500)

  let silhouette = CrowFeatherCoverageLOD.tessellation(
    lengthMeters: 12 / pixelsPerMeter,
    projectedPixelsPerMeter: pixelsPerMeter,
    baseAxialSections: 6
  )
  let vaneShell = CrowFeatherCoverageLOD.tessellation(
    lengthMeters: 48 / pixelsPerMeter,
    projectedPixelsPerMeter: pixelsPerMeter,
    baseAxialSections: 6
  )
  let barbRibbon = CrowFeatherCoverageLOD.tessellation(
    lengthMeters: 180 / pixelsPerMeter,
    projectedPixelsPerMeter: pixelsPerMeter,
    baseAxialSections: 6
  )
  let microstructureThreshold = CrowFeatherCoverageLOD.tessellation(
    lengthMeters: 520 / pixelsPerMeter,
    projectedPixelsPerMeter: pixelsPerMeter,
    baseAxialSections: 6
  )

  let tiers: [Int] = [
    silhouette.tier, vaneShell.tier, barbRibbon.tier, microstructureThreshold.tier,
  ]
  #expect(tiers == [3, 2, 1, 0])
  #expect(silhouette.widthSections == 1)
  #expect(vaneShell.widthSections == 3)
  #expect(barbRibbon.widthSections == 5)
  #expect(microstructureThreshold.widthSections == 7)
  #expect(silhouette.rachisSections == 0)
  #expect(silhouette.edgeBarbPairs == 0)
  #expect(vaneShell.rachisSections == 4)
  #expect(vaneShell.edgeBarbPairs == 10)
  #expect(barbRibbon.rachisSections == 8)
  #expect(barbRibbon.edgeBarbPairs == 9)
  #expect(barbRibbon.barbPairs == 9)
  #expect(barbRibbon.barbulesPerBarb == 0)
  #expect(microstructureThreshold.rachisSections == 12)
  #expect(microstructureThreshold.edgeBarbPairs == 18)
  #expect(microstructureThreshold.barbPairs == 18)
  #expect(microstructureThreshold.barbulesPerBarb == 3)
  #expect(
    silhouette.axialSections < vaneShell.axialSections
      && vaneShell.axialSections < barbRibbon.axialSections
      && barbRibbon.axialSections < microstructureThreshold.axialSections
  )
}

@Test("estimated standing crow capture keeps the reference private and moves subtly")
func estimatedStandingCrowCaptureProducesLoopClosedFrames() throws {
  guard let device = MTLCreateSystemDefaultDevice(),
    MTLFXTemporalScalerDescriptor.supportsDevice(device)
  else { return }
  let testFile = URL(fileURLWithPath: #filePath)
  let root = testFile.deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let output = FileManager.default.temporaryDirectory.appendingPathComponent(
    "birdflow-standing-crow-\(UUID().uuidString)",
    isDirectory: true
  )
  defer { try? FileManager.default.removeItem(at: output) }
  let aovAuditURL = output.appendingPathComponent("aov-audit.json")
  let arguments = try CrowShowcaseCapture.Arguments(commandLine: [
    "birdflow-viewer",
    "--capture-crow-frames", output.path,
    "--capture-crow-presentation", "standing",
    "--capture-crow-aov-audit", aovAuditURL.path,
    "--capture-crow-temporal-scale", "2",
    "--capture-width", "480",
    "--capture-height", "360",
    "--capture-frames", "3",
    "--capture-crow-surface-manifest",
    root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"
    ).path,
    "--capture-crow-surface-generation-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/american-crow-hybrid-surface-generation-v1.json"
    ).path,
    "--capture-crow-profile",
    root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-visual-v1.json"
    ).path,
    "--capture-crow-reality-asset",
    root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-reality-v1.json"
    ).path,
    "--capture-crow-standing-reference",
    root.appendingPathComponent(
      "ValidationInputs/american-crow-standing-reference-v1.json"
    ).path,
  ])
  try CrowShowcaseCapture.run(arguments)

  let first = try Data(contentsOf: output.appendingPathComponent("frame-000.png"))
  let middle = try Data(contentsOf: output.appendingPathComponent("frame-001.png"))
  let last = try Data(contentsOf: output.appendingPathComponent("frame-002.png"))
  #expect(first.count > 30_000)
  #expect(middle.count > 30_000)
  #expect(last.count > 30_000)
  #expect(first != middle)
  guard let loopDifference = bitmapRGBDifference(first, last) else {
    Issue.record("standing crow loop endpoints did not decode as bitmap images")
    return
  }
  // MetalFX can vary a few sub-code-value samples after a history reset.
  #expect(loopDifference.rmse < 0.0002)
  #expect(loopDifference.maximum <= 3.0 / 255.0)
  guard let dimensions = imagePixelDimensions(middle) else {
    Issue.record("standing crow capture did not encode PNG dimensions")
    return
  }
  #expect(dimensions.width == 480)
  #expect(dimensions.height == 360)

  let audit = try JSONDecoder().decode(
    CrowShowcaseAOVAuditReport.self,
    from: Data(contentsOf: aovAuditURL)
  )
  let expectedGenerationMode =
    try VisualizationBackend(device: device).supportsMeshShaders
    ? "gpu-mesh-threadgroup-8-vertex-indexed"
    : "gpu-procedural-vertex-pulling"
  #expect(audit.schemaVersion == 21)
  #expect(
    audit.frames.allSatisfy {
      $0.bodyVaneMorphologyRecordCount == 3_212
        && $0.bodyVaneMorphologyRecordBytes
          == $0.bodyVaneMorphologyRecordCount
          * MemoryLayout<CrowBodyVaneMorphologyGPU>.stride
        && $0.bodyVaneSelectedMorphologyRecordCount > 0
        && $0.bodyVaneBatchCount > 0
        && $0.bodyVaneSelectedMorphologyRecordBytes
          == $0.bodyVaneSelectedMorphologyRecordCount
          * MemoryLayout<CrowBodyVaneMorphologyGPU>.stride
        && $0.bodyVaneRetainedMorphologyCapacityBytes
          >= $0.bodyVaneSelectedMorphologyRecordBytes
        && $0.bodyVanePoseInputBytes == 1_376
        && $0.bodyVaneRetainedPoseCapacityBytes == 4_128
        && $0.bodyVaneRetainedIndirectDrawBytes
          >= $0.bodyVaneBatchCount
          * MemoryLayout<DrawPrimitivesIndirectArguments>.stride
        && $0.bodyVaneMorphologyBufferAllocationCount == 1
        && $0.bodyVaneRasterVertexInvocationCount > 0
        && $0.bodyVaneVertexGenerationMode
          == "gpu-resident-morphology-pose-instanced-indirect"
    })
  #expect(
    audit.frames.allSatisfy {
      $0.ventralBarbCandidateRecordCount == 0
        && $0.ventralBarbFrustumVisibleRecordCount == 0
        && $0.ventralBarbVisibleRecordCount == 0
        && $0.ventralBarbOcclusionTestedRecordCount == 0
        && $0.ventralBarbOcclusionCulledRecordCount == 0
        && $0.ventralBarbOcclusionDepthBytes == 0
        && $0.ventralBarbOcclusionMode == "inactive"
        && $0.ventralBarbExpandedVertexCount == 0
        && $0.ventralBarbRasterVertexInvocationCount == 0
        && $0.ventralBarbOutputCapacityBytes == 0
        && $0.ventralBarbVertexGenerationMode == expectedGenerationMode
    })
  #expect(audit.formats["hdrColor"] == "rgba16Float")
  #expect(audit.formats["normalCoverage"] == "rgba16Float")
  #expect(audit.formats["deviceDepth"] == "depth32Float")
  #expect(audit.formats["identity"] == "rgba32Uint")
  #expect(audit.frames.count == 3)
  #expect(audit.frames.allSatisfy { $0.width == 240 && $0.height == 180 })
  #expect(audit.frames.allSatisfy { $0.outputWidth == 480 && $0.outputHeight == 360 })
  #expect(audit.frames.allSatisfy { $0.reconstructionMode == "metalfx-temporal" })
  if #available(macOS 14.4, *) {
    #expect(audit.frames.allSatisfy { $0.reactiveMaskEnabled })
  }
  #expect(audit.frames.allSatisfy { $0.renderScaleX == 2 && $0.renderScaleY == 2 })
  #expect(audit.frames.allSatisfy { !$0.exteriorBirdSilhouetteSlotRuns.isEmpty })
  #expect(
    audit.frames.allSatisfy { frame in
      frame.exteriorBirdSilhouetteSlotRuns.allSatisfy {
        ($0.axis == "horizontal" || $0.axis == "vertical")
          && $0.pixelCount > 0
      }
    }
  )
  #expect(audit.frames.allSatisfy { $0.gpuDurationMilliseconds > 0 })
  #expect(
    audit.frames.allSatisfy {
      $0.nativeReferenceGPUDurationMilliseconds.map { $0 > 0 } == true
    }
  )
  #expect(
    audit.frames.allSatisfy { frame in
      frame.nativeReferenceAllocatedRenderTargetBytes.map {
        $0 > frame.allocatedRenderTargetBytes
      } == true
    }
  )
  #expect(audit.frames.allSatisfy { $0.finitePixelCount == 240 * 180 })
  #expect(audit.frames.allSatisfy { $0.aboveOneHDRPixelCount > 0 })
  #expect(audit.frames.allSatisfy { $0.activeIdentityPixelCount > 500 })
  #expect(audit.frames.allSatisfy { $0.fullyCoveredAOVPixelCount > 500 })
  #expect(audit.frames.allSatisfy { $0.visibleFeatherIdentityCount > 0 })
  #expect(audit.frames.allSatisfy { !$0.persistentFeatherIdentities.isEmpty })
  #expect(
    audit.frames.allSatisfy { frame in
      Set(frame.persistentFeatherIdentities.map(\.featherIndex)).count
        == frame.persistentFeatherIdentities.count
        && frame.persistentFeatherIdentities.allSatisfy {
          (1...3).contains($0.featherClass)
            && (0...2).contains($0.sideCode)
            && $0.order < $0.count
            && $0.visiblePixelCount > 0
            && $0.fullyCoveredPixelCount <= $0.visiblePixelCount
        }
    }
  )
  #expect(audit.frames.allSatisfy { $0.visibleFeatherClassPixelCounts.count == 32 })
  #expect(audit.frames.allSatisfy { !$0.featherClassLuminanceAudits.isEmpty })
  #expect(
    audit.frames.allSatisfy { frame in
      frame.featherClassLuminanceAudits.allSatisfy {
        $0.pixelCount > 0
          && $0.meanLinearLuminance.isFinite
          && $0.standardDeviationLinearLuminance.isFinite
          && $0.maximumLinearLuminance.isFinite
          && $0.meanSameClassNeighborAbsoluteLuminanceDifference.isFinite
      }
    }
  )
  #expect(
    audit.frames.allSatisfy {
      $0.visibleFeatherClassPixelCounts.reduce(0, +)
        == $0.activeIdentityPixelCount
    }
  )
  #expect(
    audit.frames.allSatisfy {
      $0.fullyCoveredFeatherClassPixelCounts.count == 32
        && $0.fullyCoveredFeatherClassPixelCounts.reduce(0, +)
          == $0.fullyCoveredActiveIdentityPixelCount
        && $0.fullyCoveredActiveIdentityPixelCount
          <= $0.fullyCoveredAOVPixelCount
    }
  )
  #expect(
    audit.frames.allSatisfy {
      $0.enclosedBirdSilhouetteHolePixelCount
        >= $0.largestEnclosedBirdSilhouetteHolePixelCount
    }
  )
  #expect(audit.frames.allSatisfy { $0.maximumNormalUnitError < 0.002 })
  #expect(audit.frames.allSatisfy { $0.minimumFullyCoveredDepthMeters > 0.1 })
  #expect(audit.frames.allSatisfy { $0.maximumFullyCoveredDepthMeters < 2.0 })
  #expect(audit.frames.allSatisfy { $0.minimumFullyCoveredDeviceDepth > 0 })
  #expect(audit.frames.allSatisfy { $0.maximumFullyCoveredDeviceDepth < 1 })
  #expect(
    audit.frames.allSatisfy {
      $0.supportCentroidYPixels > $0.birdCentroidYPixels + 20
    }
  )
  #expect(audit.frames[0].maximumMotionPixels < 0.01)
  #expect(audit.frames[1].movingFullyCoveredPixelCount > 250)
  #expect(audit.frames[1].maximumMotionPixels > 0.1)
  #expect(audit.frames[1].maximumMotionPixels < 100)
  #expect(audit.frames[0].historyReset)
  #expect(!audit.frames[1].historyReset)
  #expect(audit.frames[2].historyReset)
  #expect(
    audit.frames.allSatisfy {
      $0.nativeFullFrameDisplayRMSE.map { $0 < 0.01 } == true
    }
  )
  #expect(
    audit.frames.allSatisfy {
      $0.nativeForegroundDisplayRMSE.map { $0 < 0.025 } == true
    }
  )
  #expect(
    audit.frames.allSatisfy {
      $0.nativeBirdSilhouetteIntersectionOverUnion.map { $0 > 0.94 } == true
    }
  )
  #expect(
    audit.frames.allSatisfy {
      $0.nativeForegroundGradientEnergyRatio.map { $0 > 0.74 } == true
    }
  )
}
