# Current-actor body-motion residual: balanced high-rate test

Four 256-step PPO updates alternated two physically reached, reconstructed branch states (seed 20370113 at step 150 and seed 20370127 at step 50). The first used fresh optimizer state and subsequent updates continued it. The learning rate was 0.003, gamma 0.999, lambda 0.995, with two epochs. These are development seeds, not independent qualification.

The first exploratory rollout exactly matched the first rollout in the 0.0003 comparison (SHA-256 1eb395a4bbfe2750ec5319f5104c686c8370b4188d57272cf0981fbb3848ec9d). Retained-observation target changes reached 0.00512 radians RMS, subject to toe gating; protected actor parameters and optimizer moments passed their guards. These measurements establish an update, not success or causal toe control.

On the matched harder physical start, the candidate fell at absolute step 254 (5.08 s), versus 257 (5.14 s) for its starting actor. On the easier start neither fell within the 250 resumed evaluation steps; peak body tilt rose from 0.12947 to 0.14078 radians. Reject this candidate. This test uses a forced landing phase, reconstructed branch and scripted carrier; it is neither autonomous landing nor a full-duration balance qualification. All raw training/evaluation data, guards, actor checkpoints, optimizer state, commands and hashes are in the accompanying bundle.
