import Foundation
import Metal
import Testing
import simd

@testable import BirdFlowVisualization

private var crowPlumageOpticsProfileURL: URL {
  URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent(
      "ValidationInputs/american-crow-plumage-optics-estimated-v1.json"
    )
}

@Test("crow plumage optics keeps published constraints separate from estimates")
func crowPlumageOpticsProfilePreservesEvidenceBoundary() throws {
  let profile = try CrowPlumageOpticsProfile.load(
    url: crowPlumageOpticsProfileURL
  )

  #expect(profile.source.sourceTaxa == ["Corvus corax", "Corvus ossifragus"])
  #expect(profile.source.rawSpectraAvailable == false)
  #expect(
    profile.publishedConstraints.glossyCortexThicknessRangeNanometers
      == [110, 180]
  )
  #expect(
    profile.publishedConstraints.keratinComplexRefractiveIndex == [1.56, 0.03]
  )
  #expect(
    profile.publishedConstraints.melaninComplexRefractiveIndex == [2.0, 0.6]
  )
  #expect(
    profile.renderParameters.wavelengthSamplesNanometers
      == [400, 440, 480, 520, 560, 600, 640, 680]
  )
  #expect(profile.renderParameters.thinFilmCoherence == 0.08)
  #expect(profile.visibilitySource.doi == "10.1111/cgf.15235")
  #expect(
    profile.visibilitySource.implementationRevision
      == "9af1a04722f78a7275b62afb492ea8d074499128"
  )
  #expect(profile.renderParameters.barbuleAzimuthDegrees == 45)
  #expect(profile.renderParameters.barbuleRelativeSeparation == 0.55)
  #expect(profile.renderParameters.analyticMaskStrength == 1)
  #expect(
    profile.calibrationStatus == "not calibrated to an American-crow specimen"
  )

  let gpu = profile.gpuParameters
  #expect(gpu.film == SIMD4<Float>(160, 18, 0.08, 0.016))
  #expect(gpu.complexIndices == SIMD4<Float>(1.56, 0.03, 2.0, 0.6))
  #expect(gpu.melanin == SIMD4<Float>(1.32, 0.88, 1.62, 1.84))
  #expect(gpu.cortex == SIMD4<Float>(0.00492, 0.006, 0.92, 1.04))
  #expect(
    simd_length(gpu.visibilityShape - SIMD4<Float>(2.4, 3.2, .pi / 4, .pi / 10))
      < 1e-5
  )
  #expect(gpu.visibilityLayout == SIMD4<Float>(5, 0.55, 0.62, 1))
  #expect(MemoryLayout<CrowPlumageOpticsGPUParameters>.stride == 96)
}

@Test("crow plumage optics rejects invented raw spectral provenance")
func crowPlumageOpticsProfileRejectsInventedRawData() throws {
  let data = try Data(contentsOf: crowPlumageOpticsProfileURL)
  var object = try #require(
    JSONSerialization.jsonObject(with: data) as? [String: Any]
  )
  var source = try #require(object["source"] as? [String: Any])
  source["rawSpectraAvailable"] = true
  object["source"] = source

  let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
    "crow-plumage-optics-\(UUID().uuidString).json"
  )
  defer { try? FileManager.default.removeItem(at: temporaryURL) }
  try JSONSerialization.data(withJSONObject: object).write(to: temporaryURL)

  #expect(throws: CrowPlumageOpticsProfileError.self) {
    _ = try CrowPlumageOpticsProfile.load(url: temporaryURL)
  }
}

@Test("crow film optics matches polarized complex Airy reference cases")
func crowThinFilmOpticsMatchesReferenceCases() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let pipeline = try backend.compute("probeCrowThinFilmOptics")

  // wavelength nm, cosine from the microfacet normal, thickness nm, reserved.
  let inputs: [SIMD4<Float>] = [
    SIMD4<Float>(400, 1.00, 160, 0),
    SIMD4<Float>(520, 1.00, 160, 0),
    SIMD4<Float>(520, 0.75, 160, 0),
    SIMD4<Float>(680, 0.25, 160, 0),
    SIMD4<Float>(400, 0.05, 160, 0),
  ]
  // Independent FP64 evaluation of OpenPBR equations 112-118 using the
  // profile's complex keratin and melanin indices. Components are Rs, Rp, R.
  let expected: [SIMD3<Float>] = [
    SIMD3<Float>(0.03150801, 0.03150801, 0.03150801),
    SIMD3<Float>(0.13996549, 0.13996549, 0.13996549),
    SIMD3<Float>(0.22733259, 0.07402370, 0.15067815),
    SIMD3<Float>(0.39137994, 0.13279829, 0.26208910),
    SIMD3<Float>(0.89969766, 0.62692965, 0.76331365),
  ]
  var complexIndices = SIMD4<Float>(1.56, 0.03, 2.0, 0.6)
  let inputBuffer = try backend.buffer(
    length: MemoryLayout<SIMD4<Float>>.stride * inputs.count,
    shared: true
  )
  _ = inputs.withUnsafeBytes { bytes in
    memcpy(inputBuffer.contents(), bytes.baseAddress!, bytes.count)
  }
  let indexBuffer = try backend.buffer(
    length: MemoryLayout<SIMD4<Float>>.stride,
    shared: true
  )
  _ = withUnsafeBytes(of: &complexIndices) { bytes in
    memcpy(indexBuffer.contents(), bytes.baseAddress!, bytes.count)
  }
  let outputBuffer = try backend.buffer(
    length: MemoryLayout<SIMD4<Float>>.stride * inputs.count,
    shared: true
  )

  guard let commandBuffer = backend.queue.makeCommandBuffer(),
    let encoder = commandBuffer.makeComputeCommandEncoder()
  else {
    Issue.record("unable to allocate crow thin-film probe command")
    return
  }
  encoder.setBuffer(inputBuffer, offset: 0, index: 0)
  encoder.setBuffer(indexBuffer, offset: 0, index: 1)
  encoder.setBuffer(outputBuffer, offset: 0, index: 2)
  backend.dispatch1D(encoder, pipeline: pipeline, count: inputs.count)
  encoder.endEncoding()
  commandBuffer.commit()
  commandBuffer.waitUntilCompleted()
  #expect(commandBuffer.status == .completed)

  let pointer = outputBuffer.contents().bindMemory(
    to: SIMD4<Float>.self,
    capacity: inputs.count
  )
  let actual = Array(UnsafeBufferPointer(start: pointer, count: inputs.count))
  for (measured, reference) in zip(actual, expected) {
    let result = SIMD3<Float>(measured.x, measured.y, measured.z)
    #expect(simd_length(result - reference) < 2e-4)
    #expect(min(result.x, min(result.y, result.z)) >= 0)
    #expect(max(result.x, max(result.y, result.z)) <= 1)
    #expect(abs(measured.z - 0.5 * (measured.x + measured.y)) < 2e-6)
  }
  #expect(abs(actual[0].x - actual[0].y) < 2e-6)
  #expect(abs(actual[1].x - actual[1].y) < 2e-6)
}

@Test("crow analytic feather mask matches the authors' discontinuity rays")
func crowAnalyticFeatherMaskMatchesReferenceCases() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let pipeline = try backend.compute("probeCrowProjectedFeatherVisibility")
  let directions: [SIMD4<Float>] = [
    SIMD4<Float>(0, 1, 0, 0),
    SIMD4<Float>(0.6, 0.8, 0, 0),
    SIMD4<Float>(-0.6, 0.8, 0, 0),
    SIMD4<Float>(0.4, 0.5, 0.76811457, 0),
  ]
  let expected: [SIMD4<Float>] = [
    SIMD4<Float>(0.17375341, 0.33081371, 0.33081371, 0.16461918),
    SIMD4<Float>(0.26576680, 0.51379722, 0.20613001, 0.01430596),
    SIMD4<Float>(0.26576680, 0.20613001, 0.51379722, 0.01430596),
    SIMD4<Float>(0.30135849, 0.38466427, 0.20454295, 0.10943432),
  ]
  let approximateExpected: [SIMD4<Float>] = [
    SIMD4<Float>(0.22922675, 0.30226402, 0.30226402, 0.16624521),
    SIMD4<Float>(0.37979913, 0.36226826, 0.18215278, 0.07577983),
    SIMD4<Float>(0.37979913, 0.18215278, 0.36226826, 0.07577983),
    SIMD4<Float>(0.39165753, 0.39973484, 0.17972022, 0.02888741),
  ]
  var shape = SIMD4<Float>(2.4, 3.2, .pi / 4, .pi / 10)

  func evaluate(
    _ inputDirections: [SIMD4<Float>] = directions,
    separation: Float,
    analyticMaskStrength: Float = 1
  ) throws -> [SIMD4<Float>] {
    var layout = SIMD4<Float>(5, separation, 0.62, analyticMaskStrength)
    let inputBuffer = try backend.buffer(
      length: MemoryLayout<SIMD4<Float>>.stride * inputDirections.count,
      shared: true
    )
    _ = inputDirections.withUnsafeBytes { bytes in
      memcpy(inputBuffer.contents(), bytes.baseAddress!, bytes.count)
    }
    let shapeBuffer = try backend.buffer(
      length: MemoryLayout<SIMD4<Float>>.stride,
      shared: true
    )
    _ = withUnsafeBytes(of: &shape) { bytes in
      memcpy(shapeBuffer.contents(), bytes.baseAddress!, bytes.count)
    }
    let layoutBuffer = try backend.buffer(
      length: MemoryLayout<SIMD4<Float>>.stride,
      shared: true
    )
    _ = withUnsafeBytes(of: &layout) { bytes in
      memcpy(layoutBuffer.contents(), bytes.baseAddress!, bytes.count)
    }
    let outputBuffer = try backend.buffer(
      length: MemoryLayout<SIMD4<Float>>.stride * inputDirections.count,
      shared: true
    )
    guard let commandBuffer = backend.queue.makeCommandBuffer(),
      let encoder = commandBuffer.makeComputeCommandEncoder()
    else {
      Issue.record("unable to allocate crow projected-visibility probe command")
      return []
    }
    encoder.setBuffer(inputBuffer, offset: 0, index: 0)
    encoder.setBuffer(shapeBuffer, offset: 0, index: 1)
    encoder.setBuffer(layoutBuffer, offset: 0, index: 2)
    encoder.setBuffer(outputBuffer, offset: 0, index: 3)
    backend.dispatch1D(encoder, pipeline: pipeline, count: inputDirections.count)
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    #expect(commandBuffer.status == .completed)
    let pointer = outputBuffer.contents().bindMemory(
      to: SIMD4<Float>.self,
      capacity: inputDirections.count
    )
    return Array(UnsafeBufferPointer(start: pointer, count: inputDirections.count))
  }

  let actual = try evaluate(separation: 0.55)
  #expect(actual.count == expected.count)
  for (measured, reference) in zip(actual, expected) {
    #expect(simd_length(measured - reference) < 2e-5)
    #expect(abs(measured.x + measured.y + measured.z + measured.w - 1) < 2e-6)
    #expect(min(measured.x, min(measured.y, min(measured.z, measured.w))) >= 0)
    #expect(max(measured.x, max(measured.y, max(measured.z, measured.w))) <= 1)
  }
  #expect(abs(actual[1].x - actual[2].x) < 2e-6)
  #expect(abs(actual[1].y - actual[2].z) < 2e-6)
  #expect(abs(actual[1].z - actual[2].y) < 2e-6)
  #expect(abs(actual[1].w - actual[2].w) < 2e-6)

  let approximate = try evaluate(separation: 0.55, analyticMaskStrength: 0)
  for (measured, reference) in zip(approximate, approximateExpected) {
    #expect(simd_length(measured - reference) < 2e-5)
  }

  let closed = try evaluate(separation: 0)
  let open = try evaluate(separation: 1.5)
  for (closedWeights, openWeights) in zip(closed, open) {
    #expect(closedWeights.w < 1e-6)
    #expect(openWeights.w > closedWeights.w)
  }

  let denseDirections: [SIMD4<Float>] = (0..<17).flatMap { elevationIndex in
    let elevation = -Float.pi / 2
      + Float.pi * Float(elevationIndex) / 16
    return (0..<64).map { azimuthIndex in
      let azimuth = 2 * Float.pi * Float(azimuthIndex) / 64
      return SIMD4<Float>(
        cos(elevation) * cos(azimuth),
        sin(elevation),
        cos(elevation) * sin(azimuth),
        0
      )
    }
  }
  let dense = try evaluate(denseDirections, separation: 0.55)
  #expect(dense.count == 1_088)
  for weights in dense {
    #expect(weights.x.isFinite && weights.y.isFinite)
    #expect(weights.z.isFinite && weights.w.isFinite)
    #expect(abs(weights.x + weights.y + weights.z + weights.w - 1) < 3e-5)
    #expect(min(weights.x, min(weights.y, min(weights.z, weights.w))) >= 0)
    #expect(max(weights.x, max(weights.y, max(weights.z, weights.w))) <= 1)
  }
}

@Test("crow barbule discontinuity intervals match the authors' ray construction")
func crowBarbuleDiscontinuityIntervalsMatchReferenceCases() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let pipeline = try backend.compute("probeCrowAnalyticBarbuleMask")
  let directions: [SIMD4<Float>] = [
    SIMD4<Float>(0.21850802, 0.95105654, 0, 0),
    SIMD4<Float>(-0.21850802, 0.95105654, 0, 0),
    SIMD4<Float>(0.59907055, 0.76084524, 0, 0),
    SIMD4<Float>(0.24945769, 0.76084524, 0, 0),
    SIMD4<Float>(-0.24945769, 0.76084524, 0, 0),
    SIMD4<Float>(-0.59907055, 0.76084524, 0, 0),
    SIMD4<Float>(-0.12445918, 0.71288872, 0, 0),
    SIMD4<Float>(0.69014466, 0.71288872, 0, 0),
  ]
  let expected: [SIMD4<Float>] = [
    SIMD4<Float>(0.19923735, -1, 1, 0),
    SIMD4<Float>(0.19923735, -1, 1, 0),
    SIMD4<Float>(0, -0.14357781, 1, 0),
    SIMD4<Float>(0.06489849, -1, 1, 0),
    SIMD4<Float>(0.06489849, -1, 1, 0),
    SIMD4<Float>(0, -0.14357781, 1, 0),
    SIMD4<Float>(0.26098415, -1, 1, 0),
    SIMD4<Float>(0, 0.04770923, 1, 0),
  ]
  var shape = SIMD4<Float>(2.4, 3.2, .pi / 4, .pi / 10)
  var layout = SIMD4<Float>(5, 0.55, 0.62, 1)
  let input = try backend.buffer(
    length: MemoryLayout<SIMD4<Float>>.stride * directions.count,
    shared: true
  )
  _ = directions.withUnsafeBytes { bytes in
    memcpy(input.contents(), bytes.baseAddress!, bytes.count)
  }
  let shapeBuffer = try backend.buffer(
    length: MemoryLayout<SIMD4<Float>>.stride,
    shared: true
  )
  _ = withUnsafeBytes(of: &shape) { bytes in
    memcpy(shapeBuffer.contents(), bytes.baseAddress!, bytes.count)
  }
  let layoutBuffer = try backend.buffer(
    length: MemoryLayout<SIMD4<Float>>.stride,
    shared: true
  )
  _ = withUnsafeBytes(of: &layout) { bytes in
    memcpy(layoutBuffer.contents(), bytes.baseAddress!, bytes.count)
  }
  let output = try backend.buffer(
    length: MemoryLayout<SIMD4<Float>>.stride * directions.count,
    shared: true
  )
  let commandBuffer = try #require(backend.queue.makeCommandBuffer())
  let encoder = try #require(commandBuffer.makeComputeCommandEncoder())
  encoder.setBuffer(input, offset: 0, index: 0)
  encoder.setBuffer(shapeBuffer, offset: 0, index: 1)
  encoder.setBuffer(layoutBuffer, offset: 0, index: 2)
  encoder.setBuffer(output, offset: 0, index: 3)
  backend.dispatch1D(encoder, pipeline: pipeline, count: directions.count)
  encoder.endEncoding()
  commandBuffer.commit()
  commandBuffer.waitUntilCompleted()
  #expect(commandBuffer.status == .completed)
  let pointer = output.contents().bindMemory(
    to: SIMD4<Float>.self,
    capacity: directions.count
  )
  let actual = Array(UnsafeBufferPointer(start: pointer, count: directions.count))
  for (measured, reference) in zip(actual, expected) {
    #expect(simd_length(measured - reference) < 2e-5)
  }
}

@Test("crow barb discontinuity intervals match the authors' ray construction")
func crowBarbDiscontinuityIntervalsMatchReferenceCases() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let backend = try VisualizationBackend(device: device)
  let pipeline = try backend.compute("probeCrowAnalyticBarbMaskRates")
  let inputs: [SIMD4<Float>] = [
    SIMD4<Float>(0, 1, 0.19923735, 0.19923735),
    SIMD4<Float>(0.6, 0.8, 0, 0.06489849),
    SIMD4<Float>(-0.6, 0.8, 0.06489849, 0),
    SIMD4<Float>(0.4, 0.5, 0.26098415, 0),
  ]
  let expected: [SIMD4<Float>] = [
    SIMD4<Float>(0.17375341, 0.33081371, 0.33081371, 0.16461918),
    SIMD4<Float>(0.212613, 0.411038, 0.164904, 0.0114448),
    SIMD4<Float>(0.212613, 0.164904, 0.411038, 0.0114448),
    SIMD4<Float>(0.150679, 0.192332, 0.102271, 0.0547172),
  ]
  var shape = SIMD4<Float>(2.4, 3.2, .pi / 4, .pi / 10)
  var layout = SIMD4<Float>(5, 0.55, 0.62, 1)
  let input = try backend.buffer(
    length: MemoryLayout<SIMD4<Float>>.stride * inputs.count,
    shared: true
  )
  _ = inputs.withUnsafeBytes { bytes in
    memcpy(input.contents(), bytes.baseAddress!, bytes.count)
  }
  let shapeBuffer = try backend.buffer(
    length: MemoryLayout<SIMD4<Float>>.stride,
    shared: true
  )
  _ = withUnsafeBytes(of: &shape) { bytes in
    memcpy(shapeBuffer.contents(), bytes.baseAddress!, bytes.count)
  }
  let layoutBuffer = try backend.buffer(
    length: MemoryLayout<SIMD4<Float>>.stride,
    shared: true
  )
  _ = withUnsafeBytes(of: &layout) { bytes in
    memcpy(layoutBuffer.contents(), bytes.baseAddress!, bytes.count)
  }
  let output = try backend.buffer(
    length: MemoryLayout<SIMD4<Float>>.stride * inputs.count,
    shared: true
  )
  let commandBuffer = try #require(backend.queue.makeCommandBuffer())
  let encoder = try #require(commandBuffer.makeComputeCommandEncoder())
  encoder.setBuffer(input, offset: 0, index: 0)
  encoder.setBuffer(shapeBuffer, offset: 0, index: 1)
  encoder.setBuffer(layoutBuffer, offset: 0, index: 2)
  encoder.setBuffer(output, offset: 0, index: 3)
  backend.dispatch1D(encoder, pipeline: pipeline, count: inputs.count)
  encoder.endEncoding()
  commandBuffer.commit()
  commandBuffer.waitUntilCompleted()
  #expect(commandBuffer.status == .completed)
  let pointer = output.contents().bindMemory(
    to: SIMD4<Float>.self,
    capacity: inputs.count
  )
  let actual = Array(UnsafeBufferPointer(start: pointer, count: inputs.count))
  for (measured, reference) in zip(actual, expected) {
    #expect(simd_length(measured - reference) < 2e-5)
  }
}
