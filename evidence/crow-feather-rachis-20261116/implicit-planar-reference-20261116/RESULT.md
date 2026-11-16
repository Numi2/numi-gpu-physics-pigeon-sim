# Independent planar implicit control

The two force-step variants met all preregistered numerical checks: maximum free-coordinate force residuals were 1.03e-7 N and 7.04e-8 N; their positions differed by 5.60e-14 m; elastic plus kinetic energy was 7.84883216e-6 J versus 7.86246505e-6 J initially. Both BFGS invocations nevertheless reported `Desired error not necessarily achieved due to precision loss`; those warnings are retained, and the checks apply only to this local stationary point and fixed planar surrogate. The optimizer's success status must not be represented as passing.

Against the second reference variant, the published successful native CPU supported-rod control differs by up to 1.806e-6 m; the archived, now-reverted experimental GPU world candidate in the undamped control differs by up to 8.58e-9 m. The latter comparison is undamped only, and does not overrule its failing damped control or validate its global start-state integration change. No dynamic rigid attachment, mixed contacts, three-dimensional feather dynamics, multi-step trajectory, flight, landing or performance is covered. The original 1 ms step was retained.

The exact native energy bridge and local minimizer, hashes of the macmini-built library and bridge, all positions, residuals and optimizer statuses are retained alongside this result.
