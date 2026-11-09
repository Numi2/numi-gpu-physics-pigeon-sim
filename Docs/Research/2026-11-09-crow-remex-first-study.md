# First remex study: results and next prediction

The three fixed-topology candidates and the matched baseline are retained in
`Evidence/crow-remex-20261109/`. Five 100-frame views use exactly the same
layout-I states, lighting and cameras. Landing clips are inspection views with
course geometry hidden; they are not proof of foot contact or a policy test.
The v15 controller and retained physical rollout were not changed.

- Candidate 1: separate shaft identities and a passing reference-pose symmetry
  and centerline-crossing check, but sharp protruding spikes in overhead view.
  Rejected.
- Candidate 2: rounded vane envelope and a larger trailing-edge replacement
  removed the longest spikes, but produced an obviously serrated edge and
  leaves the outer primary fan obscured. Rejected.
- Candidate 3: restoring the inner sheet reduced the serration and extending
  the distal vanes exposed only a few broad outer tips. The remaining solid
  oval and repeated coverts still obscure the primary fan, while the landing
  handoff remains abrupt. Rejected as a photorealism qualification.

All three 100-frame clips completed for each of five views under the Metal API
validation layer. That is a limited no-crash observation, not a general fix
for the previously reported renderer crash. Reference-pose mathematical tests
are not vane-intersection or time-series flight validation. These replays are
historical development data, not unused layouts.

New hypothesis, prior to another visual trial: the major remaining fan defect
is occlusion by the inherited distal wing sheet and covert courses, not merely
tip shape. Removing the outer trailing portion while retaining the proximal
sheet, and exposing overlapping broad outer vanes, should yield an ordered
fan without detached roots or see-through slots. Compare the same 100 frames
and five views, plus the landing window, to all three retained trials. Reject
it if the wing gains holes or a worse silhouette. Any animation of the
estimated wrist remains a presentation approximation; no measured crow
kinematics are available in this dataset.
