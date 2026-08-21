import Testing
import simd

@testable import BirdFlowVisualization

@Test("dorsal covert barb bundles are LOD selected and vane contained")
func dorsalCovertBarbBundlesAreLODSelectedAndVaneContained() {
  let root = SIMD3<Float>(0.05, 0.02, 0.01)
  let tip = SIMD3<Float>(-0.09, 0.05, 0.015)
  let normal = simd_normalize(SIMD3<Float>(0.04, -0.03, 1))
  func segments(_ pixelsPerMeter: Float) -> [CrowFeatherMesostructureSegment] {
    CrowWingCovertBarbDetail.segments(
      root: root,
      tip: tip,
      planeNormal: normal,
      rootWidthMeters: 0.008,
      maximumWidthMeters: 0.014,
      camberMeters: 0.0012,
      transverseCamberRatio: 0.16,
      vaneAsymmetry: 0.12,
      edgeRippleAmplitude: 0.015,
      edgeRipplePhase: 0.7,
      edgeRippleCycles: 1.6,
      lodLengthMeters: 0.12,
      projectedPixelsPerMeter: pixelsPerMeter
    )
  }
  #expect(segments(0).isEmpty)
  #expect(segments(400).count == 20)
  #expect(segments(1_400).count == 18)
  #expect(segments(4_000).count == 36)

  let resolved = segments(1_400)
  #expect(resolved.allSatisfy { $0.kind == .edgeBarbGroup })
  #expect(resolved.allSatisfy { $0.startRadiusMeters > $0.endRadiusMeters })
  #expect(resolved.allSatisfy { $0.endRadiusMeters > 0 })
  let axis = simd_normalize(tip - root)
  for segment in resolved {
    let startFraction =
      simd_dot(segment.start - root, axis)
      / simd_distance(root, tip)
    let endFraction =
      simd_dot(segment.end - root, axis)
      / simd_distance(root, tip)
    #expect(startFraction > 0.17 && startFraction < 0.85)
    #expect(endFraction > startFraction && endFraction < 0.93)
    #expect(simd_distance(segment.start, segment.end) < 0.025)
  }
}
