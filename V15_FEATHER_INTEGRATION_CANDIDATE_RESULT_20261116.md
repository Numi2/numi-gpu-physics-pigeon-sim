# Position/velocity candidate: rejected

The experimental patch set each coupled-world rod position and twist to the packed substep-start configuration plus solved velocity times duration. This removed the measured one-step position/velocity residual for the loaded fixture (maximum 0.00000065 µm with damping 100/s). It did **not** repair the constrained system:

| Test | Outcome |
|---|---|
| 10 ms, one substep | maximum fixed-target error 11.841 µm; midpoint force 1.087 N; final energy 23.452 µJ versus initial 7.862 µJ |
| 100 ms, one substep | maximum error 47.323 µm; force 2.461 N; final energy 120.307 µJ |
| 10 ms, four substeps | maximum error 63.426 µm; force 3.222 N; final energy 206.289 µJ |
| 10 ms, eight substeps | native solver failure and rollback at control step 6/substep 2 (status 11); final state not accepted |

The candidate fails multiple preregistered thresholds and is not promoted. A position/velocity mismatch exists in the original path, but resolving it alone is insufficient and made these support outcomes worse. The patch, input hashes, independent direction controls and full native outputs are retained here. No claim about physical feathers, flight or landing follows.
