# Local and global rod curvature agree for the sampled planar states

For the analytical initial pose and the three recorded positive-deflection CPU poses, the sum of bend-projector local energies exactly matched the global bend energy at printed precision. Maximum per-node difference between their 1 nm centered y-derivatives was 1.7e-12 N, below the preregistered 1e-4 N threshold. This narrowly rules out a local/global bend-energy mismatch for these four planar, zero-twist states; it does not resolve the failure involving constraints, solver convergence or reaction accounting, nor does it qualify the formulation for other states.

The exact analyzer, copied source identity, input states, hashes and results are retained under `evidence/crow-feather-rachis-20261116/feather-local-curvature-20261116/` and adjacent source. The instrument includes the unchanged owner implementation to access its internal routines; it does not patch the solver.
