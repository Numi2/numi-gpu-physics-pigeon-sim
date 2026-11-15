# Read-only action-history observer

The source observer reproduced the original first 210 replay frames exactly. The history buffer contained 72 floats. At host step 201, the source's filtered knee action for each leg was approximately 0.18; on the q/v reconstructed reset's first step it was approximately 0.1138, following the reset's clear-to-zero. This difference is consistent with the observed target mismatch and saturated kick. These samples establish missing controller history, not that history is the only discrepancy or that its restoration yields a valid checkpoint. The prior control named `history` restored position/velocity references only and did not restore this action-history buffer.

Full read-only traces, input hashes, commands and build record are stored in `crow-history-probes-20261115.tar.gz`, SHA-256 `e636a225019f4290bb36efe39644ea1ab404ed9da9ac92f3bafdb0859f4d3534`.
