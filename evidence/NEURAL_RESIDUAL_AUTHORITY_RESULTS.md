# Learned leg residual authority: matched ablation

On consumed seed 20310201, all three runs used the same update-01 policy, partially reconstructed branch fixture and random seed. Their shader sources differ only in the multiplier applied to its four hip/ankle residuals. The audited reset-q line is identical across all three (SHA-256 `5de2c634c337112908dca89139fc128352bc1a16da21a3e3263abca9ffde0265`); q/v have already diverged in replay frame 1 after the different commands take effect.

| Residual multiplier | First done | Longest qualifying support and grip |
| --- | --- | --- |
| 0.00, residual disabled | tilt, interval 438 (8.76 s) | 320 intervals (6.40 s) |
| 0.08, retained baseline | tilt, interval 986 (19.72 s) | 869 intervals (17.38 s) |
| 0.16, doubled | tilt, interval 285 (5.70 s) | 167 intervals (3.34 s) |

The learned residual materially changes the physical outcome on this one start and extends the hold compared with the zero-residual control. Doubling its scale is worse than either control here; this is not a scale optimization or a generalization result. The trailing automatic resets in both ablations are preserved in raw traces but excluded above. This fixture still has a moved branch, scripted carrier, forced terminal phase and partially reconstructed initial state; it is not a continuous autonomous landing.
