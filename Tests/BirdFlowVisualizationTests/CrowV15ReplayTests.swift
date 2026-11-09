import CryptoKit
import Foundation
import simd
import Testing
@testable import BirdFlowVisualization

@Test("V15 accepted crow replay preserves 18-action identity and articulation")
func crowV15ReplayAdmission() throws {
  let names = CrowNumiReplay.ArticulatedLink.allCases.map(\.rawValue)
    + ["crow_neck_yaw_link", "crow_head", "crow_lower_beak"]
    + CrowNumiReplay.navigationCourseBodyNames
  var states = [Float](repeating: 0, count: names.count * 13)
  for i in names.indices { states[i * 13 + 6] = 1 }
  var moved = states
  moved[names.firstIndex(of: "crow_left_wing")! * 13] = 0.025
  let head = names.firstIndex(of: "crow_head")! * 13
  moved[head + 4] = sin(Float(0.1))
  moved[head + 6] = cos(Float(0.1))
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
  let wing = try #require(articulation.delta(for: .leftWing))
  #expect(abs(wing.translation.x - 0.025) < 1e-6)
  let neck = try #require(CrowStandingNeckPose.accepted(articulation))
  #expect(abs(neck.pitchRadians - 0.2) < 1e-5)
  #expect(simd_length(neck.transform(offset: .zero, coupling: 1)) < 1e-5)
}

@Test("Navigation geometry uses both accepted body and obstacle orientation")
func crowCourseTransformsAcceptedOrientation() {
  let s = Float(0.5).squareRoot()
  let course = CrowNumiReplay.NavigationCourseFrame(
    rootPosition: SIMD3(1, 0, 0),
    rootOrientationXYZW: SIMD4(0, 0, s, s),
    bodyPositions: [SIMD3(2, 0, 0)],
    bodyOrientationsXYZW: [SIMD4(0, 0, s, s)]
  )
  let p = course.pointInCrowFrame(bodyIndex: 0, localPoint: SIMD3(1, 0, 0))
  #expect(abs(p.x - 1) < 1e-5)
  #expect(abs(p.y + 1) < 1e-5)
  #expect(abs(p.z) < 1e-5)
}
