# Numi Lab American-crow journey

BirdFlow's estimated American-crow hybrid now has a separate Numi Lab task for
standing, walking/hopping, takeoff, flight, turns, approach, and supported
landing. The task exposes 14 normalized actions, 82 actor observations, and a
20-coordinate articulated state. It is simulation, not measured crow
biomechanics or hardware-flight evidence.

## Practical workflow

```sh
numi crow journey train --envs 256 --steps 128 --updates 8 --chunk 8
numi crow journey evaluate --policy-pack PATH
numi crow journey window --policy-pack PATH
numi crow journey capture                 # assisted physics-debug capture
numi crow journey capture --policy-pack PATH
numi crow journey showcase OUTPUT POSTER EVIDENCE STATE_TRACE GIF
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

## Training result retained on 26 August 2026

The teacher completed a continuous 1,600-step assisted trace with zero failed
environment steps, 29.016 m final forward progress, 0.802 m maximum root
height, and one end-of-horizon timeout. This is assisted simulated-trajectory
evidence, not autonomous flight.

MLX then distilled 512,000 samples over 20 updates. Teacher-labeled transitions
comprised 45.2% of the final update and produced a nonzero imagination loss,
confirming the native teacher stream reached the neural learner.

The autonomous held-out candidate was not qualified: all eight environments
terminated, five on the physical contact boundary and three on timeout. It
reached 9.434 m maximum forward progress, but had no clean horizon. The matched
selector therefore preferred the incumbent and recorded tilt and
physical-boundary regressions. The candidate artifact is retained for further
work; it must not be presented as a successful autonomous crow policy.

## Render boundary

[The multi-camera movie](Media/numi-crow-journey-presentation-v1.mp4) uses the
high-detail BirdFlow feather renderer from standing, takeoff, front-flight,
side-flight, rear-flight, and reversed landing views. It is phase-keyed to the
Numi journey and locked to the assisted evidence and state-trace hashes in
[`numi-crow-journey-presentation-v1.json`](Media/numi-crow-journey-presentation-v1.json).
The feathered pixels are not Numi's native visual observation and are not a
joint-exact rendering of each traced state.
