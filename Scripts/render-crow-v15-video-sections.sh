#!/bin/bash
# Render complete v15 accepted-state replays into independently playable
# sections, without generating a large sequence of intermediate PNGs.
set -euo pipefail
if [ "$#" -ne 3 ]; then
  printf "usage: %s OUTPUT_DIRECTORY I_REPLAY_JSON J_REPLAY_JSON\n" "$0" >&2
  exit 2
fi
output=$1
input_i=$2
input_j=$3
renderer=${CROW_CAPTURE_BINARY:-.build/nowmo/release/birdflow-capture}
for path in "$input_i" "$input_j" "$renderer"; do
  if [ ! -f "$path" ]; then printf "missing input: %s\n" "$path" >&2; exit 2; fi
done
mkdir -p "$output"
for course in i j; do
  if [ "$course" = i ]; then input=$input_i; else input=$input_j; fi
  for start in 0 300 600 900 1200; do
    end=$((start + 299))
    label=$(printf "%s-%04d" "$course" "$start")
    "$renderer" --capture-crow-frames "$output/$label-audit" \
      --capture-crow-video "$output/$label.mp4" --capture-crow-video-fps 25 \
      --capture-frames 1500 --capture-frame-start "$start" --capture-frame-end "$end" \
      --capture-width 1280 --capture-height 720 --capture-crow-solid-course \
      --capture-crow-presentation takeoff --capture-crow-replay-pack "$input" \
      --capture-crow-lighting overcast --capture-crow-camera-yaw -1.25 \
      --capture-crow-camera-pitch 0.25 --capture-crow-camera-distance 1.15
  done
done
