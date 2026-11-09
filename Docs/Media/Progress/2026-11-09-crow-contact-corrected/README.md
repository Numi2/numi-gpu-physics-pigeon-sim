# V15 crow: complete-state visual follow-up

This is a **simulated replay**, not footage of an animal or a new evaluation.
It presents both formerly reserved layouts from their independently verified
Numi Lab reruns. Each includes every state, steps 1–3000, at 50 frames per
second. There is no intermediate reset. Step 3000 is the recorded episode
timeout after completion, not a reset. Layout I is followed by J.

| Layout | Seed | First reach of waypoints 1–5 | Ten consecutive support samples confirmed at |
| --- | ---: | --- | ---: |
| I | 4038889268 | 859, 1113, 1371, 1578, 1728 | 2037 |
| J | 3193706597 | 802, 1046, 1300, 1484, 1553 | 1689 |

The policy is neural-only but receives simulator-provided waypoint coordinates.
The v15 physical controller, collisions and accepted trajectories were not
changed by this visual work. The original source replays and their independent
rerun verification are archived in Numi Lab commit
`7d32ee3722a1f26c58ad111b46e9edb9ce3b401c`, under
`artifacts/crow-final-video-replay-20261109/`.

## What changed and what has not been established

The estimated American crow has a straighter bill, and the visual lower
mandible follows the recorded lower-beak link relative to the head. Individual
visual toe pads follow their corresponding digit nodes. Neutral daylight and
filtered procedural surface variations replace the previous orange studio
background. A restrained local contact occlusion follows posed visual foot
vertices and fades when the foot is away from a course surface; this is a
presentation effect, not measured contact or a cast shadow. The camera-facing
obstacles may be shown as labeled wireframe cutaways; solid collider dimensions
and poses remain the recorded simulation geometry.

The bird is still visibly computer-generated and is **not validated as
photorealistic or biologically accurate**. The wing skin and feathers are
retargeted from an estimated scaffold to recorded rigid links; individual
feather flex and crow wingbeat mechanics are not measured. The supported pose
uses a presentation-only settling transition and visual toes; simulated feet
are rigid contact proxies and do not establish toe grasp. Lighting and
materials are not calibrated to a real environment. The simulation uses
simplified flight dynamics and direct body-control authority. See
`Docs/CROW_V15_REALISM_AUDIT.md` for the full limitations. Cornell's
[American Crow identification guide](https://www.allaboutbirds.org/guide/american_crow/id)
provided species-level bill and silhouette context, not calibration data.

## Reproducibility and checks

* Renderer source: `747c5652775dcbb43a7f896a43edfbe97f3f0a6d`.
* Optimized renderer SHA-256:
  `71b8f7b93beaee867bbab303011d66d093e110ea72a9d5df46e3836633d73b28`.
* Metal shader source SHA-256:
  `ff2f4102a7c0ee405de8e9e6155ae5efd557815a1f6980bceda09231d4d2f627`.
* Source replay byte SHA-256: I
  `5efa5a89a028ca5ef039191778bced33c00d20decc874284edfc53e2b165f1de`;
  J `d3d396fc3e41d7f2d56c799c18bf7b96db96de51205a69319fd920a714ac6f4f`.
  These match the separate Numi Lab verification reports. The native embedded
  payload hash does not survive parse/reserialization and is not claimed as
  verified. Hash-bound re-projections match the capture inputs byte for byte.
* Timeline and projection checks are in `timeline-checks.json` and
  `projection-checks.json`; six repeatable projection regression cases are
  in `Scripts/test-crow-replay-projection.py`. Four targeted Swift tests
  covered the jaw transform and foot-pad attachment. The optimized renderer
  completed 50 consecutive encoded frames on each course. A matched airborne
  frame was pixel-identical to the pre-contact-shading renderer, while the
  matched landing comparison shows the contact effect (`contact-before-after.png`,
  before on the left and after on the right). `landing-timeline-i.png` shows
  layout I at half-second intervals from 38 through 43.5 seconds, and
  `landing-timeline-j.png` shows layout J from 32 through 35.5 seconds; the
  estimated folding/settling transition is still visually abrupt.
* An exploratory pass reached its last frame but exited with a shell error
  after its script was edited while running; its compressed log is retained.
  The final pass used the fixed, unmodified script and exited successfully.
  All ten audit windows cover the expected states. The combined H.264 video
  independently counted 6,000 frames at 50 fps, 1,600 by 900, 120 seconds;
  a complete decode with error checking passed. Its SHA-256 is
  `7fb164266555024b10123a3ee3f113eafa81e249d3dc0be04b270b47c7788b81`.

The 3,000-state projections can be reproduced from the original uncompressed
replay bytes with `Scripts/project-crow-replay.swift`, `--stride 1`,
`--stop-index 2999`, the independently archived `--source-sha256` value above,
and `--include-final-timeout`. The complete videos are streamed in sections
by `Scripts/render-crow-v15-video-sections.sh`; the script rejects a frame-count
mismatch rather than silently duplicating or skipping states.
