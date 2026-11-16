# Articulated hand response native owner test

Research source commit `2b8b808a1` adds `metalrobo.crow.v15_articulated_hand_response`: a CPU FP64 test of the default full articulated v15 pose and synthetic hand-local point. It checks the mass-response residual, symmetry, positive definiteness and a nonzero elbow response. The test uses native articulated Jacobian and mass-response APIs, with no rod, contacts, aerodynamics, flight, or dynamic integration. The earlier independent NumPy analysis and the later rod KKT experiment are archived separately and are not part of this CTest.

The fresh focused suite passed 11/11 on macmini, including this reference, the free-hand rod reference, the wing structural and dynamics controls and the hard-equality rollback guard. Full CTest output is in `articulated-hand-response/owner-ctest-last.log`. This does not establish a production solver fix or mission qualification.
