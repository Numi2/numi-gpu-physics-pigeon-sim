# Minimum supported exploration result

At the existing policy-pack minimum of -5 log standard deviation on the four learned actions, the four first episodes terminated at 203/tilt, 263/tilt, 137/tilt and 207/tilt. The matched -3.5 control terminated at 177/contact, 195/tilt, 138/tilt and 179/tilt. The minimum-noise rollout had eight done events versus eleven for -3.5; it still did not provide reliably long episodes. This is one previously used seed, not a generalization measurement.

The diagnostic PPO update was not selected: its recorded final combined balance KL was 62.13, with per-action values 38.76, 18.05, 3.91 and 1.41. With this narrow distribution, the unchanged fixed learning rate moved the policy far too much in standardized units. The reported unclipped actor and critic gradient norms were 53.53 and 2.99, respectively; after combined clipping they were 0.760 and 0.479. These aggregate metrics are averaged across learner minibatches and do not establish whole-mission behavior. Both the short falls and the aggressive diagnostic update are preserved. No adaptive rate was applied.

The verified raw rollout, initial and resulting policy packs, learner state, logs, pack contract and per-file SHA-256 manifest are in `crow-minimum-noise-20261115.tar.gz` and its accompanying manifest. The output is a diagnostic fixture result, not an autonomous landing.
