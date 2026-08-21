import BirdFlowMetal
import Foundation
import simd

struct VisualizationUniforms {
  var grid: SIMD4<UInt32>
  var flags: SIMD4<UInt32>
  var originAndCellSize: SIMD4<Float>
  var scalesAndRanges: SIMD4<Float>
  var sliceCenterAndOpacity: SIMD4<Float>
  var sliceUAndHalfWidth: SIMD4<Float>
  var sliceVAndHalfHeight: SIMD4<Float>
  var sliceNormalAndRange: SIMD4<Float>
  var tracerAndIso: SIMD4<Float>
  var displayOptions: SIMD4<Float>
  var probeUVAndPadding: SIMD4<Float>
  var bodyPosition: SIMD4<Float>
  var orientation: SIMD4<Float>
  var bodyRadiiAndTail: SIMD4<Float>
  var wingGeometry0: SIMD4<Float>
  var wingGeometry1: SIMD4<Float>
  var leftRoot: SIMD4<Float>
  var leftChord: SIMD4<Float>
  var leftSpan: SIMD4<Float>
  var leftNormal: SIMD4<Float>
  var rightRoot: SIMD4<Float>
  var rightChord: SIMD4<Float>
  var rightSpan: SIMD4<Float>
  var rightNormal: SIMD4<Float>

  init(
    metadata: GPUFieldFrameMetadata,
    settings: VisualizationSettings,
    sliceCenter: SIMD3<Float>,
    sliceU: SIMD3<Float>,
    sliceV: SIMD3<Float>,
    tracerDeltaTime: Float,
    resetTracers: Bool,
    probeUV: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
  ) {
    let gridSize = metadata.grid
    grid = SIMD4<UInt32>(
      UInt32(gridSize.x), UInt32(gridSize.y), UInt32(gridSize.z),
      UInt32(gridSize.cellCount)
    )
    var displayFlags: UInt32 = resetTracers ? 1 : 0
    if settings.showVelocityGlyphs { displayFlags |= 1 << 1 }
    if settings.pressureUnit == .coefficient,
      metadata.referenceDynamicPressurePascals != nil
    {
      displayFlags |= 1 << 2
    }
    if settings.ribbonColor == .vorticity { displayFlags |= 1 << 3 }
    if settings.clipQBySlicePlane { displayFlags |= 1 << 4 }
    if settings.qColor == .vorticity { displayFlags |= 1 << 5 }
    flags = SIMD4<UInt32>(
      UInt32(settings.sliceField.rawValue),
      displayFlags,
      UInt32(settings.tracerCount),
      UInt32(settings.tracerHistory)
    )
    originAndCellSize = SIMD4<Float>(
      metadata.domainOriginMeters,
      metadata.cellSizeMeters
    )
    let pressureRange =
      settings.pressureUnit == .coefficient
      ? settings.pressureRangeCoefficient
      : settings.pressureRangePascals
    scalesAndRanges = SIMD4<Float>(
      metadata.velocityToPhysical,
      metadata.pressureScalePascals,
      settings.pressureProbeOffsetCells,
      max(pressureRange, 1e-6)
    )
    sliceCenterAndOpacity = SIMD4<Float>(sliceCenter, settings.sliceOpacity)
    let domain =
      SIMD3<Float>(
        Float(gridSize.x), Float(gridSize.y), Float(gridSize.z)
      ) * metadata.cellSizeMeters
    sliceUAndHalfWidth = SIMD4<Float>(sliceU, 0.5 * simd_length(domain))
    sliceVAndHalfHeight = SIMD4<Float>(sliceV, 0.5 * simd_length(domain))
    sliceNormalAndRange = SIMD4<Float>(
      simd_normalize(simd_cross(sliceU, sliceV)),
      max(settings.sliceRange, 1e-6)
    )
    tracerAndIso = SIMD4<Float>(
      max(tracerDeltaTime, 0),
      settings.qThreshold,
      settings.qOpacity,
      Float(settings.qTriangleCapacity)
    )
    displayOptions = SIMD4<Float>(
      metadata.referenceDynamicPressurePascals ?? 0,
      min(max(settings.pressureAutoscalePercentile, 0.5), 1),
      max(settings.ribbonColorRange, 1e-6),
      max(settings.qThreshold * 10, 1e-6)
    )
    probeUVAndPadding = SIMD4<Float>(
      min(max(probeUV.x, 0), 1),
      min(max(probeUV.y, 0), 1),
      0,
      0
    )
    let geometry = metadata.geometry
    bodyPosition = geometry.bodyPosition
    orientation = geometry.orientation
    bodyRadiiAndTail = SIMD4<Float>(
      metadata.bird.bodyRadiiMeters,
      metadata.bird.tailLengthMeters
    )
    wingGeometry0 = SIMD4<Float>(
      metadata.bird.wingSpanMeters,
      metadata.bird.wingRootChordMeters,
      metadata.bird.wingTipChordMeters,
      metadata.bird.wingThicknessMeters
    )
    wingGeometry1 = SIMD4<Float>(
      metadata.bird.wingSweepMeters,
      metadata.bird.tailHalfWidthMeters,
      metadata.bird.tailThicknessMeters,
      metadata.physicalAirDensity
    )
    leftRoot = geometry.leftRoot
    leftChord = geometry.leftChord
    leftSpan = geometry.leftSpan
    leftNormal = geometry.leftNormal
    rightRoot = geometry.rightRoot
    rightChord = geometry.rightChord
    rightSpan = geometry.rightSpan
    rightNormal = geometry.rightNormal
  }
}

struct TracerState {
  var positionAndAge: SIMD4<Float>
  var velocityAndSpeed: SIMD4<Float>
}

struct IsoVertex {
  var position: SIMD4<Float>
  var normal: SIMD4<Float>
}

struct SliceProbeOutput {
  var worldAndScalar: SIMD4<Float>
  var velocity: SIMD4<Float>
  var vorticity: SIMD4<Float>
}

struct DrawPrimitivesIndirectArguments {
  var vertexCount: UInt32
  var instanceCount: UInt32
  var vertexStart: UInt32
  var baseInstance: UInt32
}

/// Immutable per-feather metadata uploaded once from `BirdRealityAsset`.
/// Four-vector packing is mirrored exactly in Visualization.metal.
struct CrowFeatherRootBindingGPU {
  var sourceIndicesAndHash: SIMD4<UInt32>
  var ownershipAndIdentity: SIMD4<UInt32>
  var localDirectionAndLength: SIMD4<Float>
  var widthRachisAndPadding: SIMD4<Float>
}

/// Current and previous render-time correspondence produced by Metal.
/// The previous position is required for deformation motion vectors rather
/// than camera-only temporal reconstruction.
struct CrowFeatherRootStateGPU: Equatable {
  var currentPositionAndLength: SIMD4<Float>
  var previousPositionAndWidth: SIMD4<Float>
  var currentDirectionAndRachis: SIMD4<Float>
  var previousDirectionAndCamber: SIMD4<Float>
  var currentNormalAndPadding: SIMD4<Float>
  var previousNormalAndPadding: SIMD4<Float>
  /// Previous length, maximum half-width, rachis radius, and camber.
  ///
  /// Persistent feathers normally repeat their immutable morphology here.
  /// Live topology-bound tracts use it to collapse or deploy without applying
  /// current-frame dimensions to the previous temporal sample.
  var previousMorphology: SIMD4<Float>
  var identity: SIMD4<UInt32>
}

struct CrowFeatherDeformationUniforms {
  var frameIndices: SIMD4<UInt32>
  var counts: SIMD4<UInt32>
  var interpolation: SIMD4<Float>
}

/// Immutable classification and morphology for the grounded-pose kernel.
struct CrowStandingFeatherBindingGPU {
  var identity: SIMD4<UInt32>
  var orderCountClassSide: SIMD4<UInt32>
  var morphology: SIMD4<Float>
}

struct CrowStandingFeatherUniforms {
  var phaseAndCount: SIMD4<Float>
  var referenceBodyCenter: SIMD4<Float>
}

struct CrowTakeoffFeatherBlendUniforms {
  var blendAndCount: SIMD4<Float>
  var currentBodyTranslation: SIMD4<Float>
  var previousBodyTranslation: SIMD4<Float>
}

/// One canonical feather-template vertex. The same retained template is
/// expanded for every feather. X is axial fraction, y is signed vane width,
/// z classifies vane/rachis/barb geometry, and w is the ribbon-side coordinate.
struct CrowFeatherTemplateVertexGPU {
  var parameters: SIMD4<Float>
}

/// Compute-generated geometry that is directly renderable today and retains
/// previous positions plus stable identity for future temporal/AOV paths.
struct CrowFeatherVertexGPU: Equatable {
  var position: SIMD4<Float>
  var normal: SIMD4<Float>
  var color: SIMD4<Float>
  var previousPosition: SIMD4<Float>
  var identity: SIMD4<UInt32>
  /// Axial vane fraction, signed half-width, feather class, reserved.
  var parameters: SIMD4<Float>
}

struct CrowFeatherGeometryUniforms {
  var counts: SIMD4<UInt32>
  var renderOffsetAndDetailScale: SIMD4<Float>
}

/// One retained analytic crown-rachis curve for an interior class-7 body
/// feather. Metal expands this 112-byte record into the selected radial tube
/// tessellation; no per-triangle body-detail stream is authored on the CPU.
struct CrowVentralRachisCurveRecordGPU: Equatable {
  /// Local root position and pennaceous start fraction.
  var rootAndPennaceousStart: SIMD4<Float>
  /// Local tip position and longitudinal camber in metres.
  var tipAndCamber: SIMD4<Float>
  /// Orthogonal vane normal and transverse crown-camber ratio.
  var normalAndTransverseCamber: SIMD4<Float>
  /// Root half-width, maximum half-width, root envelope ratio, and asymmetry.
  var widthsEnvelopeAndAsymmetry: SIMD4<Float>
  /// Edge-ripple amplitude, phase, cycles, and material variation.
  var edgeRippleAndMaterial: SIMD4<Float>
  /// Lateral centerline sweep in metres followed by reserved future fields.
  var lateralSweepAndReserved: SIMD4<Float>
  /// Stable region, side, row, and column identity.
  var identity: SIMD4<UInt32>
}

/// One active analytic curve interval selected for the current output LOD.
struct CrowVentralRachisSegmentWorkGPU: Equatable {
  /// Curve-record index, interval index, interval count, reserved.
  var indices: SIMD4<UInt32>
}

struct CrowVentralRachisGeometryUniforms {
  /// Curve count, active interval count, vertices per interval, class code.
  var counts: SIMD4<UInt32>
  var currentBodyCenter: SIMD4<Float>
  var previousBodyCenter: SIMD4<Float>
}

/// Procedural crow geometry paired across two frames for true deformation
/// motion rather than camera-only reprojection.
struct CrowSurfaceTemporalVertexGPU {
  var position: SIMD4<Float>
  var previousPosition: SIMD4<Float>
  var normal: SIMD4<Float>
  var albedoAndMaterial: SIMD4<Float>
  var parameters: SIMD4<Float>
  var identity: SIMD4<UInt32>
}

/// Current and previous camera transforms plus pixel dimensions and reset
/// state. Motion is written in MetalFX's current-to-previous pixel convention.
struct CrowTemporalCameraUniforms {
  var viewProjection: simd_float4x4
  var previousViewProjection: simd_float4x4
  var eyeAndWidth: SIMD4<Float>
  var viewportAndInverse: SIMD4<Float>
  var plumageFilm: SIMD4<Float>
  var plumageComplexIndices: SIMD4<Float>
  var plumageMelanin: SIMD4<Float>
  var plumageCortex: SIMD4<Float>
}
