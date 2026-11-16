# Supported-rod microstep test: failed convergence

Both independent 10 ms qualityNewton runs reported success but violated the preregistered criteria, and the eight-substep run worsened compared with four. Max support displacement, midpoint force magnitude and total final energy (elastic plus kinetic) were:

| Physics substeps | Support error | Midpoint force | Final energy |
|---|---:|---:|---:|
| 1 (earlier comparison) | 1.260 µm | 0.579 N | 6.649 µJ |
| 4 | 31.777 µm | 1.893 N | 73.622 µJ |
| 8 | 67.320 µm | 3.374 N | 227.936 µJ |

Initial energy was 7.862 µJ and the predicted nine-node force was 0.62905 N. No gravity, aerodynamic load, actuation, contact or moving support was enabled. The status records returned success despite these discrepancies. This is an instrumented failure of the tested coupled path, not proof of its root cause, and it cannot support a physical feather or a qualified wing. Exact inputs, states and logs are preserved.
