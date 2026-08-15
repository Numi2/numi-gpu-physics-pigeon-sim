#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/Docs/Media/american-crow-hybrid-native-v1.mp4}"
POSTER="${2:-$ROOT/Docs/Media/american-crow-hybrid-native-v1.png}"
MANIFEST="$ROOT/ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"
GENERATION_AUDIT="$ROOT/ValidationArtifacts/american-crow-hybrid-surface-generation-v1.json"
PROFILE="$ROOT/ValidationInputs/american-crow-hybrid-visual-v1.json"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required to encode the crow showcase" >&2
  exit 1
fi
if ! command -v ffprobe >/dev/null 2>&1; then
  echo "ffprobe is required to verify the crow showcase" >&2
  exit 1
fi

FRAMES="$(mktemp -d "${TMPDIR:-/tmp}/birdflow-crow.XXXXXX")"
cleanup() {
  rm -r "$FRAMES"
}
trap cleanup EXIT

mkdir -p "$(dirname "$OUTPUT")" "$(dirname "$POSTER")"
cd "$ROOT"
swift build -c release --product birdflow-viewer

# The 49th frame is a seam probe equal to frame zero. The encoded movie uses
# the first 48 frames, avoiding a duplicated endpoint pause at the loop wrap.
.build/release/birdflow-viewer \
  --capture-crow-frames "$FRAMES" \
  --capture-crow-surface-manifest "$MANIFEST" \
  --capture-crow-surface-generation-audit "$GENERATION_AUDIT" \
  --capture-crow-profile "$PROFILE" \
  --capture-width 1280 \
  --capture-height 720 \
  --capture-frames 49

ffmpeg -v error -y \
  -framerate 24 \
  -i "$FRAMES/frame-%03d.png" \
  -frames:v 48 \
  -c:v libx264 \
  -preset slow \
  -crf 17 \
  -pix_fmt yuv420p \
  -movflags +faststart \
  "$OUTPUT"
# Use a solver-surface-driven mid-downstroke as the README poster rather than
# a separate reference image or a cosmetically selected non-executable pose.
cp "$FRAMES/frame-030.png" "$POSTER"

DIMENSIONS="$(
  ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height -of csv=s=x:p=0 "$OUTPUT"
)"
FRAME_COUNT="$(
  ffprobe -v error -count_frames -select_streams v:0 \
    -show_entries stream=nb_read_frames -of default=nw=1:nk=1 "$OUTPUT"
)"
FIRST_HASH="$(shasum -a 256 "$FRAMES/frame-000.png" | awk '{print $1}')"
LAST_HASH="$(shasum -a 256 "$FRAMES/frame-048.png" | awk '{print $1}')"

if [[ "$DIMENSIONS" != "1280x720" || "$FRAME_COUNT" != "48" ]]; then
  echo "unexpected crow movie contract: ${DIMENSIONS}, ${FRAME_COUNT} frames" >&2
  exit 1
fi
if [[ -z "$FIRST_HASH" || "$FIRST_HASH" != "$LAST_HASH" ]]; then
  echo "crow presentation endpoint probe is not pixel-seamless" >&2
  exit 1
fi

BYTES="$(stat -f '%z' "$OUTPUT")"
SHA256="$(shasum -a 256 "$OUTPUT" | awk '{print $1}')"
echo "Crow showcase: $OUTPUT (${DIMENSIONS}, ${FRAME_COUNT} frames, ${BYTES} bytes, sha256=${SHA256})"
