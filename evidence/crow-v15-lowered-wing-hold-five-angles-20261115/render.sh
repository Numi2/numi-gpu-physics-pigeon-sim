#!/bin/bash
set -euo pipefail
REPO=/Users/n/Developer/numi-crow-rl-20261107
A="$REPO/artifacts/crow-v15-recorded-restart-20261114"
BASE=/tmp/crow-48s-multiview-20261114
RENDERER=/tmp/crow-capsule-render-20261115
OUT="$A/v15-coupled-wing-hip-hard1500-render-20261115"
mkdir "$OUT"
EVAL="$A/v15-coupled-wing-hip-followup-20261115"
PREFIX="$A/v15-resetfixed-checkpoint-roundtrip-20370113-49-100/prefix.json"
COUNT=1500
END=$COUNT
START=1200
COUNT=$((END-START))
TOTAL=$COUNT
printf '%s %s\n' "$START" "$END" > "$OUT/window.txt"
swift "$A/crow_v15_trial_window_render_splice.swift" "$BASE/replay.json" "$PREFIX" "$EVAL/20370113-hip_minus090-1500.json" "$OUT/presentation-splice.json" "$COUNT" "$START" > "$OUT/splice.log" 2>&1
cd "$RENDERER"
while read -r view yaw pitch distance; do
 hide=0; [ "$view" = below ] && hide=1
 CROW_RENDER_ROUND_PERCH=1 CROW_WORLD_UP_CAMERA=1 CROW_RENDER_HIDE_GROUND="$hide" CROW_CAPTURE_WARMUP_FRAMES=2 .build/arm64-apple-macosx/release/birdflow-capture --capture-crow-frames "$OUT/frames-$view" --capture-crow-video "$OUT/$view.mp4" --capture-crow-video-fps 50 --capture-frames "$((TOTAL+5))" --capture-frame-start 5 --capture-width 640 --capture-height 480 --capture-crow-research-narrow-perch --capture-crow-research-toe-hinges --capture-crow-solid-course --capture-crow-presentation takeoff --capture-crow-replay-pack "$OUT/presentation-splice.json" --capture-crow-lighting overcast --capture-crow-camera-yaw "$yaw" --capture-crow-camera-pitch "$pitch" --capture-crow-camera-distance "$distance" > "$OUT/$view.log" 2>&1
 printf '%s complete\n' "$view"
done <<'VIEWS'
front 0 0.18 1.35
back 3.14159 0.18 1.35
above 0 1.32 1.35
below 0 -1.32 1.35
feet -1.25 -0.50 0.68
VIEWS
shasum -a 256 "$OUT"/*.mp4 > "$OUT/video-sha256.txt"
