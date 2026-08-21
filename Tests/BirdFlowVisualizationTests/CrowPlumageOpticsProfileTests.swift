import Foundation
import Testing

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
