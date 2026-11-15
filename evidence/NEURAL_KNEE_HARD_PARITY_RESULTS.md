# Common hard-start lane parity check

The screen was modified so its three explicit q/v neighborhood random draws use lane zero, and run for 64 intervals with seed 20370113. Despite that change, all other lanes differed from lane zero in their first actor observation and accepted action. At the first observation, all differences were in indices 337–823 of the 828-value input; the first 228 nonvisual features were equal. The observed difference occurs in the visual suffix, but its physical or rendering cause is not yet established.

Consequently this is not a matched set of lane starts for the original actor, and no candidate was selected from it. Equalizing a subset of q/v does not imply identical hidden state or identical visual input. The full 64-step rollout, all-lane differences, commands, source, build fingerprints and logs are archived, including this failed parity check.
