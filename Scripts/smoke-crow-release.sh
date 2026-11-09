#!/bin/bash
# Exercise the normal optimized capture path, including live wing uploads
# when one or more accepted replay projections are supplied.
set -euo pipefail
cd "$(dirname "$0")/.."
renderer=${CROW_CAPTURE_BINARY:-.build/release/birdflow-capture}
if [ ! -x "$renderer" ]; then
  printf "missing renderer: %s\n" "$renderer" >&2
  exit 2
fi
scratch=$(mktemp -d "${TMPDIR:-/tmp}/crow-release-smoke.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
"$renderer" --capture-crow-frames "$scratch/standing" --capture-frames 2 \
  --capture-width 320 --capture-height 180 --capture-crow-presentation standing
index=0
for replay in "$@"; do
  index=$((index + 1))
  "$renderer" --capture-crow-frames "$scratch/course-$index" --capture-frames 3 \
    --capture-width 320 --capture-height 180 --capture-crow-presentation takeoff \
    --capture-crow-solid-course --capture-crow-replay-pack "$replay"
done
