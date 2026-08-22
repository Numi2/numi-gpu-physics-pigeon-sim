import simd

/// Explicit barb curves derived from the retained class-7 crown records.
/// Once a feather spans 40 projected pixels, ten paired crown-following barbs
/// replace its coarse edge ribbons. At or above 480 pixels, each interior
/// feather resolves the full close tier without changing its stable owner.
/// At 800 pixels a second, independently gated tier resolves two crossed
/// barbule branches inside the parent vane; ordinary and barb-only closeups
/// remain byte-identical.
enum CrowVentralBarbCurveRecords {
  static let radialSegmentCount = 4
  static let verticesPerCurveInterval = radialSegmentCount * 6
  static let intervalCount = 4
  static let aggregateBarbPairCount = 10
  static let explicitBarbPairCount = 72
  static let maximumBarbPairCount = explicitBarbPairCount
  static let surfaceFeatherClass: UInt32 = 7
  static let projectedAggregateBarbThresholdPixels: Float = 40
  static let projectedFeatherThresholdPixels: Float = 480
  static let projectedBarbuleThresholdPixels: Float = 800
  static let explicitBarbulesPerBranch = 6
  static let barbuleBranchCount = 2
  static let visibilityPaddingMeters: Float = 0.0004
  static let previousDepthBias: Float = 0.00025

  static func segmentWork(
    records: [CrowVentralRachisCurveRecordGPU],
    projectedPixelsPerMeter: Float
  ) -> [CrowVentralBarbSegmentWorkGPU] {
    var work: [CrowVentralBarbSegmentWorkGPU] = []
    for packedRecordIndex in activeRecordIndices(
      records: records,
      projectedPixelsPerMeter: projectedPixelsPerMeter
    ) {
      let recordIndex = Int(packedRecordIndex)
      let pairCount = barbPairCount(
        records[recordIndex],
        projectedPixelsPerMeter: projectedPixelsPerMeter
      )
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
      if recordSupportsBarbules(
        records[recordIndex],
        projectedPixelsPerMeter: projectedPixelsPerMeter
      ) {
        for pairIndex in 0..<pairCount {
          for sideIndex in 0..<2 {
            for branchIndex in 0..<barbuleBranchCount {
              for barbuleIndex in 0..<explicitBarbulesPerBranch {
                work.append(
                  CrowVentralBarbSegmentWorkGPU(
                    indices: SIMD4<UInt32>(
                      UInt32(recordIndex),
                      UInt32(pairIndex),
                      packPairCount(pairCount, sideIndex: sideIndex),
                      packBarbule(
                        barbuleIndex,
                        count: explicitBarbulesPerBranch,
                        branchIndex: branchIndex
                      )
                    )
                  )
                )
              }
            }
          }
        }
      }
    }
    return work
  }

  static func activeBarbuleRecordIndices(
    records: [CrowVentralRachisCurveRecordGPU],
    projectedPixelsPerMeter: Float
  ) -> [UInt32] {
    records.indices.compactMap { index in
      recordSupportsBarbules(
        records[index],
        projectedPixelsPerMeter: projectedPixelsPerMeter
      ) ? UInt32(index) : nil
    }
  }

  static func activeCloseRecordIndices(
    records: [CrowVentralRachisCurveRecordGPU],
    projectedPixelsPerMeter: Float
  ) -> [UInt32] {
    records.indices.compactMap { index in
      lodReferenceLength(records[index]) * projectedPixelsPerMeter
        >= projectedFeatherThresholdPixels ? UInt32(index) : nil
    }
  }

  static func recordSupportsBarbules(
    _ record: CrowVentralRachisCurveRecordGPU,
    projectedPixelsPerMeter: Float
  ) -> Bool {
    lodReferenceLength(record) * projectedPixelsPerMeter
      >= projectedBarbuleThresholdPixels
  }

  static func activeRecordIndices(
    records: [CrowVentralRachisCurveRecordGPU],
    projectedPixelsPerMeter: Float
  ) -> [UInt32] {
    records.indices.compactMap { index in
      barbPairCount(
        records[index],
        projectedPixelsPerMeter: projectedPixelsPerMeter
      ) > 0 ? UInt32(index) : nil
    }
  }

  static func barbPairCount(
    _ record: CrowVentralRachisCurveRecordGPU,
    projectedPixelsPerMeter: Float
  ) -> Int {
    let projectedLength = lodReferenceLength(record) * projectedPixelsPerMeter
    if projectedLength >= projectedFeatherThresholdPixels {
      return explicitBarbPairCount
    }
    if projectedLength >= projectedAggregateBarbThresholdPixels {
      return aggregateBarbPairCount
    }
    return 0
  }

  static func candidateBarbWorkCount(
    records: [CrowVentralRachisCurveRecordGPU],
    projectedPixelsPerMeter: Float
  ) -> Int {
    records.reduce(0) { result, record in
      result
        + barbPairCount(
          record,
          projectedPixelsPerMeter: projectedPixelsPerMeter
        ) * 2 * intervalCount
    }
  }

  private static func lodReferenceLength(
    _ record: CrowVentralRachisCurveRecordGPU
  ) -> Float {
    let retained = record.lateralSweepAndReserved.y
    return retained > 0
      ? retained
      : simd_distance(
        xyz(record.rootAndPennaceousStart),
        xyz(record.tipAndCamber)
      )
  }

  static func visibilityUniforms(
    viewProjection: simd_float4x4,
    currentBodyCenter: SIMD3<Float>,
    projectedPixelsPerMeter: Float,
    recordCount: Int,
    previousViewProjection: simd_float4x4 = matrix_identity_float4x4,
    occlusionViewport: SIMD2<Int> = .zero,
    occlusionEnabled: Bool = false
  ) -> CrowVentralBarbVisibilityUniforms {
    let row0 = SIMD4<Float>(
      viewProjection.columns.0.x,
      viewProjection.columns.1.x,
      viewProjection.columns.2.x,
      viewProjection.columns.3.x
    )
    let row1 = SIMD4<Float>(
      viewProjection.columns.0.y,
      viewProjection.columns.1.y,
      viewProjection.columns.2.y,
      viewProjection.columns.3.y
    )
    let row2 = SIMD4<Float>(
      viewProjection.columns.0.z,
      viewProjection.columns.1.z,
      viewProjection.columns.2.z,
      viewProjection.columns.3.z
    )
    let row3 = SIMD4<Float>(
      viewProjection.columns.0.w,
      viewProjection.columns.1.w,
      viewProjection.columns.2.w,
      viewProjection.columns.3.w
    )
    return CrowVentralBarbVisibilityUniforms(
      leftPlane: normalizedPlane(row3 + row0),
      rightPlane: normalizedPlane(row3 - row0),
      bottomPlane: normalizedPlane(row3 + row1),
      topPlane: normalizedPlane(row3 - row1),
      nearPlane: normalizedPlane(row2),
      farPlane: normalizedPlane(row3 - row2),
      bodyCenterAndPadding: SIMD4<Float>(
        currentBodyCenter,
        visibilityPaddingMeters
      ),
      occlusionBodyCenterAndPadding: SIMD4<Float>(
        currentBodyCenter,
        visibilityPaddingMeters
      ),
      selection: SIMD4<Float>(
        projectedPixelsPerMeter,
        projectedAggregateBarbThresholdPixels,
        Float(explicitBarbPairCount),
        Float(intervalCount)
      ),
      counts: SIMD4<UInt32>(
        UInt32(recordCount),
        UInt32(verticesPerCurveInterval),
        surfaceFeatherClass,
        UInt32(aggregateBarbPairCount)
      ),
      barbuleSelection: SIMD4<Float>(
        projectedBarbuleThresholdPixels,
        Float(explicitBarbulesPerBranch),
        Float(barbuleBranchCount),
        projectedFeatherThresholdPixels
      ),
      previousViewProjection: previousViewProjection,
      occlusionViewportBiasAndEnabled: SIMD4<Float>(
        Float(occlusionViewport.x),
        Float(occlusionViewport.y),
        previousDepthBias,
        occlusionEnabled ? 1 : 0
      )
    )
  }

  static func visibleRecordIndices(
    records: [CrowVentralRachisCurveRecordGPU],
    uniforms: CrowVentralBarbVisibilityUniforms
  ) -> [UInt32] {
    records.indices.compactMap { index in
      isVisible(record: records[index], uniforms: uniforms)
        ? UInt32(index) : nil
    }
  }

  static func isVisible(
    record: CrowVentralRachisCurveRecordGPU,
    uniforms: CrowVentralBarbVisibilityUniforms
  ) -> Bool {
    let root = xyz(record.rootAndPennaceousStart)
    let tip = xyz(record.tipAndCamber)
    let length = simd_distance(root, tip)
    guard length * uniforms.selection.x >= uniforms.selection.y else {
      return false
    }
    let bounds = boundingSphere(
      record: record,
      bodyCenter: xyz(uniforms.bodyCenterAndPadding),
      paddingMeters: uniforms.bodyCenterAndPadding.w
    )
    return [
      uniforms.leftPlane,
      uniforms.rightPlane,
      uniforms.bottomPlane,
      uniforms.topPlane,
      uniforms.nearPlane,
      uniforms.farPlane,
    ].allSatisfy { plane in
      simd_dot(xyz(plane), bounds.center) + plane.w >= -bounds.radius
    }
  }

  static func boundingSphere(
    record: CrowVentralRachisCurveRecordGPU,
    bodyCenter: SIMD3<Float>,
    paddingMeters: Float = visibilityPaddingMeters
  ) -> (center: SIMD3<Float>, radius: Float) {
    let root = xyz(record.rootAndPennaceousStart)
    let tip = xyz(record.tipAndCamber)
    let maximumWidth =
      record.widthsEnvelopeAndAsymmetry.y
      * (1 + abs(record.widthsEnvelopeAndAsymmetry.w))
    return (
      center: 0.5 * (root + tip) + bodyCenter,
      radius: 0.5 * simd_distance(root, tip) + maximumWidth
        + abs(record.tipAndCamber.w)
        + abs(record.normalAndTransverseCamber.w) * maximumWidth
        + abs(record.lateralSweepAndReserved.x)
        + paddingMeters
    )
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
      && feather.lodReferenceLengthMeters
        * projectedPixelsPerMeter >= projectedAggregateBarbThresholdPixels
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
    if isBarbule(work) {
      return CrowFeatherMesostructureSegment(
        kind: .barbule,
        start: barbulePoint(record: record, work: work, segmentFraction: 0),
        end: barbulePoint(record: record, work: work, segmentFraction: 1),
        startRadiusMeters: barbuleRadius(
          record: record,
          work: work,
          segmentFraction: 0
        ),
        endRadiusMeters: barbuleRadius(
          record: record,
          work: work,
          segmentFraction: 1
        )
      )
    }
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

  /// Stable coordinates of the explicit barbule endpoints in the owning
  /// vane. The lateral coordinate is bounded below one, so neither crossed
  /// branch can become a new body silhouette owner.
  static func barbuleVaneCoordinates(
    record: CrowVentralRachisCurveRecordGPU,
    work: CrowVentralBarbSegmentWorkGPU,
    segmentFraction: Float
  ) -> SIMD2<Float> {
    precondition(isBarbule(work))
    let rootFraction = barbuleRootFraction(work)
    let rootAxial = barbAxial(record: record, work: work, curveFraction: rootFraction)
    let pairCount = max(unpackPairCount(work), 1)
    let pennaceousStart = record.rootAndPennaceousStart.w
    let branchSign: Float = unpackBarbuleBranchIndex(work) == 0 ? -1 : 1
    let axialSpacing = (1 - pennaceousStart) * 0.77 / Float(pairCount + 1)
    let targetAxial = min(
      0.96,
      max(pennaceousStart + 0.015, rootAxial + 0.46 * branchSign * axialSpacing)
    )
    let rootLateral = barbLateralFraction(
      record: record,
      work: work,
      curveFraction: rootFraction
    )
    let side: Float = unpackSideIndex(work) == 0 ? -1 : 1
    let targetLateral = min(
      0.93,
      rootLateral * (0.985 + 0.012 * branchSign * side)
    )
    let t = min(max(segmentFraction, 0), 1)
    return SIMD2<Float>(
      rootAxial + t * (targetAxial - rootAxial),
      side * (rootLateral + t * (targetLateral - rootLateral))
    )
  }

  static func barbulePoint(
    record: CrowVentralRachisCurveRecordGPU,
    work: CrowVentralBarbSegmentWorkGPU,
    segmentFraction: Float
  ) -> SIMD3<Float> {
    let coordinates = barbuleVaneCoordinates(
      record: record,
      work: work,
      segmentFraction: segmentFraction
    )
    let root = xyz(record.rootAndPennaceousStart)
    let tip = xyz(record.tipAndCamber)
    let normal = xyz(record.normalAndTransverseCamber)
    let direction = normalized(tip - root, fallback: SIMD3<Float>(-1, 0, 0))
    let widthAxis = normalized(
      simd_cross(normal, direction),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    let side: Float = coordinates.y < 0 ? -1 : 1
    let halfWidth = CrowVentralRachisCurveRecords.halfWidth(
      record: record,
      axial: coordinates.x,
      signedWidth: side
    )
    let rootFraction = barbuleRootFraction(work)
    let curvatureVariation = variation(
      record: record,
      pairIndex: Int(work.indices.y),
      sideIndex: unpackSideIndex(work),
      salt: 0x85EB_CA6B
    )
    let crownSeparation =
      0.000030
      + (0.000022 + 0.000008 * curvatureVariation)
      * sin(Float.pi * rootFraction)
    let branchLift: Float = unpackBarbuleBranchIndex(work) == 0
      ? 0.000005 : 0.000016
    let t = min(max(segmentFraction, 0), 1)
    return CrowVentralRachisCurveRecords.center(
      record: record,
      axial: coordinates.x
    )
      + widthAxis * halfWidth * coordinates.y
      + normal * (crownSeparation + t * branchLift)
  }

  static func barbuleRadius(
    record: CrowVentralRachisCurveRecordGPU,
    work: CrowVentralBarbSegmentWorkGPU,
    segmentFraction: Float
  ) -> Float {
    let scale = 1 + 0.10 * variation(
      record: record,
      pairIndex: Int(work.indices.y),
      sideIndex: unpackSideIndex(work),
      salt: 0x1656_67B1 &+ UInt32(unpackBarbuleIndex(work))
    )
    let t = min(max(segmentFraction, 0), 1)
    return scale * (0.000012 + t * (0.000004 - 0.000012))
  }

  /// Bounded local paired-branch occlusion. The lower hook branch sits below
  /// its crossed mate in the generated crown; this term approximates only
  /// that unresolved local blockage and never changes geometry or opacity.
  static func barbuleLocalOcclusion(
    work: CrowVentralBarbSegmentWorkGPU
  ) -> Float {
    let count = max(unpackBarbuleCount(work), 1)
    let fraction = Float(unpackBarbuleIndex(work) + 1) / Float(count + 1)
    let edge = abs(2 * fraction - 1)
    return unpackBarbuleBranchIndex(work) == 0
      ? 0.82 + 0.08 * edge
      : 0.93 + 0.05 * edge
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
    Int((work.indices.w >> 16) & 0xff)
  }

  static func isBarbule(_ work: CrowVentralBarbSegmentWorkGPU) -> Bool {
    work.indices.w & 0x8000_0000 != 0
  }

  static func unpackBarbuleIndex(_ work: CrowVentralBarbSegmentWorkGPU) -> Int {
    Int(work.indices.w & 0xffff)
  }

  static func unpackBarbuleCount(_ work: CrowVentralBarbSegmentWorkGPU) -> Int {
    Int((work.indices.w >> 16) & 0xff)
  }

  static func unpackBarbuleBranchIndex(
    _ work: CrowVentralBarbSegmentWorkGPU
  ) -> Int {
    Int((work.indices.w >> 24) & 1)
  }

  private static func packPairCount(_ count: Int, sideIndex: Int) -> UInt32 {
    UInt32(count) | (UInt32(sideIndex) << 16)
  }

  private static func packInterval(_ index: Int, count: Int) -> UInt32 {
    UInt32(index) | (UInt32(count) << 16)
  }

  private static func packBarbule(
    _ index: Int,
    count: Int,
    branchIndex: Int
  ) -> UInt32 {
    0x8000_0000
      | UInt32(index)
      | (UInt32(count) << 16)
      | (UInt32(branchIndex) << 24)
  }

  private static func barbuleRootFraction(
    _ work: CrowVentralBarbSegmentWorkGPU
  ) -> Float {
    let count = max(unpackBarbuleCount(work), 1)
    let fraction = Float(unpackBarbuleIndex(work) + 1) / Float(count + 1)
    return 0.10 + 0.78 * fraction
  }

  private static func barbAxial(
    record: CrowVentralRachisCurveRecordGPU,
    work: CrowVentralBarbSegmentWorkGPU,
    curveFraction: Float
  ) -> Float {
    let pairIndex = Int(work.indices.y)
    let pairCount = max(unpackPairCount(work), 1)
    let sideIndex = unpackSideIndex(work)
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
    let localAxial = 0.10 + spacing * Float(pairIndex + 1)
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
    return firstAxial + (secondAxial - firstAxial) * t
  }

  private static func barbLateralFraction(
    record: CrowVentralRachisCurveRecordGPU,
    work: CrowVentralBarbSegmentWorkGPU,
    curveFraction: Float
  ) -> Float {
    let attachmentVariation = variation(
      record: record,
      pairIndex: Int(work.indices.y),
      sideIndex: unpackSideIndex(work),
      salt: 0x9E37_79B9
    )
    let curvatureVariation = variation(
      record: record,
      pairIndex: Int(work.indices.y),
      sideIndex: unpackSideIndex(work),
      salt: 0x85EB_CA6B
    )
    let t = min(max(curveFraction, 0), 1)
    return (0.955 + 0.012 * attachmentVariation)
      * pow(t, 0.82 + 0.08 * curvatureVariation)
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

  private static func normalizedPlane(_ plane: SIMD4<Float>) -> SIMD4<Float> {
    let length = simd_length(xyz(plane))
    return length > 1e-12 ? plane / length : plane
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    simd_length_squared(value) > 1e-14 ? simd_normalize(value) : fallback
  }
}
