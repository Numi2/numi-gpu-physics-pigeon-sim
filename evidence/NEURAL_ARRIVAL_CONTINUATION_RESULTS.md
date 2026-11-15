# Four-update arrival continuation

The four successive training rollouts reported 8, 8, 9 and 8 done events across four environments, including repeated episodes. The fourth deterministic checkpoint was evaluated in the predeclared first-episode tests:

| Seed | Fixed baseline first termination | Four-update candidate first termination | Prior long-horizon checkpoint |
|---|---:|---:|---:|
| 20370113 | 267 (5.34 s) | 268 (5.36 s) | 266 (5.32 s) |
| 20370127 | 329 (6.58 s) | 328 (6.56 s) | no termination by 1000 (20 s) |

Both continuation tests fell; the second lost the prior checkpoint's 20-second hold. Reject the fourth checkpoint and retain the earlier one as an unqualified experimental artifact. All four rollouts and optimizer states, candidate packs, per-substep contact traces, and failures are archived. Neither checkpoint establishes general balance or a continuous landing; tests use the relocated branch and scripted carrier.
