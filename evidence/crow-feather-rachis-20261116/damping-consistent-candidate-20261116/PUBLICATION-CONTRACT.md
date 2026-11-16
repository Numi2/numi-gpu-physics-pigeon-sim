# Publication contract clarification

The no-publication prediction in `FAILURE-CONTROL-PLAN.md` was incorrect for `MetalWorld`: the host implementation moves the staged result to the caller and sets `diagnostics.published=true` before it reports a failed GPU step. Publication means that checked diagnostics and the resulting state were returned, not that the control step succeeded. The experiment still failed its preregistered criterion; this correction does not retroactively mark it as passed.

The deliberately failed first step reports status 12, zero successful steps, and one failure. Its returned rod positions differ from the analytic initial geometry by at most 7.46e-10 m, with all rod velocities zero. The script reproduces this check. This is evidence that the rod part of the initial state was restored in this one injection; it does not compare the entire world state, prove resident checkpoint identity, or cover a failure after a successful step. A separate before/after checkpoint trial remains necessary.

Host source: `src/metal/MetalWorld.mm` near `result = std::move(staged); diagnostics.published = true; if (diagnostics.failedStepCount != 0u)`, source revision `1326ac525` with the archived world candidate. This behavior is independent of the candidate's position correction.
