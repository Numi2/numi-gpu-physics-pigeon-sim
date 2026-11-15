# Extended body-motion residual training

Eight further 256-step PPO updates continued the saved optimizer and actor from the prior four-update, 0.0003 learning-rate body-motion experiment. Training alternated the same two physically reached reconstructed states (seed 20370113 at step 150, seed 20370127 at step 50), with gamma 0.999 and lambda 0.995. Both are consumed development starts. The retained training data includes episodes after a done; the first new rollout terminated at sample 98 of 256. GAE explicitly stops at done, but the later samples still participate in its PPO update. A separate first-episode-only comparison is being tested.

The final candidate fell at absolute step 256 (5.12 seconds) on the difficult start, against step 257 (5.14 seconds) for its original actor. Neither fell during the 250 resumed steps on the easier start; maximum tilt was 0.13945 radians against 0.12947 for the original. Reject this candidate; neither result proves sustained or held-out balance. Exact source checkpoint, first observation, seeds, policy and full physical traces are recorded in the archive.

This is a reconstructed, relocated branch with a forced terminal phase and scripted carrier, not a full autonomous landing. Commands, environment, actor checkpoints, rollouts, optimizer states, guarded checks and evaluation failures are preserved in the accompanying verified archive.
