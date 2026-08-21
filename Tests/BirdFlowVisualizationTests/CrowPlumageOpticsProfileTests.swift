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
  #expect(
    profile.calibrationStatus == "not calibrated to an American-crow specimen"
  )

  let gpu = profile.gpuParameters
  #expect(gpu.film == SIMD4<Float>(160, 18, 0.08, 0.016))
  #expect(gpu.complexIndices == SIMD4<Float>(1.56, 0.03, 2.0, 0.6))
  #expect(gpu.melanin == SIMD4<Float>(1.32, 0.88, 1.62, 1.84))
  #expect(gpu.cortex == SIMD4<Float>(0.00492, 0.006, 0.92, 1.04))
  #expect(MemoryLayout<CrowPlumageOpticsGPUParameters>.stride == 64)
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
