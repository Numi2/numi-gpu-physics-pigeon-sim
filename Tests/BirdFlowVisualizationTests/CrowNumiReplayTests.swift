import CryptoKit
import Foundation
import Testing
@testable import BirdFlowVisualization

@Test("Numi crow replay validates its canonical accepted-state payload")
func numiCrowReplayValidatesCanonicalPayload() throws {
  let bodyNames = [
    "crow_body", "crow_left_wing", "crow_right_wing", "crow_tail",
    "crow_left_foot", "crow_right_foot",
  ]
  let frame: [String: Any] = [
    "step": 1,
    "q": [Float](repeating: 0, count: 20),
    "v": [Float](repeating: 0, count: 19),
    "body_states": [Float](repeating: 0, count: bodyNames.count * 13),
    "accepted_actions": [Float](repeating: 0, count: 15),
    "reward": 0.5, "tracking_score": 0.8, "root_height": 0.4,
    "tilt": 0.02, "difficulty_band": 7, "done": false,
    "timeout": false, "termination_reason": 0, "outcomes": [:],
  ]
  var liftedQ = [Float](repeating: 0, count: 20)
  liftedQ[2] = 0.2
  var liftedFrame = frame
  liftedFrame["step"] = 2
  liftedFrame["q"] = liftedQ
  let payload: [String: Any] = [
    "classification": "simulated accepted-state replay",
    "task": "birdflow_american_crow_journey_v8_neural",
    "journey_variant": "v8-neural", "timestep_seconds": 0.02,
    "environment": 0, "frame_count": 2, "nq": 20, "nv": 19,
    "action_count": 15, "body_count": bodyNames.count,
    "body_state_stride": 13, "body_names": bodyNames,
    "world_fingerprint": "1", "task_fingerprint": "2",
    "observation_fingerprint": "3", "action_fingerprint": "4",
    "run_fingerprint": "5", "policy_rollout_fingerprint": "6",
    "controller_authority": "neural-only", "frames": [frame, liftedFrame],
  ]
  let payloadData = try JSONSerialization.data(
    withJSONObject: payload, options: [.sortedKeys]
  )
  let digest = SHA256.hash(data: payloadData)
    .map { String(format: "%02x", $0) }.joined()
  let envelope: [String: Any] = [
    "schema": "numi.crow-replay.v1", "payload_sha256": digest,
    "payload": payload,
  ]
  let data = try JSONSerialization.data(
    withJSONObject: envelope, options: [.prettyPrinted, .sortedKeys]
  )
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(
    "crow-replay-\(UUID().uuidString).json"
  )
  try data.write(to: url)
  defer { try? FileManager.default.removeItem(at: url) }

  let replay = try CrowNumiReplay.load(url: url)
  #expect(replay.payloadSHA256 == digest)
  #expect(replay.frames.count == 2)
  #expect(replay.frame(atPresentationFraction: 1).step == 2)
  #expect(replay.takeoffDeploymentProgress(of: replay.frames[0]) == 0)
  #expect(replay.takeoffDeploymentProgress(of: replay.frames[1]) == 1)
}

@Test("Published neural Crow replays retain their canonical payload locks")
func publishedNeuralCrowReplaysRetainCanonicalPayloadLocks() throws {
  let repository = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let cases = [
    (
      "crow-v8-neural-accepted-full-journey.crowreplay.json",
      "birdflow_american_crow_journey_v8_neural",
      "a7ae9a76ae6fc802ff0d831c88a0eecca45443e97a0128654900111adbf7d0b8"
    ),
    (
      "crow-v9-sensor-fast-accepted-full-journey.crowreplay.json",
      "birdflow_american_crow_journey_v9_visual_neural",
      "6100dd08e2abecbda833f7a3761cda04c8fb5e36e0ba75ad2bde97b77046a881"
    ),
  ]
  for (filename, task, payloadSHA256) in cases {
    let replay = try CrowNumiReplay.load(
      url: repository.appendingPathComponent("ValidationArtifacts/\(filename)")
    )
    #expect(replay.task == task)
    #expect(replay.payloadSHA256 == payloadSHA256)
    #expect(replay.frames.count == 1_600)
    #expect(replay.controllerAuthority.hasPrefix("neural-only"))
  }
}
