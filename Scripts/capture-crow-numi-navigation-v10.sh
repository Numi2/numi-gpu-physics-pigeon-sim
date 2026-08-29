#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:?usage: capture-crow-numi-navigation-v10.sh OUTPUT_DIR REPLAY_PACK QUALIFICATION}"
REPLAY_PACK="${2:?usage: capture-crow-numi-navigation-v10.sh OUTPUT_DIR REPLAY_PACK QUALIFICATION}"
QUALIFICATION="${3:?usage: capture-crow-numi-navigation-v10.sh OUTPUT_DIR REPLAY_PACK QUALIFICATION}"
WIDTH="${BIRDFLOW_CROW_V10_WIDTH:-1920}"
HEIGHT="${BIRDFLOW_CROW_V10_HEIGHT:-1080}"
FRAMES="${BIRDFLOW_CROW_V10_FRAMES:-49}"

for tool in jq shasum; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "$tool is required for the Crow v10 capture" >&2
    exit 1
  }
done
[[ -s "$REPLAY_PACK" && -s "$QUALIFICATION" ]] || {
  echo "accepted replay and qualification artifacts are required" >&2
  exit 1
}
SOURCE_REPLAY_SHA="$(jq -r '.payload.presentation_projection.source_replay_sha256 // empty' "$REPLAY_PACK")"
jq -e --arg source_replay_sha "$SOURCE_REPLAY_SHA" '
  .schema == "numi.crow-world-model-qualification.v1"
  and .payload.decision == "promote"
  and .payload.task == "birdflow_american_crow_navigation_v10_world_model"
  and .payload.accepted_replay_sha256 == $source_replay_sha
  and (.payload.contract_failures | length) == 0
' "$QUALIFICATION" >/dev/null || {
  echo "qualification does not promote the replay source" >&2
  exit 1
}
jq -e '
  .schema == "numi.crow-replay.v1"
  and .payload.classification == "simulated accepted-state replay"
  and .payload.task == "birdflow_american_crow_navigation_v10_world_model"
  and .payload.navigation_course == "held-out-a"
  and .payload.presentation_projection.terminal_frame_excluded == true
  and (.payload.frames | map(.outcomes.navigation_waypoints_reached) | max) >= 1
' "$REPLAY_PACK" >/dev/null || {
  echo "replay is not a reset-free accepted v10 waypoint projection" >&2
  exit 1
}

MANIFEST="$ROOT/ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"
GENERATION_AUDIT="$ROOT/ValidationArtifacts/american-crow-hybrid-surface-generation-v1.json"
PROFILE="$ROOT/ValidationInputs/american-crow-hybrid-visual-v1.json"
PLUMAGE_OPTICS="$ROOT/ValidationInputs/american-crow-plumage-optics-estimated-v1.json"
STANDING_REFERENCE="$ROOT/ValidationInputs/american-crow-standing-reference-v1.json"
CAPTURE="${BIRDFLOW_CROW_V10_CAPTURE_BIN:-}"
if [[ -z "$CAPTURE" ]]; then
  CAPTURE_BUILD="$ROOT/.build/numi-crow-navigation-v10-capture"
  swift build --build-path "$CAPTURE_BUILD" -c release \
    --sanitize=address --product birdflow-capture
  CAPTURE="$CAPTURE_BUILD/release/birdflow-capture"
fi
[[ -x "$CAPTURE" ]] || {
  echo "BirdFlow capture binary is unavailable: $CAPTURE" >&2
  exit 1
}

mkdir -p "$OUTPUT_DIR"
render_angle() {
  local name="$1" yaw="$2" pitch="$3" distance="$4" lighting="$5"
  local directory="$OUTPUT_DIR/$name"
  mkdir -p "$directory"
  env MTL_DEBUG_LAYER=1 ASAN_OPTIONS=abort_on_error=1 "$CAPTURE" \
    --capture-crow-frames "$directory" \
    --capture-crow-surface-manifest "$MANIFEST" \
    --capture-crow-surface-generation-audit "$GENERATION_AUDIT" \
    --capture-crow-profile "$PROFILE" \
    --capture-crow-plumage-optics "$PLUMAGE_OPTICS" \
    --capture-crow-standing-reference "$STANDING_REFERENCE" \
    --capture-crow-presentation takeoff \
    --capture-crow-replay-pack "$REPLAY_PACK" \
    --capture-crow-camera-yaw "$yaw" \
    --capture-crow-camera-pitch "$pitch" \
    --capture-crow-camera-distance "$distance" \
    --capture-crow-camera-yaw-orbit 0 \
    --capture-crow-lighting "$lighting" \
    --capture-crow-aov-audit "$directory/aov-audit.json" \
    --capture-width "$WIDTH" --capture-height "$HEIGHT" \
    --capture-frames "$FRAMES"
}

cd "$ROOT"
render_angle front-three-quarter 0.25 0.18 1.15 overcast
render_angle course-side -1.25 0.30 1.22 clear
render_angle elevated-rear 2.20 0.48 1.24 rim

REPLAY_SHA="$(shasum -a 256 "$REPLAY_PACK" | awk '{print $1}')"
QUALIFICATION_SHA="$(shasum -a 256 "$QUALIFICATION" | awk '{print $1}')"
jq -n \
  --arg replay "$REPLAY_PACK" --arg replay_sha256 "$REPLAY_SHA" \
  --arg qualification "$QUALIFICATION" \
  --arg qualification_sha256 "$QUALIFICATION_SHA" \
  --arg source_replay_sha256 "$SOURCE_REPLAY_SHA" \
  --argjson width "$WIDTH" --argjson height "$HEIGHT" \
  --argjson frames "$FRAMES" '
  {
    schema: "birdflow.crow-navigation-multiview.v1",
    classification: "multi-angle estimated BirdFlow presentation of accepted Numi simulator states",
    replay: $replay,
    replay_sha256: $replay_sha256,
    source_replay_sha256: $source_replay_sha256,
    qualification: $qualification,
    qualification_sha256: $qualification_sha256,
    width: $width,
    height: $height,
    frames_per_angle: $frames,
    angles: [
      {name: "front-three-quarter", yaw: 0.25, pitch: 0.18, distance: 1.15, lighting: "overcast"},
      {name: "course-side", yaw: -1.25, pitch: 0.30, distance: 1.22, lighting: "clear"},
      {name: "elevated-rear", yaw: 2.20, pitch: 0.48, distance: 1.24, lighting: "rim"}
    ],
    claim_boundary: "accepted root states place the accepted randomized course relative to the crow; BirdFlow feather articulation remains estimated"
  }
' > "$OUTPUT_DIR/capture-manifest.json"

echo "Crow v10 multi-angle frames: $OUTPUT_DIR"
