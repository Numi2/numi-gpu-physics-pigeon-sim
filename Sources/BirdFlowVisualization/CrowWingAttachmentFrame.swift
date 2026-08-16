import BirdFlowMetal
import simd

struct CrowWingAttachmentAnchor: Equatable {
  let rootIndex: Int
  let tipIndex: Int
  let chordIndex: Int
}

/// Stable topology anchors for presentation feathers attached to each wing.
///
/// The root and tip indices are selected once from reference topology. Runtime
/// positions may move, but the owning vertices never change, avoiding the
/// discontinuity caused by re-running a nearest/farthest search every frame.
enum CrowWingAttachmentFrame {
  static func anchor(
    dataset: MeasuredBirdSurfaceSequence,
    partIdentifier: UInt8
  ) -> CrowWingAttachmentAnchor? {
    guard let body = dataset.components.first(where: { $0.partIdentifier == 1 }),
      let wing = dataset.components.first(where: {
        $0.partIdentifier == partIdentifier
      })
    else { return nil }

    var bodyCenter = SIMD3<Float>.zero
    for index in body.vertexOffset..<(body.vertexOffset + body.vertexCount) {
      bodyCenter += dataset.vertex(frame: 0, index: index)
    }
    bodyCenter /= Float(body.vertexCount)

    let wingIndices = wing.vertexOffset..<(wing.vertexOffset + wing.vertexCount)
    guard let rootIndex = wingIndices.min(by: {
      simd_distance_squared(dataset.vertex(frame: 0, index: $0), bodyCenter)
        < simd_distance_squared(dataset.vertex(frame: 0, index: $1), bodyCenter)
    }),
      let tipIndex = wingIndices.max(by: {
        simd_distance_squared(
          dataset.vertex(frame: 0, index: $0),
          dataset.vertex(frame: 0, index: rootIndex)
        ) < simd_distance_squared(
          dataset.vertex(frame: 0, index: $1),
          dataset.vertex(frame: 0, index: rootIndex)
        )
      })
    else { return nil }

    let root = dataset.vertex(frame: 0, index: rootIndex)
    let span = normalized(
      dataset.vertex(frame: 0, index: tipIndex) - root,
      fallback: SIMD3<Float>(0, partIdentifier == 2 ? 1 : -1, 0)
    )
    guard let chordIndex = wingIndices.max(by: {
      perpendicularDistanceSquared(
        dataset.vertex(frame: 0, index: $0) - root,
        axis: span
      ) < perpendicularDistanceSquared(
        dataset.vertex(frame: 0, index: $1) - root,
        axis: span
      )
    }) else { return nil }

    return CrowWingAttachmentAnchor(
      rootIndex: rootIndex,
      tipIndex: tipIndex,
      chordIndex: chordIndex
    )
  }

  static func symmetrizedRoot(
    states: [SIMD3<Float>],
    bodyCenter: SIMD3<Float>,
    left: Bool,
    leftAnchor: CrowWingAttachmentAnchor,
    rightAnchor: CrowWingAttachmentAnchor
  ) -> SIMD3<Float> {
    let leftRoot = states[leftAnchor.rootIndex]
    let rightRoot = states[rightAnchor.rootIndex]
    return SIMD3<Float>(
      0.5 * (leftRoot.x + rightRoot.x),
      bodyCenter.y
        + (left ? 1 : -1)
          * 0.5
          * (abs(leftRoot.y - bodyCenter.y) + abs(rightRoot.y - bodyCenter.y)),
      0.5 * (leftRoot.z + rightRoot.z)
    )
  }

  static func symmetrizedSpanDirection(
    states: [SIMD3<Float>],
    left: Bool,
    leftAnchor: CrowWingAttachmentAnchor,
    rightAnchor: CrowWingAttachmentAnchor
  ) -> SIMD3<Float> {
    let leftDirection = normalized(
      states[leftAnchor.tipIndex] - states[leftAnchor.rootIndex],
      fallback: SIMD3<Float>(0, 1, 0)
    )
    let rightDirection = normalized(
      states[rightAnchor.tipIndex] - states[rightAnchor.rootIndex],
      fallback: SIMD3<Float>(0, -1, 0)
    )
    return normalized(
      SIMD3<Float>(
        0.5 * (leftDirection.x + rightDirection.x),
        (left ? 1 : -1)
          * 0.5 * (abs(leftDirection.y) + abs(rightDirection.y)),
        0.5 * (leftDirection.z + rightDirection.z)
      ),
      fallback: SIMD3<Float>(0, left ? 1 : -1, 0)
    )
  }

  static func symmetrizedChordDirection(
    states: [SIMD3<Float>],
    left: Bool,
    leftAnchor: CrowWingAttachmentAnchor,
    rightAnchor: CrowWingAttachmentAnchor
  ) -> SIMD3<Float> {
    func chord(_ anchor: CrowWingAttachmentAnchor, fallbackY: Float) -> SIMD3<Float> {
      let span = normalized(
        states[anchor.tipIndex] - states[anchor.rootIndex],
        fallback: SIMD3<Float>(0, fallbackY, 0)
      )
      let candidate = states[anchor.chordIndex] - states[anchor.rootIndex]
      return normalized(
        candidate - span * simd_dot(candidate, span),
        fallback: SIMD3<Float>(-1, 0, 0)
      )
    }
    let leftChord = chord(leftAnchor, fallbackY: 1)
    let rightChord = chord(rightAnchor, fallbackY: -1)
    let span = symmetrizedSpanDirection(
      states: states,
      left: left,
      leftAnchor: leftAnchor,
      rightAnchor: rightAnchor
    )
    let symmetric = SIMD3<Float>(
      0.5 * (leftChord.x + rightChord.x),
      (left ? 1 : -1)
        * 0.5 * (abs(leftChord.y) + abs(rightChord.y)),
      0.5 * (leftChord.z + rightChord.z)
    )
    return normalized(
      symmetric - span * simd_dot(symmetric, span),
      fallback: SIMD3<Float>(-1, 0, 0)
    )
  }

  private static func perpendicularDistanceSquared(
    _ value: SIMD3<Float>,
    axis: SIMD3<Float>
  ) -> Float {
    let perpendicular = value - axis * simd_dot(value, axis)
    return simd_length_squared(perpendicular)
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-8 ? value / length : fallback
  }
}
