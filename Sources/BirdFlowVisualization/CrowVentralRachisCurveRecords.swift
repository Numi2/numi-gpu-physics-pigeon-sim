import simd

/// Compact analytic ownership for the visible crown shaft of each interior
/// pectoral or abdominal feather. The established continuity shaft and barb
/// aggregates remain in the body surface stream; these records own only the
/// four-to-twelve crown intervals that were formerly expanded there as tubes.
enum CrowVentralRachisCurveRecords {
  static let radialSegmentCount = 4
  static let verticesPerCurveInterval = radialSegmentCount * 6
  static let maximumRachisSectionCount = 12
  static let surfaceFeatherClass: UInt32 = 7

  static func records(
    samples: [CrowVentralFeatherTractSample] = CrowVentralFeatherTracts.samples()
  ) -> [CrowVentralRachisCurveRecordGPU] {
    samples.compactMap { feather in
      guard CrowVentralFeatherTracts.retainsCrownRachis(feather) else {
        return nil
      }
      let direction = normalized(
        feather.tipOffset - feather.rootOffset,
        fallback: SIMD3<Float>(-1, 0, 0)
      )
      let normal = normalized(
        feather.planeNormal
          - direction * simd_dot(feather.planeNormal, direction),
        fallback: feather.planeNormal
      )
      return CrowVentralRachisCurveRecordGPU(
        rootAndPennaceousStart: SIMD4<Float>(
          feather.rootOffset,
          feather.pennaceousStartFraction
        ),
        tipAndCamber: SIMD4<Float>(feather.tipOffset, feather.camberMeters),
        normalAndTransverseCamber: SIMD4<Float>(
          normal,
          CrowVentralFeatherTracts.retainedRachisTransverseCamberRatio
            * CrowVentralFeatherTracts.transverseCamberScale(for: feather)
        ),
        widthsEnvelopeAndAsymmetry: SIMD4<Float>(
          feather.rootWidthMeters,
          feather.maximumWidthMeters,
          feather.rootEnvelopeRatio,
          feather.vaneAsymmetry
        ),
        edgeRippleAndMaterial: SIMD4<Float>(
          feather.edgeRippleAmplitude,
          feather.edgeRipplePhase,
          feather.edgeRippleCycles,
          feather.materialVariation
        ),
        lateralSweepAndReserved: SIMD4<Float>(
          feather.lateralSweepMeters,
          0,
          0,
          0
        ),
        identity: SIMD4<UInt32>(
          UInt32(feather.region.rawValue),
          feather.side < 0 ? 0 : 1,
          UInt32(feather.row),
          UInt32(feather.column)
        )
      )
    }
  }

  /// LOD selection remains CPU-cheap and output-quantized; only compact curve
  /// interval indices cross the bus. Metal owns all vertex construction.
  static func segmentWork(
    records: [CrowVentralRachisCurveRecordGPU],
    projectedPixelsPerMeter: Float
  ) -> [CrowVentralRachisSegmentWorkGPU] {
    guard projectedPixelsPerMeter >= 1_400 else { return [] }
    var work: [CrowVentralRachisSegmentWorkGPU] = []
    work.reserveCapacity(records.count * 4)
    for (recordIndex, record) in records.enumerated() {
      let sections = CrowFeatherCoverageLOD.tessellation(
        lengthMeters: simd_distance(
          xyz(record.rootAndPennaceousStart),
          xyz(record.tipAndCamber)
        ),
        projectedPixelsPerMeter: projectedPixelsPerMeter,
        baseAxialSections: 7
      ).rachisSections
      for section in 0..<sections {
        work.append(
          CrowVentralRachisSegmentWorkGPU(
            indices: SIMD4<UInt32>(
              UInt32(recordIndex),
              UInt32(section),
              UInt32(sections),
              0
            )
          )
        )
      }
    }
    return work
  }

  static func crownSegments(
    for feather: CrowVentralFeatherTractSample,
    projectedPixelsPerMeter: Float
  ) -> [CrowFeatherMesostructureSegment] {
    guard CrowVentralFeatherTracts.retainsCrownRachis(feather) else { return [] }
    let continuity = CrowFeatherMesostructure.segments(
      for: feather,
      projectedPixelsPerMeter: projectedPixelsPerMeter,
      transverseCamberRatio: 0
    )
    return Array(
      CrowFeatherMesostructure.segments(
        for: feather,
        projectedPixelsPerMeter: projectedPixelsPerMeter
      ).dropFirst(continuity.count)
    )
  }

  /// CPU oracle for record packing and Metal expansion tests. Production uses
  /// the matching analytic functions in Visualization.metal.
  static func segment(
    record: CrowVentralRachisCurveRecordGPU,
    intervalIndex: Int,
    intervalCount: Int
  ) -> CrowFeatherMesostructureSegment {
    let safeCount = max(intervalCount, 1)
    let localFirst = Float(intervalIndex) / Float(safeCount)
    let localSecond = Float(intervalIndex + 1) / Float(safeCount)
    let startFraction = record.rootAndPennaceousStart.w
    let first = startFraction + (1 - startFraction) * localFirst
    let second = startFraction + (1 - startFraction) * localSecond
    return CrowFeatherMesostructureSegment(
      kind: .rachis,
      start: center(record: record, axial: first),
      end: center(record: record, axial: second),
      startRadiusMeters: 0.00022 + (0.000055 - 0.00022) * first,
      endRadiusMeters: 0.00022 + (0.000055 - 0.00022) * second
    )
  }

  private static func center(
    record: CrowVentralRachisCurveRecordGPU,
    axial: Float
  ) -> SIMD3<Float> {
    let t = min(max(axial, 0), 1)
    let width = halfWidth(record: record, axial: t)
    let root = xyz(record.rootAndPennaceousStart)
    let tip = xyz(record.tipAndCamber)
    let normal = xyz(record.normalAndTransverseCamber)
    let direction = normalized(tip - root, fallback: SIMD3<Float>(-1, 0, 0))
    let widthAxis = normalized(
      simd_cross(normal, direction),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    let centerline = root + (tip - root) * t
    let lift = record.tipAndCamber.w * sin(Float.pi * t)
      + record.normalAndTransverseCamber.w * width + 0.00012
    return centerline
      + widthAxis * (record.lateralSweepAndReserved.x * sin(Float.pi * t))
      + normal * lift
  }

  private static func halfWidth(
    record: CrowVentralRachisCurveRecordGPU,
    axial: Float
  ) -> Float {
    let t = min(max(axial, 0), 1)
    let rootEnvelope = record.widthsEnvelopeAndAsymmetry.z
    let bodyEnvelope = rootEnvelope
      + (1 - rootEnvelope) * pow(max(sin(Float.pi * t), 0), 0.58)
    let tipTaper = 1 - 0.985 * pow(t, 3.2)
    let rippleEnvelope = pow(max(sin(Float.pi * t), 0), 2)
    let edgeRipple = 1
      + record.edgeRippleAndMaterial.x
      * sin(
        2 * Float.pi * record.edgeRippleAndMaterial.z * t
          + record.edgeRippleAndMaterial.y
      ) * rippleEnvelope
    let rootWidth = record.widthsEnvelopeAndAsymmetry.x
    let maximumWidth = record.widthsEnvelopeAndAsymmetry.y
    let interpolatedWidth = rootWidth + (maximumWidth - rootWidth) * t
    return interpolatedWidth * bodyEnvelope * tipTaper * edgeRipple
  }

  private static func xyz(_ value: SIMD4<Float>) -> SIMD3<Float> {
    SIMD3<Float>(value.x, value.y, value.z)
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-9 ? value / length : fallback
  }
}
