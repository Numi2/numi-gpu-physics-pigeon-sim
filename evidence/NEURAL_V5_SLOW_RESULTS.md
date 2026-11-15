# Four-update small-step balance pilot: development comparison

Four PPO updates retained gamma .99, lambda .995 and fixed 3e-5 learning rate. Across updates, the first stochastic episode in each lane terminated at 143-153 intervals for tilt or contact; there were 12 done events in each 512-by-four rollout. Final-step combined balance KL per update was 0.00449, 0.00587, 0.00330 and 0.00456; behavior log-probability maximum errors were at most 1.15e-5. The actor and critic gradient norms were separately recorded. Actual full-update actor layer parameter displacement norms were 0.0573, 0.0404, 0.0345 and 0.0331, so actor movement was not zero; these are aggregate parameter changes, not per-optimizer-step measurements. These metrics are diagnostics, not success criteria.

Deterministic evaluation of the final candidate versus v3 on the same four previously consumed arrival starts:

| Seed | V3 first done / longest qualifying streak | V5-slow first done / longest qualifying streak |
| --- | --- | --- |
| 20310111 | none by 1000 / 963 | none by 1000 / 964 |
| 20310129 | none by 1000 / 960 | tilt at 322 / 203 |
| 20310201 | tilt at 596 / 478 | tilt at 291 / 173 |
| 20310221 | tilt at 563 / 446 | none by 1000 / 961 |

The final candidate improves the last start and preserves the first, but degrades the other two. It fails the preregistered promotion rule; v3 remains the development incumbent. Automatic resets after the first failure are excluded. These are scripted-carrier, relocated-branch, partially reconstructed starts; neither policy is qualified for unused layouts, autonomous landing, or real-crow biomechanics. Full training rollouts, models, optimizers, gradient data, per-action final KL and all evaluation traces are archived. The paired seed-20310129 trajectory comparison is descriptive and does not isolate the cause of divergence.
