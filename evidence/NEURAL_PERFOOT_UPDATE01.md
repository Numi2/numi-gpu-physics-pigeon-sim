# Per-foot toe control: first training update

One PPO update trained the 24-node contact residual from the earlier direct-toe policy using the revised per-foot gate. The rollout used four environments, 512 steps, two epochs, fixed learning rate 0.00003, gamma 0.999, lambda 0.995, and fresh optimizer state. The full rollout, optimizer, model, deployment pack, command, logs, and input hashes are archived. Training used the reconstructed development branch and scripted carrier.

The verification checks show all protected actor weights, biases, observation normalization, log standard deviation and policy contracts were bit-identical to the source. All permitted residual layers changed. On identical retained observations the RMS action-derived toe target changes ranged from approximately 0.0000168 to 0.000126 rad; these are pre-gate upper bounds rather than observed physical joint motion. Physical evaluation is a separate required step.
