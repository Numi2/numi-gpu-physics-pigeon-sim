# Extended neural balance v1 evaluation

The preregistered 1000-step evaluation did not pass on either new seed. Before these tests, a test-only time-limit extension was made because the reconstructed checkpoint begins at episode step 2400 and would otherwise time out after about 600 steps. On the consumed seed 20310111, the first 400 complete state-trace rows were byte-identical between the original shader and extended-timeout shader. The extension preserves failure and physics-error termination.

| Seed | Policy | First tilt termination | Longest qualified first-episode hold | Outcome |
|---|---|---:|---:|---|
| 20310201 | initial | 438 (8.76 s) | 320 intervals | fail |
| 20310201 | v1 | 298 (5.96 s) | 180 intervals | fail |
| 20310221 | initial | 165 (3.30 s) | 38 intervals | fail |
| 20310221 | v1 | 190 (3.80 s) | 66 intervals | fail |

No run survived to the end or met the predeclared last-250-interval gate. The retained 1000-step files include automatic resets after each failure; those later episodes are not continuous and are excluded from the stated outcomes. These used seeds are no longer held out for future tuning. The reconstructed, relocated branch fixture and scripted carrier remain substantial limits.
