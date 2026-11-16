# FP32 constrained KKT feasibility

All preregistered cases passed this CPU arithmetic control. The largest force residual evaluated against the FP64 model was 2.98e-5 N, the largest support error 1.10e-11 m, the largest difference from the FP64 solution 1.80e-11 m, and the largest node-order difference 7.28e-12 m. These values are for one locally framed, planar, nine-node linearized segment and one step. Complete inputs, hashes, code, outputs and reaction forces are retained under `evidence/crow-feather-rachis-20261116/kkt-precision/`.

This indicates single precision can meet the selected thresholds for this well-defined small system using a dense CPU solve. It does not show that the current GPU XPBD/Schur implementation does so, establish GPU arithmetic behavior or performance, address dynamics over multiple steps, or qualify contacts and articulated moving wings.
