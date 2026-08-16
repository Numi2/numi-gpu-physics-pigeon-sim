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

  let visibleAnterior =
    CrowBodyAnatomy.loftRings[CrowBodyAnatomy.visibleAnteriorRingIndex]
  #expect(visibleAnterior.halfWidth > 0.030)
  #expect(visibleAnterior.dorsalRadius >= 0.040)
  let cervicalSleeve = CrowBodyAnatomy.cervicalSleeveRingRange.map {
    CrowBodyAnatomy.loftRings[$0]
  }
  #expect(
    zip(cervicalSleeve, cervicalSleeve.dropFirst()).allSatisfy {
      $0.x < $1.x
        && $0.halfWidth > $1.halfWidth
        && $0.dorsalRadius > $1.dorsalRadius
        && $0.ventralRadius > $1.ventralRadius
    }
  )
  #expect(cervicalSleeve.last!.halfWidth < 0.5 * visibleAnterior.halfWidth)
}

@Test("closed cervical sleeve terminates inside the cranial loft")
func closedCervicalSleeveTerminatesInsideCranialLoft() {
  let headCenter = CrowCranialAnatomy.showcaseCenterOffsetMeters
  let headRadii = SIMD3<Float>(0.052, 0.041, 0.044)
    * CrowCranialAnatomy.showcaseRadiusScale
  let cranialRings = CrowCranialAnatomy.sampledLoftRings()
  let sleeve = CrowBodyAnatomy.cervicalSleeveRingRange.map {
    CrowBodyAnatomy.loftRings[$0]
  }

  for bodyRing in sleeve {
    let axialFraction = (bodyRing.x - headCenter.x) / headRadii.x
    let cranialRing = cranialRings.min {
      abs($0.axialFraction - axialFraction)
        < abs($1.axialFraction - axialFraction)
    }!
    #expect(abs(cranialRing.axialFraction - axialFraction) < 0.06)
    let cranialHalfWidth = headRadii.y * cranialRing.halfWidthFraction
    let cranialTop = headCenter.z + headRadii.z
      * (cranialRing.verticalFraction + cranialRing.dorsalRadiusFraction)
    let cranialBottom = headCenter.z + headRadii.z
      * (cranialRing.verticalFraction - cranialRing.ventralRadiusFraction)
    #expect(bodyRing.halfWidth + 0.0005 < cranialHalfWidth)
    #expect(bodyRing.z + bodyRing.dorsalRadius + 0.0005 < cranialTop)
    #expect(bodyRing.z - bodyRing.ventralRadius - 0.0005 > cranialBottom)
  }

  #expect(
    CrowHeadNeckBlend.coupling(axialOffsetMeters: sleeve.last!.x) == 1
  )
}

@Test("crow anatomical body surface provides finite outward unit normals")
func crowAnatomicalBodySurfaceProvidesOutwardUnitNormals() {
  let xs: [Float] = [-0.16, -0.09, 0, 0.044, 0.105, 0.162, 0.174]
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
