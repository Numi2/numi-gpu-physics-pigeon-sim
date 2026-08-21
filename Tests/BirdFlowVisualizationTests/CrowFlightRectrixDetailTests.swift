import Testing
import simd

@testable import BirdFlowVisualization

@Test("flight rectrix rachis detail is LOD selected and vane contained")
func flightRectrixRachisDetailIsLODSelectedAndVaneContained() {
  let pose = CrowTakeoffSequence.flightRectrixPose(
    order: 5,
    count: CrowClosedTailAnatomy.rectrixCount
  )
  let root = pose.rootOffset
  let tip = root + 0.166 * pose.direction
  #expect(
    CrowFlightRectrixDetail.rachisSegments(
      root: root,
      tip: tip,
      planeNormal: pose.normal,
      baseRadiusMeters: 0.0009,
      projectedPixelsPerMeter: 0
    ).isEmpty
  )

  let segments = CrowFlightRectrixDetail.rachisSegments(
    root: root,
    tip: tip,
    planeNormal: pose.normal,
    baseRadiusMeters: 0.0009,
    projectedPixelsPerMeter: 1_400
  )
  #expect(segments.count == 8)
  #expect(segments.allSatisfy { $0.kind == .rachis })
  #expect(simd_distance(segments.first!.start, root) < 1e-7)
  #expect(segments.last!.endRadiusMeters < segments.first!.startRadiusMeters)
  #expect(
    abs(
      segments.last!.endRadiusMeters
        / segments.first!.startRadiusMeters
        - CrowFlightRectrixDetail.terminalRadiusScale
    ) < 0.02
  )
  for pair in zip(segments, segments.dropFirst()) {
    #expect(simd_distance(pair.0.end, pair.1.start) < 1e-7)
    #expect(abs(pair.0.endRadiusMeters - pair.1.startRadiusMeters) < 1e-7)
  }
  let axial = simd_dot(segments.last!.end - root, pose.direction) / 0.166
  #expect(axial > 0.98)
  #expect(axial < 1)
  #expect(simd_distance(segments.last!.end, tip) < 0.008)
}
