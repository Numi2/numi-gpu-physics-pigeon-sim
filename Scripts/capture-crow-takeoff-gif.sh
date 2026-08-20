#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/Docs/Media/american-crow-standing-to-flight-v1.gif}"
MANIFEST="$ROOT/ValidationInputs/american-crow-hybrid-surface-v1/manifest.json"
GENERATION_AUDIT="$ROOT/ValidationArtifacts/american-crow-hybrid-surface-generation-v1.json"
PROFILE="$ROOT/ValidationInputs/american-crow-hybrid-visual-v1.json"
STANDING_REFERENCE="$ROOT/ValidationInputs/american-crow-standing-reference-v1.json"

for tool in ffmpeg ffprobe; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool is required to encode and verify the crow takeoff GIF" >&2
    exit 1
  fi
done

FRAMES="$(mktemp -d "${TMPDIR:-/tmp}/birdflow-crow-takeoff.XXXXXX")"
cleanup() {
  rm -r "$FRAMES"
}
trap cleanup EXIT

mkdir -p "$(dirname "$OUTPUT")"
cd "$ROOT"
swift build -c release --product birdflow-viewer

.build/release/birdflow-viewer \
  --capture-crow-frames "$FRAMES" \
  --capture-crow-surface-manifest "$MANIFEST" \
  --capture-crow-surface-generation-audit "$GENERATION_AUDIT" \
  --capture-crow-profile "$PROFILE" \
  --capture-crow-standing-reference "$STANDING_REFERENCE" \
  --capture-crow-presentation takeoff \
  --capture-width 1280 \
  --capture-height 720 \
  --capture-frames 72

ffmpeg -v error -y \
  -framerate 24 \
  -i "$FRAMES/frame-%03d.png" \
  -filter_complex \
    "scale=800:450:flags=lanczos,split[frames][paletteInput];[paletteInput]palettegen=max_colors=224:stats_mode=diff[palette];[frames][palette]paletteuse=dither=sierra2_4a:diff_mode=rectangle" \
  -frames:v 72 \
  -loop 0 \
  -gifflags 0 \
  "$OUTPUT"

DIMENSIONS="$(
  ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height -of csv=s=x:p=0 "$OUTPUT"
)"
FRAME_COUNT="$(
  ffprobe -v error -count_frames -select_streams v:0 \
    -show_entries stream=nb_read_frames -of default=nw=1:nk=1 "$OUTPUT"
)"
DISPLAY_DURATION="$(
  ffprobe -v error -select_streams v:0 \
    -show_entries stream=duration -of default=nw=1:nk=1 "$OUTPUT"
)"
FIRST_HASH="$(shasum -a 256 "$FRAMES/frame-000.png" | awk '{print $1}')"
TRANSITION_HASH="$(shasum -a 256 "$FRAMES/frame-035.png" | awk '{print $1}')"
FLIGHT_HASH="$(shasum -a 256 "$FRAMES/frame-071.png" | awk '{print $1}')"

if [[ "$DIMENSIONS" != "800x450" || "$FRAME_COUNT" != "72" \
  || "$DISPLAY_DURATION" != "3.000000" ]]; then
  echo "unexpected crow GIF contract: ${DIMENSIONS}, ${FRAME_COUNT} frames, ${DISPLAY_DURATION}s" >&2
  exit 1
fi
if [[ "$FIRST_HASH" == "$TRANSITION_HASH" \
  || "$TRANSITION_HASH" == "$FLIGHT_HASH" \
  || "$FIRST_HASH" == "$FLIGHT_HASH" ]]; then
  echo "crow GIF stages are not visually distinct" >&2
  exit 1
fi

BYTES="$(stat -f '%z' "$OUTPUT")"
if (( BYTES >= 10000000 )); then
  echo "crow GIF exceeds the 10 MB presentation budget: $BYTES bytes" >&2
  exit 1
fi
SHA256="$(shasum -a 256 "$OUTPUT" | awk '{print $1}')"
echo "Crow takeoff GIF: $OUTPUT (${DIMENSIONS}, ${FRAME_COUNT} frames, ${BYTES} bytes, sha256=${SHA256})"
