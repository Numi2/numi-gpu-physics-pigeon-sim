# Final bounded mixed-scalar research check

Source revision: Numi2/numi-lab `1326ac525` on `agent/crow-articulated-wing-20261116` (pushed). This includes the analytic tests, binary random inputs, FP64 references, unsupported two-contact exclusion and objective certificate check. It remains a narrow experimental path, not qualification of world contact, feathers, flight or landing.

The expanded native suite passed 17/17 tests on M4 Pro; the general quality probe passed. See `crow-mixed-expanded-tests.log` and `crow-mixed-general-probe.log`. The analytic suite includes the two-contact exclusion: the path must not claim unsupported products, and any rejection must preserve output. The three fixed analytical cases and 192 seeded synthetic comparisons described in this directory passed.

The first build of the added exclusion test failed because an initializer list was assigned directly to a `std::span`; `crow-mixed-exclusion-build.log` preserves the compiler failure. The test was corrected to use vectors with sufficient lifetime and rebuilt successfully; see `crow-mixed-exclusion-build-fixed.log` and `crow-mixed-exclusion-test.log`.

The solver runs after the generic solver, is not performance-qualified, handles one compliant scalar normal only, and cannot establish multiple-contact or friction-cone correctness. The actual articulated hand attachment and two-way simulation remain unimplemented.
