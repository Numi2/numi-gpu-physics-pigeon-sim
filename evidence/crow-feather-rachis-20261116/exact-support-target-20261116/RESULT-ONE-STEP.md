# One-step fixed-world result (experimental)

The two bent-rod native controls met their predeclared bounds: damping 0 support error 2.376e-9 m, max free-node y force residual 7.411e-5 N, energy ratio 0.998342; damping 100 support error 2.856e-9 m, force residual 7.235e-5 N, energy ratio 0.998415. Stationary and +/-0.01 m/s cases returned success in both tested world solver modes. Full source patch, native build and all raw evidence are present. The 1 ms timestep was unchanged.

This does not establish dynamic-target or mixed-contact compatibility, position-correction energy transfer, multi-step passivity or correctness under CCD. The exact candidate changes behavior of world rows and invalidates the historical rejection-only world test, so it is not promoted. Next use retained evidence and explicitly separated failure controls; do not treat GPU status as physical validation.
