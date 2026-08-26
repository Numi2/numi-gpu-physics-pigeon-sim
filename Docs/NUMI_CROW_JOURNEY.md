# Numi Lab American-crow journey

BirdFlow's estimated American-crow hybrid now has a separate Numi Lab task for
standing, walking/hopping, takeoff, flight, turns, approach, and supported
landing. The v2 task exposes 14 normalized actions, 83 actor observations, and a
20-coordinate articulated state. It is simulation, not measured crow
biomechanics or hardware-flight evidence.

## Practical workflow

```sh
numi crow journey train --milestone takeoff-cruise --envs 256 --steps 128 --updates 8 --chunk 8
numi crow journey evaluate --milestone takeoff-cruise --policy-pack PATH
numi crow journey window --milestone takeoff-cruise --policy-pack PATH
numi crow journey capture --milestone takeoff-cruise --policy-pack PATH
Scripts/capture-crow-numi-journey.sh OUTPUT POSTER EVIDENCE STATE_TRACE GIF
```

`window` is deliberately policy-only. `capture` without a policy invokes an
explicit deterministic native teacher and labels the evidence
`birdflow_assisted_teacher`; with a policy it is autonomous. Both paths use
Numi's articulated dynamics, contacts, and authored aerodynamic closure.
Fresh `train` runs also invoke that teacher for distillation. Training resumed
from an existing PolicyPack is autonomous unless the teacher flag is explicitly
requested.

The corrected native visual packs bind the airframe, left/right wings, tail,
and six leg links to their actual Numi body indices. That view is useful for
contact and control debugging, but the pack meshes remain low-detail proxies.

## Takeoff-cruise qualification retained on 26 August 2026

The v2 native teacher and stage observation support separate eight-second
airborne stabilization and ground takeoff-plus-cruise bands. MLX training
retained the protected actor when later joint checkpoints were slightly worse.
That selected autonomous actor then passed both bands on three held-out seeds
with zero failed environment steps and timeout-only terminations.

Across the three seeds, isolated-cruise tracking was `0.79685...0.79688`, mean
tilt was about `0.0683 rad`, and maximum tilt stayed below `0.151 rad`. Ground
takeoff-plus-cruise tracking was `0.71321...0.71322`, maximum root height was
`0.87749...0.87763 m`, mean tilt was about `0.0867 rad`, and maximum tilt stayed
below `0.251 rad`. This qualifies the simulated v2 takeoff/cruise milestone; it
does not qualify turns, approach, landing, measured-crow flight, or hardware.

## Render boundary

[The multi-camera movie](Media/numi-crow-takeoff-cruise-v2.mp4) uses the
high-detail BirdFlow feather renderer from standing, takeoff, front-flight,
side-flight, and rear-flight views. It is phase-keyed to the selected autonomous
Numi rollout and locked to its evidence and state-trace hashes in
[`numi-crow-takeoff-cruise-v2.json`](Media/numi-crow-takeoff-cruise-v2.json).
The feathered pixels are not Numi's native visual observation and are not a
joint-exact rendering of each traced state.
