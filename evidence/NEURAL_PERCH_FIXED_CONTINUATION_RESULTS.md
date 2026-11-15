# Extended fixed-rate learning

Eight fixed 0.0003-rate updates completed. The protected carrier, normalization, exploration and semantic contract matched the initial checkpoint after every update. Their training rollouts contained 9, 8, 9, 7, 8, 8, 8 and 8 done events respectively, including resets. This is not a first-episode success measure; the two predeclared development trials of update 8 fell at interval 255 (5.10 s) on seed 20370113 and 340 (6.80 s) on seed 20370127. Both fail, and the latter is worse than the earlier direct-contact policy that held through 1000. The continued checkpoint is not promoted. Each rollout, optimizer and policy is archived, and earlier checkpoints remain preserved.

A deterministic ablation pack for the earlier direct-contact policy was also built and verified: it zeros only the new residual projection to the four toe outputs, leaving all other actor weights, inherited toe output rows and contracts unchanged. Its physical comparisons follow the continued-policy trials.

On retained observations, the final checkpoint changed leg targets by up to 0.000733 rad RMS and gated toe targets by up to 0.00204 rad RMS versus its zero-output source. Zeroing the contact features changed its outputs; these are counterfactual target comparisons, not measured joint displacement or physical success.
