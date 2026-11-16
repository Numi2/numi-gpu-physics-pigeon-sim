# Articulated v15 hand response: local control passed

The pre-registered control used source based on `80b18e8ca` plus the archived standalone extractor, the full default v15 experimental articulated fixture, and the synthetic hand-local offset [0.008, 0.012, 0.003] m. Raw full matrices, code, stdout, stderr and the independent NumPy analysis are in `articulated-hand-response/`. Extractor SHA-256 `a9e0d12c728e5001962123a18b5f8534d3c8351739cbd2a836914272622a25a1`; raw JSON SHA-256 `3f9c2087633836cadc9bc65d2db7aed3a490894e09953389f217aa51968f2097`.

All planned checks passed: max |M X - J^T| = 3.33e-16, max point-response asymmetry 1.78e-14, eigenvalues 4.27, 77.94, 92.59, max unit-velocity solve residual 4.74e-16. Each measured left wing sweep, flap, pronation, elbow, and wrist coordinate responds. The articulated point-response matrix differs from the free-hand matrix by 1.221 relative Frobenius norm, demonstrating that the free-hand model is not an adequate substitute for this local full-body response in this configuration.

This is a CPU FP64, instantaneous reference in one pose. It does not include actuation, contacts, a coupled rod, dynamic integration, or aerodynamic and landing qualification. The synthetic anchor and v15 inertia remain engineering priors. In particular this control does not fix the MetalWorld hard-constraint solver.
