# Matched disturbed-state leg and neck screen

The saved checkpoint follows 580 resumed intervals of the retained positive hip-pulse experiment. Its entire prefix exactly matches the retained original in q, v, actor observations, accepted actions, body states, rewards and termination fields. An unchanged 180-interval continuation exactly matches the corresponding original trajectory in the same fields and first terminates at original interval 693. Each intervention resumes the same checkpoint and has identical first actor observations; its first recorded q, v and body states are already after the changed control has been applied and therefore differ. The first target trace confirms that the intended two knees or neck pitch alone changed by the pre-registered +/-0.04 rad, with no other target change in that first interval.

| Fixed command from checkpoint | First termination, original interval | Bilateral upward contact intervals | Bilateral opposed-toe-normal proxy intervals | Longest within 0.01 rad of unperturbed tilt |
| --- | ---: | ---: | ---: | ---: |
| Control | 693 | 113/113 | 66/113 | 0 |
| Both knees +0.04 rad | 686 | 106/106 | 56/106 | 0 |
| Both knees -0.04 rad | 691 | 111/111 | 69/111 | 0 |
| Neck pitch +0.04 rad | 693 | 113/113 | 65/113 | 0 |
| Neck pitch -0.04 rad | 691 | 111/111 | 65/111 | 0 |

None met the pre-registered recovery criterion. These are fixed, isolated interventions after an internal hip-command disturbance on a consumed development seed and reconstructed branch; they are not a trained controller, an external-push test, independent layouts, evidence of stable grip, or a landing. The opposing-normal measure is a geometric proxy, not a validated grasp or slip measurement. The result rules out these specific commands, not coordinated or earlier whole-body control. The present v15 body lacks physical elbow/wrist articulation, so this screen also does not establish anatomically folded wings.

The initial resume attempt was rejected by the checkpoint contract because the command named the original deployment pack even though the saved checkpoint was bound to the forked hip pack. The rejection and command are retained; setting the source pack to the checkpoint-bound hip pack allowed the exact unchanged continuation above. The first attempt to launch the checkpoint script used a nonexistent interpreter path and did not execute; `/usr/bin/python3` ran it successfully. Full commands, scripts, hashes, checkpoint, policy packs, traces, contact records and all trial outcomes are in the companion archive.
