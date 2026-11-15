# Per-foot toe control: before retraining

The revised experimental control interface accepts each foot's bounded toe residual once that foot has accepted contact and its ramp is nonzero. The existing bilateral gate required both feet loaded and both ramps at least 24. The original position limits, neural policy, scripted carrier and fixture were otherwise retained. Evaluation and training shaders were rebuilt separately from the respective existing sources; their sources and build hashes are archived alongside these results.

| Consumed development seed | Original gate: first fall / longest strict streak | Per-foot gate: first fall / longest strict streak |
|---|---|---|
| 20370113 | 263 intervals (5.26 s) / 139 | 255 intervals (5.10 s) / 129 |
| 20370127 | no fall in 1000 intervals (20 s) / 962 | 293 intervals (5.86 s) / 174 |

The unadapted existing policy regressed on both starts, markedly so on the second. Neither trial was an uninterrupted autonomous landing: these use a reconstructed forced-perch development fixture and scripted physical carrier. Both simulations automatically reset after falls; only the initial episode is scored. The full traces and failed episodes are preserved in the two `crow-toe-perfoot-development-*` archives. A separate bounded retraining experiment is needed before drawing conclusions about whether a policy can adapt to this interface; this baseline does not justify promotion.
