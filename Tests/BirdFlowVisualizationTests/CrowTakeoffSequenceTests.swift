import Testing
import simd

@testable import BirdFlowVisualization

@Test("takeoff sequence holds, unfolds, and enters sustained flight")
func takeoffSequenceStagesAreOrderedAndBounded() {
  let start = CrowTakeoffSequence.sample(phase: 0)
  let hold = CrowTakeoffSequence.sample(phase: 0.10)
  let transition = CrowTakeoffSequence.sample(phase: 0.38)
  let flight = CrowTakeoffSequence.sample(phase: 1)

  #expect(start.transitionProgress == 0)
  #expect(hold.transitionProgress == 0)
  #expect(hold.bodyTranslation.z == 0)
  #expect(transition.transitionProgress > 0)
  #expect(transition.transitionProgress < 1)
  #expect(flight.transitionProgress == 1)
  #expect(flight.flightProgress == 1)
  #expect(flight.bodyTranslation.z > transition.bodyTranslation.z)
  #expect(flight.flightPhase > transition.flightPhase)
  #expect(CrowTakeoffSequence.foldedShellScale(transitionProgress: 0) == 1)
  #expect(
    CrowTakeoffSequence.foldedShellScale(
      transitionProgress: CrowTakeoffSequence.foldedShellCollapseStartProgress
    ) == 1
  )
  #expect(
    CrowTakeoffSequence.foldedShellScale(
      transitionProgress: CrowTakeoffSequence.foldedShellCollapseEndProgress
    ) == 0
  )
  #expect(CrowTakeoffSequence.foldedShellScale(transitionProgress: 1) == 0)
  #expect(
    CrowFeatherCoverageLOD.projectedPixelsPerMeter(
      viewportHeight: 720,
      cameraDistanceMeters:
        CrowTakeoffSequence.topologyLODReferenceCameraDistanceMeters
    ) >= 1_400
  )
}

@Test("takeoff feet begin planted and finish retracted beneath the body")
func takeoffFeetRetractWithoutChangingDigitTopology() {
  let start = CrowTakeoffSequence.standingPose(phase: 0)
  let flight = CrowTakeoffSequence.standingPose(phase: 1)

  for (planted, tucked) in [
    (start.leftFoot, flight.leftFoot),
    (start.rightFoot, flight.rightFoot),
  ] {
    #expect(planted.digits.map(\.phalangealSegmentCount) == [3, 4, 5, 2])
    #expect(
      tucked.digits.map(\.phalangealSegmentCount)
        == planted.digits.map(\.phalangealSegmentCount)
    )
    #expect(tucked.ankle.z > planted.ankle.z + 0.12)
    #expect(abs(tucked.ankle.z - flight.bodyCenter.z) < 0.09)
  }
}

@Test("takeoff folded wing topology is seated and bilateral")
func takeoffFoldedWingTopologyIsBilateral() {
  for chord in 0..<CrowFlightWingBodyIntegration.chordCount {
    let left = CrowTakeoffSequence.foldedWingPoint(
      spanIndex: 0,
      chordIndex: chord,
      left: true
    )
    let right = CrowTakeoffSequence.foldedWingPoint(
      spanIndex: 0,
      chordIndex: chord,
      left: false
    )
    #expect(abs(left.x - right.x) < 1e-7)
    #expect(abs(left.y + right.y) < 1e-7)
    #expect(abs(left.z - right.z) < 1e-7)
  }

  #expect(CrowTakeoffSequence.foldedWingDistalTaperStartFraction == 0.52)
  #expect(CrowTakeoffSequence.foldedWingDistalTaperEndFraction == 0.94)
  for chord in 0..<CrowFlightWingBodyIntegration.chordCount {
    let root = CrowTakeoffSequence.foldedWingPoint(
      spanIndex: 0,
      chordIndex: chord,
      left: true
    )
    let mid = CrowTakeoffSequence.foldedWingPoint(
      spanIndex: 16,
      chordIndex: chord,
      left: true
    )
    let tip = CrowTakeoffSequence.foldedWingPoint(
      spanIndex: CrowFlightWingBodyIntegration.spanCount - 1,
      chordIndex: chord,
      left: true
    )
    #expect(root.y >= 0.040 && root.y <= 0.0501)
    #expect(mid.y >= 0.040)
    #expect(tip.y >= 0.010 && tip.y <= 0.0141)
    #expect(tip.y < mid.y - 0.025)

    let taperedPoints = (17..<CrowFlightWingBodyIntegration.spanCount).map {
      CrowTakeoffSequence.foldedWingPoint(
        spanIndex: $0,
        chordIndex: chord,
        left: true
      )
    }
    for (current, next) in zip(taperedPoints, taperedPoints.dropFirst()) {
      #expect(next.x < current.x)
      #expect(next.y <= current.y + 1e-7)
      #expect(current.y - next.y < 0.006)
    }
  }
}

@Test("terminal primary handoff is bounded to initial wing deployment")
func terminalPrimaryHandoffIsBoundedToInitialWingDeployment() {
  let offset = CrowTakeoffSequence
    .terminalPrimaryHandoffLateralOffsetMeters(
      featherClass:order:count:transitionProgress:
    )
  #expect(offset(1, 9, 10, 0) == 0)
  #expect(
    abs(
      offset(1, 9, 10, 0.025)
        - CrowTakeoffSequence.terminalPrimaryHandoffMaximumLateralOffsetMeters
    ) < 1e-7
  )
  #expect(offset(1, 9, 10, 0.10) == 0)
  #expect(offset(1, 8, 10, 0.025) == 0)
  #expect(offset(2, 10, 11, 0.025) == 0)
  #expect(
    CrowTakeoffSequence.terminalPrimaryHandoffStartProgress
      < CrowTakeoffSequence.terminalPrimaryHandoffPeakProgress
  )
  #expect(
    CrowTakeoffSequence.terminalPrimaryHandoffPeakProgress
      < CrowTakeoffSequence.terminalPrimaryHandoffReleaseStartProgress
  )
  #expect(
    CrowTakeoffSequence.terminalPrimaryHandoffReleaseStartProgress
      < CrowTakeoffSequence.terminalPrimaryHandoffEndProgress
  )
}

@Test("folded remiges release progressively from distal identities inward")
func foldedRemigesReleaseProgressivelyFromDistalIdentitiesInward() {
  let visibility = CrowTakeoffSequence.retainedRemexVisibility(
    featherClass:order:count:transitionProgress:
  )
  let end = CrowTakeoffSequence.retainedRemexHandoffEndProgress(
    featherClass:order:count:
  )
  #expect(CrowTakeoffSequence.terminalPrimaryRetainedEndProgress == 0.20)
  #expect(end(1, 9, 10) == 0.20)
  #expect(end(1, 8, 10) == 0.28)
  #expect(end(1, 7, 10) == 0.36)
  #expect(end(1, 3, 10) == 0.62)
  #expect(end(2, 10, 11) == 0.30)
  #expect(end(2, 9, 11) == 0.36)
  #expect(end(2, 5, 11) == 0.60)
  #expect(end(2, 4, 11) == 0.62)
  #expect(visibility(1, 9, 10, 0.08) == 1)
  #expect(abs(visibility(1, 9, 10, 0.14) - 0.5) < 1e-6)
  #expect(visibility(1, 9, 10, 0.20) == 0)
  #expect(abs(visibility(1, 8, 10, 0.18) - 0.5) < 1e-6)
  #expect(visibility(1, 8, 10, 0.28) == 0)
  #expect(visibility(2, 10, 11, 0.18) > 0.56)
  #expect(visibility(2, 10, 11, 0.30) == 0)
  #expect(visibility(1, 3, 10, 0.62) == 0)
  #expect(visibility(2, 4, 11, 0.62) == 0)
  #expect(visibility(2, 10, 11, 0.14) > visibility(1, 9, 10, 0.14))
}

@Test("open-flight rectrix targets retain a connected root fan")
func openFlightRectrixTargetsRetainConnectedRootFan() {
  let count = CrowClosedTailAnatomy.rectrixCount
  let poses = (0..<count).map {
    CrowTakeoffSequence.flightRectrixPose(order: $0, count: count)
  }
  for index in 0..<(count / 2) {
    let right = poses[index]
    let left = poses[count - 1 - index]
    #expect(abs(right.rootOffset.x - left.rootOffset.x) < 1e-7)
    #expect(abs(right.rootOffset.y + left.rootOffset.y) < 1e-7)
    #expect(abs(right.rootOffset.z - left.rootOffset.z) < 1e-7)
    #expect(abs(right.tipOffset.x - left.tipOffset.x) < 1e-7)
    #expect(abs(right.tipOffset.y + left.tipOffset.y) < 1e-7)
  }
  let sortedRoots = poses.map(\.rootOffset.y).sorted()
  let maximumRootGap =
    zip(sortedRoots, sortedRoots.dropFirst())
    .map { $1 - $0 }
    .max() ?? 0
  #expect(maximumRootGap < 0.004)
  #expect(poses.first!.tipOffset.y < -0.07)
  #expect(poses.last!.tipOffset.y > 0.07)
  #expect(poses.last!.tipOffset.z - poses.first!.tipOffset.z > 0.035)
}

@Test("retained rectrices unfold continuously from the closed stack")
func retainedRectricesUnfoldContinuouslyFromClosedStack() {
  #expect(CrowTakeoffSequence.retainedFeatherHandoffStartProgress == 0.08)
  #expect(CrowTakeoffSequence.retainedFeatherHandoffEndProgress == 0.62)
  #expect(
    CrowTakeoffSequence.liveRectrixDeploymentWeight(transitionProgress: 0.08)
      == 0
  )
  #expect(
    abs(
      CrowTakeoffSequence.liveRectrixDeploymentWeight(
        transitionProgress: 0.35
      ) - 0.5
    ) < 1e-6
  )
  #expect(
    CrowTakeoffSequence.liveRectrixDeploymentWeight(transitionProgress: 0.62)
      == 1
  )

  let count = CrowClosedTailAnatomy.rectrixCount
  for order in 0..<count {
    let fraction = Float(order) / Float(count - 1)
    let closed = CrowClosedTailAnatomy.pose(fraction: fraction)
    let held = CrowTakeoffSequence.transitionRectrixPose(
      order: order,
      count: count,
      transitionProgress: 0
    )
    let flight = CrowTakeoffSequence.flightRectrixPose(
      order: order,
      count: count
    )
    let deployed = CrowTakeoffSequence.transitionRectrixPose(
      order: order,
      count: count,
      transitionProgress: 1
    )
    #expect(held.rootOffset == closed.rootOffset)
    #expect(held.tipOffset == closed.tipOffset)
    #expect(held.direction == closed.direction)
    #expect(held.normal == closed.normal)
    #expect(deployed == flight)

    let middle = CrowTakeoffSequence.transitionRectrixPose(
      order: order,
      count: count,
      transitionProgress: 0.35
    )
    #expect(abs(simd_length(middle.direction) - 1) < 1e-6)
    #expect(abs(simd_length(middle.normal) - 1) < 1e-6)
    #expect(
      simd_distance(middle.rootOffset, closed.rootOffset)
        < simd_distance(flight.rootOffset, closed.rootOffset)
    )
  }

  for order in 0..<(count / 2) {
    let right = CrowTakeoffSequence.transitionRectrixPose(
      order: order,
      count: count,
      transitionProgress: 0.35
    )
    let left = CrowTakeoffSequence.transitionRectrixPose(
      order: count - 1 - order,
      count: count,
      transitionProgress: 0.35
    )
    #expect(abs(right.rootOffset.x - left.rootOffset.x) < 1e-7)
    #expect(abs(right.rootOffset.y + left.rootOffset.y) < 1e-7)
    #expect(abs(right.tipOffset.y + left.tipOffset.y) < 1e-7)
  }
}
