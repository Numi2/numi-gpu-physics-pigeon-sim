# V15 crow navigation replay: two layouts

This is an estimated BirdFlow presentation of retained Numi Lab accepted states.
The video has two 60-second sections, layout I followed by layout J; each
shows one uninterrupted neural-only episode, sampled at 25 fps from the
50 Hz accepted-state trace. It is a replay, not a live agent or real footage.

The archived Numi Lab source replays and independent rerun verification are in
`artifacts/crow-final-video-replay-20261109/` at Numi Lab commit
`7d32ee3722a1f26c58ad111b46e9edb9ce3b401c`. The source tracks each contain
3,000 accepted steps; for rendering they were canonicalized by
`Scripts/project-crow-replay.swift --stride 1 --stop-index 2998`. This keeps
steps 1–2999, excluding the terminal step, with no intermediate reset. The
projection preserves the source JSON SHA-256 in its metadata. The 1,500 video
frames select steps 1, 3, ..., 2999 at the original speed.

| Layout | Seed | First recorded waypoint steps 1–5 | Sustained support confirmed |
|---|---:|---|---:|
| I | 4038889268 | 859, 1113, 1371, 1578, 1728 | 2037 |
| J | 3193706597 | 802, 1046, 1300, 1484, 1553 | 1689 |

Solid boxes and the ground patch show the recorded collision geometry; color,
lighting, the studio backdrop and feather appearance are presentation
estimates. An obstacle intersecting the camera-to-body sightline is shown as
an explicitly labeled wireframe cutaway. This is a camera aid: it does not
change the original collision or movement. The bird is centered in its body
frame and the environment moves relative to it. Head, wing and leg links are
state-driven, while the skin, feather deformation and landing transition are
estimated. Recorded support must persist 0.2 seconds before a 0.5-second
visual settling transition begins; it is not a new physics verification.

The video is H.264, 1280 × 720 at 25 fps. It was generated as 300-frame
sections, encoded directly without an image sequence, then concatenated
without re-encoding. An independently rendered two-frame overlap at the first
section boundary differed from the decoded section frames by mean RGB values
of 0.637/0.342 out of 255 for I and 0.542/0.318 for J, respectively.

A prior full-length capture ended with SSH exit 255 after at least frame 870
and left an unfinalized movie; the cause was not established. Its partial
movie was not used. The solid-only first version also obscured the bird at
step 877. The adjacent before/after images preserve that visual defect and the
labeled cutaway correction. These checks do not establish photorealism,
biomechanical realism, grasp mechanics, or generalization to real animals.
See `Docs/CROW_V15_REALISM_AUDIT.md` for the remaining gaps.
