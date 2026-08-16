import Testing
import simd

@testable import BirdFlowVisualization

@Test("closed rectrices overlap in a medial-to-lateral tent")
func closedRectricesOverlapInMedialToLateralTent() {
  let poses = (0..<CrowClosedTailAnatomy.rectrixCount).map {
    CrowClosedTailAnatomy.pose(
      fraction: Float($0) / Float(CrowClosedTailAnatomy.rectrixCount - 1)
    )
  }
  #expect(poses.count == 12)
  #expect(abs(poses.first!.rootOffset.y + 0.006) < 1e-7)
  #expect(abs(poses.last!.rootOffset.y - 0.006) < 1e-7)
  #expect(abs(poses.first!.tipOffset.y + 0.006) < 1e-7)
  #expect(abs(poses.last!.tipOffset.y - 0.006) < 1e-7)

  let rightFromMedial = Array(poses[0...5].reversed())
  let leftFromMedial = Array(poses[6...11])
  for side in [rightFromMedial, leftFromMedial] {
    for pair in zip(side, side.dropFirst()) {
      #expect(pair.0.radialFraction < pair.1.radialFraction)
      #expect(pair.0.rootOffset.z > pair.1.rootOffset.z)
      #expect(pair.0.tipOffset.z > pair.1.tipOffset.z)
    }
  }

  #expect(
    poses.allSatisfy {
      abs(simd_length($0.direction) - 1) < 1e-6
        && abs(simd_length($0.normal) - 1) < 1e-6
        && abs(
          simd_distance($0.rootOffset, $0.tipOffset)
            - CrowClosedTailAnatomy.rectrixLengthMeters
        ) < 1e-6
    }
  )
  #expect(poses[5].normal.y < 0)
  #expect(poses[6].normal.y > 0)
  #expect(abs(poses[5].normal.y + poses[6].normal.y) < 1e-6)
  #expect(poses.map { abs($0.normal.y) }.min()! > 0.05)
  #expect(poses.map { abs($0.normal.y) }.max()! < 0.16)

  let tipDepths = poses.map(\.tipOffset.z)
  #expect(tipDepths.max()! - tipDepths.min()! > 0.005)
  #expect(tipDepths.max()! - tipDepths.min()! < 0.0061)
}
