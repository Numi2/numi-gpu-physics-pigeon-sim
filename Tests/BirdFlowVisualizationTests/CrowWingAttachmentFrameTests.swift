import BirdFlowMetal
import Foundation
import Testing
import simd

@testable import BirdFlowVisualization

@Test("crow covert frame keeps fixed bilateral wing topology anchors")
func crowCovertFrameKeepsFixedBilateralWingTopologyAnchors() throws {
  let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
    manifestURL: root.appendingPathComponent(
      "ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"
    )
  )
  let left = try #require(
    CrowWingAttachmentFrame.anchor(dataset: dataset, partIdentifier: 2)
  )
  let right = try #require(
    CrowWingAttachmentFrame.anchor(dataset: dataset, partIdentifier: 3)
  )
  let leftComponent = try #require(
    dataset.components.first { $0.partIdentifier == 2 }
  )
  let rightComponent = try #require(
    dataset.components.first { $0.partIdentifier == 3 }
  )
  #expect(
    (leftComponent.vertexOffset..<(leftComponent.vertexOffset + leftComponent.vertexCount))
      .contains(left.rootIndex)
  )
  #expect(
    (rightComponent.vertexOffset..<(rightComponent.vertexOffset + rightComponent.vertexCount))
      .contains(right.rootIndex)
  )
  #expect(
    (leftComponent.vertexOffset..<(leftComponent.vertexOffset + leftComponent.vertexCount))
      .contains(left.chordIndex)
  )
  #expect(
    (rightComponent.vertexOffset..<(rightComponent.vertexOffset + rightComponent.vertexCount))
      .contains(right.chordIndex)
  )

  let body = try #require(dataset.components.first { $0.partIdentifier == 1 })
  var firstLeftRoot: SIMD3<Float>?
  var firstRightRoot: SIMD3<Float>?
  for frame in [0, 12, 24, 36, 48] {
    let states = (0..<dataset.vertexCount).map {
      dataset.vertex(frame: frame, index: $0)
    }
    var bodyCenter = SIMD3<Float>.zero
    for index in body.vertexOffset..<(body.vertexOffset + body.vertexCount) {
      bodyCenter += states[index]
    }
    bodyCenter /= Float(body.vertexCount)

    let leftRoot = CrowWingAttachmentFrame.symmetrizedRoot(
      states: states,
      bodyCenter: bodyCenter,
      left: true,
      leftAnchor: left,
      rightAnchor: right
    )
    let rightRoot = CrowWingAttachmentFrame.symmetrizedRoot(
      states: states,
      bodyCenter: bodyCenter,
      left: false,
      leftAnchor: left,
      rightAnchor: right
    )
    #expect(abs(leftRoot.x - rightRoot.x) < 1e-7)
    #expect(abs(leftRoot.z - rightRoot.z) < 1e-7)
    #expect(abs((leftRoot.y - bodyCenter.y) + (rightRoot.y - bodyCenter.y)) < 1e-7)
    // Bilateral averaging removes sub-millimetric scaffold asymmetry while
    // retaining the same fixed owning vertices at every phase.
    #expect(simd_distance(leftRoot, states[left.rootIndex]) < 0.0005)
    #expect(simd_distance(rightRoot, states[right.rootIndex]) < 0.0005)

    let leftSpan = CrowWingAttachmentFrame.symmetrizedSpanDirection(
      states: states,
      left: true,
      leftAnchor: left,
      rightAnchor: right
    )
    let rightSpan = CrowWingAttachmentFrame.symmetrizedSpanDirection(
      states: states,
      left: false,
      leftAnchor: left,
      rightAnchor: right
    )
    #expect(abs(simd_length(leftSpan) - 1) < 1e-6)
    #expect(abs(simd_length(rightSpan) - 1) < 1e-6)
    #expect(abs(leftSpan.x - rightSpan.x) < 1e-6)
    #expect(abs(leftSpan.z - rightSpan.z) < 1e-6)
    #expect(abs(leftSpan.y + rightSpan.y) < 1e-6)
    let leftChord = CrowWingAttachmentFrame.symmetrizedChordDirection(
      states: states,
      left: true,
      leftAnchor: left,
      rightAnchor: right
    )
    let rightChord = CrowWingAttachmentFrame.symmetrizedChordDirection(
      states: states,
      left: false,
      leftAnchor: left,
      rightAnchor: right
    )
    #expect(abs(simd_length(leftChord) - 1) < 1e-6)
    #expect(abs(simd_length(rightChord) - 1) < 1e-6)
    #expect(abs(simd_dot(leftChord, leftSpan)) < 1e-5)
    #expect(abs(simd_dot(rightChord, rightSpan)) < 1e-5)
    #expect(abs(leftChord.x - rightChord.x) < 1e-6)
    #expect(abs(leftChord.z - rightChord.z) < 1e-6)
    #expect(abs(leftChord.y + rightChord.y) < 1e-6)

    if frame == 0 {
      firstLeftRoot = leftRoot
      firstRightRoot = rightRoot
    } else if frame == 48 {
      #expect(simd_distance(leftRoot, firstLeftRoot!) < 1e-7)
      #expect(simd_distance(rightRoot, firstRightRoot!) < 1e-7)
    }
  }
}
