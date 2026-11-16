# Articulated wing passive-air test: failed

The preregistered passive-air criterion did not pass. This is an experimental six-link aerodynamic callback, not a flight qualification. Three lanes ran for 240 control steps at 1/240 s, four microsteps per control step, with no gravity, wind, effort, contact, or body damping. The matched aerodynamic-off and aerodynamic-on batches each accepted all 720 lane-steps.

| Lane | Aero off change in kinetic energy | Aero on change | Largest aero-on single-step increase |
| --- | ---: | ---: | ---: |
| Rest | 0 J | 0 J | 0 J |
| Root translation | 0 J | -2.44350 J | +0.08071 J |
| Root translation and joint motion | -0.0000332 J | -0.98501 J | No increase observed |

The prespecified maximum permitted increase was 0.0001 J. The root-translation lane exceeded it at steps 130 and 131, despite losing energy overall. The recorded joint trajectory also runs far outside plausible anatomical angles and reaches tens of radians per second; later a joint coordinate exceeds 18 radians. These uncontrolled, unconstrained configurations are not realistic flight. The time-discretized integration, body velocity/wrench mapping, joint constraints, and force formulation need separate investigation; this test does not establish which caused the energy increase. Do not use this experiment to claim passivity, aerodynamic realism, or successful flight.

Full initial conditions, observations, kinetic energy samples, source, command, binaries and hashes, stdout, and stderr are retained in `evidence/crow-v15-wing-continuation-20261116/wing-aero-passivity-20261116/`. The source and invocation are also retained beside that directory. The pre-run plan and amendment are `V15_ARTICULATED_WING_AERO_PASSIVITY_PLAN_20261116.md` and `V15_ARTICULATED_WING_AERO_PASSIVITY_AMENDMENT_20261116.md`.
