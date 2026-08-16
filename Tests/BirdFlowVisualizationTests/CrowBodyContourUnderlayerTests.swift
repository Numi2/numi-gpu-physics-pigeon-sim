import Testing
import simd

@testable import BirdFlowVisualization

@Test("body contour underlayer appears only when plumulaceous barbs resolve")
func bodyContourUnderlayerFollowsFinalOutputCoverage() {
  let feather = CrowBodyContourShingles.samples()[117]
  let length = simd_distance(feather.rootOffset, feather.tipOffset)
  let ordinary = CrowBodyContourUnderlayer.segments(
    for: feather,
    projectedPixelsPerMeter: 48 / length
  )
  let close = CrowBodyContourUnderlayer.segments(
    for: feather,
    projectedPixelsPerMeter: 180 / length
  )
  let future = CrowBodyContourUnderlayer.segments(
    for: feather,
    projectedPixelsPerMeter: 520 / length
  )

  #expect(ordinary.isEmpty)
  #expect(close.count == 8)
  #expect(future.count == 20)

  let axis = simd_normalize(feather.tipOffset - feather.rootOffset)
  for segment in future {
    let startFraction =
      simd_dot(segment.start - feather.rootOffset, axis) / length
    let endFraction =
      simd_dot(segment.end - feather.rootOffset, axis) / length
    #expect(startFraction > 0.05)
    #expect(endFraction > startFraction)
    #expect(endFraction < feather.pennaceousStartFraction)
    #expect(segment.startRadiusMeters > segment.endRadiusMeters)
    #expect(segment.endRadiusMeters > 0)
    #expect(segment.start.x.isFinite && segment.end.x.isFinite)
    #expect(segment.start.y.isFinite && segment.end.y.isFinite)
    #expect(segment.start.z.isFinite && segment.end.z.isFinite)
  }
}
