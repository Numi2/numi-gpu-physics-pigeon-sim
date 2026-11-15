# Per-foot toe control: four-update continuation

Four additional PPO updates resumed the per-foot experiment's own optimizer state with fresh development seeds. All four protected-actor comparisons passed. The four rollouts contained 9, 10, 8 and 8 termination events respectively, including automatic resets. Full rollouts, optimizer states, model packs and logs are retained for every update.

| Seed | Original gate | Per-foot gate before retraining | First update | Four further updates |
|---|---|---|---|---|
| 20370113 | fall at 5.26 s; strict streak 139 | fall at 5.10 s; streak 129 | fall at 5.06 s; streak 127 | fall at 5.10 s; streak 131 |
| 20370127 | no fall in 20 s; streak 962 | fall at 5.86 s; streak 174 | fall at 6.92 s; streak 227 | fall at 7.70 s; streak 267 |

Training improved the revised gate's result on the second consumed development start but did not prevent a fall or recover the original gate's 20-second result. It did not solve the first start. Strict streaks are measured in 20 ms intervals, and only the first episode counts. These are reconstructed forced-perch tests with scripted carrier motion; they do not establish autonomous landing or generalization to unused layouts.
