# Controlled fold under airflow: tracking failed

The three lanes completed all 1,440 lane-steps with no solver failure, but all three missed the preregistered 0.01 rad final tracking criterion. The body was free in zero gravity and the experimental airflow acts on it; this was not a fixed wind tunnel or a flight test.

| Airflow | Final left elbow | Final left wrist | Elbow error from 1.8 rad | Wrist error from 1.575 rad |
| ---: | ---: | ---: | ---: | ---: |
| 0 m/s | 1.60945 | 1.42490 | -0.19055 | -0.15010 |
| 5 m/s | 1.58381 | 1.41138 | -0.21619 | -0.16362 |
| 10 m/s | 1.49349 | 1.42667 | -0.30651 | -0.14833 |

The right wing was closely symmetric. At the final sample the left elbow and wrist were still moving in all three lanes; 0.5 s of hold was insufficient for the declared target under this configuration. The 10 m/s lane's root moved substantially, so differences cannot be attributed solely to local joint loading. Neither gains nor joint limits are biologically calibrated.

All 1,440 endpoint poses were independently re-evaluated using the existing collision audit; the proxy geometry produced no contacts in those samples. This is only a discrete sample of deliberately incomplete rigid proxies, not a swept-volume or full-feather no-penetration guarantee. The dynamics status records, published for the last microstep of each control step, summed to 304 active-contact counts; they do not contain all microsteps. The endpoint audit's zero contacts does not identify those contacts or prove the whole motion collision-free. Further contact attribution is necessary.

The plan, all states, solver contact statuses, audit output, commands, binary hashes and the failed result are retained under `evidence/crow-v15-wing-continuation-20261116/wing-aero-controlled-fold-20261116/`. No flight, landing, balance or realistic feather motion was qualified.
