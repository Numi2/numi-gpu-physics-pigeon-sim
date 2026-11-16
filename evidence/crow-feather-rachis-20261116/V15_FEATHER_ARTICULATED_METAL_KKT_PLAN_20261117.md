# Prediction: Metal FP32 articulated v15 rod one-step control

Test the same 46-DOF full v15 mass and Jacobian with a nine-node 3D rod as the CPU FP64 KKT control, on a standalone native Metal kernel using FP32 and no fast math. Use the same rest and incoming cases and forward/reverse rod order at the unchanged 0.125 ms macro step. The reference uses linearization at one pose and a synthetic hand anchor. The kernel builds a dense factor per case and Schur equality response; it is a correctness experiment, not the production algorithm or performance architecture.

Pre-registered gates: finite successful statuses for all cases, generalized force/torque residual <0.01, equality error <1e-9 m, coordinate difference from FP64 direct KKT <1e-6, and order gap <1e-6. Retain compiler/runtime warnings and all failed cases. No contacts, nonlinear dynamics, live MetalWorld, physical feathers, flight or landing are tested.
