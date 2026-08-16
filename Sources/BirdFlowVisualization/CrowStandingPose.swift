import Foundation
import simd

struct CrowStandingFootPose: Equatable {
  let hip: SIMD3<Float>
  let hock: SIMD3<Float>
  let ankle: SIMD3<Float>
  let digitJoints: [SIMD3<Float>]
  let digitTips: [SIMD3<Float>]
}

struct CrowStandingNeckPose: Equatable {
  static let pivotOffset = SIMD3<Float>(0.096, 0, 0.038)

  let translation: SIMD3<Float>
  let yawRadians: Float
  let pitchRadians: Float
  let rollRadians: Float

  func transform(
    offset: SIMD3<Float>,
    coupling: Float
  ) -> SIMD3<Float> {
    let blend = min(max(coupling, 0), 1)
    let local = offset - Self.pivotOffset
    return Self.pivotOffset + rotated(local, coupling: blend) + blend * translation
  }

  func rotated(
    _ vector: SIMD3<Float>,
    coupling: Float
  ) -> SIMD3<Float> {
    let blend = min(max(coupling, 0), 1)
    let roll = rollRadians * blend
    let pitch = pitchRadians * blend
    let yaw = yawRadians * blend

    let rolled = SIMD3<Float>(
      vector.x,
      cos(roll) * vector.y - sin(roll) * vector.z,
      sin(roll) * vector.y + cos(roll) * vector.z
    )
    let pitched = SIMD3<Float>(
      cos(pitch) * rolled.x + sin(pitch) * rolled.z,
      rolled.y,
      -sin(pitch) * rolled.x + cos(pitch) * rolled.z
    )
    return SIMD3<Float>(
      cos(yaw) * pitched.x - sin(yaw) * pitched.y,
      sin(yaw) * pitched.x + cos(yaw) * pitched.y,
      pitched.z
    )
  }
}

struct CrowStandingPoseSample: Equatable {
  let bodyCenter: SIMD3<Float>
  let neckPose: CrowStandingNeckPose
  let supportHeight: Float
  let leftFoot: CrowStandingFootPose
  let rightFoot: CrowStandingFootPose
}

/// A loop-closed, explicitly estimated quiet-standing pose.
///
/// The supplied public clip is used only as a qualitative front-view reference:
/// both feet remain planted, the tarsometatarsi are close to vertical, and the
/// living motion stays millimetric. No image or video bytes are part of this
/// model, and none of these values are measured kinematics.
enum CrowStandingPose {
  static let supportHeightRelativeToBodyCenter: Float = -0.172
  static let footHalfSeparationMeters: Float = 0.039
  static let tarsusLengthMeters: Float = 0.057

  static func sample(
    phase: Float,
    referenceBodyCenter: SIMD3<Float> = .zero
  ) -> CrowStandingPoseSample {
    let wrapped = phase - floor(phase)
    let slow = 2 * Float.pi * wrapped
    let breath = 2 * slow
    let bodyOffset = SIMD3<Float>(
      0.0007 * sin(slow + 0.35),
      0.0018 * sin(slow),
      0.0011 * sin(breath - 0.45)
    )
    let bodyCenter = referenceBodyCenter + bodyOffset
    let supportHeight = referenceBodyCenter.z + supportHeightRelativeToBodyCenter
    let neckPose = CrowStandingNeckPose(
      translation: SIMD3<Float>(
        0.0015 * sin(slow + 1.10),
        0.0026 * sin(slow + 0.62),
        0.0018 * sin(breath + 0.30)
      ),
      yawRadians: 0.020 * sin(slow + 0.62),
      pitchRadians: 0.017 * sin(breath + 0.30),
      rollRadians: 0.007 * sin(slow - 0.18)
    )
    return CrowStandingPoseSample(
      bodyCenter: bodyCenter,
      neckPose: neckPose,
      supportHeight: supportHeight,
      leftFoot: foot(
        side: 1,
        slowPhase: slow,
        bodyCenter: bodyCenter,
        referenceBodyCenter: referenceBodyCenter,
        supportHeight: supportHeight
      ),
      rightFoot: foot(
        side: -1,
        slowPhase: slow,
        bodyCenter: bodyCenter,
        referenceBodyCenter: referenceBodyCenter,
        supportHeight: supportHeight
      )
    )
  }

  private static func foot(
    side: Float,
    slowPhase: Float,
    bodyCenter: SIMD3<Float>,
    referenceBodyCenter: SIMD3<Float>,
    supportHeight: Float
  ) -> CrowStandingFootPose {
    let counterPhase = slowPhase + (side > 0 ? 0 : Float.pi)
    let hip = bodyCenter + SIMD3<Float>(-0.025, side * 0.035, -0.060)
    let ankle =
      referenceBodyCenter
      + SIMD3<Float>(
        0.002 + 0.0007 * sin(counterPhase),
        side * footHalfSeparationMeters,
        supportHeight - referenceBodyCenter.z + 0.006
      )
    let tarsusDirection = simd_normalize(
      SIMD3<Float>(
        -0.245 + 0.012 * sin(counterPhase),
        side * (0.018 + 0.006 * cos(counterPhase)),
        0.969
      )
    )
    let hock = ankle + tarsusLengthMeters * tarsusDirection

    // Digits II-IV point forward with increasing then decreasing length;
    // digit I (hallux) opposes them behind the ankle. The distal contacts stay
    // fixed over the loop while the proximal joints flex by sub-millimetres.
    let forwardLengths: [Float] = [0.031, 0.043, 0.035]
    let lateralFractions: [Float] = [-0.58, 0, 0.68]
    var joints: [SIMD3<Float>] = []
    var tips: [SIMD3<Float>] = []
    for index in 0..<3 {
      let length = forwardLengths[index]
      let lateral = side * lateralFractions[index] * 0.020
      joints.append(
        ankle
          + SIMD3<Float>(
            0.52 * length,
            0.52 * lateral,
            -0.002 + 0.0006 * sin(counterPhase + Float(index))
          )
      )
      tips.append(
        referenceBodyCenter
          + SIMD3<Float>(
            0.002 + length,
            side * footHalfSeparationMeters + lateral,
            supportHeight - referenceBodyCenter.z
          )
      )
    }
    joints.append(
      ankle
        + SIMD3<Float>(
          -0.014,
          side * 0.0025,
          -0.0015 + 0.0005 * cos(counterPhase)
        )
    )
    tips.append(
      referenceBodyCenter
        + SIMD3<Float>(
          -0.025,
          side * (footHalfSeparationMeters + 0.0035),
          supportHeight - referenceBodyCenter.z
        )
    )
    return CrowStandingFootPose(
      hip: hip,
      hock: hock,
      ankle: ankle,
      digitJoints: joints,
      digitTips: tips
    )
  }
}
