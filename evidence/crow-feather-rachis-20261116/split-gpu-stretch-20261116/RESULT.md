# GPU compensated 3D stretch-force control

The native M4 Pro probe passed all 96 preregistered segments with fast math disabled. The maximum absolute compensated tension error was 6.46e-7 N against the independently generated double reference, below the 0.0001 N threshold. The largest ordinary-FP32 error was 2.443 N, above the 0.01 N control threshold. Cases covered 3D orientation, near-rest extension and translations 0, 1 and 16 m. Inputs, executable source, GPU shader, output, device/compile evidence and all errors are retained.

This is a bounded scalar stretch-tension component experiment. It does not implement or test rod state representation and updates, bending/twist, damping, collisions, live articulated attachment, solver convergence, performance, biological calibration, flight or landing. It does not repair previous rounded states. Native Metal compiler fast math was disabled and must remain disabled for the compensated arithmetic.
