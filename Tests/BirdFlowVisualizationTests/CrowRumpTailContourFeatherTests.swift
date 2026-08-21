import Testing
import simd

@testable import BirdFlowVisualization

@Test("rump-tail contour vanes overlap while staying outside their underlayer")
func rumpTailContourVanesCoverUnderlayer() {
  let samples = CrowRumpTailContourFeathers.samples()
  #expect(samples == CrowRumpTailContourFeathers.samples())
  #expect(CrowRumpTailContourFeathers.rowCount == 7)
  #expect(samples.count == 168)
  #expect(
    samples.count
      == CrowRumpTailContourFeathers.rowCount
        * CrowRumpTailContourFeathers.columnCount
  )
  #expect(
    CrowRumpTailContourFeathers.visibleSamples(projectedPixelsPerMeter: 1_000)
      .isEmpty
  )
  #expect(
    CrowRumpTailContourFeathers.visibleSamples(projectedPixelsPerMeter: 1_600)
      .count == samples.count
  )
  #expect(Set(samples.map(\.surfaceFeatherClass)) == Set([5, 7]))

  for sample in samples {
    #expect(
      abs(
        simd_distance(sample.rootOffset, sample.rootSurfaceOffset)
          - CrowRumpTailContourFeathers.shellClearanceMeters
      ) < 1e-6
    )
    #expect(
      abs(
        simd_distance(sample.tipOffset, sample.tipSurfaceOffset)
          - CrowRumpTailContourFeathers.shellClearanceMeters
      ) < 1e-6
    )
    #expect(sample.tipOffset.x < sample.rootOffset.x)
    #expect(sample.maximumWidthMeters > sample.rootWidthMeters)
    #expect(abs(simd_length(sample.planeNormal) - 1) < 1e-5)
  }

  for row in 0..<CrowRumpTailContourFeathers.rowCount {
    let ranked = samples.filter { $0.row == row }
    #expect(ranked.map(\.column) == Array(0..<CrowRumpTailContourFeathers.columnCount))
    for column in ranked.indices {
      let next = (column + 1) % ranked.count
      #expect(
        simd_distance(ranked[column].rootOffset, ranked[next].rootOffset)
          < ranked[column].maximumWidthMeters + ranked[next].maximumWidthMeters
      )
    }
  }

  for row in 0..<(CrowRumpTailContourFeathers.rowCount - 1) {
    let current = samples.filter { $0.row == row }
    let next = samples.filter { $0.row == row + 1 }
    #expect(current.map(\.tipOffset.x).max()! < next.map(\.rootOffset.x).min()!)
  }
}

@Test("rump-tail contour vanes resolve future-compute mesostructure")
func rumpTailContourVanesResolveMesostructure() {
  for sample in CrowRumpTailContourFeathers.samples() {
    #expect(
      CrowFeatherMesostructure.segments(
        for: sample,
        projectedPixelsPerMeter: 600
      ).isEmpty
    )
    let resolved = CrowFeatherMesostructure.segments(
      for: sample,
      projectedPixelsPerMeter: 1_600
    )
    #expect(resolved.filter { $0.kind == .rachis }.count == 4)
    #expect(resolved.filter { $0.kind == .edgeBarbGroup }.count == 25)
    #expect(resolved.allSatisfy { simd_distance($0.start, $0.end) > 0 })

    let future = CrowFeatherMesostructure.segments(
      for: sample,
      projectedPixelsPerMeter: 14_000
    )
    #expect(future.contains { $0.kind == .barb })
    #expect(future.count > resolved.count)
  }
}
