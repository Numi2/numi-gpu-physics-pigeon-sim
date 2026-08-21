import simd

struct CrowAxillaryFeatherSample: Equatable {
  let side: Float
  let row: Int
  let column: Int
  let rootThetaRadians: Float
  let tipThetaRadians: Float
  let rootSurfaceOffset: SIMD3<Float>
  let rootOffset: SIMD3<Float>
  let tipOffset: SIMD3<Float>
  let planeNormal: SIMD3<Float>
  let rootWidthMeters: Float
  let maximumWidthMeters: Float
  let camberMeters: Float
  let vaneAsymmetry: Float
  let edgeRippleAmplitude: Float
  let edgeRipplePhase: Float
  let edgeRippleCycles: Float
  let rootEnvelopeRatio: Float
  let pennaceousStartFraction: Float
  let materialVariation: Float
  let surfaceFeatherClass: UInt32
}

/// Body-seated axillaries beneath the lower edge of the folded wing.
///
/// Scapulars own the dorsal overlap and the folded covert shell owns the wing
/// surface. Axillaries are a separate tract: their roots sit in the body-side
/// axilla, remain beneath the outer covert course, and their longer distal
/// vanes emerge along the lower wing/flank seam. Keeping them full-density
/// only avoids replacing their individual identities with a coarse dark slab.
enum CrowAxillaryFeatherTracts {
  static let rowCount = 7
  static let columnCount = 28
  static let fullDensityPixelsPerMeter: Float = 1_400
  static let shellClearanceMeters: Float = 0.0010
  static let surfaceFeatherClass: UInt32 = 7

  static func visibleSamples(
    projectedPixelsPerMeter: Float
  ) -> [CrowAxillaryFeatherSample] {
    guard projectedPixelsPerMeter >= fullDensityPixelsPerMeter else { return [] }
    return samples()
  }

  static func samples() -> [CrowAxillaryFeatherSample] {
    var result: [CrowAxillaryFeatherSample] = []
    result.reserveCapacity(2 * rowCount * columnCount)
    for side: Float in [-1, 1] {
      for row in 0..<rowCount {
        let rowFraction = Float(row) / Float(rowCount - 1)
        let rootTheta = -0.08 - 0.52 * rowFraction
        for column in 0..<columnCount {
          let axial = Float(column) / Float(columnCount - 1)
          let shapeIdentity = identityVariation(
            row: row,
            column: column,
            salt: 0x85EB_CA6B
          )
          let materialIdentity = identityVariation(
            row: row,
            column: column,
            salt: 0xC2B2_AE35
          )
          let vaneIdentity = identityVariation(
            row: row,
            column: column,
            salt: 0xB529_7A4D
          )
          let edgeIdentity = identityVariation(
            row: row,
            column: column,
            salt: 0x68E3_1DA4
          )
          let cycleIdentity = identityVariation(
            row: row,
            column: column,
            salt: 0x1656_67B1
          )
          let stagger =
            courseStaggerFraction(row: row)
            * 0.178 / Float(columnCount - 1)
          let rootX = 0.074 - 0.178 * axial - stagger
          let rootSurface = mirroredSurfacePoint(
            x: rootX,
            theta: rootTheta,
            side: side
          )
          let rootNormal = mirroredSurfaceNormal(
            x: rootX,
            theta: rootTheta,
            side: side
          )
          let clearance = shellClearanceMeters + 0.00018 * rowFraction
          let root = rootSurface + clearance * rootNormal
          let length =
            (0.035 + 0.014 * axial + 0.007 * rowFraction)
            * (1 + 0.045 * shapeIdentity)
          let tipX = max(
            rootX - length,
            CrowBodyAnatomy.loftRings.first!.x
          )
          let tipTheta =
            rootTheta - 0.045 - 0.050 * rowFraction
            + 0.010 * shapeIdentity
          let tipSurface = mirroredSurfacePoint(
            x: tipX,
            theta: tipTheta,
            side: side
          )
          let tipNormal = mirroredSurfaceNormal(
            x: tipX,
            theta: tipTheta,
            side: side
          )
          let tip = tipSurface + clearance * tipNormal
          let angularStep = 0.52 / Float(rowCount - 1)
          let circumferentialSpacing = simd_distance(
            mirroredSurfacePoint(
              x: rootX,
              theta: rootTheta - 0.5 * angularStep,
              side: side
            ),
            mirroredSurfacePoint(
              x: rootX,
              theta: rootTheta + 0.5 * angularStep,
              side: side
            )
          )
          let maximumWidth =
            max(0.0060, 1.32 * circumferentialSpacing)
            * (1 + 0.055 * shapeIdentity)
          result.append(
            CrowAxillaryFeatherSample(
              side: side,
              row: row,
              column: column,
              rootThetaRadians: rootTheta,
              tipThetaRadians: tipTheta,
              rootSurfaceOffset: rootSurface,
              rootOffset: root,
              tipOffset: tip,
              planeNormal: normalized(
                rootNormal + tipNormal,
                fallback: rootNormal
              ),
              rootWidthMeters: (0.60 + 0.06 * rowFraction) * maximumWidth,
              maximumWidthMeters: maximumWidth,
              camberMeters: (0.00145 + 0.00050 * rowFraction)
                * (1 + 0.08 * shapeIdentity),
              vaneAsymmetry: 0.045 * vaneIdentity,
              edgeRippleAmplitude: 0.012 + 0.016 * (0.5 + 0.5 * edgeIdentity),
              edgeRipplePhase: Float.pi * (edgeIdentity + 1),
              edgeRippleCycles: 1.25 + 0.70 * (0.5 + 0.5 * cycleIdentity),
              rootEnvelopeRatio: 0.68 + 0.06 * rowFraction,
              pennaceousStartFraction: 0.18 + 0.05 * rowFraction,
              materialVariation: materialIdentity,
              surfaceFeatherClass: surfaceFeatherClass
            )
          )
        }
      }
    }
    return result
  }

  /// Interleaved axial phases keep neighboring courses from exposing a
  /// continuous transverse root lane while preserving deterministic overlap.
  static func courseStaggerFraction(row: Int) -> Float {
    let boundedRow = min(max(row, 0), rowCount - 1)
    let stratum = 0.035 * Float(boundedRow / 2)
    return boundedRow.isMultiple(of: 2) ? stratum : 0.54 + stratum
  }

  private static func mirroredSurfacePoint(
    x: Float,
    theta: Float,
    side: Float
  ) -> SIMD3<Float> {
    let point = CrowBodyAnatomy.surfacePoint(atX: x, theta: theta)
    return SIMD3<Float>(point.x, side * point.y, point.z)
  }

  private static func mirroredSurfaceNormal(
    x: Float,
    theta: Float,
    side: Float
  ) -> SIMD3<Float> {
    let normal = CrowBodyAnatomy.surfaceNormal(atX: x, theta: theta)
    return SIMD3<Float>(normal.x, side * normal.y, normal.z)
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-8 ? value / length : fallback
  }

  private static func identityVariation(
    row: Int,
    column: Int,
    salt: UInt32
  ) -> Float {
    var value = UInt32(truncatingIfNeeded: row) &* 0x9E37_79B9
    value ^= UInt32(truncatingIfNeeded: column) &* 0x85EB_CA6B
    value ^= salt
    value ^= value >> 16
    value &*= 0x7FEB_352D
    value ^= value >> 15
    value &*= 0x846C_A68B
    value ^= value >> 16
    return 2 * Float(value & 0x00FF_FFFF) / Float(0x00FF_FFFF) - 1
  }
}

/// Couples body-owned axillary feathers to the live inner wing without moving
/// their follicles or stretching their estimated lengths.
///
/// The standing tract points caudally along the flank. During deployment its
/// direction and vane normal rotate toward topology-derived inner-wing targets,
/// with the dorsal axillary rows following more strongly than the ventral rows.
/// This is a presentation constraint, not a measured crow linkage model.
enum CrowAxillaryWingRootIntegration {
  static let deploymentStartProgress: Float = 0.20
  static let deploymentEndProgress: Float = 0.72
  static let minimumRowCoupling: Float = 0.36
  static let maximumRowCoupling: Float = 0.92

  static func deploymentWeight(transitionProgress: Float) -> Float {
    let normalized = min(
      max(
        (transitionProgress - deploymentStartProgress)
          / (deploymentEndProgress - deploymentStartProgress),
        0
      ),
      1
    )
    return normalized * normalized * (3 - 2 * normalized)
  }

  static func retargetedSample(
    _ sample: CrowAxillaryFeatherSample,
    wingTargetOffset: SIMD3<Float>,
    wingNormal: SIMD3<Float>,
    transitionProgress: Float
  ) -> CrowAxillaryFeatherSample {
    guard deploymentWeight(transitionProgress: transitionProgress) > 0 else {
      return sample
    }
    let rowFraction =
      Float(sample.row)
      / Float(max(CrowAxillaryFeatherTracts.rowCount - 1, 1))
    let rowCoupling =
      maximumRowCoupling
      + (minimumRowCoupling - maximumRowCoupling) * rowFraction
    let weight = deploymentWeight(transitionProgress: transitionProgress)
      * rowCoupling
    let originalVector = sample.tipOffset - sample.rootOffset
    let length = simd_length(originalVector)
    let originalDirection = normalized(
      originalVector,
      fallback: SIMD3<Float>(-1, 0, 0)
    )
    let targetDirection = normalized(
      wingTargetOffset - sample.rootOffset,
      fallback: originalDirection
    )
    let direction = normalized(
      originalDirection + weight * (targetDirection - originalDirection),
      fallback: originalDirection
    )
    let resolvedNormal = normalized(
      sample.planeNormal + weight * (wingNormal - sample.planeNormal),
      fallback: sample.planeNormal
    )
    return CrowAxillaryFeatherSample(
      side: sample.side,
      row: sample.row,
      column: sample.column,
      rootThetaRadians: sample.rootThetaRadians,
      tipThetaRadians: sample.tipThetaRadians,
      rootSurfaceOffset: sample.rootSurfaceOffset,
      rootOffset: sample.rootOffset,
      tipOffset: sample.rootOffset + length * direction,
      planeNormal: resolvedNormal,
      rootWidthMeters: sample.rootWidthMeters,
      maximumWidthMeters: sample.maximumWidthMeters,
      camberMeters: sample.camberMeters,
      vaneAsymmetry: sample.vaneAsymmetry,
      edgeRippleAmplitude: sample.edgeRippleAmplitude,
      edgeRipplePhase: sample.edgeRipplePhase,
      edgeRippleCycles: sample.edgeRippleCycles,
      rootEnvelopeRatio: sample.rootEnvelopeRatio,
      pennaceousStartFraction: sample.pennaceousStartFraction,
      materialVariation: sample.materialVariation,
      surfaceFeatherClass: sample.surfaceFeatherClass
    )
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 1e-8 ? value / length : fallback
  }
}
