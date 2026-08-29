import CryptoKit
import Foundation
import simd

/// Accepted Numi Lab simulator state used to retarget the estimated crow
/// presentation. This is simulation evidence, not measured animal motion.
public struct CrowNumiReplay: Sendable {
  public enum ArticulatedLink: String, CaseIterable, Sendable {
    case body = "crow_body"
    case leftWingSweep = "crow_left_wing_sweep"
    case rightWingSweep = "crow_right_wing_sweep"
    case leftWingFlap = "crow_left_wing_flap_link"
    case rightWingFlap = "crow_right_wing_flap_link"
    case leftWing = "crow_left_wing"
    case rightWing = "crow_right_wing"
    case tail = "crow_tail"
    case leftThigh = "crow_left_thigh"
    case leftShank = "crow_left_shank"
    case leftFoot = "crow_left_foot"
    case rightThigh = "crow_right_thigh"
    case rightShank = "crow_right_shank"
    case rightFoot = "crow_right_foot"
  }

  /// Exact accepted link-pose change relative to the accepted crow body.
  /// Registration pivots remain part of the estimated BirdFlow anatomy; the
  /// rotation and translation themselves come directly from Numi body state.
  public struct LinkDelta: Sendable, Equatable {
    public let rotationXYZW: SIMD4<Float>
    public let translation: SIMD3<Float>

    public func transform(
      point: SIMD3<Float>,
      around registrationPivot: SIMD3<Float>
    ) -> SIMD3<Float> {
      registrationPivot
        + Self.rotate(rotationXYZW, point - registrationPivot)
        + translation
    }

    public func rotate(direction: SIMD3<Float>) -> SIMD3<Float> {
      Self.rotate(rotationXYZW, direction)
    }

    private static func rotate(
      _ quaternion: SIMD4<Float>, _ vector: SIMD3<Float>
    ) -> SIMD3<Float> {
      let imaginary = SIMD3(quaternion.x, quaternion.y, quaternion.z)
      let tangent = 2 * simd_cross(imaginary, vector)
      return vector + quaternion.w * tangent
        + simd_cross(imaginary, tangent)
    }
  }

  public struct ArticulationFrame: Sendable {
    public let replayStep: Int
    public let deltas: [ArticulatedLink: LinkDelta]

    public func delta(for link: ArticulatedLink) -> LinkDelta? {
      deltas[link]
    }
  }

  private struct RigidPose {
    let position: SIMD3<Float>
    let orientationXYZW: SIMD4<Float>

    func relative(to parent: RigidPose) -> RigidPose {
      let inverseParent = Self.conjugate(parent.orientationXYZW)
      return RigidPose(
        position: Self.rotate(inverseParent, position - parent.position),
        orientationXYZW: Self.normalized(
          Self.multiply(inverseParent, orientationXYZW)
        )
      )
    }

    static func delta(from reference: RigidPose, to current: RigidPose)
      -> LinkDelta
    {
      LinkDelta(
        rotationXYZW: normalized(
          multiply(current.orientationXYZW, conjugate(reference.orientationXYZW))
        ),
        translation: current.position - reference.position
      )
    }

    static func normalized(_ quaternion: SIMD4<Float>) -> SIMD4<Float> {
      quaternion / simd_length(quaternion)
    }

    static func conjugate(_ quaternion: SIMD4<Float>) -> SIMD4<Float> {
      SIMD4(-quaternion.x, -quaternion.y, -quaternion.z, quaternion.w)
    }

    static func multiply(
      _ lhs: SIMD4<Float>, _ rhs: SIMD4<Float>
    ) -> SIMD4<Float> {
      SIMD4(
        lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
        lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,
        lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w,
        lhs.w * rhs.w - simd_dot(
          SIMD3(lhs.x, lhs.y, lhs.z), SIMD3(rhs.x, rhs.y, rhs.z)
        )
      )
    }

    static func rotate(
      _ quaternion: SIMD4<Float>, _ vector: SIMD3<Float>
    ) -> SIMD3<Float> {
      let imaginary = SIMD3(quaternion.x, quaternion.y, quaternion.z)
      let tangent = 2 * simd_cross(imaginary, vector)
      return vector + quaternion.w * tangent
        + simd_cross(imaginary, tangent)
    }
  }
  public struct NavigationCourseFrame: Sendable {
    public let rootPosition: SIMD3<Float>
    public let bodyPositions: [SIMD3<Float>]
  }

  public static let navigationCourseBodyNames = [
    "crow_course_gate_left", "crow_course_gate_right",
    "crow_course_slalom_a", "crow_course_slalom_b", "crow_course_perch",
  ]

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
    let navigationCourse: String?
    let policyLightingContract: String?
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
      case navigationCourse = "navigation_course"
      case policyLightingContract = "policy_lighting_contract"
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
  public let navigationCourse: String?
  public let policyLightingContract: String?
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
      (payload.task.hasPrefix("birdflow_american_crow_journey_v") ||
        payload.task == "birdflow_american_crow_navigation_v10_world_model"),
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
      navigationCourse: payload.navigationCourse,
      policyLightingContract: payload.policyLightingContract,
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

  public func bodyPosition(named name: String, in frame: Frame) -> SIMD3<Float>? {
    guard let index = bodyNames.firstIndex(of: name) else { return nil }
    let start = index * 13
    guard start + 2 < frame.bodyStates.count else { return nil }
    return SIMD3(
      frame.bodyStates[start], frame.bodyStates[start + 1],
      frame.bodyStates[start + 2]
    )
  }

  private func bodyPose(
    named name: String, in frame: Frame
  ) -> RigidPose? {
    guard let index = bodyNames.firstIndex(of: name) else { return nil }
    let start = index * 13
    guard start + 6 < frame.bodyStates.count else { return nil }
    let orientation = SIMD4<Float>(
      frame.bodyStates[start + 3], frame.bodyStates[start + 4],
      frame.bodyStates[start + 5], frame.bodyStates[start + 6]
    )
    let length = simd_length(orientation)
    guard length.isFinite, length > 1e-6 else { return nil }
    return RigidPose(
      position: SIMD3(
        frame.bodyStates[start], frame.bodyStates[start + 1],
        frame.bodyStates[start + 2]
      ),
      orientationXYZW: orientation / length
    )
  }

  /// Composes every accepted Numi link against `crow_body` and removes the
  /// root trajectory. BirdFlow can therefore use an independent camera while
  /// retaining exact sweep, flap, pronation, tail, and leg-link articulation.
  public func articulationFrame(of frame: Frame) -> ArticulationFrame? {
    guard
      let referenceBody = bodyPose(
        named: ArticulatedLink.body.rawValue, in: frames[0]
      ),
      let currentBody = bodyPose(
        named: ArticulatedLink.body.rawValue, in: frame
      )
    else { return nil }
    var deltas: [ArticulatedLink: LinkDelta] = [:]
    for link in ArticulatedLink.allCases where link != .body {
      guard
        let reference = bodyPose(named: link.rawValue, in: frames[0]),
        let current = bodyPose(named: link.rawValue, in: frame)
      else { return nil }
      deltas[link] = RigidPose.delta(
        from: reference.relative(to: referenceBody),
        to: current.relative(to: currentBody)
      )
    }
    deltas[.body] = LinkDelta(
      rotationXYZW: SIMD4(0, 0, 0, 1), translation: .zero
    )
    return ArticulationFrame(replayStep: frame.step, deltas: deltas)
  }

  public func navigationCourseFrame(of frame: Frame) -> NavigationCourseFrame? {
    let positions = Self.navigationCourseBodyNames.compactMap {
      bodyPosition(named: $0, in: frame)
    }
    guard positions.count == Self.navigationCourseBodyNames.count else {
      return nil
    }
    return NavigationCourseFrame(
      rootPosition: rootPosition(of: frame),
      bodyPositions: positions
    )
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
