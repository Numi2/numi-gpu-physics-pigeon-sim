import Foundation

public enum BirdRealityAssetError: Error, CustomStringConvertible, Equatable {
  case invalidAsset(String)

  public var description: String {
    switch self {
    case .invalidAsset(let message):
      return "Invalid bird-reality asset: \(message)"
    }
  }
}

public enum BirdRealityEvidenceClass: String, Codable, Sendable {
  case measured
  case derivedMeasured = "derived-measured"
  case estimated
  case estimatedHybrid = "estimated-hybrid"
  case procedural
  case assumed
}

public enum BirdRealitySide: String, Codable, Sendable {
  case center
  case left
  case right
}

public enum BirdRealityJointRole: String, Codable, Sendable {
  case bodyRoot
  case shoulder
  case elbow
  case wrist
  case tailRoot
}

public enum BirdRealityFeatherClass: String, Codable, Sendable {
  case primary
  case secondary
  case tail
  case covert
  case contour
}

public enum BirdRealityLODRepresentation: String, Codable, Sendable {
  case referenceMicrostructure
  case barbRibbons
  case vaneShell
  case silhouetteMeshlet
}

public enum BirdRealityMaterialModel: String, Codable, Sendable {
  case analyticFeatherBCSDFV1
}

@frozen
public struct BirdRealityVector3: Codable, Sendable, Equatable {
  public let x: Float
  public let y: Float
  public let z: Float

  public init(x: Float, y: Float, z: Float) {
    self.x = x
    self.y = y
    self.z = z
  }

  public var simd: SIMD3<Float> { SIMD3<Float>(x, y, z) }

  fileprivate var isFinite: Bool {
    x.isFinite && y.isFinite && z.isFinite
  }

  fileprivate var length: Float {
    sqrt(x * x + y * y + z * z)
  }
}

@frozen
public struct BirdRealityQuaternion: Codable, Sendable, Equatable {
  public let x: Float
  public let y: Float
  public let z: Float
  public let w: Float

  public init(x: Float, y: Float, z: Float, w: Float) {
    self.x = x
    self.y = y
    self.z = z
    self.w = w
  }

  fileprivate var isFinite: Bool {
    x.isFinite && y.isFinite && z.isFinite && w.isFinite
  }

  fileprivate var length: Float {
    sqrt(x * x + y * y + z * z + w * w)
  }
}

@frozen
public struct BirdRealityScalarRange: Codable, Sendable, Equatable {
  public let first: Float
  public let last: Float

  public init(first: Float, last: Float) {
    self.first = first
    self.last = last
  }

  fileprivate func value(at fraction: Float) -> Float {
    first + fraction * (last - first)
  }
}

@frozen
public struct BirdRealityProvenance: Codable, Sendable, Equatable {
  public let specimenIdentifier: String
  public let evidenceClass: BirdRealityEvidenceClass
  public let dataLicense: String
  public let citations: [String]
  public let processingDescription: String

  public init(
    specimenIdentifier: String,
    evidenceClass: BirdRealityEvidenceClass,
    dataLicense: String,
    citations: [String],
    processingDescription: String
  ) {
    self.specimenIdentifier = specimenIdentifier
    self.evidenceClass = evidenceClass
    self.dataLicense = dataLicense
    self.citations = citations
    self.processingDescription = processingDescription
  }
}

@frozen
public struct BirdRealityCoordinateFrame: Codable, Sendable, Equatable {
  public let handedness: String
  public let origin: String
  public let xAxis: String
  public let yAxis: String
  public let zAxis: String
  public let lengthUnit: String

  public init(
    handedness: String,
    origin: String,
    xAxis: String,
    yAxis: String,
    zAxis: String,
    lengthUnit: String
  ) {
    self.handedness = handedness
    self.origin = origin
    self.xAxis = xAxis
    self.yAxis = yAxis
    self.zAxis = zAxis
    self.lengthUnit = lengthUnit
  }
}

@frozen
public struct BirdRealitySourceLock: Codable, Sendable, Equatable {
  public let role: String
  public let path: String
  public let sha256: String
  public let evidenceClass: BirdRealityEvidenceClass

  public init(
    role: String,
    path: String,
    sha256: String,
    evidenceClass: BirdRealityEvidenceClass
  ) {
    self.role = role
    self.path = path
    self.sha256 = sha256
    self.evidenceClass = evidenceClass
  }
}

@frozen
public struct BirdRealityJoint: Codable, Sendable, Equatable {
  public let identifier: String
  public let parentIdentifier: String?
  public let role: BirdRealityJointRole
  public let side: BirdRealitySide
  public let restPositionMeters: BirdRealityVector3
  public let restOrientationBodyToJoint: BirdRealityQuaternion
  public let evidenceClass: BirdRealityEvidenceClass

  public init(
    identifier: String,
    parentIdentifier: String?,
    role: BirdRealityJointRole,
    side: BirdRealitySide,
    restPositionMeters: BirdRealityVector3,
    restOrientationBodyToJoint: BirdRealityQuaternion,
    evidenceClass: BirdRealityEvidenceClass
  ) {
    self.identifier = identifier
    self.parentIdentifier = parentIdentifier
    self.role = role
    self.side = side
    self.restPositionMeters = restPositionMeters
    self.restOrientationBodyToJoint = restOrientationBodyToJoint
    self.evidenceClass = evidenceClass
  }
}

@frozen
public struct BirdRealityFeatherMaterial: Codable, Sendable, Equatable {
  public let identifier: String
  public let model: BirdRealityMaterialModel
  public let baseReflectanceLinearRGB: BirdRealityVector3
  public let longitudinalRoughness: Float
  public let azimuthalRoughness: Float
  public let anisotropy: Float
  public let iridescenceStrength: Float
  public let evidenceClass: BirdRealityEvidenceClass

  public init(
    identifier: String,
    model: BirdRealityMaterialModel,
    baseReflectanceLinearRGB: BirdRealityVector3,
    longitudinalRoughness: Float,
    azimuthalRoughness: Float,
    anisotropy: Float,
    iridescenceStrength: Float,
    evidenceClass: BirdRealityEvidenceClass
  ) {
    self.identifier = identifier
    self.model = model
    self.baseReflectanceLinearRGB = baseReflectanceLinearRGB
    self.longitudinalRoughness = longitudinalRoughness
    self.azimuthalRoughness = azimuthalRoughness
    self.anisotropy = anisotropy
    self.iridescenceStrength = iridescenceStrength
    self.evidenceClass = evidenceClass
  }
}

@frozen
public struct BirdRealityRenderLOD: Codable, Sendable, Equatable {
  public let level: Int
  public let representation: BirdRealityLODRepresentation
  public let minimumProjectedLengthPixels: Float

  public init(
    level: Int,
    representation: BirdRealityLODRepresentation,
    minimumProjectedLengthPixels: Float
  ) {
    self.level = level
    self.representation = representation
    self.minimumProjectedLengthPixels = minimumProjectedLengthPixels
  }
}

@frozen
public struct BirdRealityFeatherSeries: Codable, Sendable, Equatable {
  public let identifier: String
  public let identifierPrefix: String
  public let identifierDigits: Int
  public let firstOrdinal: Int
  public let count: Int
  public let featherClass: BirdRealityFeatherClass
  public let side: BirdRealitySide
  public let rootJointIdentifier: String
  public let rootStartMeters: BirdRealityVector3
  public let rootEndMeters: BirdRealityVector3
  public let restDirectionStart: BirdRealityVector3
  public let restDirectionEnd: BirdRealityVector3
  public let lengthMeters: BirdRealityScalarRange
  public let maximumWidthMeters: BirdRealityScalarRange
  public let rachisRadiusMeters: BirdRealityScalarRange
  public let materialIdentifier: String
  public let evidenceClass: BirdRealityEvidenceClass

  public init(
    identifier: String,
    identifierPrefix: String,
    identifierDigits: Int,
    firstOrdinal: Int,
    count: Int,
    featherClass: BirdRealityFeatherClass,
    side: BirdRealitySide,
    rootJointIdentifier: String,
    rootStartMeters: BirdRealityVector3,
    rootEndMeters: BirdRealityVector3,
    restDirectionStart: BirdRealityVector3,
    restDirectionEnd: BirdRealityVector3,
    lengthMeters: BirdRealityScalarRange,
    maximumWidthMeters: BirdRealityScalarRange,
    rachisRadiusMeters: BirdRealityScalarRange,
    materialIdentifier: String,
    evidenceClass: BirdRealityEvidenceClass
  ) {
    self.identifier = identifier
    self.identifierPrefix = identifierPrefix
    self.identifierDigits = identifierDigits
    self.firstOrdinal = firstOrdinal
    self.count = count
    self.featherClass = featherClass
    self.side = side
    self.rootJointIdentifier = rootJointIdentifier
    self.rootStartMeters = rootStartMeters
    self.rootEndMeters = rootEndMeters
    self.restDirectionStart = restDirectionStart
    self.restDirectionEnd = restDirectionEnd
    self.lengthMeters = lengthMeters
    self.maximumWidthMeters = maximumWidthMeters
    self.rachisRadiusMeters = rachisRadiusMeters
    self.materialIdentifier = materialIdentifier
    self.evidenceClass = evidenceClass
  }

  fileprivate func featherIdentifier(ordinal: Int) -> String {
    identifierPrefix
      + String(
        format: "%0*d",
        identifierDigits,
        firstOrdinal + ordinal
      )
  }
}

@frozen
public struct BirdRealityFeatherSurfaceBinding: Codable, Sendable, Equatable {
  public let seriesIdentifier: String
  public let surfacePartIdentifier: UInt8
  public let rootVertexIndices: [Int]
  public let evidenceClass: BirdRealityEvidenceClass

  public init(
    seriesIdentifier: String,
    surfacePartIdentifier: UInt8,
    rootVertexIndices: [Int],
    evidenceClass: BirdRealityEvidenceClass
  ) {
    self.seriesIdentifier = seriesIdentifier
    self.surfacePartIdentifier = surfacePartIdentifier
    self.rootVertexIndices = rootVertexIndices
    self.evidenceClass = evidenceClass
  }
}

@frozen
public struct BirdRealityPhysicsBinding: Codable, Sendable, Equatable {
  public let surfaceDatasetIdentifier: String
  public let surfaceManifestPath: String
  public let surfaceManifestSHA256: String
  public let surfaceVertexCount: Int
  public let surfaceTriangleCount: Int
  public let mappingRepresentation: String
  public let featherSeries: [BirdRealityFeatherSurfaceBinding]

  public init(
    surfaceDatasetIdentifier: String,
    surfaceManifestPath: String,
    surfaceManifestSHA256: String,
    surfaceVertexCount: Int,
    surfaceTriangleCount: Int,
    mappingRepresentation: String,
    featherSeries: [BirdRealityFeatherSurfaceBinding]
  ) {
    self.surfaceDatasetIdentifier = surfaceDatasetIdentifier
    self.surfaceManifestPath = surfaceManifestPath
    self.surfaceManifestSHA256 = surfaceManifestSHA256
    self.surfaceVertexCount = surfaceVertexCount
    self.surfaceTriangleCount = surfaceTriangleCount
    self.mappingRepresentation = mappingRepresentation
    self.featherSeries = featherSeries
  }
}

@frozen
public struct BirdRealityReadiness: Codable, Sendable, Equatable {
  public let stableFeatherIdentifiersReady: Bool
  public let physicsRenderBindingsReady: Bool
  public let measuredCrowGeometryReady: Bool
  public let measuredCrowKinematicsReady: Bool
  public let quantitativeAerodynamicsReady: Bool

  public init(
    stableFeatherIdentifiersReady: Bool,
    physicsRenderBindingsReady: Bool,
    measuredCrowGeometryReady: Bool,
    measuredCrowKinematicsReady: Bool,
    quantitativeAerodynamicsReady: Bool
  ) {
    self.stableFeatherIdentifiersReady = stableFeatherIdentifiersReady
    self.physicsRenderBindingsReady = physicsRenderBindingsReady
    self.measuredCrowGeometryReady = measuredCrowGeometryReady
    self.measuredCrowKinematicsReady = measuredCrowKinematicsReady
    self.quantitativeAerodynamicsReady = quantitativeAerodynamicsReady
  }
}

@frozen
public struct BirdRealityFeather: Sendable, Equatable {
  public let identifier: String
  public let seriesIdentifier: String
  public let ordinal: Int
  public let featherClass: BirdRealityFeatherClass
  public let side: BirdRealitySide
  public let rootJointIdentifier: String
  public let rootPositionMeters: SIMD3<Float>
  public let restDirection: SIMD3<Float>
  public let lengthMeters: Float
  public let maximumWidthMeters: Float
  public let rachisRadiusMeters: Float
  public let materialIdentifier: String
  public let physicsSurfacePartIdentifier: UInt8
  public let physicsRootVertexIndex: Int
  public let evidenceClass: BirdRealityEvidenceClass
}

@frozen
public struct BirdRealityAsset: Codable, Sendable, Equatable {
  public let schemaVersion: Int
  public let assetIdentifier: String
  public let taxon: String
  public let commonName: String
  public let provenance: BirdRealityProvenance
  public let coordinateFrame: BirdRealityCoordinateFrame
  public let sourceLocks: [BirdRealitySourceLock]
  public let joints: [BirdRealityJoint]
  public let featherMaterials: [BirdRealityFeatherMaterial]
  public let renderLODs: [BirdRealityRenderLOD]
  public let featherSeries: [BirdRealityFeatherSeries]
  public let physicsBinding: BirdRealityPhysicsBinding
  public let readiness: BirdRealityReadiness
  public let excludedClaims: [String]
  public let antiFabricationRule: String

  public init(
    schemaVersion: Int,
    assetIdentifier: String,
    taxon: String,
    commonName: String,
    provenance: BirdRealityProvenance,
    coordinateFrame: BirdRealityCoordinateFrame,
    sourceLocks: [BirdRealitySourceLock],
    joints: [BirdRealityJoint],
    featherMaterials: [BirdRealityFeatherMaterial],
    renderLODs: [BirdRealityRenderLOD],
    featherSeries: [BirdRealityFeatherSeries],
    physicsBinding: BirdRealityPhysicsBinding,
    readiness: BirdRealityReadiness,
    excludedClaims: [String],
    antiFabricationRule: String
  ) {
    self.schemaVersion = schemaVersion
    self.assetIdentifier = assetIdentifier
    self.taxon = taxon
    self.commonName = commonName
    self.provenance = provenance
    self.coordinateFrame = coordinateFrame
    self.sourceLocks = sourceLocks
    self.joints = joints
    self.featherMaterials = featherMaterials
    self.renderLODs = renderLODs
    self.featherSeries = featherSeries
    self.physicsBinding = physicsBinding
    self.readiness = readiness
    self.excludedClaims = excludedClaims
    self.antiFabricationRule = antiFabricationRule
  }

  /// Deterministic, render-independent feather inventory. The generated IDs
  /// remain stable as geometry LOD and GPU storage layouts evolve.
  public var feathers: [BirdRealityFeather] {
    let bindings = physicsBinding.featherSeries.reduce(
      into: [String: BirdRealityFeatherSurfaceBinding]()
    ) { result, binding in
      result[binding.seriesIdentifier] = binding
    }
    return featherSeries.flatMap { series -> [BirdRealityFeather] in
      guard let binding = bindings[series.identifier],
        binding.rootVertexIndices.count == series.count
      else {
        return []
      }
      return (0..<series.count).map { index in
        let fraction =
          series.count == 1
          ? 0
          : Float(index) / Float(series.count - 1)
        let direction = normalized(
          interpolate(
            series.restDirectionStart.simd,
            series.restDirectionEnd.simd,
            fraction
          )
        )
        return BirdRealityFeather(
          identifier: series.featherIdentifier(ordinal: index),
          seriesIdentifier: series.identifier,
          ordinal: series.firstOrdinal + index,
          featherClass: series.featherClass,
          side: series.side,
          rootJointIdentifier: series.rootJointIdentifier,
          rootPositionMeters: interpolate(
            series.rootStartMeters.simd,
            series.rootEndMeters.simd,
            fraction
          ),
          restDirection: direction,
          lengthMeters: series.lengthMeters.value(at: fraction),
          maximumWidthMeters: series.maximumWidthMeters.value(at: fraction),
          rachisRadiusMeters: series.rachisRadiusMeters.value(at: fraction),
          materialIdentifier: series.materialIdentifier,
          physicsSurfacePartIdentifier: binding.surfacePartIdentifier,
          physicsRootVertexIndex: binding.rootVertexIndices[index],
          evidenceClass: series.evidenceClass
        )
      }
    }
  }

  public var stableFeatherIdentifiers: [String] {
    feathers.map(\.identifier)
  }

  /// Stable UTF-8 FNV-1a identifiers for GPU records. The loader rejects the
  /// extremely unlikely collision so shaders never use process-random hashes.
  public var stableFeatherIdentifierHashes: [UInt32] {
    stableFeatherIdentifiers.map(stableIdentifierHash)
  }
}

public enum BirdRealityAssetLoader {
  public static func load(
    assetURL: URL,
    repositoryRootURL: URL? = nil
  ) throws -> BirdRealityAsset {
    let data: Data
    let asset: BirdRealityAsset
    do {
      data = try Data(contentsOf: assetURL)
      asset = try JSONDecoder().decode(BirdRealityAsset.self, from: data)
    } catch {
      throw invalid("unable to decode \(assetURL.lastPathComponent): \(error)")
    }
    try validate(asset)
    if let repositoryRootURL {
      try validateSourceLocks(asset, repositoryRootURL: repositoryRootURL)
      try validatePhysicsSurface(asset, repositoryRootURL: repositoryRootURL)
    }
    return asset
  }

  public static func validate(_ asset: BirdRealityAsset) throws {
    guard asset.schemaVersion == 1 else {
      throw invalid("schemaVersion must be 1")
    }
    guard !asset.assetIdentifier.isEmpty,
      !asset.taxon.isEmpty,
      !asset.commonName.isEmpty,
      !asset.provenance.specimenIdentifier.isEmpty,
      !asset.provenance.dataLicense.isEmpty,
      !asset.provenance.citations.isEmpty,
      !asset.provenance.processingDescription.isEmpty,
      !asset.excludedClaims.isEmpty,
      !asset.antiFabricationRule.isEmpty
    else {
      throw invalid("identity, provenance, and claim boundaries are required")
    }
    guard asset.coordinateFrame.handedness == "rightHanded",
      asset.coordinateFrame.origin == "centerOfMass",
      asset.coordinateFrame.xAxis == "forward",
      asset.coordinateFrame.yAxis == "left",
      asset.coordinateFrame.zAxis == "up",
      asset.coordinateFrame.lengthUnit == "meter"
    else {
      throw invalid("coordinate frame must use the BirdFlow SI body convention")
    }
    try validateSourceLockRecords(asset.sourceLocks)
    try validateJoints(asset.joints)
    try validateMaterials(asset.featherMaterials)
    try validateLODs(asset.renderLODs)
    try validateFeathers(asset)

    guard asset.readiness.stableFeatherIdentifiersReady,
      asset.readiness.physicsRenderBindingsReady
    else {
      throw invalid("schema 1 requires stable IDs and physics/render bindings")
    }
    if asset.provenance.evidenceClass != .measured {
      guard !asset.readiness.measuredCrowGeometryReady,
        !asset.readiness.measuredCrowKinematicsReady,
        !asset.readiness.quantitativeAerodynamicsReady
      else {
        throw invalid("non-measured provenance cannot assert measured readiness")
      }
    }
  }

  private static func validateSourceLockRecords(
    _ locks: [BirdRealitySourceLock]
  ) throws {
    guard !locks.isEmpty,
      Set(locks.map(\.role)).count == locks.count,
      Set(locks.map(\.path)).count == locks.count
    else {
      throw invalid("source-lock roles and paths must be nonempty and unique")
    }
    for lock in locks {
      guard !lock.role.isEmpty,
        isSafeRelativePath(lock.path),
        isSHA256(lock.sha256)
      else {
        throw invalid("source lock is empty, unsafe, or not SHA-256")
      }
    }
  }

  private static func validateJoints(_ joints: [BirdRealityJoint]) throws {
    let identifiers = joints.map(\.identifier)
    guard !joints.isEmpty,
      Set(identifiers).count == joints.count,
      joints.filter({ $0.parentIdentifier == nil }).count == 1,
      joints.filter({ $0.role == .bodyRoot }).count == 1
    else {
      throw invalid("joint identifiers and root must form one canonical hierarchy")
    }
    let identifierSet = Set(identifiers)
    let parentByIdentifier = Dictionary(
      uniqueKeysWithValues: joints.map { ($0.identifier, $0.parentIdentifier) }
    )
    for joint in joints {
      guard !joint.identifier.isEmpty,
        joint.restPositionMeters.isFinite,
        joint.restOrientationBodyToJoint.isFinite,
        abs(joint.restOrientationBodyToJoint.length - 1) <= 1e-4,
        joint.parentIdentifier.map(identifierSet.contains) ?? true,
        joint.parentIdentifier != joint.identifier
      else {
        throw invalid("joint \(joint.identifier) has an invalid transform or parent")
      }
      var visited: Set<String> = []
      var cursor: String? = joint.identifier
      while let identifier = cursor {
        guard visited.insert(identifier).inserted else {
          throw invalid("joint hierarchy contains a cycle")
        }
        cursor = parentByIdentifier[identifier] ?? nil
      }
    }
  }

  private static func validateMaterials(
    _ materials: [BirdRealityFeatherMaterial]
  ) throws {
    guard !materials.isEmpty,
      Set(materials.map(\.identifier)).count == materials.count
    else {
      throw invalid("feather material identifiers must be nonempty and unique")
    }
    for material in materials {
      let color = material.baseReflectanceLinearRGB
      guard !material.identifier.isEmpty,
        color.isFinite,
        (0...1).contains(color.x),
        (0...1).contains(color.y),
        (0...1).contains(color.z),
        material.longitudinalRoughness.isFinite,
        (0...1).contains(material.longitudinalRoughness),
        material.azimuthalRoughness.isFinite,
        (0...1).contains(material.azimuthalRoughness),
        material.anisotropy.isFinite,
        (-1...1).contains(material.anisotropy),
        material.iridescenceStrength.isFinite,
        (0...1).contains(material.iridescenceStrength)
      else {
        throw invalid("material \(material.identifier) is outside its physical bounds")
      }
    }
  }

  private static func validateLODs(_ lods: [BirdRealityRenderLOD]) throws {
    guard !lods.isEmpty,
      lods.map(\.level) == Array(0..<lods.count),
      Set(lods.map(\.representation)).count == lods.count
    else {
      throw invalid("render LOD levels and representations must be unique and contiguous")
    }
    var previous = Float.infinity
    for lod in lods {
      guard lod.minimumProjectedLengthPixels.isFinite,
        lod.minimumProjectedLengthPixels >= 0,
        lod.minimumProjectedLengthPixels < previous
      else {
        throw invalid("render LOD thresholds must be finite and strictly descending")
      }
      previous = lod.minimumProjectedLengthPixels
    }
    guard lods.last?.minimumProjectedLengthPixels == 0 else {
      throw invalid("the farthest render LOD must cover zero projected pixels")
    }
  }

  private static func validateFeathers(_ asset: BirdRealityAsset) throws {
    let jointIdentifiers = Set(asset.joints.map(\.identifier))
    let materialIdentifiers = Set(asset.featherMaterials.map(\.identifier))
    let seriesIdentifiers = asset.featherSeries.map(\.identifier)
    guard !asset.featherSeries.isEmpty,
      Set(seriesIdentifiers).count == asset.featherSeries.count
    else {
      throw invalid("feather-series identifiers must be nonempty and unique")
    }
    for series in asset.featherSeries {
      let scalarRanges = [
        series.lengthMeters,
        series.maximumWidthMeters,
        series.rachisRadiusMeters,
      ]
      guard !series.identifier.isEmpty,
        !series.identifierPrefix.isEmpty,
        (1...6).contains(series.identifierDigits),
        series.firstOrdinal >= 0,
        (1...4096).contains(series.count),
        jointIdentifiers.contains(series.rootJointIdentifier),
        materialIdentifiers.contains(series.materialIdentifier),
        series.rootStartMeters.isFinite,
        series.rootEndMeters.isFinite,
        isUnit(series.restDirectionStart),
        isUnit(series.restDirectionEnd),
        scalarRanges.allSatisfy({
          $0.first.isFinite && $0.last.isFinite
            && $0.first > 0 && $0.last > 0
        })
      else {
        throw invalid("feather series \(series.identifier) is incomplete or invalid")
      }
    }

    let generatedIdentifiers = asset.featherSeries.flatMap { series in
      (0..<series.count).map(series.featherIdentifier)
    }
    guard Set(generatedIdentifiers).count == generatedIdentifiers.count else {
      throw invalid("generated feather identifiers must be globally unique")
    }
    let generatedHashes = generatedIdentifiers.map(stableIdentifierHash)
    guard Set(generatedHashes).count == generatedHashes.count else {
      throw invalid("generated feather identifier GPU hashes must be unique")
    }

    let physics = asset.physicsBinding
    guard !physics.surfaceDatasetIdentifier.isEmpty,
      isSafeRelativePath(physics.surfaceManifestPath),
      isSHA256(physics.surfaceManifestSHA256),
      physics.surfaceVertexCount > 0,
      physics.surfaceTriangleCount > 0,
      physics.mappingRepresentation == "featherRootToSurfaceVertexV1",
      physics.featherSeries.map(\.seriesIdentifier).sorted()
        == seriesIdentifiers.sorted()
    else {
      throw invalid("physics surface identity or series coverage is invalid")
    }
    let countBySeries = Dictionary(
      uniqueKeysWithValues: asset.featherSeries.map { ($0.identifier, $0.count) }
    )
    var allRootIndices: [Int] = []
    for binding in physics.featherSeries {
      guard let expectedCount = countBySeries[binding.seriesIdentifier],
        binding.rootVertexIndices.count == expectedCount,
        (1...4).contains(binding.surfacePartIdentifier),
        binding.rootVertexIndices.allSatisfy({
          $0 >= 0 && $0 < physics.surfaceVertexCount
        })
      else {
        throw invalid("physics binding \(binding.seriesIdentifier) is incomplete")
      }
      allRootIndices.append(contentsOf: binding.rootVertexIndices)
    }
    guard Set(allRootIndices).count == allRootIndices.count else {
      throw invalid("each feather must have a distinct physics root anchor")
    }
  }

  private static func validateSourceLocks(
    _ asset: BirdRealityAsset,
    repositoryRootURL: URL
  ) throws {
    for lock in asset.sourceLocks {
      let url = try resolvedURL(
        relativePath: lock.path,
        repositoryRootURL: repositoryRootURL
      )
      let data: Data
      do {
        data = try Data(contentsOf: url)
      } catch {
        throw invalid("unable to read locked source \(lock.path): \(error)")
      }
      guard CheckpointArchive.sha256(data) == lock.sha256 else {
        throw invalid("source-lock mismatch for \(lock.path)")
      }
    }
  }

  private static func validatePhysicsSurface(
    _ asset: BirdRealityAsset,
    repositoryRootURL: URL
  ) throws {
    let binding = asset.physicsBinding
    let manifestURL = try resolvedURL(
      relativePath: binding.surfaceManifestPath,
      repositoryRootURL: repositoryRootURL
    )
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
      manifestURL: manifestURL
    )
    guard surface.datasetIdentifier == binding.surfaceDatasetIdentifier,
      surface.manifestSHA256 == binding.surfaceManifestSHA256,
      surface.vertexCount == binding.surfaceVertexCount,
      surface.triangleCount == binding.surfaceTriangleCount
    else {
      throw invalid("physics binding does not match its locked surface")
    }
    let partByVertex = asset.physicsBinding.featherSeries.flatMap { binding in
      binding.rootVertexIndices.map { (vertex: $0, part: binding.surfacePartIdentifier) }
    }
    for anchor in partByVertex {
      guard
        let component = surface.components.first(where: {
          $0.partIdentifier == anchor.part
        }),
        anchor.vertex >= component.vertexOffset,
        anchor.vertex < component.vertexOffset + component.vertexCount
      else {
        throw invalid("feather root anchor is outside its surface component")
      }
    }
  }

  private static func resolvedURL(
    relativePath: String,
    repositoryRootURL: URL
  ) throws -> URL {
    guard isSafeRelativePath(relativePath) else {
      throw invalid("unsafe repository-relative path: \(relativePath)")
    }
    let root = repositoryRootURL.standardizedFileURL
    let url = root.appendingPathComponent(relativePath).standardizedFileURL
    guard url.path.hasPrefix(root.path + "/") else {
      throw invalid("path escapes repository root: \(relativePath)")
    }
    return url
  }

  private static func isSafeRelativePath(_ path: String) -> Bool {
    !path.isEmpty
      && !path.hasPrefix("/")
      && !path.split(separator: "/").contains("..")
  }

  private static func isSHA256(_ value: String) -> Bool {
    value.count == 64
      && value.allSatisfy { $0.isNumber || ("a"..."f").contains(String($0)) }
  }

  private static func isUnit(_ vector: BirdRealityVector3) -> Bool {
    vector.isFinite && abs(vector.length - 1) <= 1e-4
  }

  private static func invalid(_ message: String) -> BirdRealityAssetError {
    .invalidAsset(message)
  }
}

private func interpolate(
  _ first: SIMD3<Float>,
  _ second: SIMD3<Float>,
  _ fraction: Float
) -> SIMD3<Float> {
  first + fraction * (second - first)
}

private func normalized(_ vector: SIMD3<Float>) -> SIMD3<Float> {
  let magnitude = sqrt(
    vector.x * vector.x + vector.y * vector.y + vector.z * vector.z
  )
  return magnitude > 0 ? vector / magnitude : .zero
}

private func stableIdentifierHash(_ identifier: String) -> UInt32 {
  identifier.utf8.reduce(UInt32(2_166_136_261)) { hash, byte in
    (hash ^ UInt32(byte)) &* 16_777_619
  }
}
