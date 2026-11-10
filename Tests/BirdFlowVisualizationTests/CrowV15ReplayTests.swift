import CryptoKit
import Foundation
import simd
import Testing
@testable import BirdFlowVisualization

@Test("V15 accepted crow replay preserves 18-action identity and articulation")
func crowV15ReplayAdmission() throws {
  let names = CrowNumiReplay.ArticulatedLink.allCases.map(\.rawValue)
    + ["crow_neck_yaw_link", "crow_head", "crow_lower_beak"]
    + ["left", "right"].flatMap { side in
      (1...3).map { "crow_\(side)_front_toe_\($0)" } + ["crow_\(side)_rear_toe"]
    }
    + CrowNumiReplay.navigationCourseBodyNames
  var states = [Float](repeating: 0, count: names.count * 13)
  for i in names.indices { states[i * 13 + 6] = 1 }
  for (name, sign): (String, Float) in [("crow_left_wing", 1), ("crow_right_wing", -1)] {
    let index = names.firstIndex(of: name)! * 13
    states[index + 3] = sign * sin(Float(0.35 / 2))
    states[index + 6] = cos(Float(0.35 / 2))
  }
  // The foot and reference toe share a quarter turn around the body z axis.
  // The subsequent local x flexion must be conjugated into body coordinates.
  let foot = names.firstIndex(of: "crow_left_foot")! * 13
  let toe = names.firstIndex(of: "crow_left_front_toe_1")! * 13
  let half = Float.pi / 4
  states[foot + 5] = sin(half); states[foot + 6] = cos(half)
  states[toe + 5] = sin(half); states[toe + 6] = cos(half)
  var moved = states
  let toeFlex = Float(0.2)
  moved[toe + 3] = cos(half) * sin(toeFlex)
  moved[toe + 4] = sin(half) * sin(toeFlex)
  moved[toe + 5] = sin(half) * cos(toeFlex)
  moved[toe + 6] = cos(half) * cos(toeFlex)
  for (name, sign): (String, Float) in [("crow_left_wing", 1), ("crow_right_wing", -1)] {
    let index = names.firstIndex(of: name)! * 13
    moved[index + 3] = sign * sin(Float(0.50 / 2))
    moved[index + 6] = cos(Float(0.50 / 2))
  }
  moved[names.firstIndex(of: "crow_left_wing")! * 13] = 0.025
  let head = names.firstIndex(of: "crow_head")! * 13
  moved[head + 4] = sin(Float(0.1))
  moved[head + 6] = cos(Float(0.1))
  let beak = names.firstIndex(of: "crow_lower_beak")! * 13
  moved[beak + 4] = sin(Float(0.15))
  moved[beak + 6] = cos(Float(0.15))
  func frame(_ step: Int, _ values: [Float]) -> [String: Any] {
    ["step": step, "q": [Float](repeating: 0, count: 23),
     "v": [Float](repeating: 0, count: 22), "body_states": values,
     "accepted_actions": [Float](repeating: 0, count: 18),
     "reward": 0, "tracking_score": 1, "root_height": 0.2, "tilt": 0,
     "difficulty_band": 10, "done": false, "timeout": false,
     "termination_reason": 0,
     "outcomes": step == 2 ? ["navigation_completion": 1.0, "ground_support": 0.012] : [:]]
  }
  let payload: [String: Any] = [
    "classification": "simulated accepted-state replay",
    "task": "american_crow_v15_conditional_landing_navigation_development_v1",
    "journey_variant": "v15-conditional-landing-navigation",
    "timestep_seconds": 0.02, "environment": 1, "frame_count": 2,
    "nq": 23, "nv": 22, "action_count": 18, "body_count": names.count,
    "body_state_stride": 13, "body_names": names,
    "world_fingerprint": "1", "task_fingerprint": "2",
    "observation_fingerprint": "3", "action_fingerprint": "4",
    "run_fingerprint": "5", "policy_rollout_fingerprint": "6",
    "controller_authority": "neural-only", "navigation_course": "reserved-final-i",
    "frames": [frame(1, states), frame(2, moved)],
  ]
  let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
  let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  let envelope = try JSONSerialization.data(withJSONObject: [
    "schema": "numi.crow-replay.v1", "payload_sha256": digest, "payload": payload,
  ], options: [.sortedKeys])
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try envelope.write(to: url)
  defer { try? FileManager.default.removeItem(at: url) }
  let replay = try CrowNumiReplay.load(url: url)
  #expect(replay.actionCount == 18)
  #expect(replay.navigationCourse == "reserved-final-i")
  #expect(!replay.usesSupportedNavigationPresentation(of: replay.frames[0]))
  #expect(replay.usesSupportedNavigationPresentation(of: replay.frames[1]))
  let articulation = try #require(replay.articulationFrame(of: replay.frames[1]))
  #expect(abs((articulation.wingReferenceElevations[.leftWing] ?? 0) - 0.35) < 1e-5)
  #expect(abs((articulation.wingReferenceElevations[.rightWing] ?? 0) - 0.35) < 1e-5)
  #expect((articulation.wingUpstrokeStrength[.leftWing] ?? 0) > 0.9)
  #expect((articulation.wingUpstrokeStrength[.rightWing] ?? 0) > 0.9)
  let wing = try #require(articulation.delta(for: .leftWing))
  #expect(abs(wing.translation.x - 0.025) < 1e-6)
  let digit = try #require(articulation.toeDeltas[.left(2)])
  #expect(abs(digit.rotationXYZW.x) < 1e-5)
  #expect(abs(digit.rotationXYZW.y - sin(toeFlex)) < 1e-5)
  #expect(abs(digit.rotationXYZW.w - cos(toeFlex)) < 1e-5)
  #expect(digit.translation == .zero)
  #expect(articulation.toeDeltas.count == 8)
  let other = try #require(articulation.toeDeltas[.right(2)])
  #expect(simd_distance(other.rotationXYZW, SIMD4<Float>(0, 0, 0, 1)) < 1e-5)
  let jaw = try #require(articulation.lowerBeakDelta)
  #expect(abs(jaw.rotationXYZW.y - sin(Float(0.05))) < 1e-5)
  #expect(abs(jaw.rotationXYZW.w - cos(Float(0.05))) < 1e-5)
  let neck = try #require(CrowStandingNeckPose.accepted(articulation))
  #expect(abs(neck.pitchRadians - 0.2) < 1e-5)
  #expect(simd_length(neck.transform(offset: .zero, coupling: 1)) < 1e-5)

  // Replay files predating the toe-body model must still load unchanged.
  let retained = names.indices.filter { !names[$0].contains("_toe") }
  let legacyNames = retained.map { names[$0] }
  func retainedStates(_ all: [Float]) -> [Float] {
    retained.flatMap { Array(all[($0 * 13)..<($0 * 13 + 13)]) }
  }
  var legacy = payload
  legacy["body_names"] = legacyNames
  legacy["body_count"] = legacyNames.count
  legacy["frames"] = [frame(1, retainedStates(states)), frame(2, retainedStates(moved))]
  let legacyData = try JSONSerialization.data(withJSONObject: legacy, options: [.sortedKeys])
  let legacyDigest = SHA256.hash(data: legacyData).map { String(format: "%02x", $0) }.joined()
  let legacyEnvelope = try JSONSerialization.data(withJSONObject: [
    "schema": "numi.crow-replay.v1", "payload_sha256": legacyDigest, "payload": legacy,
  ], options: [.sortedKeys])
  try legacyEnvelope.write(to: url)
  let oldReplay = try CrowNumiReplay.load(url: url)
  let oldFrame = try #require(oldReplay.articulationFrame(of: oldReplay.frames[1]))
  #expect(oldFrame.toeDeltas.isEmpty)
}

@Test("Navigation geometry uses both accepted body and obstacle orientation")
func crowCourseTransformsAcceptedOrientation() {
  let s = Float(0.5).squareRoot()
  let course = CrowNumiReplay.NavigationCourseFrame(
    rootPosition: SIMD3(1, 0, 0),
    rootOrientationXYZW: SIMD4(0, 0, s, s),
    bodyPositions: [SIMD3(2, 0, 0)],
    bodyOrientationsXYZW: [SIMD4(0, 0, s, s)],
    groundPosition: nil, groundOrientationXYZW: nil
  )
  let p = course.pointInCrowFrame(bodyIndex: 0, localPoint: SIMD3(1, 0, 0))
  #expect(abs(p.x - 1) < 1e-5)
  #expect(abs(p.y + 1) < 1e-5)
  #expect(abs(p.z) < 1e-5)
  let world = course.worldPointInCrowFrame(SIMD3(2, 0, 0))
  #expect(abs(world.x) < 1e-5 && abs(world.y + 1) < 1e-5)
}


@Test("landing presentation rejects transient and discontinuous support")
func crowLandingPresentationRequiresSustainedSupport() {
  let samples: [(Int, Bool)] = [(1, true), (2, false), (20, true)]
    + (40...80).map { ($0, true) } + [(81, false), (100, true)]
  let weights = CrowNumiReplay.supportedLandingWeights(
    samples: samples, timestepSeconds: 0.02
  )
  #expect(weights[1] == 0)
  #expect(weights[20] == 0)
  #expect(weights[49] == 0)
  #expect((weights[50] ?? 0) > 0)
  #expect((weights[60] ?? 0) < (weights[70] ?? 0))
  #expect(weights[74] == 1)
  #expect(weights[81] == 0)
  #expect(weights[100] == 0)
}

@Test("replay capture windows preserve timeline bounds")
func crowReplayCaptureWindowsValidateBounds() throws {
  let base = ["capture", "--capture-crow-frames", "/tmp/crow-test",
    "--capture-frames", "30", "--capture-crow-presentation", "takeoff",
    "--capture-crow-replay-pack", "/tmp/replay.json"]
  let args = try CrowShowcaseCapture.Arguments(commandLine:
    base + ["--capture-frame-start", "10", "--capture-frame-end", "14"])
  #expect(args.frameCount == 30 && args.frameStart == 10 && args.frameEnd == 14)
  #expect(throws: (any Error).self) {
    try CrowShowcaseCapture.Arguments(commandLine:
      base + ["--capture-frame-start", "20", "--capture-frame-end", "14"])
  }
  #expect(throws: (any Error).self) {
    try CrowShowcaseCapture.Arguments(commandLine:
      base + ["--capture-frame-start", "0", "--capture-frame-end", "30"])
  }
  #expect(throws: (any Error).self) {
    try CrowShowcaseCapture.Arguments(commandLine:
      ["capture", "--capture-crow-frames", "/tmp/crow-test",
       "--capture-frames", "30", "--capture-frame-start", "1"])
  }
}

@Test("camera cutaway identifies only obstacles between camera and crow")
func crowCameraCutawayDetectsObstruction() {
  let course = CrowNumiReplay.NavigationCourseFrame(
    rootPosition: .zero, rootOrientationXYZW: SIMD4(0, 0, 0, 1),
    bodyPositions: [SIMD3(0.5, 0, 0), SIMD3(-0.5, 0, 0)],
    bodyOrientationsXYZW: [SIMD4(0, 0, 0, 1), SIMD4(0, 0, 0, 1)],
    groundPosition: nil, groundOrientationXYZW: nil
  )
  #expect(CrowCourseCamera.occludingBodies(course: course, bodyCenter: .zero,
    camera: SIMD3(1, 0, 0)) == [0])
  #expect(CrowCourseCamera.occludingBodies(course: course, bodyCenter: .zero,
    camera: SIMD3(1, 1, 0)).isEmpty)
  #expect(!CrowCourseCamera.segmentIntersectsBox(start: SIMD3(1, 1, 0),
    end: SIMD3(1, -1, 0), half: SIMD3(0.1, 0.1, 0.1)))
}

@Test("research perch override matches collider without changing legacy geometry")
func crowResearchPerchGeometryIsExplicit() throws {
  var course = CrowNumiReplay.NavigationCourseFrame(
    rootPosition: .zero, rootOrientationXYZW: SIMD4(0, 0, 0, 1),
    bodyPositions: Array(repeating: .zero, count: 5),
    bodyOrientationsXYZW: Array(repeating: SIMD4(0, 0, 0, 1), count: 5),
    groundPosition: nil, groundOrientationXYZW: nil
  )
  #expect(CrowCourseCamera.halfExtents(for: course)[4] == SIMD3<Float>(0.10, 0.72, 0.055))
  course.perchHalfWidth = 0.025
  #expect(CrowCourseCamera.halfExtents(for: course)[4] == SIMD3<Float>(0.025, 0.72, 0.055))
  let base = ["capture", "--capture-crow-frames", "/tmp/crow-test", "--capture-frames", "2",
    "--capture-crow-presentation", "takeoff", "--capture-crow-replay-pack", "/tmp/replay.json"]
  #expect(try CrowShowcaseCapture.Arguments(commandLine: base).researchNarrowPerch == false)
  #expect(try CrowShowcaseCapture.Arguments(commandLine: base + ["--capture-crow-research-narrow-perch"]).researchNarrowPerch == true)
}
