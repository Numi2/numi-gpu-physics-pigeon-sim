import Foundation
import simd

enum CrowPlumageOpticsProfileError: Error, CustomStringConvertible, Equatable {
  case invalid(String)
  case unreadable(String)

  var description: String {
    switch self {
    case .invalid(let message), .unreadable(let message):
      return message
    }
  }
}

/// Versioned appearance input for the live crow feather shader.
///
/// Published comparative constraints and renderer-only estimates are separate
/// on purpose. A future American-crow measurement can replace the latter
/// without relabelling a figure trace or a related corvid as target evidence.
struct CrowPlumageOpticsProfile: Decodable, Equatable {
  struct Source: Decodable, Equatable {
    let title: String
    let doi: String
    let pmcid: String
    let sourceTaxa: [String]
    let rawSpectraAvailable: Bool
  }

  struct VisibilitySource: Decodable, Equatable {
    let title: String
    let doi: String
    let implementationURL: String
    let implementationLicense: String
    let modelClass: String
  }

  struct PublishedConstraints: Decodable, Equatable {
    let wavelengthRangeNanometers: [Float]
    let interpolatedBinWidthNanometers: Float
    let specularProbeAngleFromPlaneNormalDegrees: Float
    let diffuseMeanReflectanceUpperBound: Float
    let glossySpecularMeanReflectanceLowerBound: Float
    let glossyCortexThicknessRangeNanometers: [Float]
    let glossyCortexGroupMeanNanometers: Float
    let keratinComplexRefractiveIndex: [Float]
    let melaninComplexRefractiveIndex: [Float]
  }

  struct RenderParameters: Decodable, Equatable {
    let wavelengthSamplesNanometers: [Float]
    let cortexThicknessMeanNanometers: Float
    let cortexThicknessVariationNanometers: Float
    let thinFilmCoherence: Float
    let volumeReturnScale: Float
    let melaninExtinctionRange: [Float]
    let melaninDensityRange: [Float]
    let incoherentKeratinScatterRange: [Float]
    let cortexScaleRange: [Float]
    let barbAspectRatio: Float
    let barbuleAspectRatio: Float
    let barbuleAzimuthDegrees: Float
    let barbuleInclinationDegrees: Float
    let barbuleRelativeLength: Float
    let barbuleRelativeSeparation: Float
    let projectedVisibilityStrength: Float
  }

  let schemaVersion: Int
  let profileIdentifier: String
  let targetTaxon: String
  let evidenceClass: String
  let source: Source
  let visibilitySource: VisibilitySource
  let publishedConstraints: PublishedConstraints
  let renderParameters: RenderParameters
  let calibrationStatus: String
  let excludedClaims: [String]

  static func load(url: URL) throws -> Self {
    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch {
      throw CrowPlumageOpticsProfileError.unreadable(
        "unable to read crow plumage optics profile: \(error)"
      )
    }
    let profile: Self
    do {
      profile = try JSONDecoder().decode(Self.self, from: data)
    } catch {
      throw CrowPlumageOpticsProfileError.unreadable(
        "unable to decode crow plumage optics profile: \(error)"
      )
    }
    try profile.validate()
    return profile
  }

  func validate() throws {
    func finite(_ values: [Float]) -> Bool {
      values.allSatisfy(\.isFinite)
    }
    func increasing(_ values: [Float]) -> Bool {
      zip(values, values.dropFirst()).allSatisfy { $0.0 < $0.1 }
    }
    func pair(_ values: [Float]) -> Bool {
      values.count == 2 && finite(values) && values[0] < values[1]
    }
    func finitePair(_ values: [Float]) -> Bool {
      values.count == 2 && finite(values)
    }
    func near(_ value: Float, _ expected: Float) -> Bool {
      abs(value - expected) < 1e-5
    }

    let published = publishedConstraints
    let render = renderParameters
    guard schemaVersion == 1,
      profileIdentifier == "american-crow-plumage-optics-estimated-v1",
      targetTaxon == "Corvus brachyrhynchos",
      evidenceClass == "comparative-corvid-constrained-render-estimate",
      source.doi == "10.1098/rspb.2010.1637",
      source.pmcid == "PMC3107640",
      source.sourceTaxa.contains("Corvus corax"),
      source.sourceTaxa.contains("Corvus ossifragus"),
      !source.rawSpectraAvailable,
      visibilitySource.doi == "10.1111/cgf.15235",
      visibilitySource.implementationURL
        == "https://github.com/juanraul8/PennaceousFeathersRendering",
      visibilitySource.implementationLicense == "MIT",
      visibilitySource.modelClass
        == "projected-area-regular-cross-section-approximation",
      calibrationStatus == "not calibrated to an American-crow specimen",
      excludedClaims.count >= 4
    else {
      throw invalid("identity, provenance, or evidence boundary is invalid")
    }

    guard pair(published.wavelengthRangeNanometers),
      near(published.wavelengthRangeNanometers[0], 300),
      near(published.wavelengthRangeNanometers[1], 700),
      near(published.interpolatedBinWidthNanometers, 1),
      near(published.specularProbeAngleFromPlaneNormalDegrees, 75),
      near(published.diffuseMeanReflectanceUpperBound, 0.05),
      near(published.glossySpecularMeanReflectanceLowerBound, 0.20),
      pair(published.glossyCortexThicknessRangeNanometers),
      near(published.glossyCortexThicknessRangeNanometers[0], 110),
      near(published.glossyCortexThicknessRangeNanometers[1], 180),
      near(published.glossyCortexGroupMeanNanometers, 160),
      published.keratinComplexRefractiveIndex.count == 2,
      published.melaninComplexRefractiveIndex.count == 2,
      finite(published.keratinComplexRefractiveIndex),
      finite(published.melaninComplexRefractiveIndex),
      near(published.keratinComplexRefractiveIndex[0], 1.56),
      near(published.keratinComplexRefractiveIndex[1], 0.03),
      near(published.melaninComplexRefractiveIndex[0], 2.00),
      near(published.melaninComplexRefractiveIndex[1], 0.60)
    else {
      throw invalid("published glossy-feather constraints drifted")
    }

    let expectedWavelengths: [Float] = [400, 440, 480, 520, 560, 600, 640, 680]
    let positiveExtinction = render.melaninExtinctionRange.allSatisfy { $0 > 0 }
    let positiveDensity = render.melaninDensityRange.allSatisfy { $0 > 0 }
    let boundedScatter = render.incoherentKeratinScatterRange.allSatisfy {
      $0 >= 0 && $0 < published.diffuseMeanReflectanceUpperBound
    }
    let positiveCortexScale = render.cortexScaleRange.allSatisfy { $0 > 0 }
    guard render.wavelengthSamplesNanometers == expectedWavelengths,
      increasing(render.wavelengthSamplesNanometers),
      render.cortexThicknessMeanNanometers
        >= published.glossyCortexThicknessRangeNanometers[0],
      render.cortexThicknessMeanNanometers
        <= published.glossyCortexThicknessRangeNanometers[1],
      render.cortexThicknessVariationNanometers.isFinite,
      render.cortexThicknessVariationNanometers > 0,
      render.cortexThicknessVariationNanometers <= 35,
      render.thinFilmCoherence.isFinite,
      render.thinFilmCoherence >= 0,
      render.thinFilmCoherence <= 0.25,
      render.volumeReturnScale.isFinite,
      render.volumeReturnScale >= 0,
      render.volumeReturnScale <= published.diffuseMeanReflectanceUpperBound,
      finitePair(render.melaninExtinctionRange),
      pair(render.melaninDensityRange),
      pair(render.incoherentKeratinScatterRange),
      pair(render.cortexScaleRange),
      positiveExtinction,
      positiveDensity,
      boundedScatter,
      positiveCortexScale
    else {
      throw invalid("renderer estimates are outside the bounded optics contract")
    }

    guard render.barbAspectRatio.isFinite,
      render.barbAspectRatio >= 1,
      render.barbAspectRatio <= 8,
      render.barbuleAspectRatio.isFinite,
      render.barbuleAspectRatio >= 1,
      render.barbuleAspectRatio <= 8,
      render.barbuleAzimuthDegrees.isFinite,
      render.barbuleAzimuthDegrees >= 25,
      render.barbuleAzimuthDegrees <= 65,
      render.barbuleInclinationDegrees.isFinite,
      render.barbuleInclinationDegrees >= 0,
      render.barbuleInclinationDegrees <= 45,
      render.barbuleRelativeLength.isFinite,
      render.barbuleRelativeLength >= 1,
      render.barbuleRelativeLength <= 12,
      render.barbuleRelativeSeparation.isFinite,
      render.barbuleRelativeSeparation >= 0,
      render.barbuleRelativeSeparation <= 4,
      render.projectedVisibilityStrength.isFinite,
      render.projectedVisibilityStrength >= 0,
      render.projectedVisibilityStrength <= 1
    else {
      throw invalid("renderer visibility estimates are outside the bounded contract")
    }
  }

  var gpuParameters: CrowPlumageOpticsGPUParameters {
    let published = publishedConstraints
    let render = renderParameters
    return CrowPlumageOpticsGPUParameters(
      film: SIMD4<Float>(
        render.cortexThicknessMeanNanometers,
        render.cortexThicknessVariationNanometers,
        render.thinFilmCoherence,
        render.volumeReturnScale
      ),
      complexIndices: SIMD4<Float>(
        published.keratinComplexRefractiveIndex[0],
        published.keratinComplexRefractiveIndex[1],
        published.melaninComplexRefractiveIndex[0],
        published.melaninComplexRefractiveIndex[1]
      ),
      melanin: SIMD4<Float>(
        render.melaninExtinctionRange[0],
        render.melaninExtinctionRange[1],
        render.melaninDensityRange[0],
        render.melaninDensityRange[1]
      ),
      cortex: SIMD4<Float>(
        render.incoherentKeratinScatterRange[0],
        render.incoherentKeratinScatterRange[1],
        render.cortexScaleRange[0],
        render.cortexScaleRange[1]
      ),
      visibilityShape: SIMD4<Float>(
        render.barbAspectRatio,
        render.barbuleAspectRatio,
        render.barbuleAzimuthDegrees * .pi / 180,
        render.barbuleInclinationDegrees * .pi / 180
      ),
      visibilityLayout: SIMD4<Float>(
        render.barbuleRelativeLength,
        render.barbuleRelativeSeparation,
        render.projectedVisibilityStrength,
        0
      )
    )
  }

  private func invalid(_ detail: String) -> CrowPlumageOpticsProfileError {
    .invalid("crow plumage optics profile \(detail)")
  }
}

struct CrowPlumageOpticsGPUParameters: Equatable {
  var film: SIMD4<Float>
  var complexIndices: SIMD4<Float>
  var melanin: SIMD4<Float>
  var cortex: SIMD4<Float>
  var visibilityShape: SIMD4<Float>
  var visibilityLayout: SIMD4<Float>
}
