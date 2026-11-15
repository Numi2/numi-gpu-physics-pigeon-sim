# Contact-gated neural toe policy: development screen

The V1 actor and physical toe carrier were unchanged; its toe residual was enabled only while both accepted foot-load flags and contact ramp thresholds were present. With zero toe outputs, a 300-interval matched control exactly reproduced the ungated comparator in q, v, observations and accepted actions. The prior V1 policy fell at interval 307 on seed 20310129. After gating, all four previously consumed starts survived the entire 1000-interval, 20-second first episode:

| Seed | First done | Longest strict supported opposing-toe streak |
| --- | --- | --- |
| 20310111 | none | 963 |
| 20310129 | none | 960 |
| 20310201 | none | 961 |
| 20310221 | none | 961 |

On the two previously tested seeds with a matched zero-toe comparator, decoded packed contact state showed the gate first open around intervals 36 and 38, and physical q first diverged from the zero-toe run at the same numbered intervals. This confirms that trained outputs affected simulated state after contact, not that they improved balance: both zero-toe controls also survived 1000 on those starts. The screen uses a relocated branch and partially reconstructed arrival with a scripted contact-driven carrier. It does not establish an uninterrupted landing, out-of-distribution reliability, useful learned toe contribution, or biological realism. The separate predeclared reserved-seed paired study addresses only the first two relevant simulation questions, within the same layout.
