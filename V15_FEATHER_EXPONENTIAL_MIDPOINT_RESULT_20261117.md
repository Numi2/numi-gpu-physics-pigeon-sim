# Exponential-midpoint nonlinear candidate

The preregistered candidate failed both requested nonlinear criteria. Its maximum sampled position error against the converged tighter DOP853 reference was 0.1652 micrometres at step 79, worse than the uncorrected linear reference's 0.0723 micrometres and above the 0.0578 micrometre target. Its maximum native total-energy drift was 1.017%, above the 1% limit. The zero-nonlinear-force control matched the prior GPU linear reference within 1.22e-10 m. Full states, energy, source, reference identities, commands, hashes and comparison are retained under `evidence/crow-feather-rachis-20261116/exponential-midpoint/`.

This fixed-macro-step CPU research method is not promoted. It does not solve nonlinear feather dynamics, contact or wing coupling, and these tests do not qualify flight or landing. The comparison uses the retained DOP853 convergence pair solely as a measurement reference, not as a production timestep change.
