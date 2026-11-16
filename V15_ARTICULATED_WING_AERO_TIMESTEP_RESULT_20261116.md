# Passive airflow timestep follow-up

The preregistered energy-screen prediction passed: the original four-microstep result reproduced, the largest positive energy increment decreased at each refinement, and the 32-microstep root-translation run had no positive increment. All 720 lane-steps in each of eight matched batches were accepted.

| Microsteps per 1/240-second control step | Largest increase, aerodynamic-on root-translation lane | Total one-second energy change | Original three-lane screen |
| ---: | ---: | ---: | --- |
| 4 | +0.080709 J | -2.44350 J | Fail |
| 8 | +0.021326 J | -2.78528 J | Fail |
| 16 | +0.001414 J | -2.75990 J | Fail |
| 32 | -0.000397 J | -2.67790 J | Pass |

The 32-microstep result satisfies the narrowly specified screen, and the comparison supports timestep sensitivity as a contributor to the earlier energy spikes. It does not establish trajectory convergence: total energy loss changes across refinements, joints are unconstrained and move beyond anatomical limits, and the three initial conditions do not cover flight or landing. The prototype is not qualified for general use, and the 32-microstep setting is not an endorsed production configuration. Further force and solver verification with realistic joint limits, contacts and commanded motions is required.

The exact four runs, including failed results and every saved state, plus inputs and binary hashes are retained in `evidence/crow-v15-wing-continuation-20261116/wing-aero-timestep-20261116/`. See the adjacent source and invocation and `V15_ARTICULATED_WING_AERO_TIMESTEP_PLAN_20261116.md`.
