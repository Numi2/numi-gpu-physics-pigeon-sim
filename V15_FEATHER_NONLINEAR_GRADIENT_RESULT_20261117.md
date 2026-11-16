# Native nonlinear gradient perturbation control

The preregistered gradient sensitivity control passed. The retained 1e-9 m perturbation gave a maximum force residual of 0.034515932179 N; 1e-8 m gave 0.034515932176 N, and 1e-10 m gave 0.034515932184 N. All peak at the same step 69 and coordinate 0. Thus this specific failure is robust to the tested hundredfold range of central-difference perturbations and remains above the 0.01 N limit. Complete per-state/per-coordinate results, source and hashes are retained in `evidence/crow-feather-rachis-20261116/nonlinear-gradient/`.

This does not establish a general nonlinear force bound, identify a complete fix, or validate contacts or articulated flight. It specifically supports rejecting the tested fixed-Hessian trajectory as a nonlinear solution under its preregistered force criterion.
