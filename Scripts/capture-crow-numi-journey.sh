#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/Docs/Media/numi-crow-journey-presentation-v1.mp4}"
POSTER="${2:-$ROOT/Docs/Media/numi-crow-journey-presentation-v1.png}"
EVIDENCE="${3:?usage: capture-crow-numi-journey.sh OUTPUT POSTER EVIDENCE STATE_TRACE [GIF]}"
STATE_TRACE="${4:?usage: capture-crow-numi-journey.sh OUTPUT POSTER EVIDENCE STATE_TRACE [GIF]}"
GIF="${5:-${OUTPUT%.mp4}.gif}"
SIDECAR="${OUTPUT%.mp4}.json"

FRAMES_ONLY_DIR="${BIRDFLOW_NUMI_FRAMES_ONLY_DIR:-}"
REUSE_FRAMES_DIR="${BIRDFLOW_NUMI_REUSE_FRAMES_DIR:-}"
[[ -z "$FRAMES_ONLY_DIR" || -z "$REUSE_FRAMES_DIR" ]] || {
  echo "frame-only and frame-reuse modes are mutually exclusive" >&2
  exit 1
}
for tool in jq shasum; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "$tool is required for the Numi crow journey presentation" >&2
    exit 1
  }
done
if [[ -z "$FRAMES_ONLY_DIR" ]]; then
  for tool in ffmpeg ffprobe; do
    command -v "$tool" >/dev/null 2>&1 || {
      echo "$tool is required to encode the Numi crow journey presentation" >&2
      exit 1
    }
  done
fi
[[ -s "$EVIDENCE" && -s "$STATE_TRACE" ]] || {
  echo "Numi evidence and state trace must both be nonempty" >&2
  exit 1
}
jq -e '
  .world_source == "birdflow_american_crow_journey_showcase_v1"
  and .action_count == 14
  and .actor_observation_count == 82
' "$EVIDENCE" >/dev/null || {
  echo "evidence is not the fingerprinted 14-action/82-observation crow journey" >&2
  exit 1
}
grep -q '^# step nq=20 ' "$STATE_TRACE" || {
  echo "state trace is not the 20-coordinate crow journey trace" >&2
  exit 1
}

MANIFEST="$ROOT/ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"
GENERATION_AUDIT="$ROOT/ValidationArtifacts/american-crow-hybrid-surface-generation-v1.json"
PROFILE="$ROOT/ValidationInputs/american-crow-hybrid-visual-v1.json"
PLUMAGE_OPTICS="$ROOT/ValidationInputs/american-crow-plumage-optics-estimated-v1.json"
STANDING_REFERENCE="$ROOT/ValidationInputs/american-crow-standing-reference-v1.json"

if [[ -n "$REUSE_FRAMES_DIR" ]]; then
  TEMP="$REUSE_FRAMES_DIR"
elif [[ -n "$FRAMES_ONLY_DIR" ]]; then
  TEMP="$FRAMES_ONLY_DIR"
  mkdir -p "$TEMP"
else
  TEMP="$(mktemp -d "${TMPDIR:-/tmp}/birdflow-numi-crow.XXXXXX")"
fi
cleanup() {
  if [[ -z "$FRAMES_ONLY_DIR" && -z "$REUSE_FRAMES_DIR" ]]; then
    rm -r "$TEMP"
  fi
}
trap cleanup EXIT

mkdir -p "$(dirname "$OUTPUT")" "$(dirname "$POSTER")" "$(dirname "$GIF")"
cd "$ROOT"

render_pass() {
  local name="$1"
  local presentation="$2"
  local yaw="$3"
  local pitch="$4"
  local distance="$5"
  local yaw_orbit="$6"
  local distance_scale="$7"
  local distance_args=()
  if [[ "$distance" != "auto" ]]; then
    distance_args=(--capture-crow-camera-distance "$distance")
  fi
  local directory="$TEMP/$name"
  mkdir -p "$directory"
  # This renderer currently needs both ASan's lifetime instrumentation and the
  # Metal API validation interposer in optimized command-line captures. Without
  # that pair, it can fault before the first completed command buffer. Shader
  # validation is intentionally not enabled because it is not required and is
  # much slower.
  env MTL_DEBUG_LAYER=1 ASAN_OPTIONS=abort_on_error=1 "$CAPTURE" \
    --capture-crow-frames "$directory" \
    --capture-crow-surface-manifest "$MANIFEST" \
    --capture-crow-surface-generation-audit "$GENERATION_AUDIT" \
    --capture-crow-profile "$PROFILE" \
    --capture-crow-plumage-optics "$PLUMAGE_OPTICS" \
    --capture-crow-standing-reference "$STANDING_REFERENCE" \
    --capture-crow-presentation "$presentation" \
    --capture-crow-camera-yaw "$yaw" \
    --capture-crow-camera-yaw-orbit "$yaw_orbit" \
    --capture-crow-camera-pitch "$pitch" \
    "${distance_args[@]}" \
    --capture-crow-camera-distance-scale "$distance_scale" \
    --capture-width 1280 \
    --capture-height 720 \
    --capture-frames 49
}

# Each pass owns a deliberate readable angle. Camera cuts happen only at stage
# boundaries; the crow renderer retains its full feather topology within every
# pass. The presentation is phase-keyed to Numi's task structure, not a claim
# that these pixels are the native visual sensor or a joint-exact state replay.
if [[ -z "$REUSE_FRAMES_DIR" ]]; then
  CAPTURE_BUILD="$ROOT/.build/numi-crow-capture"
  swift build --build-path "$CAPTURE_BUILD" -c release \
    --sanitize=address --product birdflow-capture
  CAPTURE="$CAPTURE_BUILD/release/birdflow-capture"
  render_pass standing standing 0.62 0.12 0.52 0.025 1
  render_pass takeoff takeoff 0.18 0.20 auto 0.08 1.35
  render_pass flight-front wingbeat -0.42 0.29 1.12 0.12 1
  render_pass flight-side wingbeat -0.88 0.38 1.07 -0.22 1
  render_pass flight-rear wingbeat 0.82 0.38 1.08 0.20 1
fi
if [[ -n "$FRAMES_ONLY_DIR" ]]; then
  echo "Numi crow presentation frames: $TEMP"
  exit 0
fi

encode_loop() {
  local name="$1"
  ffmpeg -v error -y -framerate 24 \
    -i "$TEMP/$name/frame-%03d.png" -frames:v 48 \
    -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p \
    "$TEMP/$name.mp4"
}
encode_loop standing
encode_loop flight-front
encode_loop flight-side
encode_loop flight-rear
ffmpeg -v error -y -framerate 24 \
  -i "$TEMP/takeoff/frame-%03d.png" -frames:v 49 \
  -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p \
  "$TEMP/takeoff.mp4"
ffmpeg -v error -y -i "$TEMP/takeoff.mp4" \
  -vf reverse -an -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p \
  "$TEMP/landing.mp4"

ffmpeg -v error -y \
  -i "$TEMP/standing.mp4" \
  -i "$TEMP/takeoff.mp4" \
  -i "$TEMP/flight-front.mp4" \
  -i "$TEMP/flight-side.mp4" \
  -i "$TEMP/flight-rear.mp4" \
  -i "$TEMP/landing.mp4" \
  -filter_complex \
    '[0:v][1:v][2:v][3:v][4:v][5:v]concat=n=6:v=1:a=0[v]' \
  -map '[v]' -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p \
  -movflags +faststart "$OUTPUT"

# Use the close three-quarter stance as the poster so the eye, bill, layered
# body contours, feet, and tail remain readable at README scale. The video
# carries the complete takeoff and multi-angle flight sequence.
cp "$TEMP/standing/frame-024.png" "$POSTER"
ffmpeg -v error -y -i "$OUTPUT" \
  -vf 'fps=12,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse' \
  "$GIF"

DIMENSIONS="$(
  ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height -of csv=s=x:p=0 "$OUTPUT"
)"
FRAME_COUNT="$(
  ffprobe -v error -count_frames -select_streams v:0 \
    -show_entries stream=nb_read_frames -of default=nw=1:nk=1 "$OUTPUT"
)"
[[ "$DIMENSIONS" == "1280x720" && "$FRAME_COUNT" -ge 280 ]] || {
  echo "unexpected presentation contract: $DIMENSIONS, $FRAME_COUNT frames" >&2
  exit 1
}

OUTPUT_HASH="$(shasum -a 256 "$OUTPUT" | awk '{print $1}')"
EVIDENCE_HASH="$(shasum -a 256 "$EVIDENCE" | awk '{print $1}')"
TRACE_HASH="$(shasum -a 256 "$STATE_TRACE" | awk '{print $1}')"
TRACE_FINAL_STEP="$(awk 'END {print $1}' "$STATE_TRACE")"
jq -n \
  --arg schema "birdflow.numi-crow-presentation.v1" \
  --arg output "$OUTPUT" \
  --arg output_sha256 "$OUTPUT_HASH" \
  --arg evidence "$EVIDENCE" \
  --arg evidence_sha256 "$EVIDENCE_HASH" \
  --arg state_trace "$STATE_TRACE" \
  --arg state_trace_sha256 "$TRACE_HASH" \
  --argjson state_trace_final_step "$TRACE_FINAL_STEP" \
  --argjson native_evidence "$(jq '{action_source,birdflow_journey_teacher,task_fingerprint,observation_fingerprint,action_fingerprint,mean_root_height,maximum_root_height,mean_tilt,maximum_tilt,mean_final_forward_progress_m,maximum_forward_progress_m,termination_reason_counts}' "$EVIDENCE")" \
  '{
    schema: $schema,
    classification: "high-quality phase-keyed presentation replay",
    limitation: "BirdFlow feather pixels are not the Numi native visual sensor and are not a joint-exact state replay.",
    camera_sequence: ["standing-front-three-quarter", "takeoff-three-quarter", "flight-front-orbit", "flight-high-left-orbit", "flight-rear-orbit", "landing-reverse-three-quarter"],
    output: $output,
    output_sha256: $output_sha256,
    evidence: $evidence,
    evidence_sha256: $evidence_sha256,
    state_trace: $state_trace,
    state_trace_sha256: $state_trace_sha256,
    state_trace_final_step: $state_trace_final_step,
    native_evidence: $native_evidence
  }' > "$SIDECAR"

echo "Numi crow presentation: $OUTPUT ($DIMENSIONS, $FRAME_COUNT frames, sha256=$OUTPUT_HASH)"
echo "Evidence sidecar: $SIDECAR"
