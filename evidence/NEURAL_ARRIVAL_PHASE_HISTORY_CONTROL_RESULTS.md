# Arrival reconstruction: phase and approximate actuator history

This diagnostic sets elapsed phase to 1.0 and initializes the three 18-action history slots with a recorded later source-frame history (host step 201). That later state is not the original 48-second checkpoint. The q/v and relocated branch are reconstructed and a scripted carrier remains active. All results are on consumed development starts, not an autonomous landing or a held-out qualification.

The phase-only control saturated all six leg drives on the first substep at +0.75, -0.75, +0.60, +0.75, -0.75 and +0.60. With phase and later-frame history initialized, the measured first-substep efforts became approximately -0.108, +0.002, +0.101, -0.127, +0.002 and +0.078. This demonstrates a controller-history initialization effect in this reconstruction; it does not restore the actual missing checkpoint.

| Development seed | Original first done / longest strict grip streak | Phase plus history first done / longest strict grip streak |
| --- | --- | --- |
| 20370113 | 263 / 139 intervals | 260 / 134 intervals |
| 20370127 | no done in 1000 / 962 intervals | 357 / 238 intervals |

Each interval is 0.02 s. Strict streaks require accepted upward support and opposed toe contacts on both feet, no other scene or ground support, and bounded body tilt and speed. Automatic resets after first failure are not included. Reducing the kick did not improve balance on these matched starts; the approximation is retained only as a diagnostic and not promoted as a controller fix. The complete traces, later resets, source, build hashes and source-history identity are archived.
