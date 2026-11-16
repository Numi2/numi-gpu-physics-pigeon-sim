# Wing-drive sensitivity candidate: rejected

The preregistered higher-gain candidate completed 2,880 lane-steps without solver failures and all final joint speeds were below 0.05 rad/s. It passed the 0.01 rad position criterion at 0 and 5 m/s but failed at 10 m/s; therefore the overall candidate failed and was not promoted.

| Airflow | Left elbow / wrist final (rad) | Right elbow / wrist final (rad) | Largest position error |
| ---: | --- | --- | ---: |
| 0 m/s | 1.79998 / 1.57498 | 1.79998 / 1.57498 | 0.000020 rad |
| 5 m/s | 1.79807 / 1.57309 | 1.79793 / 1.57305 | 0.002073 rad |
| 10 m/s | 1.78011 / 1.56920 | 1.78211 / 1.56940 | 0.019892 rad |

The corresponding unchanged-gain maximum errors were approximately 0.00145, 0.02745 and 0.09202 rad. This is a comparison between freely moving bodies, not a controlled fixed-load calibration: the 10 m/s candidate root ended roughly 3.97 m behind, 1.65 m sideways and 1.70 m lower than it began. The extra gains are not biologically calibrated, and no actuator-energy or thermal qualification was performed. The 480-sample-per-lane proxy audit detected no contacts; it cannot establish continuous or feather clearance. Full results, failed decision, commands, hashes and source are retained under `evidence/crow-v15-wing-continuation-20261116/wing-aero-drive-response-20261116/` and adjacent files.
