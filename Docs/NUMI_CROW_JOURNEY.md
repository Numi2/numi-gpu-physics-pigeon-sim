# Numi Lab American-crow journey

BirdFlow's estimated American-crow hybrid has a separate Numi Lab task for
standing, walking/hopping, takeoff, flight, turns, approach, and supported
landing. The v7 task exposes 15 normalized actions, 84 actor observations, and a
20-coordinate articulated state. It is simulation, not measured crow
biomechanics or hardware-flight evidence.

## Practical workflow

```sh
numi crow journey train --milestone takeoff-cruise --envs 256 --steps 128 --updates 8 --chunk 8
numi crow journey evaluate --milestone takeoff-cruise --policy-pack PATH
numi crow journey window --milestone takeoff-cruise --policy-pack PATH
numi crow journey capture --milestone takeoff-cruise --policy-pack PATH
Scripts/capture-crow-numi-journey.sh OUTPUT POSTER EVIDENCE STATE_TRACE QUALIFICATION_DIR GIF
```

`window` is deliberately policy-only. `capture` without a policy invokes an
explicit deterministic native teacher and labels the evidence
`birdflow_assisted_teacher`. Both paths use Numi's articulated dynamics,
contacts, and authored aerodynamic closure. Fresh `train` runs invoke that
teacher for distillation.

The selected v7 controller is hierarchical rather than pure end-to-end neural
control. The neural actor owns the journey normally. During the late approach,
absolute pitch above `0.16 rad` begins a state-triggered blend toward the native
teacher, reaching full supervisory authority at `0.22 rad`; a late pitch loop
also remains inside the native actuator carrier. The evidence records this as
`v7_state_triggered_approach_supervisor_pitch_0.16_0.22_full_authority`.

The corrected native visual packs bind the airframe, left/right wings, tail,
and six leg links to their actual Numi body indices. That view is useful for
contact and control debugging, but the pack meshes remain low-detail proxies.

## All-milestone qualification retained on 26 August 2026

The frozen v7 candidate was selected with an absolute protected-milestone
contract. The final matrix covers all 11 bands—standing, walking, takeoff,
cruise, takeoff-cruise, both turns, approach, touchdown, landed hold, and the
full journey—at three held-out seeds and 32 parallel environments per run. That
is 33 runs, 1,056 environment lanes, and 1,689,600 environment control steps.

Every run has zero failed environment steps and zero non-timeout terminations.
The minimum run-level mean tracking score is `0.6748238`, the largest run-level
mean tilt is `0.0973423 rad`, the global maximum tilt is `0.2829840 rad`, and the
largest root height is `1.7136120 m`. The deployed PolicyPack SHA-256 is
`650e6ca7b14cb4351474586eef45b4959d40c1808174f607589935b18aefd0e9`.
This qualifies the simulated hierarchical v7 milestone contract; it does not
qualify a pure neural controller, measured-crow flight, or hardware.

## Render boundary

[The 1920×1080 multi-camera movie](Media/numi-crow-journey-v7.mp4) uses the
high-detail BirdFlow feather renderer from standing, opposite-quarter takeoff,
frontal flight, true lateral flight, and rear/dorsal flight views. It is
phase-keyed to the selected v7 rollout and locked to the presentation trace and
the complete 33-run qualification matrix in
[`numi-crow-journey-v7.json`](Media/numi-crow-journey-v7.json). The feathered
pixels are not Numi's native visual observation and are not a joint-exact
rendering of each traced state.
