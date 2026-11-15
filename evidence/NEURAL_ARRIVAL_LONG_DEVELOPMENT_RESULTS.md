# Longer-horizon update: matched development tests

| Seed | Baseline first termination | Longer-horizon first termination | Longest strict streak baseline / candidate |
|---|---:|---:|---:|
| 20370113 | 267 (5.34 s) | 266 (5.32 s) | 143 / 142 intervals |
| 20370127 | 329 (6.58 s) | none by 1000 (20 s) | 210 / 960 intervals |

The longer-horizon update passed the 20-second screen on the second start, with a terminal strict contact streak of 960 intervals, but failed at 5.32 seconds on the first. This is meaningful within-fixture improvement on one consumed start, and fails the predeclared non-regression and reliability requirements. The two matched training rollouts are byte-identical; changing gamma changed the learned update, but neither this two-start comparison nor estimated advantages alone establishes a general causal explanation. The branch remains relocated; state, carrier and terminal mode are partially reconstructed or scripted. It is not a continuous landing or layout qualification.
