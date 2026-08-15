#!/usr/bin/env python3
"""Build the estimated American-crow indexed surface used by Metal simulation.

The Deetjen dove remains the only measured time-varying surface. This converter
removes its body translation, samples the documented presentation loop at the
selected crow display frequency, and applies explicit species-estimate warps.
The result is always labeled estimated-hybrid and is never a measured-crow
surface or a same-specimen free-flight dataset.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
from pathlib import Path


START_FRAME = 27
END_FRAME = 121
CLOSURE_SECONDS = 0.014
OUTPUT_INTERVALS = 48
METAL_TRIANGLE_LIMIT = 4096


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_path(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def fail(message: str) -> None:
    raise SystemExit(message)


def smoothstep(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def lerp(first: tuple[float, float, float], second: tuple[float, float, float], blend: float) -> tuple[float, float, float]:
    return tuple(first[axis] + blend * (second[axis] - first[axis]) for axis in range(3))


def add(first: tuple[float, float, float], second: tuple[float, float, float]) -> tuple[float, float, float]:
    return tuple(first[axis] + second[axis] for axis in range(3))


def subtract(first: tuple[float, float, float], second: tuple[float, float, float]) -> tuple[float, float, float]:
    return tuple(first[axis] - second[axis] for axis in range(3))


def multiply(vector: tuple[float, float, float], scalar: float) -> tuple[float, float, float]:
    return tuple(value * scalar for value in vector)


def average(points: list[tuple[float, float, float]]) -> tuple[float, float, float]:
    inverse = 1.0 / len(points)
    return tuple(sum(point[axis] for point in points) * inverse for axis in range(3))


def decode_positions(data: bytes, frame_count: int, vertex_count: int) -> list[list[tuple[float, float, float]]]:
    expected = frame_count * vertex_count * 3
    values = struct.unpack(f"<{expected}f", data)
    frames: list[list[tuple[float, float, float]]] = []
    for frame in range(frame_count):
        base = frame * vertex_count * 3
        frames.append([
            (values[base + 3 * vertex], values[base + 3 * vertex + 1], values[base + 3 * vertex + 2])
            for vertex in range(vertex_count)
        ])
    return frames


def body_centers(
    frames: list[list[tuple[float, float, float]]],
    body_offset: int,
    body_count: int,
) -> list[tuple[float, float, float]]:
    return [average(frame[body_offset : body_offset + body_count]) for frame in frames]


def source_sample(
    frames: list[list[tuple[float, float, float]]],
    centers: list[tuple[float, float, float]],
    sample_rate: float,
    time_seconds: float,
) -> list[tuple[float, float, float]]:
    coordinate = max(0.0, min(len(frames) - 1.0, time_seconds * sample_rate))
    lower = min(int(math.floor(coordinate)), len(frames) - 2)
    upper = lower + 1
    blend = coordinate - lower
    center = lerp(centers[lower], centers[upper], blend)
    return [subtract(lerp(frames[lower][index], frames[upper][index], blend), center) for index in range(len(frames[0]))]


def source_velocity(
    frames: list[list[tuple[float, float, float]]],
    centers: list[tuple[float, float, float]],
    sample_rate: float,
    time_seconds: float,
) -> list[tuple[float, float, float]]:
    half_step = 0.5 / sample_rate
    first = source_sample(frames, centers, sample_rate, time_seconds - half_step)
    second = source_sample(frames, centers, sample_rate, time_seconds + half_step)
    return [multiply(subtract(second[index], first[index]), sample_rate) for index in range(len(first))]


def loop_sample(
    frames: list[list[tuple[float, float, float]]],
    centers: list[tuple[float, float, float]],
    sample_rate: float,
    phase: float,
) -> list[tuple[float, float, float]]:
    start_time = START_FRAME / sample_rate
    end_time = END_FRAME / sample_rate
    measured_duration = end_time - start_time
    loop_duration = measured_duration + CLOSURE_SECONDS
    equivalent = (phase % 1.0) * loop_duration
    if equivalent < measured_duration:
        return source_sample(frames, centers, sample_rate, start_time + equivalent)

    blend = (equivalent - measured_duration) / CLOSURE_SECONDS
    start = source_sample(frames, centers, sample_rate, start_time)
    end = source_sample(frames, centers, sample_rate, end_time)
    start_velocity = source_velocity(frames, centers, sample_rate, start_time)
    end_velocity = source_velocity(frames, centers, sample_rate, end_time)
    blend2 = blend * blend
    blend3 = blend2 * blend
    h00 = 2 * blend3 - 3 * blend2 + 1
    h10 = blend3 - 2 * blend2 + blend
    h01 = -2 * blend3 + 3 * blend2
    h11 = blend3 - blend2
    return [
        add(
            add(multiply(end[index], h00), multiply(end_velocity[index], h10 * CLOSURE_SECONDS)),
            add(multiply(start[index], h01), multiply(start_velocity[index], h11 * CLOSURE_SECONDS)),
        )
        for index in range(len(start))
    ]


def transform_frame(
    points: list[tuple[float, float, float]],
    components: list[dict],
    body_reference_bounds: tuple[float, float],
    transforms: dict,
) -> list[tuple[float, float, float]]:
    result = list(points)
    body = components[0]
    body_scale = transforms["bodyScaleXYZ"]
    body_minimum_x, body_maximum_x = body_reference_bounds
    body_span_x = max(body_maximum_x - body_minimum_x, 1.0e-6)
    for index in range(body["vertexOffset"], body["vertexOffset"] + body["vertexCount"]):
        point = points[index]
        fraction = (point[0] - body_minimum_x) / body_span_x
        head = math.exp(-((fraction - 0.80) / 0.18) ** 2)
        bill_extension = 0.038 * smoothstep((fraction - 0.83) / 0.17)
        result[index] = (
            point[0] * body_scale[0] + bill_extension,
            point[1] * body_scale[1] * (1.0 + 0.22 * head),
            point[2] * body_scale[2] * (1.0 + 0.18 * head),
        )

    wing_scale = transforms["wingScaleXYZ"]
    left = components[1]
    right = components[2]
    if left["vertexCount"] != right["vertexCount"]:
        fail("crow wing symmetrization requires equal bilateral vertex counts")
    for local_index in range(left["vertexCount"]):
        left_index = left["vertexOffset"] + local_index
        right_index = right["vertexOffset"] + local_index
        left_point = points[left_index]
        right_point = points[right_index]
        mean_x = 0.5 * (left_point[0] + right_point[0]) * wing_scale[0]
        mean_y = 0.5 * (abs(left_point[1]) + abs(right_point[1])) * wing_scale[1]
        mean_z = 0.5 * (left_point[2] + right_point[2]) * wing_scale[2]
        result[left_index] = (mean_x, mean_y, mean_z)
        result[right_index] = (mean_x, -mean_y, mean_z)

    tail = components[3]
    tail_scale = transforms["tailScaleXYZ"]
    for index in range(tail["vertexOffset"], tail["vertexOffset"] + tail["vertexCount"]):
        point = points[index]
        result[index] = (
            point[0] * tail_scale[0],
            point[1] * tail_scale[1],
            point[2] * tail_scale[2],
        )
    return result


def bounds(points: list[tuple[float, float, float]]) -> tuple[list[float], list[float]]:
    return (
        [min(point[axis] for point in points) for axis in range(3)],
        [max(point[axis] for point in points) for axis in range(3)],
    )


def maximum_adjacent_speed(frames: list[list[tuple[float, float, float]]], time_step: float) -> float:
    maximum = 0.0
    for first, second in zip(frames, frames[1:]):
        for a, b in zip(first, second):
            speed = math.sqrt(sum((b[axis] - a[axis]) ** 2 for axis in range(3))) / time_step
            maximum = max(maximum, speed)
    return maximum


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dove-manifest", type=Path, default=Path("ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"))
    parser.add_argument("--profile", type=Path, default=Path("ValidationInputs/american-crow-hybrid-visual-v1.json"))
    parser.add_argument("--output", type=Path, default=Path("ValidationInputs/american-crow-hybrid-surface-v1"))
    parser.add_argument("--audit", type=Path, default=Path("ValidationArtifacts/american-crow-hybrid-surface-generation-v1.json"))
    arguments = parser.parse_args()

    manifest_bytes = arguments.dove_manifest.read_bytes()
    manifest = json.loads(manifest_bytes)
    profile_bytes = arguments.profile.read_bytes()
    profile = json.loads(profile_bytes)
    expected_manifest_hash = profile["doveScaffold"]["manifestSHA256"]
    if sha256_bytes(manifest_bytes) != expected_manifest_hash:
        fail("dove manifest does not match the crow profile lock")
    topology = manifest["topology"]
    if topology["triangleCount"] > METAL_TRIANGLE_LIMIT:
        fail("source topology exceeds the live Metal triangle identifier limit")
    positions_path = arguments.dove_manifest.parent / manifest["binary"]["positions"]["file"]
    triangles_path = arguments.dove_manifest.parent / manifest["binary"]["triangles"]["file"]
    positions_bytes = positions_path.read_bytes()
    triangles_bytes = triangles_path.read_bytes()
    if sha256_bytes(positions_bytes) != manifest["binary"]["positions"]["sha256"]:
        fail("dove position stream failed its manifest lock")
    if sha256_bytes(triangles_bytes) != manifest["binary"]["triangles"]["sha256"]:
        fail("dove triangle stream failed its manifest lock")

    source_frames = decode_positions(positions_bytes, manifest["frames"]["count"], topology["vertexCount"])
    body = topology["components"][0]
    centers = body_centers(source_frames, body["vertexOffset"], body["vertexCount"])
    reference = loop_sample(source_frames, centers, manifest["frames"]["sampleRateHertz"], 0.0)
    body_points = reference[body["vertexOffset"] : body["vertexOffset"] + body["vertexCount"]]
    body_reference_bounds = (min(point[0] for point in body_points), max(point[0] for point in body_points))

    selected = profile["selectedCrowEstimate"]
    period = 1.0 / selected["presentationWingbeatFrequencyHertz"]
    time_step = period / OUTPUT_INTERVALS
    simulation_transforms = profile["simulationTransform"]
    output_frames = [
        transform_frame(
            loop_sample(source_frames, centers, manifest["frames"]["sampleRateHertz"], index / OUTPUT_INTERVALS),
            topology["components"],
            body_reference_bounds,
            simulation_transforms,
        )
        for index in range(OUTPUT_INTERVALS + 1)
    ]
    flat = [coordinate for frame in output_frames for point in frame for coordinate in point]
    output_positions = struct.pack(f"<{len(flat)}f", *flat)

    arguments.output.mkdir(parents=True, exist_ok=True)
    output_positions_path = arguments.output / "positions.f32le"
    output_triangles_path = arguments.output / "triangles.u16le"
    output_manifest_path = arguments.output / "manifest.json"
    output_positions_path.write_bytes(output_positions)
    output_triangles_path.write_bytes(triangles_bytes)

    evidence = [
        "estimated-crow-body-warp-from-published-range",
        "estimated-crow-left-wing-allometric-remap-from-dove-scaffold",
        "bilaterally-symmetrized-estimated-crow-right-wing",
        "estimated-crow-tail-allometric-remap-from-dove-scaffold",
    ]
    components = []
    for source, evidence_class in zip(topology["components"], evidence):
        copied = dict(source)
        copied["evidenceClass"] = evidence_class
        components.append(copied)

    output_manifest = {
        "schemaVersion": 1,
        "datasetIdentifier": "american-crow-estimated-hybrid-complete-surface-v1",
        "scientificTier": "estimated-hybrid-complete-surface",
        "source": {
            "datasetDOI": manifest["source"]["datasetDOI"],
            "articleDOI": manifest["source"]["articleDOI"],
            "surfaceSHA256": manifest["source"]["surfaceSHA256"],
            "muscleModelSHA256": manifest["source"]["muscleModelSHA256"],
            "license": manifest["source"]["license"],
            "hybridProfile": str(arguments.profile),
            "hybridProfileSHA256": sha256_bytes(profile_bytes),
            "interpretation": "Measured-derived dove articulation scaffold plus estimated American-crow morphology; not measured crow geometry or kinematics.",
        },
        "frames": {
            "count": OUTPUT_INTERVALS + 1,
            "sampleRateHertz": OUTPUT_INTERVALS / period,
            "frameNumbers": list(range(OUTPUT_INTERVALS + 1)),
            "timesSeconds": [index * time_step for index in range(OUTPUT_INTERVALS + 1)],
            "interpolation": "piecewise-linear-nonperiodic",
            "endpointVelocity": "one-sided-adjacent-frame",
            "periodic": False,
            "presentationLoop": {
                "sourceStartFrame": START_FRAME,
                "sourceEndFrame": END_FRAME,
                "sourceClosureSeconds": CLOSURE_SECONDS,
                "outputEndpointDuplicatesFrameZero": True,
            },
        },
        "coordinateFrame": {
            "name": "body-centered BirdFlow estimated-crow presentation frame",
            "units": "meters",
            "birdFlowAxes": {"x": "forward", "y": "left", "z": "up"},
        },
        "topology": {
            "vertexCount": topology["vertexCount"],
            "triangleCount": topology["triangleCount"],
            "indexType": topology["indexType"],
            "metalTriangleIdentifierLimit": topology["metalTriangleIdentifierLimit"],
            "fixedAcrossFrames": True,
            "components": components,
        },
        "binary": {
            "positions": {
                "file": output_positions_path.name,
                "format": "float32-little-endian",
                "layout": "frame-major, vertex-major, xyz",
                "bytes": len(output_positions),
                "sha256": sha256_bytes(output_positions),
            },
            "triangles": {
                "file": output_triangles_path.name,
                "format": "uint16-little-endian",
                "layout": "triangle-major, three global vertex indices",
                "bytes": len(triangles_bytes),
                "sha256": sha256_bytes(triangles_bytes),
            },
        },
        "readiness": {
            "completeBirdSurfaceReady": True,
            "cpuParityRequired": True,
            "metalReplayReady": True,
            "quantitativeForceAcceptanceReady": False,
        },
    }
    encoded_manifest = (json.dumps(output_manifest, indent=2, sort_keys=True) + "\n").encode()
    output_manifest_path.write_bytes(encoded_manifest)

    minimum, maximum = bounds([point for frame in output_frames for point in frame])
    frame_zero_minimum, frame_zero_maximum = bounds(output_frames[0])
    endpoint_error = max(
        abs(first[axis] - last[axis])
        for first, last in zip(output_frames[0], output_frames[-1])
        for axis in range(3)
    )
    audit = {
        "schemaVersion": 1,
        "artifactIdentifier": "american-crow-hybrid-surface-generation-v1",
        "evidenceClass": "estimated-hybrid-simulation-input",
        "generatedBy": "Scripts/build-american-crow-surface.py",
        "manifestPath": str(output_manifest_path),
        "manifestSHA256": sha256_bytes(encoded_manifest),
        "sourceDoveManifestSHA256": expected_manifest_hash,
        "crowProfileSHA256": sha256_bytes(profile_bytes),
        "counts": {
            "frames": len(output_frames),
            "verticesPerFrame": topology["vertexCount"],
            "triangles": topology["triangleCount"],
            "positionBytes": len(output_positions),
            "triangleBytes": len(triangles_bytes),
        },
        "timing": {
            "selectedWingbeatFrequencyHertz": selected["presentationWingbeatFrequencyHertz"],
            "periodSeconds": period,
            "sampleRateHertz": OUTPUT_INTERVALS / period,
            "endpointMaximumAbsolutePositionErrorMeters": endpoint_error,
        },
        "geometry": {
            "allFrameMinimumMeters": minimum,
            "allFrameMaximumMeters": maximum,
            "frameZeroMinimumMeters": frame_zero_minimum,
            "frameZeroMaximumMeters": frame_zero_maximum,
            "maximumAdjacentPointSpeedMetersPerSecond": maximum_adjacent_speed(output_frames, time_step),
        },
        "checks": {
            "sourceLocks": True,
            "finitePositions": all(math.isfinite(value) for value in flat),
            "fixedTopology": True,
            "triangleBudget": topology["triangleCount"] <= METAL_TRIANGLE_LIMIT,
            "bilateralWingVertexParity": topology["components"][1]["vertexCount"] == topology["components"][2]["vertexCount"],
            "pixelIndependentEndpointClosure": endpoint_error <= 1.0e-7,
            "quantitativeForceAcceptanceReady": False,
        },
        "claimBoundary": "This artifact creates a fixed, GPU-addressable estimated-hybrid crow surface from the locked dove articulation scaffold and explicit crow morphology estimates. It does not establish measured crow geometry, measured crow kinematics, aerodynamic accuracy, force prediction, mass properties, or free flight.",
    }
    arguments.audit.parent.mkdir(parents=True, exist_ok=True)
    arguments.audit.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    print(f"wrote {output_manifest_path} sha256={sha256_bytes(encoded_manifest)}")
    print(f"wrote {arguments.audit}")


if __name__ == "__main__":
    main()
