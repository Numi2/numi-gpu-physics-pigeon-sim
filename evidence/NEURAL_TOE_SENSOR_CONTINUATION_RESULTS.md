# Toe sensor continuation: training

Four fixed-rate sensor-only continuation updates completed. For every update the inherited actor weights, biases, normalization and exploration parameters matched the reference exactly. The recorded training rollouts had 8, 8, 8 and 9 done events respectively (including later automatic-reset episodes); this is not a first-episode qualification or evidence of improved balance. The actor pre-clip norms were approximately 0.0154, 0.0138, 0.0137 and 0.0125 with separate clipping. All rollout packs, checkpoints, optimizer states, commands, logs, code and hashes are preserved in the accompanying Git archives.

Physical development evaluation of the final checkpoint is underway. The starting policy and every intermediate checkpoint remain available; none is promoted on the basis of training metrics.
