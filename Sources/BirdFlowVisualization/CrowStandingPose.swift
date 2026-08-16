import Foundation
import simd

struct CrowStandingDigitPose: Equatable {
  let digitNumber: Int
  let nodes: [SIMD3<Float>]

  var phalangealSegmentCount: Int { max(0, nodes.count - 1) }
  var tip: SIMD3<Float> { nodes.last! }
}

struct CrowStandingFootPose: Equatable {
  let hip: SIMD3<Float>
  let hock: SIMD3<Float>
  let ankle: SIMD3<Float>
  let digits: [CrowStandingDigitPose]

  var digitTips: [SIMD3<Float>] { digits.map(\.tip) }
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
  static let phalangealSegmentCounts = [2, 3, 4, 5]

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
    // digit I (hallux) opposes them behind the ankle. Each chain retains the
    // avian 2-3-4-5 phalangeal pattern. Distal contacts stay fixed over the
    // loop while the intervening joints flex by sub-millimetres.
    let forwardLengths: [Float] = [0.031, 0.043, 0.035]
    let lateralFractions: [Float] = [-0.58, 0, 0.68]
    var digits: [CrowStandingDigitPose] = []
    for index in 0..<3 {
      let length = forwardLengths[index]
      let lateral = side * lateralFractions[index] * 0.020
      let tip =
        referenceBodyCenter
          + SIMD3<Float>(
            0.002 + length,
            side * footHalfSeparationMeters + lateral,
            supportHeight - referenceBodyCenter.z
          )
      digits.append(
        digit(
          number: index + 2,
          segmentCount: phalangealSegmentCounts[index + 1],
          ankle: ankle,
          tip: tip,
          supportHeight: supportHeight,
          flexionPhase: counterPhase + Float(index)
        )
      )
    }
    let halluxTip =
      referenceBodyCenter
        + SIMD3<Float>(
          -0.025,
          side * (footHalfSeparationMeters + 0.0035),
          supportHeight - referenceBodyCenter.z
        )
    digits.append(
      digit(
        number: 1,
        segmentCount: phalangealSegmentCounts[0],
        ankle: ankle,
        tip: halluxTip,
        supportHeight: supportHeight,
        flexionPhase: counterPhase + 0.7
      )
    )
    return CrowStandingFootPose(
      hip: hip,
      hock: hock,
      ankle: ankle,
      digits: digits
    )
  }

  private static func digit(
    number: Int,
    segmentCount: Int,
    ankle: SIMD3<Float>,
    tip: SIMD3<Float>,
    supportHeight: Float,
    flexionPhase: Float
  ) -> CrowStandingDigitPose {
    precondition(segmentCount > 0)
    let weights = (0..<segmentCount).map { pow(0.78, Float($0)) }
    let totalWeight = weights.reduce(0, +)
    var nodes: [SIMD3<Float>] = [ankle]
    nodes.reserveCapacity(segmentCount + 1)
    var accumulated: Float = 0
    for segmentIndex in 0..<segmentCount {
      accumulated += weights[segmentIndex]
      let fraction = accumulated / totalWeight
      if segmentIndex == segmentCount - 1 {
        nodes.append(tip)
        continue
      }
      var node = ankle + fraction * (tip - ankle)
      let plantarArch =
        0.006 * pow(max(1 - fraction, 0), 2.1)
        + 0.0012 * sin(Float.pi * fraction)
        + 0.00025 * sin(flexionPhase + Float(segmentIndex))
          * sin(Float.pi * fraction)
      node.z = supportHeight + max(plantarArch, 0.0016)
      nodes.append(node)
    }
    return CrowStandingDigitPose(digitNumber: number, nodes: nodes)
  }
}
