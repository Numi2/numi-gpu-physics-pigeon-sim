# Extended fold hold: still-air settling succeeds, wind cases fail

All 2,880 lane-steps were accepted, and the first 480 observations reproduced the previous experiment exactly at the printed precision. Extending the hold from 0.5 to 2.5 seconds brought every tested joint within 0.01 rad of its target with speed below 0.05 rad/s in still air. The two wind lanes missed the same criterion, so the preregistered three-lane prediction failed.

| Airflow | Left elbow / wrist final (rad) | Right elbow / wrist final (rad) | Outcome |
| ---: | --- | --- | --- |
| 0 m/s | 1.79855 / 1.57386 | 1.79855 / 1.57386 | Pass |
| 5 m/s | 1.77329 / 1.54997 | 1.77255 / 1.54989 | Fail |
| 10 m/s | 1.70963 / 1.49391 | 1.70798 / 1.49420 | Fail |

Targets were 1.8 rad elbow and 1.575 rad wrist. Final speeds met the 0.05 rad/s threshold, but joint error persisted under wind. The free root moved about 0.95 m in x in the 5 m/s lane and about 5.39 m in x and 5.06 m in z in the 10 m/s lane, so this experiment does not isolate stationary aerodynamic loads or establish flight stability. Contact auditing of 480 evenly spaced poses per lane found no proxy contacts; that discrete incomplete-geometry result cannot establish continuous or feather clearance.

The full native results, 960-state trajectories, 480-pose-per-lane audits, inputs and binaries hashes, command, stderr, and source are retained under `evidence/crow-v15-wing-continuation-20261116/wing-aero-extended-hold-20261116/`. The prior two-second failure is preserved separately. No flight, landing or balance outcome is claimed.
