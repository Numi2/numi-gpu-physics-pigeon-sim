import Testing
import simd

@testable import BirdFlowVisualization

@Test("wingbeat head contour feathers preserve their bilateral source geometry")
func wingbeatHeadContourFeathersPreserveBilateralSourceGeometry() {
  let center = SIMD3<Float>(0.164, 0, 0.052)
  let radii = SIMD3<Float>(0.0447, 0.0328, 0.0387)
  let samples = CrowHeadContourFeathers.samples(center: center, radii: radii)

  #expect(samples == CrowHeadContourFeathers.samples(center: center, radii: radii))
  #expect(
    samples.count
      == 2 * CrowHeadContourFeathers.rowCount * CrowHeadContourFeathers.columnCount
  )
  #expect(samples.count == 40)
  #expect(samples.allSatisfy { $0.surfaceFeatherClass == 0 })

  for sample in samples {
    let fraction = Float(sample.column)
      / Float(CrowHeadContourFeathers.columnCount - 1)
    #expect(abs(sample.root.x - (center.x + 0.025 - 0.054 * fraction)) < 1e-7)
    #expect(abs(simd_length(sample.planeNormal) - 1) < 1e-6)
    #expect(sample.maximumWidthMeters > sample.rootWidthMeters)
    #expect(simd_distance(sample.root, sample.tip) > sample.maximumWidthMeters)
  }

  for row in 0..<CrowHeadContourFeathers.rowCount {
    for column in 0..<CrowHeadContourFeathers.columnCount {
      let left = samples.first {
        $0.side < 0 && $0.row == row && $0.column == column
      }!
      let right = samples.first {
        $0.side > 0 && $0.row == row && $0.column == column
      }!
      #expect(abs(left.root.x - right.root.x) < 1e-7)
      #expect(abs(left.root.y + right.root.y) < 1e-7)
      #expect(abs(left.root.z - right.root.z) < 1e-7)
      #expect(abs(left.tip.x - right.tip.x) < 1e-7)
      #expect(abs(left.tip.y + right.tip.y) < 1e-7)
      #expect(abs(left.tip.z - right.tip.z) < 1e-7)
      #expect(abs(left.planeNormal.x - right.planeNormal.x) < 1e-7)
      #expect(abs(left.planeNormal.y + right.planeNormal.y) < 1e-7)
      #expect(abs(left.planeNormal.z - right.planeNormal.z) < 1e-7)
    }
  }
}
