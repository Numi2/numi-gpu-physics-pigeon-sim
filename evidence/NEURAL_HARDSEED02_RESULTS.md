# Hard-seed continuation and paired branch replays

One fixed-rate masked PPO update resumed the phase-and-later-history continuation-04 policy and optimizer using seed 20370113 in four training lanes, 512 steps per lane, gamma 0.999 and lambda 0.995. The four-lane training reset is not established as identical to the one-lane evaluation start. The first launch failed because the host dynamic library path was missing; its command and error are included. The corrected run completed. The frozen actor weights, biases, normalization, log standard deviations and contract matched the input, while 1,632 intended residual weights changed. RMS output target changes on retained training observations were 0.0000045–0.0000582 rad across the eight outputs; these are not measured physical improvements. Actor pre/post clip norms were 3.336/1.000; critic 1.011/0.879; post-update residual KL was 0.000101. The training record does not justify selecting by KL.

| Consumed development seed | Earlier continuation-04 first termination | Hard-seed update first termination |
| --- | --- | --- |
| 20370113 | step 257, 5.14 s | step 259, 5.18 s |
| 20370127 | none through step 1000, 20 s | step 376, 7.52 s |

Termination reason was 2 for both new first failures. Scheduled resets were disabled; autonomous task resets occur after termination, and later frames cannot extend the first episode. Each 1,000-step replay, complete compressed physics/contact log, state trace, command, result, inputs and hashes is archived. The earlier candidate's 20-second first episode also had a 959-step strict bilateral-support and opposing-toe-contact streak; the new candidate was not qualified for grip. The two-step gain is negligible and the easier-start regression rejects this candidate.

All tests use consumed development starts, a reconstructed relocated branch, forced landing phase and scripted carrier. They do not establish an exact restart of the original run, autonomous landing, robust branch balance, unused-layout generalization, or real-bird accuracy. The old 48-second source video also used collision-disabled flight. The prior continuation-04 policy remains the best partial candidate and is not promoted as a qualified controller.
