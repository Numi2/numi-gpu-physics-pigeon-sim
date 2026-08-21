import Testing
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
  let maximumRootGap = zip(sortedRoots, sortedRoots.dropFirst())
    .map { $1 - $0 }
    .max() ?? 0
  #expect(maximumRootGap < 0.004)
  #expect(poses.first!.tipOffset.y < -0.07)
  #expect(poses.last!.tipOffset.y > 0.07)
  #expect(poses.last!.tipOffset.z - poses.first!.tipOffset.z > 0.035)
}
