import Testing
import simd

@testable import BirdFlowVisualization

@Test("crow trunk cross-section separates shoulder, breast, and pelvic regions")
func crowTrunkCrossSectionSeparatesAnatomicalRegions() {
  let shoulder = CrowBodyAnatomy.loftRings[CrowBodyAnatomy.shoulderRingIndex]
  let upperFlank = CrowBodyAnatomy.surfacePoint(ring: shoulder, theta: 0.42)
  let lowerFlank = CrowBodyAnatomy.surfacePoint(ring: shoulder, theta: -0.42)
  #expect(abs(upperFlank.y) > 1.12 * abs(lowerFlank.y))

  let ellipticalUpperZ = shoulder.z + sin(0.42) * shoulder.dorsalRadius
  let ellipticalLowerZ = shoulder.z - sin(0.42) * shoulder.ventralRadius
  #expect(upperFlank.z < ellipticalUpperZ)
  #expect(lowerFlank.z < ellipticalLowerZ)

  let sternum = CrowBodyAnatomy.interpolatedRing(atX: 0)
  let pelvis = CrowBodyAnatomy.interpolatedRing(atX: -0.13)
  let sternumLower = CrowBodyAnatomy.surfacePoint(ring: sternum, theta: -0.62)
  let pelvisLower = CrowBodyAnatomy.surfacePoint(ring: pelvis, theta: -0.62)
  let sternumNormalizedWidth = abs(sternumLower.y) / sternum.halfWidth
  let pelvisNormalizedWidth = abs(pelvisLower.y) / pelvis.halfWidth
  #expect(pelvisNormalizedWidth < sternumNormalizedWidth)

  let cranialBodyRings = CrowBodyAnatomy.loftRings.suffix(3)
  #expect(cranialBodyRings.last!.halfWidth > 0.030)
  #expect(cranialBodyRings.last!.dorsalRadius >= 0.040)
  #expect(
    zip(cranialBodyRings, cranialBodyRings.dropFirst()).allSatisfy {
      abs($1.halfWidth - $0.halfWidth) < 0.008
        && abs(($1.z + $1.dorsalRadius) - ($0.z + $0.dorsalRadius)) < 0.012
    }
  )
}

@Test("crow anatomical body surface provides finite outward unit normals")
func crowAnatomicalBodySurfaceProvidesOutwardUnitNormals() {
  let xs: [Float] = [-0.16, -0.09, 0, 0.044, 0.105]
  for x in xs {
    let ring = CrowBodyAnatomy.interpolatedRing(atX: x)
    for index in 0..<24 {
      let theta = 2 * Float.pi * Float(index) / 24
      let point = CrowBodyAnatomy.surfacePoint(ring: ring, theta: theta)
      let normal = CrowBodyAnatomy.surfaceNormal(atX: x, theta: theta)
      let radial = SIMD3<Float>(0, point.y, point.z - ring.z)
      #expect(normal.x.isFinite && normal.y.isFinite && normal.z.isFinite)
      #expect(abs(simd_length(normal) - 1) < 1e-5)
      #expect(simd_dot(normal, radial) > 0)
    }
  }
}
