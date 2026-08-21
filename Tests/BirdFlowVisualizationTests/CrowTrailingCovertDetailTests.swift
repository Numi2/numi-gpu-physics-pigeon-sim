import Testing
import simd

@testable import BirdFlowVisualization

@Test("two trailing covert ranks own finite contained detail")
func twoTrailingCovertRanksOwnFiniteContainedDetail() {
  let root = SIMD3<Float>(0.05, 0.02, 0.01)
  let tip = SIMD3<Float>(-0.10, 0.05, 0.02)
  let normal = simd_normalize(SIMD3<Float>(0.03, -0.04, 1))
  func segments(_ deployment: Float) -> [CrowFeatherMesostructureSegment] {
    CrowTrailingCovertDetail.segments(
      root: root,
      tip: tip,
      planeNormal: normal,
      rootWidthMeters: 0.008,
      maximumWidthMeters: 0.015,
      camberMeters: 0.0011,
      transverseCamberRatio: 0.16,
      vaneAsymmetry: 0.10,
      edgeRippleAmplitude: 0.014,
      edgeRipplePhase: 0.8,
      edgeRippleCycles: 1.5,
      baseRadiusMeters: 0.00018,
      deployment: deployment,
      lodLengthMeters: 0.12,
      projectedPixelsPerMeter: 1_400
    )
  }
  let folded = segments(0)
  let deployed = segments(1)
  #expect(folded.count == deployed.count)
  #expect(deployed.filter { $0.kind == .rachis }.count == 8)
  #expect(deployed.filter { $0.kind == .edgeBarbGroup }.count == 16)
  #expect(folded.allSatisfy { $0.startRadiusMeters == 0 })
  #expect(folded.allSatisfy { $0.endRadiusMeters == 0 })
  #expect(deployed.allSatisfy { $0.startRadiusMeters > 0 })
  #expect(deployed.allSatisfy { $0.endRadiusMeters > 0 })
  #expect(
    deployed.allSatisfy {
      $0.start.x.isFinite && $0.start.y.isFinite && $0.start.z.isFinite
        && $0.end.x.isFinite && $0.end.y.isFinite && $0.end.z.isFinite
    }
  )
  #expect(
    zip(folded, deployed).allSatisfy {
      simd_distance($0.start, $1.start) > 0
        || simd_distance($0.end, $1.end) > 0
    }
  )
}
