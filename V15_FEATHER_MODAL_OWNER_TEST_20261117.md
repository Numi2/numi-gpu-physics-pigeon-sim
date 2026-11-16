# Owner fixed-step modal research test

The standalone modal reference is registered as `metalrobo.crow.rod_free_modal_reference` in isolated research source commit `6a9390d88`. It checks all 80 GPU positions against the FP64 modal oracle, finite values, energy drift and momentum using only Python's standard library. The oracle was independently regenerated from the archived fixture with matching SHA-256 `7d71ebae4566d7675686ea7fe9527d8aa86d834168d1fc5ee047b5e1cd0bc903`. The generator and eight-of-eight targeted CTest log are retained under `evidence/crow-feather-rachis-20261116/native-modal/`.

This remains a free, planar, linearized fixed-Hessian reference. It does not integrate the experimental kernel into MetalWorld, validate contact or attached feathers, qualify the shared solver, or establish biological or mission realism.
