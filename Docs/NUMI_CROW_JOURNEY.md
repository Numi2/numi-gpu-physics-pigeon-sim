# Numi Lab American-crow journey

BirdFlow's estimated American-crow hybrid has a separate Numi Lab task for
standing, walking/hopping, takeoff, flight, turns, approach, and supported
landing. V8 is a neural-only 15-action, 84-observation controller. V9 retains
that action contract and adds four 16x9 masked-depth frames plus 24 derived
sensor features for 684 actor inputs and an 84-input privileged critic. Both
use a 20-coordinate articulated state. This is simulation, not measured crow
biomechanics or hardware-flight evidence.

## Practical workflow

```sh
numi crow journey train --milestone takeoff-cruise --envs 256 --steps 128 --updates 8 --chunk 8
numi crow journey evaluate --milestone takeoff-cruise --policy-pack PATH
numi crow journey window --milestone takeoff-cruise --policy-pack PATH
numi crow journey capture --milestone takeoff-cruise --policy-pack PATH
Scripts/capture-crow-numi-journey.sh OUTPUT POSTER EVIDENCE REPLAY_PACK QUALIFICATION_DIR GIF
```

`window` is deliberately policy-only. `capture` without a policy invokes an
explicit deterministic native teacher and labels the evidence
`birdflow_assisted_teacher`. Both paths use Numi's articulated dynamics,
contacts, and authored aerodynamic closure. Fresh `train` runs invoke that
teacher for distillation.

The historical v7 controller is hierarchical rather than pure end-to-end
neural control. Its approach-pitch supervisor can reach full actuator
authority. V8 and v9 remove that authority: their pitch-envelope signals are
diagnostics and held-out gates only. The teacher supplies executed training
labels but has zero authority in autonomous selection, qualification, and the
deployment PolicyPack.

The corrected native visual packs bind the airframe, left/right wings, tail,
and six leg links to their actual Numi body indices. That view is useful for
contact and control debugging, but the pack meshes remain low-detail proxies.

## Neural all-milestone qualification completed on 28 August 2026

The state-only v8 and masked-depth v9 policies each cleared an absolute
protected-milestone curriculum covering all 11 bands—standing, walking,
takeoff, cruise, takeoff-cruise, both turns, approach, touchdown, landed hold,
and the full journey. Each was then independently re-run at three seeds and 32
parallel environments per band: 33 runs, 1,056 environment lanes, and
1,689,600 environment control steps per policy.

V8 recorded zero failed environment steps and zero non-timeout terminations.
Its minimum run-level mean tracking score is `0.6813128`; its largest run-level
mean tilt is `0.0896696 rad`, global maximum tilt is `0.2198471 rad`, and
largest root height is `0.9389769 m`. The deployed PolicyPack SHA-256 is
`072d842d60a9a4291f2c52d0bb07770702e9026ae6e0d068f721486547def58b`.
The complete matrix and exact accepted replay are retained in the
[`v8 qualification bundle`](../ValidationArtifacts/crow-v8-neural-qualification/qualification.json)
and [`v8 replay`](../ValidationArtifacts/crow-v8-neural-accepted-full-journey.crowreplay.json).

V9 was initialized only from that promoted v8 actor, then protected every v9
milestone independently. Its final 33-run matrix also recorded zero failed
environment steps and zero non-timeout terminations. Minimum run-level mean
tracking is `0.6708923`; largest run-level mean tilt is `0.0863282 rad`, global
maximum tilt is `0.1825500 rad`, and largest root height is `1.3927420 m`. The
deployed PolicyPack SHA-256 is
`e444223ef9867e8b6323cdb7e8e5030106ab8ef6a7e39a3623ee46d34d2e7bcb`.
The complete matrix and exact accepted replay are retained in the
[`v9 qualification bundle`](../ValidationArtifacts/crow-v9-sensor-fast-qualification/qualification.json)
and [`v9 replay`](../ValidationArtifacts/crow-v9-sensor-fast-accepted-full-journey.crowreplay.json).

The replay SHA-256 values are `740c6e801322af25308a524d5a0d60357c60ca03517dbdd59d94e2600a475cc3`
for v8 and `6ffab1a5b04b977c5b3c2876b452dfd4895cbc259d231350ad9738b014182554`
for v9. These results qualify the simulated authored milestone contracts at the
recorded seeds; they do not qualify measured-crow flight, out-of-distribution
visual navigation, or hardware.

The cross-variant runtime, policy, replay, qualification, and presentation
hashes are collected in the
[`final roadmap evidence index`](../ValidationArtifacts/crow-neural-roadmap-final-20260828.json).

## Render boundary

[The 1920×1080 multi-camera movie](Media/numi-crow-journey-v9-sensor-fast.mp4)
uses the high-detail BirdFlow feather renderer from standing,
opposite-quarter takeoff, frontal flight, true lateral flight, and rear/dorsal
flight views. All five passes consume the same immutable, SHA-locked v9
accepted-state replay. The root trajectory and standing-to-flight handoff come
from that replay; detailed feather deformation remains BirdFlow's estimated
retarget. The exact media, replay, controller, and 33-run qualification locks
are in
[`numi-crow-journey-v9-sensor-fast.json`](Media/numi-crow-journey-v9-sensor-fast.json).
These pixels are not the v9 masked-depth sensor images and are not a joint-exact
visual reconstruction of the Numi state.
