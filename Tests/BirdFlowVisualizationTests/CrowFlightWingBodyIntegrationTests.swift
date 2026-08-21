import BirdFlowMetal
import Foundation
import Testing
import simd

@testable import BirdFlowVisualization

@Test("flight wing root is broad, bilateral, and body seated")
func flightWingRootIsBroadBilateralAndBodySeated() {
  let left = (0..<CrowFlightWingBodyIntegration.chordCount).map {
    CrowFlightWingBodyIntegration.bodyRoot(chordIndex: $0, left: true)
  }
  let right = (0..<CrowFlightWingBodyIntegration.chordCount).map {
    CrowFlightWingBodyIntegration.bodyRoot(chordIndex: $0, left: false)
  }

  #expect(left.first!.x > 0.075)
  #expect(left.last!.x < -0.110)
  #expect(left.first!.x - left.last!.x > 0.185)
  for (leftPoint, rightPoint) in zip(left, right) {
    #expect(abs(leftPoint.x - rightPoint.x) < 1e-7)
    #expect(abs(leftPoint.y + rightPoint.y) < 1e-7)
    #expect(abs(leftPoint.z - rightPoint.z) < 1e-7)
    #expect(abs(leftPoint.y) > 0.045)
    #expect(abs(leftPoint.y) < 0.065)
  }
}

@Test("flight wing root remains body pinned throughout the stroke")
func flightWingRootRemainsBodyPinnedThroughoutStroke() throws {
  let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
    manifestURL: root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"
    )
  )
  let body = try #require(dataset.components.first { $0.partIdentifier == 1 })
  var bodyCenter = SIMD3<Float>.zero
  for index in body.vertexOffset..<(body.vertexOffset + body.vertexCount) {
    bodyCenter += dataset.vertex(frame: 12, index: index)
  }
  bodyCenter /= Float(body.vertexCount)

  for partIdentifier: UInt8 in [2, 3] {
    let wing = try #require(
      dataset.components.first { $0.partIdentifier == partIdentifier }
    )
    let left = partIdentifier == 2
    let sourceLeadingRoot = dataset.vertex(frame: 12, index: wing.vertexOffset)
      - bodyCenter
    for chordIndex in 0..<CrowFlightWingBodyIntegration.chordCount {
      let index = wing.vertexOffset + chordIndex
      let sourceRoot = dataset.vertex(frame: 12, index: index) - bodyCenter
      for phase: Float in [0, 0.25, 0.5, 0.75, 1] {
        let integrated = CrowFlightWingBodyIntegration.integratedPoint(
          referencePoint: sourceRoot,
          sourceRoot: sourceRoot,
          sourceLeadingRoot: sourceLeadingRoot,
          spanIndex: 0,
          chordIndex: chordIndex,
          left: left,
          phase: phase
        )
        #expect(
          simd_distance(
            integrated,
            CrowFlightWingBodyIntegration.bodyRoot(
              chordIndex: chordIndex,
              left: left
            )
          ) < 1e-6
        )
      }
    }
  }
}

@Test("flight wing attachment deformation is continuous")
func flightWingAttachmentDeformationIsContinuous() {
  let sourceLeadingRoot = SIMD3<Float>(-0.20, 0.06, -0.05)
  let sourceRoot = SIMD3<Float>(-0.21, 0.065, -0.052)
  var previous: SIMD3<Float>?
  for spanIndex in 0..<CrowFlightWingBodyIntegration.spanCount {
    let referencePoint = sourceRoot + SIMD3<Float>(
      -0.002 * Float(spanIndex),
      0.012 * Float(spanIndex),
      0.006 * Float(spanIndex)
    )
    let point = CrowFlightWingBodyIntegration.integratedPoint(
      referencePoint: referencePoint,
      sourceRoot: sourceRoot,
      sourceLeadingRoot: sourceLeadingRoot,
      spanIndex: spanIndex,
      chordIndex: 4,
      left: true,
      phase: 0
    )
    if let previous {
      #expect(simd_distance(point, previous) < 0.055)
    }
    previous = point
  }
}

@Test("flight covert courses densely cover every body-to-wing station")
func flightCovertCoursesDenselyCoverEveryBodyToWingStation() {
  #expect(CrowFlightWingBodyIntegration.covertChordIndices == [0, 3, 4, 5, 6])
  #expect(
    CrowFlightWingBodyIntegration.covertChordIndices.allSatisfy {
      (0..<CrowFlightWingBodyIntegration.chordCount).contains($0)
    }
  )
  let indices = CrowFlightWingBodyIntegration.covertSpanIndices
  #expect(indices.first == 0)
  #expect(indices.dropFirst().first == 1)
  #expect(indices.last == CrowFlightWingBodyIntegration.spanCount - 3)
  #expect(indices.count == CrowFlightWingBodyIntegration.spanCount - 2)
  #expect(Set(indices).count == indices.count)
  #expect(
    indices.allSatisfy {
      (0..<CrowFlightWingBodyIntegration.spanCount - 2).contains($0)
    }
  )
  #expect(
    zip(indices, indices.dropFirst()).allSatisfy {
      $1 - $0 == 1
    }
  )

  let overlapScales = (0..<CrowFlightWingBodyIntegration.spanCount).map {
    CrowFlightWingBodyIntegration.covertAttachmentOverlapScale(spanIndex: $0)
  }
  #expect(
    abs(
      overlapScales.first!
        - CrowFlightWingBodyIntegration.covertAttachmentMaximumOverlapScale
    ) < 1e-6
  )
  #expect(
    CrowFlightWingBodyIntegration.covertAttachmentMaximumOverlapScale == 1.68
  )
  #expect(
    abs(CrowFlightWingBodyIntegration.covertCourseOverlapScale - 1.24) < 1e-6
  )
  #expect(
    abs(overlapScales[CrowFlightWingBodyIntegration.attachmentSpanCount] - 1)
      < 1e-6
  )
  #expect(
    overlapScales.dropFirst().allSatisfy {
      $0 >= 1
        && $0
          <= CrowFlightWingBodyIntegration.covertAttachmentMaximumOverlapScale
    }
  )
  #expect(
    zip(overlapScales, overlapScales.dropFirst()).allSatisfy { $1 <= $0 }
  )

  let proximalReliefs = (0..<CrowFlightWingBodyIntegration.spanCount).map {
    CrowFlightWingBodyIntegration.covertProximalReliefScale(
      chordIndex: 3,
      spanIndex: $0,
      deploymentProgress: 1
    )
  }
  #expect(abs(proximalReliefs.first! - 0.48) < 1e-6)
  #expect(proximalReliefs.allSatisfy { $0 > 0 && $0 <= 1 })
  #expect(
    zip(proximalReliefs, proximalReliefs.dropFirst()).allSatisfy { $1 >= $0 }
  )
  #expect(
    proximalReliefs[
      CrowFlightWingBodyIntegration.covertProximalSeatingSpanCount
    ] == 1
  )
  #expect(proximalReliefs.last == 1)
  for span in 0..<CrowFlightWingBodyIntegration.spanCount {
    #expect(
      CrowFlightWingBodyIntegration.covertProximalReliefScale(
        chordIndex: 3,
        spanIndex: span,
        deploymentProgress: 0
      ) == 1
    )
  }
  for chord in [5, 6] {
    #expect(
      (0..<CrowFlightWingBodyIntegration.spanCount).allSatisfy {
        CrowFlightWingBodyIntegration.covertProximalReliefScale(
          chordIndex: chord,
          spanIndex: $0,
          deploymentProgress: 1
        ) == 1
      }
    )
  }

  let distalExtensions = (0..<CrowFlightWingBodyIntegration.spanCount).map {
    CrowFlightWingBodyIntegration.covertDistalChordExtension(spanIndex: $0)
  }
  #expect(
    abs(distalExtensions[CrowFlightWingBodyIntegration.spanCount - 10]) < 1e-6
  )
  #expect(
    abs(
      distalExtensions[CrowFlightWingBodyIntegration.spanCount - 3]
        - CrowFlightWingBodyIntegration.covertDistalMaximumChordExtension
    ) < 1e-6
  )
  #expect(
    CrowFlightWingBodyIntegration.covertDistalMaximumChordExtension == 0.70
  )
  #expect(
    zip(distalExtensions, distalExtensions.dropFirst()).allSatisfy { $1 >= $0 }
  )
  for chordIndex in [0, 3] {
    let anteriorExtensions = (0..<CrowFlightWingBodyIntegration.spanCount).map {
      CrowFlightWingBodyIntegration.covertDistalAnteriorChordExtension(
        chordIndex: chordIndex,
        spanIndex: $0
      )
    }
    #expect(
      anteriorExtensions[CrowFlightWingBodyIntegration.spanCount - 10] == 0
    )
    #expect(
      abs(
        anteriorExtensions[CrowFlightWingBodyIntegration.spanCount - 3]
          - CrowFlightWingBodyIntegration.covertDistalAnteriorMaximumChordExtension
      ) < 1e-6
    )
    #expect(
      zip(anteriorExtensions, anteriorExtensions.dropFirst()).allSatisfy {
        $1 >= $0
      }
    )
  }
  #expect(
    CrowFlightWingBodyIntegration.covertDistalAnteriorMaximumChordExtension == 0.50
  )
  #expect(
    (0..<CrowFlightWingBodyIntegration.spanCount).allSatisfy {
      CrowFlightWingBodyIntegration.covertDistalAnteriorChordExtension(
        chordIndex: 4,
        spanIndex: $0
      ) == 0
    }
  )
  let proximalExtensions = (0..<CrowFlightWingBodyIntegration.spanCount).map {
    CrowFlightWingBodyIntegration.covertProximalChordExtension(spanIndex: $0)
  }
  #expect(
    abs(
      proximalExtensions.first!
        - CrowFlightWingBodyIntegration.covertProximalMaximumChordExtension
    ) < 1e-6
  )
  #expect(
    CrowFlightWingBodyIntegration.covertProximalMaximumChordExtension == 1.60
  )
  #expect(abs(proximalExtensions[8]) < 1e-6)
  #expect(
    zip(proximalExtensions, proximalExtensions.dropFirst()).allSatisfy {
      $1 <= $0
    }
  )

  #expect(
    CrowFlightWingBodyIntegration.covertAbdominalHandoffMaximumWidthScale
      == 1.35
  )
  #expect(
    CrowFlightWingBodyIntegration.covertAbdominalHandoffWidthScale(
      chordIndex: 5,
      spanIndex: 5
    ) == 1
  )

  #expect(
    abs(
      CrowFlightWingBodyIntegration.covertAbdominalHandoffWidthScale(
        chordIndex: 6,
        spanIndex: 4
      ) - 1.175
    ) < 1e-6
  )
  #expect(
    CrowFlightWingBodyIntegration.covertAbdominalHandoffWidthScale(
      chordIndex: 6,
      spanIndex: 5
    ) == 1.35
  )
  #expect(
    abs(
      CrowFlightWingBodyIntegration.covertAbdominalHandoffWidthScale(
        chordIndex: 6,
        spanIndex: 6
      ) - 1.175
    ) < 1e-6
  )
  #expect(
    CrowFlightWingBodyIntegration.covertAbdominalHandoffWidthScale(
      chordIndex: 6,
      spanIndex: 7
    ) == 1
  )

  #expect(
    CrowFlightWingBodyIntegration.covertAbdominalHandoffMaximumNormalLiftMeters
      == 0.001
  )
  #expect(
    CrowFlightWingBodyIntegration.covertAbdominalHandoffNormalLift(
      chordIndex: 5,
      spanIndex: 5
    ) == 0
  )
  #expect(
    CrowFlightWingBodyIntegration.covertAbdominalHandoffNormalLift(
      chordIndex: 6,
      spanIndex: 3
    ) == 0
  )
  #expect(
    abs(
      CrowFlightWingBodyIntegration.covertAbdominalHandoffNormalLift(
        chordIndex: 6,
        spanIndex: 4
      ) - 0.0005
    ) < 1e-7
  )
  #expect(
    CrowFlightWingBodyIntegration.covertAbdominalHandoffNormalLift(
      chordIndex: 6,
      spanIndex: 5
    ) == 0.001
  )
  #expect(
    abs(
      CrowFlightWingBodyIntegration.covertAbdominalHandoffNormalLift(
        chordIndex: 6,
        spanIndex: 6
      ) - 0.0005
    ) < 1e-7
  )
  #expect(
    CrowFlightWingBodyIntegration.covertAbdominalHandoffNormalLift(
      chordIndex: 6,
      spanIndex: 7
    ) == 0
  )

  #expect(
    CrowFlightWingBodyIntegration.covertDistalTrailingMaximumWidthScale
      == 1.25
  )
  #expect(
    CrowFlightWingBodyIntegration
      .covertDistalTrailingBodyHandoffMaximumWidthScale == 1.10
  )
  #expect(
    CrowFlightWingBodyIntegration.covertDistalTrailingBodyHandoffStartPhase
      == 0.20
  )
  #expect(
    CrowFlightWingBodyIntegration.covertDistalTrailingBodyHandoffPeakPhase
      == 0.25
  )
  #expect(
    CrowFlightWingBodyIntegration.covertDistalTrailingBodyHandoffEndPhase
      == 0.375
  )
  #expect(
    CrowFlightWingBodyIntegration
      .covertDistalTrailingBodyHandoffTransitionWeight(
        presentationPhase: 0.125
      ) == 0
  )
  #expect(
    CrowFlightWingBodyIntegration
      .covertDistalTrailingBodyHandoffTransitionWeight(
        presentationPhase: 0.20
      ) == 0
  )
  #expect(
    CrowFlightWingBodyIntegration
      .covertDistalTrailingBodyHandoffTransitionWeight(
        presentationPhase: 0.25
      ) == 1
  )
  #expect(
    abs(
      CrowFlightWingBodyIntegration
        .covertDistalTrailingBodyHandoffTransitionWeight(
          presentationPhase: 0.3125
        ) - 0.5
    ) < 1e-6
  )
  #expect(
    CrowFlightWingBodyIntegration
      .covertDistalTrailingBodyHandoffTransitionWeight(
        presentationPhase: 0.375
      ) == 0
  )
  #expect(
    CrowFlightWingBodyIntegration.covertDistalTrailingWidthScale(
      chordIndex: 5,
      spanIndex: 28
    ) == 1
  )
  #expect(
    CrowFlightWingBodyIntegration.covertDistalTrailingWidthScale(
      chordIndex: 6,
      spanIndex: 27
    ) == 1
  )
  #expect(
    abs(
      CrowFlightWingBodyIntegration.covertDistalTrailingWidthScale(
        chordIndex: 6,
        spanIndex: 28
      ) - 1.197_530_9
    ) < 1e-6
  )
  #expect(
    abs(
      CrowFlightWingBodyIntegration.covertDistalTrailingWidthScale(
        chordIndex: 6,
        spanIndex: 29
      ) - 1.197_530_9
    ) < 1e-6
  )
  #expect(
    CrowFlightWingBodyIntegration.covertDistalTrailingWidthScale(
      chordIndex: 6,
      spanIndex: 30
    ) == 1
  )
  #expect(
    CrowFlightWingBodyIntegration.covertDistalTrailingBodyHandoffWidthScale(
      chordIndex: 5,
      spanIndex: 28,
      presentationPhase: 0.25
    ) == 1
  )
  #expect(
    CrowFlightWingBodyIntegration.covertDistalTrailingBodyHandoffWidthScale(
      chordIndex: 6,
      spanIndex: 27,
      presentationPhase: 0.25
    ) == 1
  )
  #expect(
    abs(
      CrowFlightWingBodyIntegration.covertDistalTrailingBodyHandoffWidthScale(
        chordIndex: 6,
        spanIndex: 28,
        presentationPhase: 0.25
      ) - 1.079_012_4
    ) < 1e-6
  )
  #expect(
    abs(
      CrowFlightWingBodyIntegration.covertDistalTrailingBodyHandoffWidthScale(
        chordIndex: 6,
        spanIndex: 29,
        presentationPhase: 0.25
      ) - 1.079_012_4
    ) < 1e-6
  )
  #expect(
    abs(
      CrowFlightWingBodyIntegration.covertDistalTrailingBodyHandoffWidthScale(
        chordIndex: 6,
        spanIndex: 28,
        presentationPhase: 0.3125
      ) - 1.039_506_2
    ) < 1e-6
  )
  #expect(
    CrowFlightWingBodyIntegration.covertDistalTrailingBodyHandoffWidthScale(
      chordIndex: 6,
      spanIndex: 30,
      presentationPhase: 0.25
    ) == 1
  )
  #expect(
    CrowFlightWingBodyIntegration.covertDistalTrailingBodyHandoffWidthScale(
      chordIndex: 6,
      spanIndex: 28,
      presentationPhase: 0.375
    ) == 1
  )

  #expect(
    CrowFlightWingBodyIntegration.covertCaudalSecondaryHandoffMaximumWidthScale
      == 1.40
  )
  #expect(
    CrowFlightWingBodyIntegration
      .covertCaudalSecondaryHandoffMaximumVaneAsymmetry == 0.45
  )
  #expect(
    CrowFlightWingBodyIntegration.covertCaudalSecondaryHandoffWidthScale(
      chordIndex: 6,
      spanIndex: 21
    ) == 1
  )
  let caudalHandoffWidths = (0..<CrowFlightWingBodyIntegration.spanCount).map {
    CrowFlightWingBodyIntegration.covertCaudalSecondaryHandoffWidthScale(
      chordIndex: 5,
      spanIndex: $0
    )
  }
  #expect(caudalHandoffWidths[17] == 1)
  #expect(caudalHandoffWidths[18] > 1)
  #expect(abs(caudalHandoffWidths[21] - 1.395_386_9) < 1e-6)
  #expect(caudalHandoffWidths[21] == caudalHandoffWidths[22])
  #expect(caudalHandoffWidths[25] > 1)
  #expect(caudalHandoffWidths[26] == 1)
  for span in 0..<CrowFlightWingBodyIntegration.spanCount {
    let left = CrowFlightWingBodyIntegration
      .covertCaudalSecondaryHandoffVaneAsymmetry(
        chordIndex: 5,
        spanIndex: span,
        left: true
      )
    let right = CrowFlightWingBodyIntegration
      .covertCaudalSecondaryHandoffVaneAsymmetry(
        chordIndex: 5,
        spanIndex: span,
        left: false
      )
    #expect(abs(left + right) < 1e-7)
  }
  #expect(
    abs(
      CrowFlightWingBodyIntegration
        .covertCaudalSecondaryHandoffVaneAsymmetry(
          chordIndex: 5,
          spanIndex: 21,
          left: true
        ) - 0.444_810_24
    ) < 1e-6
  )
  #expect(
    CrowFlightWingBodyIntegration.covertCaudalSecondaryHandoffVaneAsymmetry(
      chordIndex: 5,
      spanIndex: 26,
      left: true
    ) == 0
  )

  #expect(
    CrowFlightWingBodyIntegration
      .covertFoldedSecondaryHandoffMaximumWidthScale == 1.70
  )
  #expect(
    CrowFlightWingBodyIntegration
      .covertFoldedSecondaryHandoffReleaseStartPhase == 0.25
  )
  #expect(
    CrowFlightWingBodyIntegration
      .covertFoldedSecondaryHandoffReleaseEndPhase == Float(7) / 24
  )
  for chord in [5, 6] {
    #expect(
      CrowFlightWingBodyIntegration.covertFoldedSecondaryHandoffWidthScale(
        chordIndex: chord,
        spanIndex: 16,
        presentationPhase: 0
      ) == 1.70
    )
    #expect(
      abs(
        CrowFlightWingBodyIntegration.covertFoldedSecondaryHandoffWidthScale(
          chordIndex: chord,
          spanIndex: 16,
          presentationPhase: 13 / 48
        ) - 1.35
      ) < 1e-6
    )
    #expect(
      CrowFlightWingBodyIntegration.covertFoldedSecondaryHandoffWidthScale(
        chordIndex: chord,
        spanIndex: 16,
        presentationPhase: 7 / 24
      ) == 1
    )
  }
  #expect(
    CrowFlightWingBodyIntegration.covertFoldedSecondaryHandoffWidthScale(
      chordIndex: 4,
      spanIndex: 16,
      presentationPhase: 0
    ) == 1
  )
  #expect(
    CrowFlightWingBodyIntegration.covertFoldedSecondaryHandoffWidthScale(
      chordIndex: 5,
      spanIndex: 11,
      presentationPhase: 0
    ) == 1
  )
  #expect(
    CrowFlightWingBodyIntegration.covertFoldedSecondaryHandoffWidthScale(
      chordIndex: 6,
      spanIndex: 21,
      presentationPhase: 0
    ) == 1
  )

  #expect(
    CrowFlightWingBodyIntegration.covertFoldedShellHandoffMaximumWidthScale
      == 1.40
  )
  #expect(
    CrowFlightWingBodyIntegration.covertFoldedShellHandoffStartPhase == 0.30
  )
  #expect(
    CrowFlightWingBodyIntegration.covertFoldedShellHandoffPeakPhase == 0.375
  )
  #expect(
    CrowFlightWingBodyIntegration.covertFoldedShellHandoffEndPhase == 0.46
  )
  #expect(
    CrowFlightWingBodyIntegration.covertFoldedShellHandoffWidthScale(
      chordIndex: 6,
      spanIndex: 0,
      presentationPhase: 0.375
    ) == 1.40
  )
  #expect(
    abs(
      CrowFlightWingBodyIntegration.covertFoldedShellHandoffWidthScale(
        chordIndex: 6,
        spanIndex: 0,
        presentationPhase: 0.3375
      ) - 1.20
    ) < 1e-6
  )
  #expect(
    abs(
      CrowFlightWingBodyIntegration.covertFoldedShellHandoffWidthScale(
        chordIndex: 6,
        spanIndex: 1,
        presentationPhase: 0.375
      ) - 1.20
    ) < 1e-6
  )
  for phase: Float in [0, 0.30, 0.46, 1] {
    #expect(
      CrowFlightWingBodyIntegration.covertFoldedShellHandoffWidthScale(
        chordIndex: 6,
        spanIndex: 0,
        presentationPhase: phase
      ) == 1
    )
  }
  #expect(
    CrowFlightWingBodyIntegration.covertFoldedShellHandoffWidthScale(
      chordIndex: 5,
      spanIndex: 0,
      presentationPhase: 0.375
    ) == 1
  )
  #expect(
    CrowFlightWingBodyIntegration.covertFoldedShellHandoffWidthScale(
      chordIndex: 6,
      spanIndex: 2,
      presentationPhase: 0.375
    ) == 1
  )

  let axillarySpans = CrowFlightWingBodyIntegration.axillaryUnderlayerSpanIndices
  #expect(axillarySpans == Array(0...8))
  #expect(axillarySpans.allSatisfy {
    $0 < CrowFlightWingBodyIntegration.attachmentSpanCount
  })
  #expect(CrowFlightWingBodyIntegration.axillaryUnderlayerRootChordIndex == 6)
  #expect(CrowFlightWingBodyIntegration.axillaryUnderlayerTipChordIndex == 8)
  let axillaryTipFractions = axillarySpans.map {
    CrowFlightWingBodyIntegration.axillaryUnderlayerTipSpanFraction(spanIndex: $0)
  }
  #expect(axillaryTipFractions.min()! > 0.32)
  #expect(axillaryTipFractions.max()! < 0.36)
  #expect(Set(axillaryTipFractions).count == axillarySpans.count)

  let identities = CrowFlightWingBodyIntegration.covertChordIndices.flatMap {
    chord in
    CrowFlightWingBodyIntegration.covertSpanIndices.map { span in
      (
        chord,
        span,
        CrowFlightWingBodyIntegration.covertTipSpanFraction(
          chordIndex: chord,
          spanIndex: span
        ),
        CrowFlightWingBodyIntegration.covertWidthScale(
          chordIndex: chord,
          spanIndex: span
        ),
        CrowFlightWingBodyIntegration.covertCamberScale(
          chordIndex: chord,
          spanIndex: span
        ),
        CrowFlightWingBodyIntegration.covertMaterialVariation(
          chordIndex: chord,
          spanIndex: span
        )
      )
    }
  }
  #expect(identities.count == 155)
  #expect(identities.map(\.2).min()! > 0.285)
  #expect(identities.map(\.2).max()! < 0.400)
  #expect(identities.map(\.3).min()! > 1.00)
  #expect(identities.map(\.3).max()! > 1.05)
  #expect(identities.map(\.4).min()! < 0.91)
  #expect(identities.map(\.4).max()! > 1.09)
  #expect(identities.map(\.5).min()! < -0.90)
  #expect(identities.map(\.5).max()! > 0.90)
  let courseMeans = CrowFlightWingBodyIntegration.covertChordIndices.map {
    chord in
    let course = identities.filter { $0.0 == chord }
    return course.map(\.2).reduce(0, +) / Float(course.count)
  }
  #expect(Set(courseMeans.map { Int(($0 * 100_000).rounded()) }).count == 5)
}

@Test("underwing covert courses stay inset, deterministic, and topology bound")
func underwingCovertCoursesStayInsetAndTopologyBound() {
  #expect(CrowFlightWingBodyIntegration.underwingCovertChordIndices == [1, 3, 5, 6])
  #expect(CrowFlightWingBodyIntegration.underwingCovertSurfaceFeatherClass == 12)
  #expect(
    CrowFlightWingBodyIntegration.underwingPrimaryCovertSurfaceFeatherClass == 13
  )
  #expect(
    CrowFlightWingBodyIntegration.underwingCovertChordIndices.allSatisfy {
      $0 > 0 && $0 + 2 < CrowFlightWingBodyIntegration.chordCount
    }
  )
  let spans = CrowFlightWingBodyIntegration.underwingCovertSpanIndices
  #expect(spans.first == 2)
  #expect(spans.last == CrowFlightWingBodyIntegration.spanCount - 5)
  #expect(spans.count == CrowFlightWingBodyIntegration.spanCount - 6)
  #expect(Set(spans).count == spans.count)
  #expect(zip(spans, spans.dropFirst()).allSatisfy { $1 - $0 == 1 })
  #expect(spans.allSatisfy { $0 > 1 && $0 + 3 < CrowFlightWingBodyIntegration.spanCount })

  let identities = CrowFlightWingBodyIntegration.underwingCovertChordIndices
    .flatMap { chord in
      spans.map { span in
        (
          chord,
          span,
          CrowFlightWingBodyIntegration.underwingCovertTipSpanFraction(
            chordIndex: chord,
            spanIndex: span
          ),
          CrowFlightWingBodyIntegration.underwingCovertWidthScale(
            chordIndex: chord,
            spanIndex: span
          ),
          CrowFlightWingBodyIntegration.underwingCovertCamberScale(
            chordIndex: chord,
            spanIndex: span
          ),
          CrowFlightWingBodyIntegration.underwingCovertMaterialVariation(
            chordIndex: chord,
            spanIndex: span
          )
        )
      }
    }
  #expect(identities.count == 108)
  #expect(identities.map(\.2).min()! > 0.075)
  #expect(identities.map(\.2).max()! < 0.125)
  #expect(
    identities.allSatisfy {
      CrowFlightWingBodyIntegration.underwingCovertChordTargetScale(
        chordIndex: $0.0
      ) + $0.2 < 1
    }
  )
  #expect(identities.map(\.3).min()! > 0.88)
  #expect(identities.map(\.3).max()! < 1.00)
  #expect(identities.map(\.4).min()! > 0.82)
  #expect(identities.map(\.4).max()! < 0.98)
  #expect(identities.map(\.5).min()! < -0.90)
  #expect(identities.map(\.5).max()! > 0.90)
  #expect(CrowFlightWingBodyIntegration.underwingCovertChordTargetScale(chordIndex: 5) == 0.86)
  #expect(CrowFlightWingBodyIntegration.underwingCovertChordTargetScale(chordIndex: 6) == 0.64)
  #expect(CrowFlightWingBodyIntegration.underwingCovertCourseWidthScale(chordIndex: 5) == 1)
  #expect(CrowFlightWingBodyIntegration.underwingCovertCourseWidthScale(chordIndex: 6) == 0.82)
  #expect(CrowFlightWingBodyIntegration.underwingCovertClassCode(chordIndex: 5) == 12)
  #expect(CrowFlightWingBodyIntegration.underwingCovertClassCode(chordIndex: 6) == 13)
  #expect(
    CrowFlightWingBodyIntegration.underwingCovertSurfaceFeatherClass
      != CrowFootAnatomy.surfaceIdentityClassCode
  )
  #expect(
    CrowFlightWingBodyIntegration.underwingPrimaryCovertSurfaceFeatherClass
      != CrowFootAnatomy.surfaceIdentityClassCode
  )
  #expect(CrowFlightWingBodyIntegration.underwingCovertRootClearanceMeters == 0.0001)
  #expect(CrowFlightWingBodyIntegration.underwingCovertTipClearanceMeters == 0.00015)
  #expect(CrowFlightWingBodyIntegration.underwingCovertDeploymentWeight(transitionProgress: 0) == 0)
  #expect(CrowFlightWingBodyIntegration.underwingCovertDeploymentWeight(transitionProgress: 0.01) == 0)
  #expect(CrowFlightWingBodyIntegration.underwingCovertDeploymentWeight(transitionProgress: 0.20) == 1)
  #expect(CrowFlightWingBodyIntegration.underwingCovertDeploymentWeight(transitionProgress: 1) == 1)
  let halfDeployment = CrowFlightWingBodyIntegration.underwingCovertDeploymentWeight(
    transitionProgress: 0.105
  )
  #expect(abs(halfDeployment - 0.5) < 1e-6)
}

@Test("underwing covert normals remain the anatomical reverse face")
func underwingCovertNormalsRemainTheReverseFace() {
  let chord = SIMD3<Float>(-1, 0, 0)
  for (left, span) in [
    (true, SIMD3<Float>(0, 1, 0)),
    (false, SIMD3<Float>(0, -1, 0)),
  ] {
    let dorsal = CrowFlightWingBodyIntegration.covertSurfaceNormal(
      chordDirection: chord,
      spanDirection: span,
      left: left
    )
    let ventral = CrowFlightWingBodyIntegration.underwingCovertSurfaceNormal(
      chordDirection: chord,
      spanDirection: span,
      left: left
    )
    #expect(abs(simd_length(ventral) - 1) < 1e-6)
    #expect(simd_dot(dorsal, ventral) < -0.999)
  }
}

@Test("rectrix wing handoff is compact and bilateral")
func rectrixWingHandoffIsCompactAndBilateral() {
  let count = CrowClosedTailAnatomy.rectrixCount
  let scales = (0..<count).map {
    CrowFlightWingBodyIntegration.rectrixWingHandoffWidthScale(
      order: $0,
      count: count
    )
  }

  #expect(
    CrowFlightWingBodyIntegration.rectrixWingHandoffMaximumWidthScale == 1.40
  )
  #expect(scales[0] == 1)
  #expect(abs(scales[1] - 1.266_666_7) < 1e-6)
  #expect(scales[1] == scales[2])
  #expect(scales[3] == 1)
  #expect(scales[8] == 1)
  #expect(scales[9] == scales[10])
  #expect(abs(scales[10] - 1.266_666_7) < 1e-6)
  #expect(scales[11] == 1)
  for order in 0..<count {
    #expect(abs(scales[order] - scales[count - 1 - order]) < 1e-7)
  }
  #expect(
    CrowFlightWingBodyIntegration.rectrixWingHandoffWidthScale(
      order: -1,
      count: count
    ) == 1
  )
  #expect(
    CrowFlightWingBodyIntegration.rectrixWingHandoffWidthScale(
      order: count,
      count: count
    ) == 1
  )
}

@Test("proximal trailing covert handoff recovers before articulation")
func proximalTrailingCovertHandoffRecoversBeforeArticulation() {
  #expect(
    CrowFlightWingBodyIntegration
      .covertProximalTailHandoffMaximumWidthScale == 1.35
  )
  #expect(
    CrowFlightWingBodyIntegration.covertProximalTailHandoffWidthScale(
      chordIndex: 5,
      spanIndex: 0
    ) == 1
  )
  #expect(
    CrowFlightWingBodyIntegration.covertProximalTailHandoffWidthScale(
      chordIndex: 6,
      spanIndex: 0
    ) == 1.35
  )
  #expect(
    abs(
      CrowFlightWingBodyIntegration.covertProximalTailHandoffWidthScale(
        chordIndex: 6,
        spanIndex: 1
      ) - 1.175
    ) < 1e-6
  )
  #expect(
    CrowFlightWingBodyIntegration.covertProximalTailHandoffWidthScale(
      chordIndex: 6,
      spanIndex: 2
    ) == 1
  )
}

@Test("leading covert ventral handoff is compact and chord-specific")
func leadingCovertVentralHandoffIsCompactAndChordSpecific() {
  #expect(
    CrowFlightWingBodyIntegration
      .covertVentralBodyHandoffMaximumWidthScale == 1.35
  )
  #expect(
    CrowFlightWingBodyIntegration.covertVentralBodyHandoffWidthScale(
      chordIndex: 3,
      spanIndex: 13
    ) == 1
  )
  #expect(
    CrowFlightWingBodyIntegration.covertVentralBodyHandoffWidthScale(
      chordIndex: 0,
      spanIndex: 11
    ) == 1
  )
  #expect(
    abs(
      CrowFlightWingBodyIntegration.covertVentralBodyHandoffWidthScale(
        chordIndex: 0,
        spanIndex: 12
      ) - 1.14
    ) < 1e-6
  )
  #expect(
    abs(
      CrowFlightWingBodyIntegration.covertVentralBodyHandoffWidthScale(
        chordIndex: 0,
        spanIndex: 13
      ) - 1.28
    ) < 1e-6
  )
  #expect(
    CrowFlightWingBodyIntegration.covertVentralBodyHandoffWidthScale(
      chordIndex: 0,
      spanIndex: 13
    )
      == CrowFlightWingBodyIntegration.covertVentralBodyHandoffWidthScale(
        chordIndex: 0,
        spanIndex: 14
      )
  )
  #expect(
    CrowFlightWingBodyIntegration.covertVentralBodyHandoffWidthScale(
      chordIndex: 0,
      spanIndex: 16
    ) == 1
  )
}

@Test("flight covert normals retain anatomical side through reversal")
func flightCovertNormalsRetainAnatomicalSideThroughReversal() {
  let chord = SIMD3<Float>(-1, 0, 0)
  let leftSpan = SIMD3<Float>(0, 1, 0)
  let rightSpan = SIMD3<Float>(0, -1, 0)
  let left = CrowFlightWingBodyIntegration.covertSurfaceNormal(
    chordDirection: chord,
    spanDirection: leftSpan,
    left: true
  )
  let right = CrowFlightWingBodyIntegration.covertSurfaceNormal(
    chordDirection: chord,
    spanDirection: rightSpan,
    left: false
  )
  #expect(left.z < -0.999 && right.z < -0.999)
  #expect(simd_distance(left, right) < 1e-7)

  for angle: Float in [-0.54, -0.27, 0, 0.27, 0.54] {
    let span = SIMD3<Float>(0, cos(angle), sin(angle))
    let normal = CrowFlightWingBodyIntegration.covertSurfaceNormal(
      chordDirection: chord,
      spanDirection: span,
      left: true
    )
    let expected = simd_normalize(simd_cross(chord, span))
    #expect(abs(simd_length(normal) - 1) < 1e-6)
    #expect(simd_dot(normal, expected) > 0.999)
  }
}

@Test("dorsal folded-wing handoff is bilateral and collapses before free flight")
func dorsalFoldedWingHandoffIsBilateralAndCollapsesBeforeFreeFlight() {
  let spans = CrowFlightWingBodyIntegration
    .dorsalFoldedWingHandoffSpanIndices
  #expect(spans == [21, 29])
  #expect(spans.allSatisfy {
    (0..<CrowFlightWingBodyIntegration.spanCount).contains($0)
  })
  #expect(
    (0..<CrowFlightWingBodyIntegration.chordCount).contains(
      CrowFlightWingBodyIntegration.dorsalFoldedWingHandoffChordIndex
    )
  )
  let bodyRadials = [true, false].map {
    CrowFlightWingBodyIntegration
      .dorsalFoldedWingHandoffBodyRadialIndex(left: $0)
  }
  #expect(bodyRadials == [19, 29])
  #expect(bodyRadials.allSatisfy {
    (0..<CrowBodyContourShingles.radialCount).contains($0)
  })
  #expect(
    (0..<CrowBodyContourShingles.axialCount).contains(
      CrowFlightWingBodyIntegration.dorsalFoldedWingHandoffBodyAxialIndex
    )
  )

  let weight = CrowFlightWingBodyIntegration
    .dorsalFoldedWingHandoffWeight(presentationPhase:)
  #expect(abs(weight(0) - 1) < 1e-7)
  #expect(abs(weight(0.28) - 1) < 1e-7)
  #expect(abs(weight(0.35) - 0.5) < 1e-6)
  #expect(abs(weight(0.42)) < 1e-7)
  #expect(abs(weight(1)) < 1e-7)
}

@Test("terminal axillary bridge collapses as reverse-face coverts deploy")
func terminalAxillaryBridgeCollapsesWithUnderwingDeployment() {
  let weight = CrowFlightWingBodyIntegration
    .terminalAxillaryHandoffWeight(transitionProgress:)
  #expect(abs(weight(0) - 1) < 1e-7)
  #expect(abs(weight(0.01) - 1) < 1e-7)
  #expect(abs(weight(0.105) - 0.5) < 1e-6)
  #expect(abs(weight(0.20)) < 1e-7)
  #expect(abs(weight(1)) < 1e-7)
}

@Test("distal trailing covert tips converge while other courses retain coverage")
func distalTrailingCovertTipsConvergeWithoutChangingOtherCourses() {
  let terminalRatio = CrowFlightWingBodyIntegration.covertTerminalWidthRatio(
    chordIndex:spanIndex:
  )
  #expect(abs(terminalRatio(6, 26) - 0.015) < 1e-7)
  #expect(terminalRatio(6, 27) == 0)
  #expect(terminalRatio(6, 30) == 0)
  #expect(abs(terminalRatio(5, 30) - 0.015) < 1e-7)

  let chordScale = CrowFlightWingBodyIntegration
    .covertDistalTrailingChordScale(chordIndex:spanIndex:)
  #expect(chordScale(6, 26) == 1)
  #expect(abs(chordScale(6, 27) - 0.88) < 1e-7)
  #expect(abs(chordScale(6, 28) - 0.80) < 1e-7)
  #expect(abs(chordScale(6, 29) - 0.72) < 1e-7)
  #expect(abs(chordScale(6, 30) - 0.64) < 1e-7)
  #expect(chordScale(5, 30) == 1)
}
