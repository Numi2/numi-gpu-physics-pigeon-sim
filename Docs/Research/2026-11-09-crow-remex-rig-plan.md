# Crow remex rig: bounded exploratory plan

Owner: BirdFlow visualization on macmini. Baseline: Git 40a9874; existing v15
accepted-state replays are unchanged and are not new policy evaluations.

Question: can a fixed-topology, separately articulated set of flight feathers
replace the uniformly rounded trailing surface without visible gaps, crossing,
or a temporal renderer failure? Alternative: the estimated dove-derived surface
and existing coverts cannot support an anatomically plausible crow outline.

Intervention: bind estimated primary and secondary feathers to the live wing
surface and its visual shoulder/elbow/wrist controls. Preserve recorded body
poses, controller, colliders and physical contact. The joints and feather
motion are presentation estimates, not animal measurements or simulated
forces. Use existing reality asset dimensions as initial estimates and compare
qualitatively against documented American crow imagery. The existing magpie
flight study informs flexion direction, not species calibration.

Exploratory views: paired same-state before/after captures on layout I from
front, side, back, top and underside across at least one complete 50 Hz stroke,
plus continuous takeoff and landing windows. Mask course geometry only for
inspection. Retain failed/interrupted variants and source identities in Git.
Layout J remains unused for design decisions until the visual design freezes;
it was used historically and is not a scientific held-out layout.

Predictions and checks before acceptance:
- Both wings retain ten primary and eleven secondary identities; temporal
  topology and identifiers remain constant, including deployment to landing.
- Mirrored rest inputs produce mirrored roots/tips within 1e-5 m; roots remain
  attached to their sampled surface, and vanes have finite nonzero length in
  deployed flight. Evaluate tip ordering and neighboring intersections in
  the common wing plane; any crossings, detached roots or large holes are a
  failure, not a result to conceal with camera or lighting.
- At least 100 consecutive matched I frames and a continuous landing window
  must render and decode without temporal-topology or GPU errors. Qualify both
  full I and J sequences only after the design is fixed. Inspect visible
  five-angle playback and the first/last contact transitions.
- Compare the same state, camera, lighting and resolution to the 40a9874
  baseline. Preserve control and intervention evidence. This is visual
  engineering qualification, not proof of photorealism, biological fidelity,
  animal aerodynamic validity or success on new layouts.

Bounded experiment: up to three distinct remex-layout candidates, then record
which deficiencies remain. Calibration against tracked 3D American-crow wing
landmarks and independent animal footage is not currently available; do not
claim it passed. Store compact evidence and source in the original Git repo;
remove temporary expanded replays and frames after verified restoration.
