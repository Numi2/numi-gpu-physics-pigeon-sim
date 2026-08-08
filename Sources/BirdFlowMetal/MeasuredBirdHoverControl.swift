import BirdFlowCore
import CryptoKit
import Foundation

/// Fixed-body D3Q19 screening for an explicitly virtual flapping robot.
///
/// This is intentionally separate from `runTrimSearch`: forward-flight trim
/// preserves measured wing motion and changes attitude/airspeed, whereas a
/// hovering virtual robot must declare the aerodynamic actuator it varies.
@frozen
public struct MeasuredBirdHoverControlCandidateReport: Codable, Sendable {
    public var powerStrokePitchRadians: Float
    public var recoveryStrokePitchRadians: Float
    public var candidateDatasetSHA256: String
    public var finalCycleMeanAerodynamicForceNewtons: SIMD3<Float>
    public var finalCycleMeanAerodynamicTorqueNewtonMeters: SIMD3<Float>
    public var upwardForceNewtons: Float
    public var horizontalForceNewtons: Float
    public var equivalentSupportedMassKilograms: Float
}

@frozen
public struct MeasuredBirdHoverControlSweepReport: Codable, Sendable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var datasetIdentifier: String
    public var specimenIdentifier: String
    public var baseInputSHA256: String
    public var deviceName: String
    public var chordCells: Int
    public var cycles: Float
    public var collisionOperator: D3Q19CollisionOperator
    public var candidateDefinition: String
    public var candidates: [MeasuredBirdHoverControlCandidateReport]
    public var bestCandidate: MeasuredBirdHoverControlCandidateReport
    public var scientificVerdict: String
}

private func makeMeasuredBirdHoverControlCandidate(
    _ loaded: LoadedMeasuredBirdDataset,
    powerStrokePitchRadians: Float,
    recoveryStrokePitchRadians: Float
) throws -> LoadedMeasuredBirdDataset {
    guard powerStrokePitchRadians.isFinite,
          recoveryStrokePitchRadians.isFinite else {
        throw MeasuredBirdReplayError.invalidInput(
            "hover control pitches must be finite"
        )
    }
    var dataset = loaded.dataset
    dataset.kinematics.keyframes = dataset.kinematics.keyframes.map { keyframe in
        var adjusted = keyframe
        let pitchOffset = keyframe.phase >= 0.25 && keyframe.phase <= 0.5
            ? powerStrokePitchRadians
            : recoveryStrokePitchRadians
        // Preserve the authored actuator waveform. The screening action is a
        // state-commandable feathering offset, not an accidental replacement
        // of its phase-dependent neutral pitch.
        adjusted.left.pitchRadians += pitchOffset
        adjusted.right.pitchRadians += pitchOffset
        adjusted.left.pitchRateRadiansPerSecond = 0
        adjusted.right.pitchRateRadiansPerSecond = 0
        return adjusted
    }
    dataset.provenance.processingDescription +=
        "; virtual hover-control screening candidate: power-stroke pitch "
        + "\(powerStrokePitchRadians) rad, recovery-stroke pitch "
        + "\(recoveryStrokePitchRadians) rad"
    try dataset.validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(dataset)
    return LoadedMeasuredBirdDataset(
        dataset: dataset,
        sourceURL: loaded.sourceURL,
        sourceSHA256: CheckpointArchive.sha256(data),
        sourceData: data
    )
}

private func finalCycleMean(
    _ replay: MeasuredBirdReplayReport,
    frequencyHz: Float
) throws -> ForceTorque {
    let completedCycles = max(1, Int(floor(replay.cycles + 1.0e-4)))
    let finalCycle = completedCycles - 1
    let samples = replay.samples.filter {
        Int(floor($0.timeSeconds * frequencyHz + 1.0e-6)) == finalCycle
    }
    guard !samples.isEmpty else {
        throw MeasuredBirdReplayError.invalidInput(
            "hover control replay did not contain a completed final cycle"
        )
    }
    let divisor = Float(samples.count)
    return ForceTorque(
        forceNewtons: samples.reduce(.zero) { $0 + $1.aerodynamicLoad.forceNewtons }
            / divisor,
        torqueNewtonMeters: samples.reduce(.zero) { $0 + $1.aerodynamicLoad.torqueNewtonMeters }
            / divisor
    )
}

extension MeasuredBirdReplay {
    public static func runHoverControlSweep(
        _ loaded: LoadedMeasuredBirdDataset,
        chordCells: Int = 12,
        cycles: Float = 5,
        batchSize: Int = 32,
        collisionOperator: D3Q19CollisionOperator = .productionTRT
    ) throws -> MeasuredBirdHoverControlSweepReport {
        guard loaded.dataset.schemaVersion >= 2,
              loaded.dataset.prescribedWingDynamics != nil else {
            throw MeasuredBirdReplayError.invalidInput(
                "hover-control screening requires schema 2 wing inertia"
            )
        }
        guard vectorLength(loaded.dataset.replay.farFieldVelocityMetersPerSecond) <= 1.0e-6 else {
            throw MeasuredBirdReplayError.invalidInput(
                "hover-control screening requires zero far-field velocity"
            )
        }
        guard chordCells >= 8, cycles.isFinite, cycles >= 5, batchSize > 0 else {
            throw MeasuredBirdReplayError.invalidInput(
                "hover-control screening requires chord cells >= 8, at least five cycles, and positive batch size"
            )
        }

        // The controller owns a physical chord-pitch setpoint, so screen an
        // actuator-scale range rather than perturbing a presumed biological
        // waveform by a few milliradians.  This remains fixed-body screening:
        // a candidate does not yet establish closed-loop flight.
        let pitchLevels: [Float] = [-0.30, 0, 0.30]
        let gravity = abs(loaded.dataset.replay.gravityMetersPerSecondSquared.z)
        var candidates: [MeasuredBirdHoverControlCandidateReport] = []
        var deviceName = ""
        for powerPitch in pitchLevels {
            for recoveryPitch in pitchLevels {
                let candidate = try makeMeasuredBirdHoverControlCandidate(
                    loaded,
                    powerStrokePitchRadians: powerPitch,
                    recoveryStrokePitchRadians: recoveryPitch
                )
                let replay = try run(
                    candidate,
                    chordCells: chordCells,
                    cycles: cycles,
                    batchSize: batchSize,
                    collisionOperator: collisionOperator
                )
                deviceName = replay.deviceName
                let final = try finalCycleMean(
                    replay,
                    frequencyHz: candidate.dataset.kinematics.frequencyHz
                )
                let horizontal = sqrt(
                    final.forceNewtons.x * final.forceNewtons.x
                        + final.forceNewtons.y * final.forceNewtons.y
                )
                let upward = final.forceNewtons.z
                candidates.append(MeasuredBirdHoverControlCandidateReport(
                    powerStrokePitchRadians: powerPitch,
                    recoveryStrokePitchRadians: recoveryPitch,
                    candidateDatasetSHA256: candidate.sourceSHA256,
                    finalCycleMeanAerodynamicForceNewtons: final.forceNewtons,
                    finalCycleMeanAerodynamicTorqueNewtonMeters: final.torqueNewtonMeters,
                    upwardForceNewtons: upward,
                    horizontalForceNewtons: horizontal,
                    equivalentSupportedMassKilograms: max(0, upward) / gravity
                ))
            }
        }
        guard let best = candidates.max(by: {
            ($0.upwardForceNewtons - $0.horizontalForceNewtons)
                < ($1.upwardForceNewtons - $1.horizontalForceNewtons)
        }) else {
            throw MeasuredBirdReplayError.nonFiniteResult
        }
        return MeasuredBirdHoverControlSweepReport(
            schemaVersion: MeasuredBirdHoverControlSweepReport.schemaVersion,
            datasetIdentifier: loaded.dataset.datasetIdentifier,
            specimenIdentifier: loaded.dataset.provenance.specimenIdentifier,
            baseInputSHA256: loaded.sourceSHA256,
            deviceName: deviceName,
            chordCells: chordCells,
            cycles: cycles,
            collisionOperator: collisionOperator,
            candidateDefinition: "3x3 declared virtual actuator sweep over [-0.30, 0, +0.30] rad power-stroke and recovery-stroke body-local chord-pitch offsets about the authored waveform; fixed-body D3Q19 force screening only under the serialized \(collisionOperator.rawValue) operator",
            candidates: candidates,
            bestCandidate: best,
            scientificVerdict: "screening only: a selected kinematic candidate still requires attitude trim, coupled six-DOF release, and refinement before any free-flight claim"
        )
    }
}
