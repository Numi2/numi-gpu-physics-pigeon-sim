import Testing
import simd

@testable import BirdFlowVisualization

@Test("femoral plumage bridges the body loft and upper crural tract")
func femoralPlumageBridgesBodyLoftAndUpperCruralTract() {
  let bodyCenter = SIMD3<Float>.zero
  let leftHip = SIMD3<Float>(-0.025, 0.035, -0.060)
  let leftHock = SIMD3<Float>(-0.014, 0.040, -0.111)
  let rightHip = SIMD3<Float>(-0.025, -0.035, -0.060)
  let rightHock = SIMD3<Float>(-0.014, -0.040, -0.111)
  let left = CrowFemoralPlumage.samples(
    bodyCenter: bodyCenter,
    hip: leftHip,
    hock: leftHock
  )
  let right = CrowFemoralPlumage.samples(
    bodyCenter: bodyCenter,
    hip: rightHip,
    hock: rightHock
  )
  #expect(left.count == CrowFemoralPlumage.rowCount * CrowFemoralPlumage.courseCount)
  #expect(left.count == right.count)

  for pair in zip(left, right) {
    #expect(pair.0.row == pair.1.row)
    #expect(pair.0.course == pair.1.course)
    #expect(abs(pair.0.root.x - pair.1.root.x) < 1e-7)
    #expect(abs(pair.0.root.y + pair.1.root.y) < 1e-7)
    #expect(abs(pair.0.root.z - pair.1.root.z) < 1e-7)
    #expect(abs(pair.0.tip.y + pair.1.tip.y) < 1e-7)
  }

  let legAxis = simd_normalize(leftHock - leftHip)
  let cruralRoots = CrowLegPlumage.samples(hip: leftHip, hock: leftHock).map(\.root)
  for feather in left {
    let clearance = simd_distance(feather.root, feather.rootSurface)
    let tipProjection = simd_dot(feather.tip - leftHip, legAxis)
    let tipAxisPoint = leftHip + tipProjection * legAxis
    #expect(abs(clearance - CrowFemoralPlumage.shellClearanceMeters) < 1e-5)
    #expect(feather.root.y > 0)
    #expect(tipProjection > 0.004)
    #expect(tipProjection < 0.018)
    #expect(simd_distance(feather.tip, tipAxisPoint) > 0.010)
    #expect(simd_distance(feather.tip, tipAxisPoint) < 0.014)
    #expect(simd_distance(feather.root, feather.tip) < 0.070)
    #expect(feather.maximumWidthMeters > feather.rootWidthMeters)
    #expect(abs(simd_length(feather.planeNormal) - 1) < 1e-5)
    #expect(cruralRoots.map { simd_distance($0, feather.tip) }.min()! < 0.025)
  }

  for row in 0..<CrowFemoralPlumage.rowCount {
    let course = left.filter { $0.row == row }.sorted { $0.course < $1.course }
    for pair in zip(course, course.dropFirst()) {
      #expect(
        simd_distance(pair.0.root, pair.1.root)
          < simd_distance(pair.0.root, pair.0.tip)
      )
    }
  }
}
