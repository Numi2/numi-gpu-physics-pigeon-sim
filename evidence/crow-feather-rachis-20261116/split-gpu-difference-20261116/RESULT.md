# Native GPU compensated difference control

The M4 Pro Metal probe passed all 96 cases with fast math disabled. Maximum absolute error in the reconstructed compensated endpoint difference was 5.33e-14 m against the original double reference, below 3e-12 m. The maximum naive high-only error was 1.51e-6 m, above the 1e-8 m control threshold. Inputs, all output float pairs, native shader/driver, identity hashes, compilation warning and analysis are retained.

This establishes only the tested coordinate-difference arithmetic for these inputs and compiler mode. It does not establish a production implementation, preserved low parts through integration, compensated vector lengths, contact/attachment behavior, force accuracy, rollback, performance or flight. The earlier world candidate remains unpromoted.
