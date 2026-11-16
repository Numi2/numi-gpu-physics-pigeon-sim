# Articulated rod Metal owner regression

Research source commit `c021f3eeb` registers `metalrobo.crow.rod_v15_articulated_reference`. The standalone test exercises four fixed-pose, 73-coordinate linearized GPU cases against FP64 data, including two node orderings. It is a numerical reference, not the live MetalWorld solver, nonlinear contact, physical feathers or a flight/landing qualification. Its oracle regenerates byte-for-byte to SHA-256 `6bc92ea05329690142fa21d57e8c785de878932027ddd536912c9c4fab77247a` using `articulated-metal-kkt/generate_oracle.py`.

The macmini focused suite passed 12/12; `articulated-metal-kkt/owner-ctest-last.log` contains the detailed results. The source build's deprecation warning for `fastMathEnabled` is retained in the original Metal experiment evidence. The production hard-equality and live articulated-rod integration remain open.
