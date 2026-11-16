# Wing self-contact stop: partial result, prediction failed

All 2,880 lane-steps succeeded. The safe lane reached its target within 0.01 rad. The two deliberately unsafe target lanes developed contacts at the expected pairs and stopped short; the 480 sampled poses per lane had no separation deeper than the preregistered -0.5 mm limit. The overall prediction nonetheless failed: the body/hand lane stopped only about 0.0094 rad short of its elbow target, not the predicted 0.02 rad.

| Target (elbow, wrist) | Final left elbow / wrist (rad) | Sampled contact pairs | Deepest sampled separation |
| --- | --- | --- | ---: |
| Safe: 1.8, 1.575 | 1.79855 / 1.57386 | None | None |
| Upper wing / hand: 1.8, 2.1 | 1.77023 / 2.07265 | Upper wing / hand | -0.0988 mm |
| Body / hand: 2.4, 0.525 | 2.39061 / 0.52197 | Body / hand | -0.1003 mm |

The right wing behaved similarly. The solver published active contact in the two unsafe lanes on 299 and 348 of the recorded last-microstep statuses, respectively. The geometric audit is performed on every second accepted control-step pose with zeroed velocities in a separate short query; it cannot detect all between-sample penetration. The collision geometry deliberately omits feathers and uses uncalibrated small bone capsules and an upper-wing box. The result demonstrates useful contact response in these specific test paths, not realistic anatomical folding or a no-penetration guarantee. It also does not qualify flight, landing or balance.

Commands, exact states and target-driving source, per-step statuses, all audits, inputs and binary hashes, and failed prediction are preserved under `evidence/crow-v15-wing-continuation-20261116/wing-contact-stop-20261116/` and adjacent source files.
