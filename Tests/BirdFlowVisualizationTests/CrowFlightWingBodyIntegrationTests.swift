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
