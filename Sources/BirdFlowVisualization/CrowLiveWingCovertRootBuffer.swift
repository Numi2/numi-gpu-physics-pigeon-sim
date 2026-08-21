import BirdFlowMetal
import Foundation
import Metal
import simd

/// Compact, stable root records for the topology-bound reverse-wing tract.
///
/// The live scaffold is still authored on the CPU today, but it uploads only
/// one 128-byte temporal record per feather. `CrowFeatherGeometryDeformer`
/// expands the retained high-density vane template on Metal, so increasing
/// feather surface quality no longer duplicates triangle construction for the
/// current and previous temporal samples.
final class CrowLiveWingCovertRootBuffer {
  private static let bufferedFrameCount = 3
  /// The canonical template lacks the retired blade's edge-wave excursions.
  /// Preserve its measured overlap envelope with a small, class-local width
  /// allowance rather than retaining a second CPU tessellation path.
  private static let canonicalTemplateOverlapScale: Float = 1.04

  private let buffers: [MTLBuffer]
  private let leftWingOffset: Int
  private let rightWingOffset: Int
  private let requiredStateCount: Int
  private var nextSlot = 0

  let featherCount: Int

  init(backend: VisualizationBackend, dataset: MeasuredBirdSurfaceSequence) throws {
    guard
      let left = dataset.components.first(where: { $0.partIdentifier == 2 }),
      let right = dataset.components.first(where: { $0.partIdentifier == 3 }),
      left.vertexCount
        == CrowFlightWingBodyIntegration.chordCount
          * CrowFlightWingBodyIntegration.spanCount,
      right.vertexCount == left.vertexCount
    else {
      throw VisualizationError.pipeline(
        "live underwing covert roots require bilateral 9 x 33 wing topology"
      )
    }
    leftWingOffset = left.vertexOffset
    rightWingOffset = right.vertexOffset
    requiredStateCount = max(
      left.vertexOffset + left.vertexCount,
      right.vertexOffset + right.vertexCount
    )
    featherCount = 2
      * CrowFlightWingBodyIntegration.underwingCovertChordIndices.count
      * CrowFlightWingBodyIntegration.underwingCovertSpanIndices.count
    let byteCount = MemoryLayout<CrowFeatherRootStateGPU>.stride * featherCount
    buffers = try (0..<Self.bufferedFrameCount).map { _ in
      try backend.buffer(length: byteCount, shared: true)
    }
  }

  func upload(
    currentStates: [SIMD3<Float>],
    previousStates: [SIMD3<Float>],
    currentDeployment: Float,
    previousDeployment: Float
  ) throws -> CrowFeatherRootFrame {
    guard
      currentStates.count >= requiredStateCount,
      previousStates.count >= requiredStateCount
    else {
      throw VisualizationError.pipeline(
        "live underwing covert root upload received incomplete surface state"
      )
    }
    let states = referenceStates(
      currentStates: currentStates,
      previousStates: previousStates,
      currentDeployment: currentDeployment,
      previousDeployment: previousDeployment
    )
    let slot = nextSlot
    nextSlot = (nextSlot + 1) % Self.bufferedFrameCount
    let buffer = buffers[slot]
    states.withUnsafeBytes { bytes in
      guard let baseAddress = bytes.baseAddress else { return }
      memcpy(buffer.contents(), baseAddress, bytes.count)
    }
    return CrowFeatherRootFrame(
      slot: slot,
      readbackReady: true,
      outputBuffer: buffer,
      currentPhase: currentDeployment,
      previousPhase: previousDeployment
    )
  }

  func states(for frame: CrowFeatherRootFrame) -> [CrowFeatherRootStateGPU] {
    let pointer = frame.outputBuffer.contents().bindMemory(
      to: CrowFeatherRootStateGPU.self,
      capacity: featherCount
    )
    return Array(UnsafeBufferPointer(start: pointer, count: featherCount))
  }

  func referenceStates(
    currentStates: [SIMD3<Float>],
    previousStates: [SIMD3<Float>],
    currentDeployment: Float,
    previousDeployment: Float
  ) -> [CrowFeatherRootStateGPU] {
    var result: [CrowFeatherRootStateGPU] = []
    result.reserveCapacity(featherCount)
    for (left, offset, partIdentifier): (Bool, Int, UInt32) in [
      (true, leftWingOffset, 2),
      (false, rightWingOffset, 3),
    ] {
      for chord in CrowFlightWingBodyIntegration.underwingCovertChordIndices {
        let featherClass =
          CrowFlightWingBodyIntegration.underwingCovertClassCode(
            chordIndex: chord
          )
        let classCourse = chord == 1 ? 0 : (chord == 3 ? 1 : (chord == 5 ? 2 : 0))
        let classCount = featherClass
          == CrowFlightWingBodyIntegration.underwingCovertSurfaceFeatherClass
          ? 3 * CrowFlightWingBodyIntegration.underwingCovertSpanIndices.count
          : CrowFlightWingBodyIntegration.underwingCovertSpanIndices.count
        for span in CrowFlightWingBodyIntegration.underwingCovertSpanIndices {
          let spanOrder = span
            - (CrowFlightWingBodyIntegration.underwingCovertSpanIndices.first ?? 0)
          let classOrder = featherClass
            == CrowFlightWingBodyIntegration.underwingCovertSurfaceFeatherClass
            ? classCourse
              * CrowFlightWingBodyIntegration.underwingCovertSpanIndices.count
              + spanOrder
            : spanOrder
          let current = Self.pose(
            states: currentStates,
            wingOffset: offset,
            left: left,
            chord: chord,
            span: span,
            deployment: currentDeployment
          )
          let previous = Self.pose(
            states: previousStates,
            wingOffset: offset,
            left: left,
            chord: chord,
            span: span,
            deployment: previousDeployment
          )
          let packedIdentity = featherClass
            | ((left ? UInt32(1) : UInt32(2)) << 8)
            | (UInt32(classOrder) << 16)
            | (UInt32(classCount) << 24)
          let stableIdentifier = UInt32(0xC000_0000)
            | (partIdentifier << 20)
            | (UInt32(chord) << 12)
            | UInt32(span)
          result.append(
            CrowFeatherRootStateGPU(
              currentPositionAndLength: SIMD4<Float>(
                current.root,
                current.length
              ),
              previousPositionAndWidth: SIMD4<Float>(
                previous.root,
                current.maximumWidth
              ),
              currentDirectionAndRachis: SIMD4<Float>(
                current.direction,
                current.rachisRadius
              ),
              previousDirectionAndCamber: SIMD4<Float>(
                previous.direction,
                current.camber
              ),
              currentNormalAndPadding: SIMD4<Float>(current.normal, 0),
              previousNormalAndPadding: SIMD4<Float>(previous.normal, 0),
              previousMorphology: SIMD4<Float>(
                previous.length,
                previous.maximumWidth,
                previous.rachisRadius,
                previous.camber
              ),
              identity: SIMD4<UInt32>(
                UInt32(result.count),
                stableIdentifier,
                partIdentifier,
                packedIdentity
              )
            )
          )
        }
      }
    }
    return result
  }

  private struct Pose {
    let root: SIMD3<Float>
    let direction: SIMD3<Float>
    let normal: SIMD3<Float>
    let length: Float
    let maximumWidth: Float
    let rachisRadius: Float
    let camber: Float
  }

  private static func pose(
    states: [SIMD3<Float>],
    wingOffset: Int,
    left: Bool,
    chord: Int,
    span: Int,
    deployment: Float
  ) -> Pose {
    let chordCount = CrowFlightWingBodyIntegration.chordCount
    func point(span: Int, chord: Int) -> SIMD3<Float> {
      states[wingOffset + span * chordCount + chord]
    }
    let weight = min(max(deployment, 0), 1)
    let surfaceRoot = point(span: span, chord: chord)
    let chordVector = point(span: span, chord: chord + 2) - surfaceRoot
    let spanVector = point(span: span + 2, chord: chord) - surfaceRoot
    let chordDirection = safeNormalize(
      chordVector,
      fallback: SIMD3<Float>(-1, 0, 0)
    )
    let spanDirection = safeNormalize(
      spanVector,
      fallback: SIMD3<Float>(0, left ? 1 : -1, 0)
    )
    let normal = CrowFlightWingBodyIntegration.underwingCovertSurfaceNormal(
      chordDirection: chordDirection,
      spanDirection: spanDirection,
      left: left
    )
    let surfaceTip = surfaceRoot
      + CrowFlightWingBodyIntegration.underwingCovertChordTargetScale(
        chordIndex: chord
      ) * chordVector
      + CrowFlightWingBodyIntegration.underwingCovertTipSpanFraction(
        chordIndex: chord,
        spanIndex: span
      ) * spanVector
    let root = surfaceRoot
      + normal
        * CrowFlightWingBodyIntegration.underwingCovertRootClearanceMeters
        * weight
    let tip = surfaceRoot + weight * (surfaceTip - surfaceRoot)
      + normal
        * CrowFlightWingBodyIntegration.underwingCovertTipClearanceMeters
        * weight
    let vector = tip - root
    let spacing = max(0.5 * simd_length(spanVector), 0.006)
    let widthScale = CrowFlightWingBodyIntegration.underwingCovertWidthScale(
      chordIndex: chord,
      spanIndex: span
    ) * CrowFlightWingBodyIntegration.underwingCovertCourseWidthScale(
      chordIndex: chord
    )
    return Pose(
      root: root,
      direction: safeNormalize(vector, fallback: chordDirection),
      normal: normal,
      length: simd_length(vector),
      maximumWidth: weight * Self.canonicalTemplateOverlapScale
        * widthScale * 0.58 * spacing,
      rachisRadius: weight * max(0.000055, 0.032 * spacing),
      camber: weight
        * CrowFlightWingBodyIntegration.underwingCovertCamberScale(
          chordIndex: chord,
          spanIndex: span
        ) * 0.004 * simd_length(chordVector)
    )
  }

  private static func safeNormalize(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let magnitude = simd_length(value)
    return magnitude > 1e-12 ? value / magnitude : fallback
  }
}
