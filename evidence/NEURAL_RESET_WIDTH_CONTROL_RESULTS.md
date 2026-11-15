# Reset-width control results

With the same consumed seed, v3 policy weights, four stochastic lanes, action-noise settings, reward and physical solver, narrowing the randomized reset from x/y ±.006 m and vx ±.05 m/s to x/y ±.002 m and vx ±.02 m/s produced these first-episode termination intervals (3 = contact, 2 = tilt):

| Condition | Lane 0 | Lane 1 | Lane 2 | Lane 3 |
|---|---:|---:|---:|---:|
| Wide, baseline noise | 138 / 3 | 161 / 3 | 37 / 3 | 141 / 3 |
| Narrow, baseline noise | 143 / 3 | 158 / 3 | 155 / 3 | 146 / 3 |
| Wide, low balance noise | 177 / 3 | 195 / 2 | 138 / 2 | 179 / 2 |
| Narrow, low balance noise | 174 / 2 | 195 / 2 | 194 / 2 | 189 / 3 |

The narrower distribution delayed the early lane-2 failure but all four stochastic episodes still failed within 195 steps. The initial physical states differ by design; these results do not establish a generally stable policy. The two narrow-control rollouts and learner diagnostic artifacts are preserved with remote file manifests. A separate registered feasibility test checks a reset from a physically reached supported state, with fresh hidden solver/controller history disclosed.
