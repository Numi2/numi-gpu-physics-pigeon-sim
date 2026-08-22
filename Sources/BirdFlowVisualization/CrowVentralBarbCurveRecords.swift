import simd

/// Explicit close-up barb curves derived from the retained class-7 crown
/// records. Below the microstructure threshold the vane and analytic
/// discontinuity-ray mask remain authoritative; no dormant curve vertices are
/// emitted. At or above 480 projected feather pixels, each interior feather
/// resolves paired, crown-following barbs without changing its stable owner.
enum CrowVentralBarbCurveRecords {
  static let radialSegmentCount = 4
  static let verticesPerCurveInterval = radialSegmentCount * 6
  static let intervalCount = 4
  static let explicitBarbPairCount = 72
  static let maximumBarbPairCount = explicitBarbPairCount
  static let surfaceFeatherClass: UInt32 = 7
  static let projectedFeatherThresholdPixels: Float = 480

  static func segmentWork(
    records: [CrowVentralRachisCurveRecordGPU],
    projectedPixelsPerMeter: Float
  ) -> [CrowVentralBarbSegmentWorkGPU] {
    var work: [CrowVentralBarbSegmentWorkGPU] = []
    for (recordIndex, record) in records.enumerated() {
      let length = simd_distance(
        xyz(record.rootAndPennaceousStart),
        xyz(record.tipAndCamber)
      )
      let tessellation = CrowFeatherCoverageLOD.tessellation(
        lengthMeters: length,
        projectedPixelsPerMeter: projectedPixelsPerMeter,
        baseAxialSections: 7
      )
      guard tessellation.tier == 0 else { continue }
      let pairCount = explicitBarbPairCount
      for pairIndex in 0..<pairCount {
        for sideIndex in 0..<2 {
          for intervalIndex in 0..<intervalCount {
            work.append(
              CrowVentralBarbSegmentWorkGPU(
                indices: SIMD4<UInt32>(
                  UInt32(recordIndex),
                  UInt32(pairIndex),
                  packPairCount(pairCount, sideIndex: sideIndex),
                  packInterval(intervalIndex, count: intervalCount)
                )
              )
            )
          }
        }
      }
    }
    return work
  }

  /// CPU surface geometry keeps the vane, continuity shaft, and aggregate edge
  /// bundles. Individual barbs/barbules are exclusively owned by the retained
  /// curve path once future output coverage can resolve them.
  static func surfaceFallbackSegments(
    for feather: CrowVentralFeatherTractSample,
    projectedPixelsPerMeter: Float,
    explicitCurvesEnabled: Bool = true
  ) -> [CrowFeatherMesostructureSegment] {
    let explicitCurvesActive =
      explicitCurvesEnabled
      && CrowVentralFeatherTracts.retainsCrownRachis(feather)
      && simd_distance(feather.rootOffset, feather.tipOffset)
        * projectedPixelsPerMeter >= projectedFeatherThresholdPixels
    let segments = CrowFeatherMesostructure.segments(
      for: feather,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      transverseCamberRatio: 0
    )
    guard explicitCurvesActive else { return segments }
    return segments.filter {
      $0.kind != .barb && $0.kind != .barbule && $0.kind != .edgeBarbGroup
    }
  }

  static func segment(
    record: CrowVentralRachisCurveRecordGPU,
    work: CrowVentralBarbSegmentWorkGPU
  ) -> CrowFeatherMesostructureSegment {
    let intervalIndex = unpackIntervalIndex(work)
    let intervals = unpackIntervalCount(work)
    let first = Float(intervalIndex) / Float(max(intervals, 1))
    let second = Float(intervalIndex + 1) / Float(max(intervals, 1))
    return CrowFeatherMesostructureSegment(
      kind: .barb,
      start: point(record: record, work: work, curveFraction: first),
      end: point(record: record, work: work, curveFraction: second),
      startRadiusMeters: radius(
        record: record,
        work: work,
        curveFraction: first
      ),
      endRadiusMeters: radius(
        record: record,
        work: work,
        curveFraction: second
      )
    )
  }

  static func point(
    record: CrowVentralRachisCurveRecordGPU,
    work: CrowVentralBarbSegmentWorkGPU,
    curveFraction: Float
  ) -> SIMD3<Float> {
    let pairIndex = Int(work.indices.y)
    let pairCount = max(unpackPairCount(work), 1)
    let sideIndex = unpackSideIndex(work)
    let side: Float = sideIndex == 0 ? -1 : 1
    let spacing = 0.77 / Float(pairCount + 1)
    let attachmentVariation = variation(
      record: record,
      pairIndex: pairIndex,
      sideIndex: sideIndex,
      salt: 0x9E37_79B9
    )
    let curvatureVariation = variation(
      record: record,
      pairIndex: pairIndex,
      sideIndex: sideIndex,
      salt: 0x85EB_CA6B
    )
    let localAxial =
      0.10 + spacing * Float(pairIndex + 1)
      + 0.24 * spacing * attachmentVariation
    let localReach = min(
      0.94,
      localAxial + 0.030 + 0.018 * localAxial
        + 0.16 * spacing * curvatureVariation
    )
    let pennaceousStart = record.rootAndPennaceousStart.w
    let firstAxial = pennaceousStart + (1 - pennaceousStart) * localAxial
    let secondAxial = pennaceousStart + (1 - pennaceousStart) * localReach
    let t = min(max(curveFraction, 0), 1)
    let axial = firstAxial + (secondAxial - firstAxial) * t
    let center = CrowVentralRachisCurveRecords.center(
      record: record,
      axial: axial
    )
    let root = xyz(record.rootAndPennaceousStart)
    let tip = xyz(record.tipAndCamber)
    let normal = xyz(record.normalAndTransverseCamber)
    let direction = normalized(tip - root, fallback: SIMD3<Float>(-1, 0, 0))
    let widthAxis = normalized(
      simd_cross(normal, direction),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    let halfWidth = CrowVentralRachisCurveRecords.halfWidth(
      record: record,
      axial: axial,
      signedWidth: side
    )
    // Ease the lateral reach so the curve leaves the rachis coherently, then
    // follows the changing vane crown instead of cutting a straight chord.
    let lateralExponent = 0.82 + 0.08 * curvatureVariation
    let lateralFraction =
      (0.955 + 0.012 * attachmentVariation)
      * pow(t, lateralExponent)
    let crownSeparation =
      0.000030
      + (0.000022 + 0.000008 * curvatureVariation) * sin(Float.pi * t)
    return center
      + side * widthAxis * halfWidth * lateralFraction
      + normal * crownSeparation
  }

  static func radius(
    record: CrowVentralRachisCurveRecordGPU,
    work: CrowVentralBarbSegmentWorkGPU,
    curveFraction: Float
  ) -> Float {
    let t = min(max(curveFraction, 0), 1)
    let scale =
      1 + 0.12
      * variation(
        record: record,
        pairIndex: Int(work.indices.y),
        sideIndex: unpackSideIndex(work),
        salt: 0xC2B2_AE35
      )
    return scale * (0.000026 + (0.000004 - 0.000026) * pow(t, 0.88))
  }

  static func unpackPairCount(_ work: CrowVentralBarbSegmentWorkGPU) -> Int {
    Int(work.indices.z & 0xffff)
  }

  static func unpackSideIndex(_ work: CrowVentralBarbSegmentWorkGPU) -> Int {
    Int((work.indices.z >> 16) & 1)
  }

  static func unpackIntervalIndex(_ work: CrowVentralBarbSegmentWorkGPU) -> Int {
    Int(work.indices.w & 0xffff)
  }

  static func unpackIntervalCount(_ work: CrowVentralBarbSegmentWorkGPU) -> Int {
    Int(work.indices.w >> 16)
  }

  private static func packPairCount(_ count: Int, sideIndex: Int) -> UInt32 {
    UInt32(count) | (UInt32(sideIndex) << 16)
  }

  private static func packInterval(_ index: Int, count: Int) -> UInt32 {
    UInt32(index) | (UInt32(count) << 16)
  }

  private static func variation(
    record: CrowVentralRachisCurveRecordGPU,
    pairIndex: Int,
    sideIndex: Int,
    salt: UInt32
  ) -> Float {
    var value = record.identity.x &* 0xA511_E9B3
    value ^= record.identity.y &* 0x63D8_3595
    value ^= record.identity.z &* 0x9E37_79B9
    value ^= record.identity.w &* 0x85EB_CA6B
    value ^= UInt32(pairIndex) &* 0xC2B2_AE35
    value ^= UInt32(sideIndex) &* 0x27D4_EB2F
    value ^= salt
    value ^= value >> 16
    value &*= 0x7FEB_352D
    value ^= value >> 15
    value &*= 0x846C_A68B
    value ^= value >> 16
    return 2 * Float(value & 0x00FF_FFFF) / Float(0x00FF_FFFF) - 1
  }

  private static func xyz(_ value: SIMD4<Float>) -> SIMD3<Float> {
    SIMD3<Float>(value.x, value.y, value.z)
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    simd_length_squared(value) > 1e-14 ? simd_normalize(value) : fallback
  }
}
