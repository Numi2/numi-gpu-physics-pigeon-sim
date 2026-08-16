import Foundation
import Testing

@testable import BirdFlowMetal

private var birdRealityRepositoryRootURL: URL {
  URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
}

private var estimatedCrowRealityAssetURL: URL {
  birdRealityRepositoryRootURL.appendingPathComponent(
    "ValidationInputs/american-crow-hybrid-reality-v1.json"
  )
}

@Test
func birdRealityAssetLocksStableFeathersToPhysicsSurface() throws {
  let asset = try BirdRealityAssetLoader.load(
    assetURL: estimatedCrowRealityAssetURL,
    repositoryRootURL: birdRealityRepositoryRootURL
  )

  #expect(asset.schemaVersion == 1)
  #expect(asset.assetIdentifier == "american-crow-estimated-hybrid-reality-v1")
  #expect(asset.provenance.evidenceClass == .estimatedHybrid)
  #expect(asset.joints.count == 8)
  #expect(asset.featherSeries.count == 5)
  #expect(asset.feathers.count == 54)
  #expect(Set(asset.stableFeatherIdentifiers).count == 54)
  #expect(Set(asset.stableFeatherIdentifierHashes).count == 54)
  #expect(asset.stableFeatherIdentifiers.first == "left.primary.01")
  #expect(asset.stableFeatherIdentifiers.last == "tail.rectrix.12")
  #expect(asset.feathers.allSatisfy { $0.physicsRootVertexIndex < 2_157 })
  #expect(asset.readiness.stableFeatherIdentifiersReady)
  #expect(asset.readiness.physicsRenderBindingsReady)
  #expect(!asset.readiness.measuredCrowGeometryReady)
  #expect(!asset.readiness.measuredCrowKinematicsReady)
  #expect(!asset.readiness.quantitativeAerodynamicsReady)
}

@Test
func birdRealityAssetExpandsBilateralFeathersDeterministically() throws {
  let asset = try BirdRealityAssetLoader.load(
    assetURL: estimatedCrowRealityAssetURL,
    repositoryRootURL: birdRealityRepositoryRootURL
  )
  let left = asset.feathers.filter { $0.seriesIdentifier == "left.primary" }
  let right = asset.feathers.filter { $0.seriesIdentifier == "right.primary" }

  #expect(left.count == right.count)
  #expect(
    left.map(\.physicsRootVertexIndex) == [
      1_609, 1_618, 1_627, 1_636, 1_645,
      1_654, 1_663, 1_672, 1_681, 1_690,
    ])
  for (leftFeather, rightFeather) in zip(left, right) {
    #expect(leftFeather.ordinal == rightFeather.ordinal)
    #expect(leftFeather.rootPositionMeters.x == rightFeather.rootPositionMeters.x)
    #expect(leftFeather.rootPositionMeters.y == -rightFeather.rootPositionMeters.y)
    #expect(leftFeather.rootPositionMeters.z == rightFeather.rootPositionMeters.z)
    #expect(leftFeather.restDirection.x == rightFeather.restDirection.x)
    #expect(leftFeather.restDirection.y == -rightFeather.restDirection.y)
    #expect(leftFeather.restDirection.z == rightFeather.restDirection.z)
    #expect(leftFeather.lengthMeters == rightFeather.lengthMeters)
    #expect(rightFeather.physicsRootVertexIndex - leftFeather.physicsRootVertexIndex == 297)
  }
}

@Test
func birdRealityAssetRejectsGeneratedIdentifierCollision() throws {
  let mutatedURL = try mutatedRealityAsset { root in
    var series = root["featherSeries"] as! [[String: Any]]
    series[1]["identifierPrefix"] = "left.primary."
    root["featherSeries"] = series
  }
  defer { try? FileManager.default.removeItem(at: mutatedURL) }

  #expect(throws: BirdRealityAssetError.self) {
    _ = try BirdRealityAssetLoader.load(assetURL: mutatedURL)
  }
}

@Test
func birdRealityAssetRejectsSourceLockDrift() throws {
  let mutatedURL = try mutatedRealityAsset { root in
    var locks = root["sourceLocks"] as! [[String: Any]]
    locks[0]["sha256"] = String(repeating: "0", count: 64)
    root["sourceLocks"] = locks
  }
  defer { try? FileManager.default.removeItem(at: mutatedURL) }

  #expect(throws: BirdRealityAssetError.self) {
    _ = try BirdRealityAssetLoader.load(
      assetURL: mutatedURL,
      repositoryRootURL: birdRealityRepositoryRootURL
    )
  }
}

@Test
func estimatedBirdRealityAssetCannotAssertMeasuredReadiness() throws {
  let mutatedURL = try mutatedRealityAsset { root in
    var readiness = root["readiness"] as! [String: Any]
    readiness["measuredCrowGeometryReady"] = true
    root["readiness"] = readiness
  }
  defer { try? FileManager.default.removeItem(at: mutatedURL) }

  #expect(throws: BirdRealityAssetError.self) {
    _ = try BirdRealityAssetLoader.load(assetURL: mutatedURL)
  }
}

private func mutatedRealityAsset(
  _ mutate: (inout [String: Any]) -> Void
) throws -> URL {
  let source = try Data(contentsOf: estimatedCrowRealityAssetURL)
  var root = try #require(
    JSONSerialization.jsonObject(with: source) as? [String: Any]
  )
  mutate(&root)
  let output = FileManager.default.temporaryDirectory.appendingPathComponent(
    "bird-reality-\(UUID().uuidString).json"
  )
  try JSONSerialization.data(
    withJSONObject: root,
    options: [.prettyPrinted, .sortedKeys]
  ).write(to: output)
  return output
}
