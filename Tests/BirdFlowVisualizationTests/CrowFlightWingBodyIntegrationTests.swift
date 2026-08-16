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
  #expect(abs(overlapScales.first! - 1.28) < 1e-6)
  #expect(
    abs(CrowFlightWingBodyIntegration.covertCourseOverlapScale - 1.24) < 1e-6
  )
  #expect(
    abs(overlapScales[CrowFlightWingBodyIntegration.attachmentSpanCount] - 1)
      < 1e-6
  )
  #expect(
    overlapScales.dropFirst().allSatisfy { $0 >= 1 && $0 <= 1.28 }
  )
  #expect(
    zip(overlapScales, overlapScales.dropFirst()).allSatisfy { $1 <= $0 }
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
