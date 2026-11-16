# Owner 3D coupled-modal research test

The standalone 3D rod and moving point-mass reference is registered as `metalrobo.crow.rod_coupled_3d_modal_reference` on isolated source commit `e2cc2de2d`. Its standard-library Python validation checks all 80 native GPU states against FP64 positions, total energy, three-axis momentum and force residual. The oracle was independently regenerated from the archived fixture with matching SHA-256 `5e94ddee955531587690576fefee018c78dc9dd605dcedfacc6cb2c7a04f0fad`; the generator and nine-of-nine targeted CTest log are retained in `evidence/crow-feather-rachis-20261116/coupled-3d/`.

This standalone linearized, fixed-twist reference does not implement nonlinear feathers, articulated rigid wing attachment, unilateral contact, aerodynamics or MetalWorld; high-frequency sampled motion remains aliased. The nine checks do not qualify the solver or the crow mission.
