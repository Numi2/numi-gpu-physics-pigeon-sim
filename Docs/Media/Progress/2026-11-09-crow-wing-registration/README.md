# V15 crow wing-motion and multi-angle inspection

The completed videos are presentations of the same previously recorded,
simulated navigation runs, not footage of a bird or fresh policy evaluations.
The physical v15 body, controller, contacts and trajectories were unchanged.

## Changes and limits

The earlier renderer used the centroid of a wing surface as its hinge and
treated an already raised scaffold as the reference pose. In the v15 recording
the wing links share a shoulder origin. The renderer now seats that hinge on
the body and registers each visual wing to its recorded terminal-wing
reference elevation before applying link motion. Both sides reach a
downstroke below the body plane in the targeted test.

The estimated outer wing also bends and sweeps during upstroke, with a bounded
presentation-only cue derived from neighboring recorded wing orientations.
The recorded model has no measured wrist or individual feather joints; the
cue is neither a simulated physical joint nor a measurement of a crow.
The direction was informed by a
[high-speed study of several bird species](https://umimpact.umt.edu/en/publications/wing-kinematics-of-avian-flight-across-speeds/),
including the black-billed magpie, a different corvid. It does not calibrate
American crow kinematics.

Top, underside and side views still expose a simplified surface and visibly
inadequate individual primary feathers. An attempted feather extension
introduced spikes; a replacement surface introduced overlap and was also
discarded. A first refinement failed because varying feather tessellation
changed temporal vertex counts. The failed log and images are retained; none
of those rejected feather changes is in the committed renderer. The current
capture's uninterrupted encode tests the retained path, not a fully realistic
feather rig. Wing morphology, anatomy, material, and speed-dependent feather
movement are not validated against crow footage. Landing uses a presentation
settling transition and rigid physical contact proxies, not measured toe grasp.

## Contents

* `crow-wing-multiview-inspection.mp4`: front, side, rear, above and below
  views of frames 700–799 (recorded steps 701–800), shown three times at
  recorded 50 Hz. Course geometry and the ground are hidden for inspection;
  the underlying simulation is not modified. Per-view audits are in
  `inspection-audits/`.
* `crow-wing-corrected-both-layouts.mp4`: complete visual replay, layout I
  followed by J, with the course visible.
* `crow-multiview-corrected-labels.jpg`: the initial pivot-only inspection;
  below view was blocked by the ground. `crow-flex-multiview.jpg` documents
  an earlier, stronger flex prototype and its printed 'step' labels are
  zero-based frame indices (actual recorded steps are one higher).
* `crow-primary-above.png` and `crow-stable-above.png` show two rejected
  feather-extension variants; `crow-replacement-above.png` shows the rejected
  replacement. `rejected-changing-feather-topology.log` records the temporal
  topology failure, which occurred in an experimental build.
* `interrupted-pivot-only-render.log.gz`: the pivot-only full render was
  intentionally stopped after the request for broader inspection. This was
  not the final render.
* `final-tests.log`, `final-build.log`, `capture-audits/` and
  `completed-render.log.gz` record the final checks and rendering.

Final renderer source: `00317d3`; optimized executable SHA-256:
`083c39d1aeb528e78341495ace12fbde49ee5d214936a5d2d6c131e1bc0a7231`.
I raw native replay SHA-256:
`5efa5a89a028ca5ef039191778bced33c00d20decc874284edfc53e2b165f1de`;
J:
`d3d396fc3e41d7f2d56c799c18bf7b96db96de51205a69319fd920a714ac6f4f`.
Original replays and independent verification are preserved in Numi Lab commit
`7d32ee3722a1f26c58ad111b46e9edb9ce3b401c`. The hash-checked projections
include the final recorded timeout. These layouts were previously used and
are no longer held out.

The full video camera uses yaw -0.6 radians, pitch 0.2 radians and distance
1.2 meters. The timeline is 3000 recorded frames per layout at 50 fps.
First waypoint reaches for I were steps 859, 1113, 1371, 1578 and 1728,
and ten consecutive support samples were confirmed at 2037. For J these
were steps 802, 1046, 1300, 1484 and 1553, with ten support samples at 1689.
These are historical results, not new independent trials. The policy receives
simulator waypoint coordinates and the body has simplified direct control
authority. Course obstacles are sometimes presented as wireframe cutaways.

The optimized renderer exited successfully after all ten full-flight sections.
Their audit windows cover both timelines without gaps or overlaps
(`timeline-checks.json`). Independent video inspection counted 6,000 frames
at 50 fps, 1,600 × 900, and 120 seconds; a full error-checked decode passed.
The synchronized multi-angle video counted 300 frames at 50 fps, including
three repetitions of the same 100-frame sample. The full video's SHA-256 is
`ba3954e4854af1e95fb3e176e57f7fb2f7254cf0267e701ad8b5a7ffe08079e6`;
the multi-angle video's is
`14e0b6a8a017a6f209b509392a6db678809f94e1a9a1aaa5f9768d4dc741c146`.
`landing-timeline-i.jpg` and `landing-timeline-j.jpg` sample the approach
and show the still abrupt settling transition on each layout.
