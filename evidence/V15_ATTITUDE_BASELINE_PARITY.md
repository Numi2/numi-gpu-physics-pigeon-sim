# Body-motion and toe-contact residual: zero-output parity

A 42-unit paired-sign residual was appended to the current direct-contact baseline so the new trainable path can see nine root linear-velocity, angular-velocity and projected-gravity features plus twelve toe-contact features. The existing controller and its previously learned contact residual remain in place. The added output projection is initialized to zero. Numeric actor outputs were exactly equal on 128 random observations and the retained balance rollout; observation normalization and stochastic critic parameters were preserved.

From exact reconstructed checkpoints on consumed seeds 20370113 and 20370127, the new and original deterministic policies matched every recorded q, v, actor observation, accepted action, body state, reward, done, termination reason and outcome for all 250 resumed intervals. The hard start fell at absolute step 257 in both; neither fell during the shorter seed-27 comparison. This parity is a controlled starting point for training, not a balance improvement or a generalization claim.

The archived source, zero-output packs, worker code, complete simulator traces and hashes are in `crow-v15-attitude-baseline-parity-20261115.tar.gz`. These are forced-phase, relocated-branch, scripted-carrier reconstructions and are not autonomous flight-to-landing evidence.
