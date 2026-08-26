#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/Docs/Media/numi-crow-journey-v7.mp4}"
POSTER="${2:-$ROOT/Docs/Media/numi-crow-journey-v7.png}"
EVIDENCE="${3:?usage: capture-crow-numi-journey.sh OUTPUT POSTER EVIDENCE REPLAY_PACK QUALIFICATION_DIR [GIF]}"
REPLAY_PACK="${4:?usage: capture-crow-numi-journey.sh OUTPUT POSTER EVIDENCE REPLAY_PACK QUALIFICATION_DIR [GIF]}"
QUALIFICATION_DIR="${5:?usage: capture-crow-numi-journey.sh OUTPUT POSTER EVIDENCE REPLAY_PACK QUALIFICATION_DIR [GIF]}"
GIF="${6:-${OUTPUT%.mp4}.gif}"
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
[[ -s "$EVIDENCE" && -s "$REPLAY_PACK" && -d "$QUALIFICATION_DIR" ]] || {
  echo "Numi evidence, CrowReplayPack, and qualification directory are required" >&2
  exit 1
}
TASK="$(jq -r '.task // empty' "$EVIDENCE")"
ACTION_CARRIER="$(jq -r '.action_carrier // empty' "$EVIDENCE")"
case "$TASK:$ACTION_CARRIER" in
  birdflow_american_crow_journey_v7:v7_state_triggered_approach_supervisor_pitch_0.16_0.22_full_authority)
    ACTOR_OBSERVATIONS=84
    CONTROLLER_BOUNDARY="The v7 policy carrier retains state-triggered approach-pitch supervisor actuator authority." ;;
  birdflow_american_crow_journey_v8_neural:v8_neural_only_shadow_approach_envelope)
    ACTOR_OBSERVATIONS=84
    CONTROLLER_BOUNDARY="The v8 policy carrier is neural-only; approach envelopes are diagnostic outcomes without actuator authority." ;;
  birdflow_american_crow_journey_v9_visual_neural:v9_visual_neural_only_masked_depth_history)
    ACTOR_OBSERVATIONS=684
    CONTROLLER_BOUNDARY="The v9 policy carrier is neural-only and consumes masked-depth history; approach envelopes are diagnostic outcomes without actuator authority." ;;
  *)
    echo "evidence does not identify a supported Crow journey controller" >&2
    exit 1 ;;
esac
jq -e --arg task "$TASK" --arg carrier "$ACTION_CARRIER" \
  --argjson actor_observations "$ACTOR_OBSERVATIONS" '
  .world_source == $task
  and .task == $task
  and .action_count == 15
  and .actor_observation_count == $actor_observations
  and .action_source == "policy_pack"
  and .birdflow_journey_teacher == false
  and .action_carrier == $carrier
  and .failed_environment_steps == 0
  and .termination_count == .timeout_count
' "$EVIDENCE" >/dev/null || {
  echo "evidence is not a clean fingerprinted Crow journey policy rollout" >&2
  exit 1
}
jq -e --arg task "$TASK" '
  .schema == "numi.crow-replay.v1"
  and .payload.classification == "simulated accepted-state replay"
  and .payload.task == $task
  and .payload.nq == 20 and .payload.nv == 19
  and .payload.action_count == 15
  and .payload.body_state_stride == 13
  and .payload.frame_count == (.payload.frames | length)
  and .payload.frame_count >= 2
  and (.payload_sha256 | length) == 64
' "$REPLAY_PACK" >/dev/null || {
  echo "CrowReplayPack is not a complete accepted-state replay for $TASK" >&2
  exit 1
}
QUALIFICATION_EVIDENCE=("$QUALIFICATION_DIR"/*/evidence.json)
[[ "${#QUALIFICATION_EVIDENCE[@]}" -eq 33 ]] || {
  echo "qualification must contain exactly 33 milestone/seed evidence files" >&2
  exit 1
}
QUALIFICATION_SUMMARY="$(jq -s -e --arg task "$TASK" --arg carrier "$ACTION_CARRIER" '
  def band: .minimum_sampled_difficulty_band;
  def tracking_floor:
    if band == 0 or band == 9 then 0.95
    elif band == 1 then 0.85
    else 0.65
    end;
  . as $runs
  | (($runs | length) == 33
    and all($runs[].world_source; . == $task)
    and all($runs[].task; . == $task)
    and all($runs[].action_carrier; . == $carrier)
    and all($runs[]; .failed_environment_steps == 0)
    and all($runs[]; .termination_count == .timeout_count)
    and all($runs[]; .mean_tracking_score >= tracking_floor)
    and all($runs[]; .mean_tilt <= 0.35 and .maximum_tilt < 0.8)
    and all($runs[]; . as $run | if ([2,3,4,5,6,7,10] | index($run.minimum_sampled_difficulty_band)) != null then $run.maximum_root_height >= 0.55 else true end)
    and all($runs[]; . as $run |
      if ($task != "birdflow_american_crow_journey_v7" and ([7,8,9,10] | index($run.minimum_sampled_difficulty_band)) != null)
      then ($run.outcomes.approach_pitch_warning_fraction.mean <= 0.05
        and $run.outcomes.approach_pitch_full_envelope_fraction.mean <= 0.000001)
      else true end)
    and (($runs | map(.benchmark_seed) | unique | length) == 3)
    and (($runs | map(band) | unique) == [0,1,2,3,4,5,6,7,8,9,10])) as $valid
  | if $valid then {
      run_count: ($runs | length),
      environment_count: (($runs | length) * 32),
      benchmark_seeds: ($runs | map(.benchmark_seed) | unique),
      failed_environment_steps: ($runs | map(.failed_environment_steps) | add),
      non_timeout_terminations: ($runs | map(.termination_count - .timeout_count) | add),
      minimum_mean_tracking_score: ($runs | map(.mean_tracking_score) | min),
      maximum_mean_tilt: ($runs | map(.mean_tilt) | max),
      maximum_tilt: ($runs | map(.maximum_tilt) | max),
      maximum_root_height: ($runs | map(.maximum_root_height) | max)
    } else false end
' "${QUALIFICATION_EVIDENCE[@]}")" || {
  echo "the 33-run $TASK qualification matrix does not satisfy the render gate" >&2
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
  local yaw="$2"
  local pitch="$3"
  local distance="$4"
  local yaw_orbit="$5"
  local distance_scale="$6"
  local directory="$TEMP/$name"
  mkdir -p "$directory"
  # This renderer currently needs both ASan's lifetime instrumentation and the
  # Metal API validation interposer in optimized command-line captures. Without
  # that pair, it can fault before the first completed command buffer. Shader
  # validation is intentionally not enabled because it is not required and is
  # much slower.
  local command=(
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
    --capture-crow-camera-yaw-orbit "$yaw_orbit" \
    --capture-crow-camera-pitch "$pitch" \
    --capture-crow-camera-distance-scale "$distance_scale" \
    --capture-width 1920 \
    --capture-height 1080 --capture-frames 49
  )
  if [[ "$distance" != "auto" ]]; then
    command+=(--capture-crow-camera-distance "$distance")
  fi
  "${command[@]}"
}

# Each pass owns a different readable angle but consumes the same immutable,
# SHA-locked accepted-state replay. Failed liftoff cannot become visual flight:
# the retained surface handoff advances from accepted root lift.
if [[ -z "$REUSE_FRAMES_DIR" ]]; then
  CAPTURE_BUILD="$ROOT/.build/numi-crow-capture"
  swift build --build-path "$CAPTURE_BUILD" -c release \
    --sanitize=address --product birdflow-capture
  CAPTURE="$CAPTURE_BUILD/release/birdflow-capture"
  render_pass standing 0.62 0.12 0.52 0.025 1
  render_pass takeoff -0.28 0.20 auto 0.08 1.35
  render_pass flight-front 0.00 0.26 1.15 0.06 1
  render_pass flight-side -1.42 0.34 1.22 -0.08 1
  render_pass flight-rear 2.20 0.42 1.24 0.08 1
fi
if [[ -n "$FRAMES_ONLY_DIR" ]]; then
  echo "Numi crow presentation frames: $TEMP"
  exit 0
fi

encode_loop() {
  local name="$1"
  ffmpeg -v error -y -framerate 24 \
    -i "$TEMP/$name/frame-%03d.png" -frames:v 48 \
    -c:v libx264 -preset slow -crf 15 -pix_fmt yuv420p \
    "$TEMP/$name.mp4"
}
encode_loop standing
encode_loop flight-front
encode_loop flight-side
encode_loop flight-rear
ffmpeg -v error -y -framerate 24 \
  -i "$TEMP/takeoff/frame-%03d.png" -frames:v 49 \
  -c:v libx264 -preset slow -crf 15 -pix_fmt yuv420p \
  "$TEMP/takeoff.mp4"

ffmpeg -v error -y \
  -i "$TEMP/standing.mp4" \
  -i "$TEMP/takeoff.mp4" \
  -i "$TEMP/flight-front.mp4" \
  -i "$TEMP/flight-side.mp4" \
  -i "$TEMP/flight-rear.mp4" \
  -filter_complex \
    '[0:v][1:v][2:v][3:v][4:v]concat=n=5:v=1:a=0[v]' \
  -map '[v]' -c:v libx264 -preset slow -crf 15 -pix_fmt yuv420p \
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
[[ "$DIMENSIONS" == "1920x1080" && "$FRAME_COUNT" -ge 240 ]] || {
  echo "unexpected presentation contract: $DIMENSIONS, $FRAME_COUNT frames" >&2
  exit 1
}

OUTPUT_HASH="$(shasum -a 256 "$OUTPUT" | awk '{print $1}')"
EVIDENCE_HASH="$(shasum -a 256 "$EVIDENCE" | awk '{print $1}')"
REPLAY_HASH="$(shasum -a 256 "$REPLAY_PACK" | awk '{print $1}')"
QUALIFICATION_EVIDENCE_HASH="$(
  shasum -a 256 "${QUALIFICATION_EVIDENCE[@]}" | shasum -a 256 | awk '{print $1}'
)"
REPLAY_FINAL_STEP="$(jq '.payload.frames[-1].step' "$REPLAY_PACK")"
jq -n \
  --arg schema "birdflow.numi-crow-presentation.v8" \
  --arg output "$OUTPUT" \
  --arg output_sha256 "$OUTPUT_HASH" \
  --arg evidence "$EVIDENCE" \
  --arg evidence_sha256 "$EVIDENCE_HASH" \
  --arg replay_pack "$REPLAY_PACK" \
  --arg replay_pack_sha256 "$REPLAY_HASH" \
  --arg replay_payload_sha256 "$(jq -r '.payload_sha256' "$REPLAY_PACK")" \
  --arg controller_boundary "$CONTROLLER_BOUNDARY" \
  --arg qualification_dir "$QUALIFICATION_DIR" \
  --arg qualification_evidence_sha256 "$QUALIFICATION_EVIDENCE_HASH" \
  --argjson qualification_summary "$QUALIFICATION_SUMMARY" \
  --argjson replay_final_step "$REPLAY_FINAL_STEP" \
  --argjson native_evidence "$(jq '{task,world_source,action_carrier,action_source,birdflow_journey_teacher,task_fingerprint,observation_fingerprint,action_fingerprint,policy_rollout_fingerprint,policy_sample_count,run_fingerprint,mean_root_height,maximum_root_height,mean_tracking_score,mean_tilt,maximum_tilt,mean_final_forward_progress_m,maximum_forward_progress_m,failed_environment_steps,termination_reason_counts}' "$EVIDENCE")" \
  '{
    schema: $schema,
    classification: "high-quality accepted-state-conditioned presentation of an all-milestone-qualified Crow journey policy",
    limitation: ("Root lift and timeline come from the accepted CrowReplayPack; detailed feather deformation remains the estimated BirdFlow retarget and is not the Numi native visual sensor. " + $controller_boundary),
    camera_sequence: ["standing-front-three-quarter", "takeoff-opposite-quarter", "flight-frontal-orbit", "flight-left-lateral-orbit", "flight-rear-dorsal-orbit"],
    output: $output,
    output_sha256: $output_sha256,
    evidence: $evidence,
    evidence_sha256: $evidence_sha256,
    replay_pack: $replay_pack,
    replay_pack_sha256: $replay_pack_sha256,
    replay_payload_sha256: $replay_payload_sha256,
    replay_final_step: $replay_final_step,
    qualification_dir: $qualification_dir,
    qualification_evidence_sha256: $qualification_evidence_sha256,
    qualification_summary: $qualification_summary,
    native_evidence: $native_evidence
  }' > "$SIDECAR"

echo "Numi crow presentation: $OUTPUT ($DIMENSIONS, $FRAME_COUNT frames, sha256=$OUTPUT_HASH)"
echo "Evidence sidecar: $SIDECAR"
