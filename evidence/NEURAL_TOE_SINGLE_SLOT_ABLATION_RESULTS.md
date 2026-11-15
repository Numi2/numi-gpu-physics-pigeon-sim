# Single-output toe ablations, exploratory

Each trial ran 400 intervals at 0.02 s, counting only the first episode, on previously consumed starts. The named action row was zeroed and the rest of its source actor remained unchanged.

| Source / seed | Intervention | First done | Longest strict streak |
| --- | --- | --- | --- |
| V1 / 20310129 | none, retained baseline | tilt 307 | 187 |
| V1 / 20310129 | left-front output 4 zero | none by 400 | 360 |
| V1 / 20310129 | right-rear output 7 zero | tilt 336 | 218 |
| V2 / 20310201 | none, retained baseline | tilt 358 | 240 |
| V2 / 20310201 | right-front output 5 zero | tilt 377 | 260 |
| V2 / 20310201 | right-rear output 7 zero | tilt 321 | 203 |

The left-front V1 output contributes to the first failure on that matched start: removing only that output prevented failure through the 400-step diagnostic while right-rear removal did not. On the second start neither tested single-output ablation prevented the V2 failure. These observations do not isolate every interaction or prove robustness, and 400 steps are not long-term survival. Full records including post-done resets are retained.
