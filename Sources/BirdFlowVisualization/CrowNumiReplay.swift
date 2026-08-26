import CryptoKit
import Foundation

/// Accepted Numi Lab simulator state used to retarget the estimated crow
/// presentation. This is simulation evidence, not measured animal motion.
public struct CrowNumiReplay: Sendable {
  public struct Frame: Codable, Sendable {
    public let step: Int
    public let q: [Float]
    public let v: [Float]
    public let bodyStates: [Float]
    public let acceptedActions: [Float]
    public let reward: Float
    public let trackingScore: Float
    public let rootHeight: Float
    public let tilt: Float
    public let difficultyBand: UInt32
    public let done: Bool
    public let timeout: Bool
    public let terminationReason: UInt32
    public let outcomes: [String: Float]

    enum CodingKeys: String, CodingKey {
      case step, q, v, reward, tilt, done, timeout, outcomes
      case bodyStates = "body_states"
      case acceptedActions = "accepted_actions"
      case trackingScore = "tracking_score"
      case rootHeight = "root_height"
      case difficultyBand = "difficulty_band"
      case terminationReason = "termination_reason"
    }
  }

  private struct Envelope: Decodable {
    let schema: String
    let payloadSHA256: String
    let payload: Payload

    enum CodingKeys: String, CodingKey {
      case schema, payload
      case payloadSHA256 = "payload_sha256"
    }
  }

  private struct Payload: Decodable {
    let classification: String
    let task: String
    let journeyVariant: String
    let timestepSeconds: Float
    let environment: Int
    let frameCount: Int
    let nq: Int
    let nv: Int
    let actionCount: Int
    let bodyCount: Int
    let bodyStateStride: Int
    let bodyNames: [String]
    let worldFingerprint: String
    let taskFingerprint: String
    let observationFingerprint: String
    let actionFingerprint: String
    let runFingerprint: String
    let policyRolloutFingerprint: String
    let controllerAuthority: String
    let frames: [Frame]

    enum CodingKeys: String, CodingKey {
      case classification, task, environment, nq, nv, frames
      case journeyVariant = "journey_variant"
      case timestepSeconds = "timestep_seconds"
      case frameCount = "frame_count"
      case actionCount = "action_count"
      case bodyCount = "body_count"
      case bodyStateStride = "body_state_stride"
      case bodyNames = "body_names"
      case worldFingerprint = "world_fingerprint"
      case taskFingerprint = "task_fingerprint"
      case observationFingerprint = "observation_fingerprint"
      case actionFingerprint = "action_fingerprint"
      case runFingerprint = "run_fingerprint"
      case policyRolloutFingerprint = "policy_rollout_fingerprint"
      case controllerAuthority = "controller_authority"
    }
  }

  public enum ReplayError: Error, CustomStringConvertible {
    case invalid(String)

    public var description: String {
      switch self { case .invalid(let reason): return reason }
    }
  }

  public let payloadSHA256: String
  public let classification: String
  public let task: String
  public let journeyVariant: String
  public let timestepSeconds: Float
  public let environment: Int
  public let configurationCount: Int
  public let velocityCount: Int
  public let actionCount: Int
  public let bodyNames: [String]
  public let worldFingerprint: String
  public let taskFingerprint: String
  public let observationFingerprint: String
  public let actionFingerprint: String
  public let runFingerprint: String
  public let policyRolloutFingerprint: String
  public let controllerAuthority: String
  public let frames: [Frame]

  public static func load(url: URL) throws -> Self {
    let data = try Data(contentsOf: url)
    let object = try JSONSerialization.jsonObject(with: data)
    guard let dictionary = object as? [String: Any],
      let rawPayload = dictionary["payload"],
      JSONSerialization.isValidJSONObject(rawPayload)
    else {
      throw ReplayError.invalid("CrowReplayPack payload is missing")
    }
    let payloadData = try JSONSerialization.data(
      withJSONObject: rawPayload, options: [.sortedKeys]
    )
    let envelope = try JSONDecoder().decode(Envelope.self, from: data)
    let actualSHA256 = SHA256.hash(data: payloadData)
      .map { String(format: "%02x", $0) }.joined()
    guard envelope.schema == "numi.crow-replay.v1",
      envelope.payloadSHA256 == actualSHA256
    else {
      throw ReplayError.invalid("CrowReplayPack schema or payload SHA-256 is invalid")
    }
    let payload = envelope.payload
    let requiredBodies: Set<String> = [
      "crow_body", "crow_left_wing", "crow_right_wing", "crow_tail",
      "crow_left_foot", "crow_right_foot",
    ]
    guard payload.classification == "simulated accepted-state replay",
      payload.task.hasPrefix("birdflow_american_crow_journey_v"),
      payload.frameCount == payload.frames.count,
      payload.frames.count >= 2,
      payload.nq >= 20,
      payload.nv >= 19,
      payload.actionCount == 15,
      payload.bodyCount == payload.bodyNames.count,
      payload.bodyStateStride == 13,
      requiredBodies.isSubset(of: Set(payload.bodyNames)),
      payload.timestepSeconds.isFinite,
      payload.timestepSeconds > 0
    else {
      throw ReplayError.invalid("CrowReplayPack dimensions or identity are invalid")
    }
    for frame in payload.frames {
      let values = frame.q + frame.v + frame.bodyStates + frame.acceptedActions
      guard frame.q.count == payload.nq,
        frame.v.count == payload.nv,
        frame.bodyStates.count == payload.bodyCount * payload.bodyStateStride,
        frame.acceptedActions.count == payload.actionCount,
        values.allSatisfy(\.isFinite),
        frame.step > 0
      else {
        throw ReplayError.invalid("CrowReplayPack contains a malformed frame")
      }
    }
    return Self(
      payloadSHA256: envelope.payloadSHA256,
      classification: payload.classification,
      task: payload.task,
      journeyVariant: payload.journeyVariant,
      timestepSeconds: payload.timestepSeconds,
      environment: payload.environment,
      configurationCount: payload.nq,
      velocityCount: payload.nv,
      actionCount: payload.actionCount,
      bodyNames: payload.bodyNames,
      worldFingerprint: payload.worldFingerprint,
      taskFingerprint: payload.taskFingerprint,
      observationFingerprint: payload.observationFingerprint,
      actionFingerprint: payload.actionFingerprint,
      runFingerprint: payload.runFingerprint,
      policyRolloutFingerprint: payload.policyRolloutFingerprint,
      controllerAuthority: payload.controllerAuthority,
      frames: payload.frames
    )
  }

  public func frame(atPresentationFraction fraction: Float) -> Frame {
    let clamped = min(max(fraction, 0), 1)
    let index = min(
      Int((clamped * Float(frames.count - 1)).rounded()), frames.count - 1
    )
    return frames[index]
  }

  public func rootPosition(of frame: Frame) -> SIMD3<Float> {
    SIMD3(frame.q[0], frame.q[1], frame.q[2])
  }

  /// Maps accepted root lift onto the retained standing-to-flight topology
  /// handoff. It deliberately does not advance
  /// merely because render time advanced: a failed takeoff stays grounded.
  public func takeoffDeploymentProgress(of frame: Frame) -> Float {
    let initial = frames[0]
    let lift = max(frame.q[2] - initial.q[2], 0) / 0.105
    return min(max(lift, 0), 1)
  }
}
