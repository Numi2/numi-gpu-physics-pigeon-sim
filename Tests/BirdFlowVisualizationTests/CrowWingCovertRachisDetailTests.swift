import Testing
import simd

@testable import BirdFlowVisualization

@Test("dorsal covert rachis detail is LOD selected and vane contained")
func dorsalCovertRachisDetailIsLODSelectedAndVaneContained() {
  let root = SIMD3<Float>(0.04, 0.12, 0.01)
  let tip = SIMD3<Float>(-0.08, 0.15, 0.02)
  let normal = simd_normalize(SIMD3<Float>(0.08, -0.04, 1))
  #expect(
    CrowWingCovertRachisDetail.segments(
      root: root,
      tip: tip,
      planeNormal: normal,
      camberMeters: 0.0012,
      baseRadiusMeters: 0.00020,
      lodLengthMeters: 0.12,
      projectedPixelsPerMeter: 0
    ).isEmpty
  )

  let segments = CrowWingCovertRachisDetail.segments(
    root: root,
    tip: tip,
    planeNormal: normal,
    camberMeters: 0.0012,
    baseRadiusMeters: 0.00020,
    lodLengthMeters: 0.12,
    projectedPixelsPerMeter: 1_400
  )
  #expect(segments.count == 8)
  #expect(segments.allSatisfy { $0.kind == .rachis })
  #expect(segments.first!.startRadiusMeters == 0.00020)
  #expect(segments.last!.endRadiusMeters < segments.first!.startRadiusMeters)
  #expect(
    abs(
      segments.last!.endRadiusMeters / segments.first!.startRadiusMeters
        - CrowWingCovertRachisDetail.terminalRadiusScale
    ) < 1e-6
  )
  for pair in zip(segments, segments.dropFirst()) {
    #expect(simd_distance(pair.0.end, pair.1.start) < 1e-7)
    #expect(abs(pair.0.endRadiusMeters - pair.1.startRadiusMeters) < 1e-7)
  }
  let direction = simd_normalize(tip - root)
  let firstAxial =
    simd_dot(segments.first!.start - root, direction)
    / simd_distance(root, tip)
  let lastAxial =
    simd_dot(segments.last!.end - root, direction)
    / simd_distance(root, tip)
  #expect(firstAxial > 0.035 && firstAxial < 0.045)
  #expect(lastAxial > 0.96 && lastAxial < 0.97)
}
