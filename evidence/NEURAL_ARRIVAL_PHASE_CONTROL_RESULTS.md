# Arrival reconstruction: elapsed-phase control

This development control sets the elapsed journey phase to 1.0 at the reconstructed 48-second arrival. It retains the same learned toe policy, relocated branch, scripted carrier, approximate q/v reconstruction and consumed starts as the original arrival fixture. It is not a full checkpoint or an autonomous landing.

The first substep still saturates all six leg drives: +0.75, -0.75, +0.60, +0.75, -0.75, +0.60, identical to the control. Setting phase alone therefore does not remove the initial kick in this fixture.

| Development seed | Original first done / longest strict grip streak | Phase control first done / longest strict grip streak |
| --- | --- | --- |
| 20370113 | 263 / 139 intervals | 256 / 130 intervals |
| 20370127 | no done in 1000 / 962 intervals | 507 / 391 intervals |

Each interval is 0.02 s; a done ends the first episode even though the host resets and continues collecting. Strict streaks require accepted upward support and opposed toe contacts on both feet, no other scene or ground support, and bounded body tilt and speed. The phase control regressed on both used starts and is not promoted. Individual complete traces, subsequent resets, first-episode analyses, shader sources and build hashes are retained alongside this report.
