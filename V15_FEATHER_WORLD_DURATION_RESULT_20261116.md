# Multi-step coupled-world rod test: failed

The independent qualityNewton fixtures completed 10 and 100 steps with success status, yet **both failed** the preregistered fixed-support and midpoint-force checks.

| Duration | Max target error | Midpoint elastic force magnitude | Deviation from 0.62905 N | Max free-node force |
|---|---:|---:|---:|---:|
| 10 ms | 1.260 µm | 0.57869 N | -8.0% | 0.000526 N |
| 100 ms | 1.736 µm | 0.55961 N | -11.0% | 0.000578 N |

Final elastic plus kinetic energy was 6.64946 and 6.22114 µJ, respectively, below the 7.86247 µJ initial energy. This check rules out the narrow one-step pass as sufficient evidence for maintained fixed supports, but does not identify a root cause. All accepted states, velocities, twists, diagnostics and exact instrument inputs are retained. The 0.62905 N reference is derived from the same bending parameters and is not independent biological validation.
