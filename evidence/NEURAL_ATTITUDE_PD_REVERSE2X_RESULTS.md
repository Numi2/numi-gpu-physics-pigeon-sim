# Stronger reverse pitch/rate probe

The reverse diagnostic doubled both gains and the target bound to `clamp(-0.24*(pitch-0.13)-0.08*pitch_rate,-0.08,0.08)` radians at the two physical hips. This was privileged feedback on the original gate and direct-residual policy, not a neural controller.

Seed 20370113 terminated on tilt at interval 194 (3.88 s) with a longest strict streak of 61 intervals; the original gate lasted 263 intervals with a streak of 139. Seed 20370127 terminated on tilt at interval 493 (9.86 s), with a 368-interval streak; the original did not terminate within 1000 intervals and had a streak of 962. Stronger correction regressed both development starts. Full source, build inputs, traces and subsequent automatic resets are retained. The fixture remains a reconstructed forced perch with a scripted carrier.
