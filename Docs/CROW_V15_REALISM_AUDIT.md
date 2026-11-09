# V15 crow realism audit and replay integration

Scope: the Numi Lab v15 conditional-landing navigation simulations, not a real
animal. The two final unused-layout assessments are bound to Numi Lab commit
`7d32ee3722a1f26c58ad111b46e9edb9ce3b401c`. Their full, independently restored
accepted-state replays and verification are archived in Numi Lab under
`artifacts/crow-final-video-replay-20261109/`. The controller remains frozen.

## What this revision changes

* The native BirdFlow crow renderer accepts the v15 23-coordinate, 18-action
  replay only when the required named crow and course bodies are present. Its
  projected envelope payload digest is checked; v15 is not relabeled as v10.
  The native source bytes are checked separately against independently archived
  SHA-256 hashes before projection; its embedded payload digest does not match
  a parse-and-reserialize check and is not claimed as validated.
* Body-relative wing, tail and leg transformations use the accepted replay as
  in the v10 renderer. Recorded v15 head-link motion drives the cranial/neck
  presentation, including the CPU and Metal feather paths. BirdFlow's head
  registration and skinning remain estimates.
* The proximal wing surface now blends the accepted terminal-link movement
  into a body-seated shoulder; the distal surface retains the full link delta.
  CPU tail and GPU feather registration pivots move with the presentation body
  translation. These are visual estimates, not changes to the flight policy.
* Course cage corners now transform both the recorded obstacle orientation
  and the inverse recorded crow orientation; subtracting centers alone was
  wrong whenever the bird banked or turned.
* The v15 presentation requires 0.2 seconds of uninterrupted recorded
  support after all waypoints, then eases into the folded pose over 0.5
  seconds. Missing or nonconsecutive accepted states break support continuity.
  This is a visual estimate, not a contact verifier; the independent Numi
  assessment supplies the simulated landing verdict.
* Plantar pads and claws now follow a raised digit instead of remaining at
  the standing support height during takeoff; a geometric regression test
  checks that the lifted foot surface remains together.
* A replay no longer draws the unrelated presentation-only standing platform.
  Optional solid course boxes use the simulated collision dimensions and
  accepted poses; a finite visual patch represents the recorded ground plane.
  Their color and lighting are presentation choices, not recorded ecology.
  When a box blocks the camera-to-body sightline, it is shown as a labeled
  wireframe cutaway; the physical obstacle and trajectory are unchanged.
  Replay overlays identify the simulation, layout, recorded waypoint count and
  sustained-support presentation.
* Native H.264 encoding streams frames directly into a video file instead of
  storing thousands of PNGs. The original video sampled the 50 Hz trace at
  25 fps; the updated capture uses every retained state at 50 fps.

## Follow-up: recorded mandible and presentation lighting

The lower bill surface now follows the recorded v15 lower-beak link relative
to the head. The visual hinge registration and bill shape remain estimated;
the replay shows only its recorded, generally small jaw excursions. The bill
profile was made straighter in line with the [Cornell Lab American Crow
identification description](https://www.allaboutbirds.org/guide/american_crow/id).
Toe pads now follow their own phalangeal nodes instead of all inheriting the
height of the toe tip. The toes remain visual anatomy, not simulated grasp.
Navigation lighting now uses a neutral daylight background and mild,
spatially anchored procedural course material variation, with distance filtering
of unresolved detail. This is an estimated presentation, not measured sky,
texture, cast shadow, or ecology. A small local occlusion effect uses the
posed pedal vertices and fades with distance from a course surface; it is an
estimated visual effect, not a contact measurement or a cast shadow. The
controller, physical scene and accepted trajectory remain unchanged.

The updated complete-state projection can include the final episode timeout
only through an explicit option, only at the final source state, and only when
navigation completion is recorded. It still rejects intervening terminal
states. The final timeout is not a reset. Projection requires a separately
supplied source-byte SHA-256: the embedded native payload digest cannot be
revalidated by the renderer after JSON parsing and reserialization. The two
input files match their independently archived byte hashes, and projections
created with that independent check match the captured inputs byte for byte.

## Known gaps, including limitations that remain

### Anatomy and surface

1. The visual bird is an estimated multi-source hybrid, not a scan or
   measurements of the simulated individual. Body, head, bill, feet and
   feather proportions are approximate.
2. The body is an authored loft and the base wing/tail motion derives from a
   dove scaffold. The remiges, rectrices, coverts, contour feathers, eye,
   beak and scales are species-informed procedural estimates; precise
   American-crow feather geometry and optics have not been validated.
3. The simulated wing has sweep, flap and pronation links, but not a complete
   articulated avian shoulder, elbow, wrist and each feather. BirdFlow uses
   estimated registration, interpolation and feather deformations between
   those links; it is not a feather-exact physical reconstruction.
4. The lower mandible follows the recorded link, but the visual hinge, bill
   proportions and internal mouth geometry are estimates. Toe shapes are visual
   anatomy: the physical model has rigid sole proxies rather than individually
   articulated grasping toes or claws.
5. The head is retargeted through an estimated neck pivot; there are no
   independently measured vertebral joints, tongue, eyelids, breathing or
   soft-tissue deformation.

### Appearance, environment and temporal presentation

6. Lighting and black feather material are designed estimates, not calibrated
   multispectral plumage, measured reflectance or specimen texture scans.
   Feather microstructure, wetness, weathering and individual variation are
   incomplete; this renderer is not photorealistically validated.
7. The optional solid course and ground use procedural presentation materials
   and a neutral sky, not a reconstructed ecological environment. They lack
   calibrated materials, indirect illumination and cast perch shadows. Box
   dimensions and poses match the simulated collision scene.
8. The updated complete replay displays all 3,000 retained 50 Hz accepted states
   at 50 fps, including the final timeout. It does not
   establish continuous contact, accurate wingbeat shape, motion blur or
   absence of visual interpenetration between the accepted samples.
9. The presentation uses estimated deployment and settling transitions.
   Sustained support is now checked before settling, but loss of support can
   still switch the estimate back to flight. The transitions, feather settling
   and supported pose need temporal and all-angle validation; replaying the
   full trajectory does not by itself establish realistic motion.
10. Retargeting removes global root motion to frame the crow. Course cages are
    transformed into the crow frame, but the camera and inferred feather
    topology are presentation choices. RGB imagery is not the actor's sensor.

### Physical model and behavior

11. Mass, inertia, segment lengths, joint axes and limits are engineering
    estimates derived from an allometrically adjusted dove model rather than
    same-specimen crow measurements. Lightweight connector links are
    numerical model components, not anatomical bones.
12. The blade-element and unsteady aerodynamic closures are authored,
    state-responsive approximations, not a crow-calibrated force, wake, power,
    energy or CFD validation. Individual feather flexibility, near-ground
    effects, turbulence, gusts and complex wing-wake interactions are missing
    or unvalidated.
13. Direct body pitch/yaw wrench actuators and the controller's explicit
    clock and feedback shortcuts provide control authority that has not been
    demonstrated to arise from the bird's muscles and feathers alone.
14. Contact uses simplified rigid collision shapes and a material model.
    Supported landing does not establish toe grasp, perch compliance, muscle
    loading, toe force, nonpenetration of the detailed plumage, or a
    biologically accurate landing.
15. The navigation policy receives simulator-provided waypoint coordinates;
    this is not a vision-only navigation result. Sensor optics, dynamic visual
    acuity, occlusion, attention and perceptual ecology remain unvalidated.
16. There is no individually measured validation of voluntary crow flight,
    gaze, wingbeat timing, force, metabolism, landing kinematics, or behavior
    across real environments. Two unused simulated layouts establish the
    stated simulation outcome only, not biological generalization.
17. On this machine a normal whole-module-optimized release capture crashed
    in `objc_retain`, including without a replay. Debug, AddressSanitizer
    release, and an optimized non-whole-module build rendered successfully.
    Disabling whole-module optimization on the visualization target alone
    also allowed a release capture to run. This is a renderer reliability
    issue, not evidence of physics failure. Two pointer-copy paths were
    subsequently isolated from throwing render/upload paths. A fresh default
    optimized build then passed standing, diagnostic AOV and retained I/J
    course captures, including 50 consecutive video frames per layout and a
    900-frame uninterrupted video capture on I. The
    exact compiler/runtime mechanism remains unproven; the regression smoke
    test is `Scripts/smoke-crow-release.sh` (supply replay projections to
    exercise live-wing uploads).

## Evidence needed for stronger realism

Use licensed crow photographs/scans and synchronized multi-view kinematics,
same-individual mass/inertia and force measurements, with explicit source
rights and uncertainty. Validate held-out silhouettes and landmark errors,
wingbeat phase and frequency, bill and toe poses, contact and forces, material
appearance under held-out lighting, and independent turn/landing sequences.
Keep view quality, numerical behavior, navigation success and biological
validation as separate gates. Requalify flight and navigation if physical
geometry, actuation, aerodynamic closure or observation semantics change.

References: Cornell Lab of Ornithology, American Crow identification,
https://www.allaboutbirds.org/guide/American_Crow/id; Jackson and Dial 2011,
https://journals.biologists.com/jeb/article/214/3/452/33507/Scaling-of-mechanical-power-output-during-burst;
BirdFlow's `Docs/AMERICAN_CROW_MODEL.md` and Numi Lab's
`docs/AMERICAN_CROW_KINEMATIC_DATA_INTAKE.md`.
