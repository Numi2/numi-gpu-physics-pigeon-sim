# Matched exploration control results

Four 512-step four-lane stochastic rollouts shared the same v3 actor/critic weights, randomized seed, v4 wide-reset shader and signed-push schedule. The control packs matched weights, normalization, and action contract exactly; only the stated log standard deviations changed. First-episode termination intervals and reasons (3 = contact, 2 = tilt) were:

| Action noise | Lane 0 | Lane 1 | Lane 2 | Lane 3 |
|---|---:|---:|---:|---:|
| baseline | 138 / 3 | 161 / 3 | 37 / 3 | 141 / 3 |
| lower first-four balance | 177 / 3 | 195 / 2 | 138 / 2 | 179 / 2 |
| lower head/beak | 136 / 3 | 165 / 3 | 36 / 3 | 143 / 3 |
| lower both groups | 172 / 2 | 198 / 3 | 138 / 2 | 176 / 2 |

Reducing balance-action noise increased survival on these four matched lanes, but every lane still terminated in under four seconds. Reducing head/beak noise alone had little effect in this sample. This does not prove generality or that the user-visible behavior will improve; differences between trajectories accumulate after the first changed action. PPO behavior log-probability maximum errors were 6.20e-6, 1.14e-5, 5.72e-6, and 9.54e-6 respectively. The diagnostic updates following the rollouts were not selected as candidates. Individual input/output policies, learner states, rollouts, logs, remote SHA-256 manifests and the pack generation script are archived.
