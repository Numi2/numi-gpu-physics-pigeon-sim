# Native 3D energy versus linear model

Test the domain of the archived straight-rest translational Hessian against the actual native nonlinear rod energy using the same nine-node 3D initial displacement direction used by the GPU control. Evaluate energy at displacement scales 0.1, 1, 5 and 10 with twist fixed to zero, and compare each with `0.5 q^T K q` using the archived Hessian. The reference Hessian uses a 0.1 micrometre position finite-difference perturbation; record the native model, source, scale, full states and energy components. This is a comparison to the same native model, not a biological validation.

Preregister: expect relative energy discrepancy <5% at scale 1, and at least one of scales 5 or 10 to exceed 5%; if either prediction fails, record that outcome. Do not adjust timestep or discard failed scales. Even if the energy approximation agrees, it does not establish force, phase, contact, aerodynamic, 3D wing-coupling or whole-feather fidelity.
