# Extended fixed-rate learning

Eight fixed 0.0003-rate updates completed. The protected carrier, normalization, exploration and semantic contract matched the initial checkpoint after every update. Their training rollouts contained 9, 8, 9, 7, 8, 8, 8 and 8 done events respectively, including resets. This is not a first-episode success measure; the two predeclared development trials of update 8 are underway. Each rollout, optimizer and policy is archived, and earlier checkpoints remain preserved.

A deterministic ablation pack for the earlier direct-contact policy was also built and verified: it zeros only the new residual projection to the four toe outputs, leaving all other actor weights, inherited toe output rows and contracts unchanged. Its physical comparisons follow the continued-policy trials.
