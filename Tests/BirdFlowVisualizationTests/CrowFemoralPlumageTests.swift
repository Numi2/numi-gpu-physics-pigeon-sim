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
  #expect(left.count == 108)
  #expect(left.count == right.count)
  #expect(
    CrowFemoralPlumage.visibleSamples(
      bodyCenter: bodyCenter,
      hip: leftHip,
      hock: leftHock,
      projectedPixelsPerMeter: 800
    ).count == 35
  )
  #expect(
    CrowFemoralPlumage.visibleSamples(
      bodyCenter: bodyCenter,
      hip: leftHip,
      hock: leftHock,
      projectedPixelsPerMeter: 1_000
    ).count == 35
  )
  #expect(
    CrowFemoralPlumage.visibleSamples(
      bodyCenter: bodyCenter,
      hip: leftHip,
      hock: leftHock,
      projectedPixelsPerMeter: 1_600
    ).count == 108
  )
  #expect(
    left
      == CrowFemoralPlumage.samples(
        bodyCenter: bodyCenter,
        hip: leftHip,
        hock: leftHock
      )
  )
  #expect(left.map(\.materialVariation).min()! < -0.90)
  #expect(left.map(\.materialVariation).max()! > 0.90)
  #expect(left.allSatisfy { $0.bodyMaterialBlend >= 0.60 })
  #expect(left.allSatisfy { $0.bodyMaterialBlend <= 0.88 })
  #expect(
    CrowFemoralPlumage.visibleSamples(
      bodyCenter: bodyCenter,
      hip: leftHip,
      hock: leftHock,
      projectedPixelsPerMeter: 1_000
    ).allSatisfy {
      $0.materialVariation == 0 && $0.bodyMaterialBlend == 0
    }
  )

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
    let length = simd_distance(feather.root, feather.tip)
    #expect(abs(clearance - CrowFemoralPlumage.shellClearanceMeters) < 1e-5)
    #expect(feather.root.y > 0)
    #expect(length > 0.015)
    #expect(length < 0.032)
    #expect(simd_dot(feather.tip - feather.root, legAxis) > 0)
    #expect(feather.maximumWidthMeters > feather.rootWidthMeters)
    #expect(abs(simd_length(feather.planeNormal) - 1) < 1e-5)
    let rootNormal = simd_normalize(feather.root - feather.rootSurface)
    #expect(simd_dot(rootNormal, feather.planeNormal) > 0.94)
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

  for course in 0..<CrowFemoralPlumage.courseCount {
    let row = left.filter { $0.course == course }.sorted { $0.row < $1.row }
    #expect(row.count == CrowFemoralPlumage.rowCount)
    for pair in zip(row, row.dropFirst()) {
      #expect(
        simd_distance(pair.0.root, pair.1.root)
          < pair.0.maximumWidthMeters + pair.1.maximumWidthMeters
      )
      #expect(abs(pair.0.root.x - pair.1.root.x) > 0.002)
    }
  }
}
