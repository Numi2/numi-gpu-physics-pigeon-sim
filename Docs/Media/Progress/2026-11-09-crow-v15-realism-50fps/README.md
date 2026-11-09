# V15 crow replay: retargeted 50 Hz presentation

This video renders the two retained, formerly reserved Numi Lab v15 navigation
rollouts. It is a replay of simulator states, not a fresh controller run or
footage of an animal. Each layout displays steps 1–2999 consecutively at
50 fps; the final terminal step 3000 is excluded, as in the earlier video.
There are no intermediate resets. Layout I comes first, then layout J.

| Layout | Seed | First waypoint steps 1–5 | Sustained support confirmed |
|---|---:|---|---:|
| I | 4038889268 | 859, 1113, 1371, 1578, 1728 | 2037 |
| J | 3193706597 | 802, 1046, 1300, 1484, 1553 | 1689 |

The independent native replays, verification, and input traces are archived in
Numi Lab commit `7d32ee3722a1f26c58ad111b46e9edb9ce3b401c`, directory
`artifacts/crow-final-video-replay-20261109/`. Their controller was neural-only
and the frozen flight controller and physical model were not changed for this
presentation. The policy uses simulator-provided waypoint coordinates.

The image uses the existing estimated BirdFlow crow. The proximal wing surface
now blends the accepted link movement into a seated shoulder, and tail and
feather registration pivots follow the presentation body translation. The
free distal wing retains its accepted link delta. This is estimated skinning,
not measured feather deformation. The landing-fold transition is inferred
only after recorded sustained support; the model does not demonstrate toe
grasp or realistic contact. Box cutaways, studio light and color are visual
choices; the recorded collider poses, controller and trajectory are unchanged.
The crow and scene remain visibly computer-generated and are not validated
against photographed crow anatomy, wingbeat kinematics, forces or illumination.
See `Docs/CROW_V15_REALISM_AUDIT.md`.

The video was streamed as ten independently playable H.264 sections from
capture source commit `5e198dd` using the non-whole-module-optimized release
build, then concatenated without re-encoding. The retained timeline, all
waypoint counters and landing-support overlay correspond to the recorded
states. No image sequence was retained. A subsequent repair at commit
`3162421` allows normal whole-module-optimized release captures: standing,
AOV, both course smoke runs, 50 consecutive encoded frames on each course,
and a 900-frame continuous encoded run on I passed. A matching step-1500
flight frame was pixel-identical between the video build and repaired default
release build at 640 × 360. These checks do not prove all renderer modes or
physical/biological realism.
