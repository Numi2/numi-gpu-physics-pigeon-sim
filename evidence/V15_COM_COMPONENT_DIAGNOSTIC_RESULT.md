# Live COM observer component diagnosis

The 620-step diagnostic retained exact control q/v, body states, actor observations, actions and done values; 70 rewards intentionally carried telemetry. Across 18 COM-velocity samples, the live articulated body-state velocity field produced zero in every case, while the replay-derived mass-weighted velocity ranged from -0.1103 to +0.2745 m/s. This explains why the prior observer did not implement its intended velocity term.

Across sampled frames the live mass-weighted COM position differed from the independent accepted replay calculation by at most 0.000384 m. Contact impulse-weighted x differed by at most 0.0000038 m, and net vertical impulse by at most 8e-10 N s. These tests establish neither the cause of the remaining small position discrepancy nor biological validity. The planned follow-up is explicitly position-only and subject to independently predicted physical target changes and recovery gates. No model was trained or promoted.
