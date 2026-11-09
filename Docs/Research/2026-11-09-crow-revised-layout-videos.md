# Revised v15 replay videos

The two 60-second H.264 videos are replays of the exact same 3,000 retained
simulation states per layout, not fresh executions. Each 50 fps video was
rendered in five sections and concatenated without dropping frames. Both
videos were fully decoded and counted after concatenation. The capture ran
with Metal API validation; the script and per-section audits record the exact
flags and frame ranges. Candidate 9 adds opt-in presentation remiges, separated
flight digits, a slower support-triggered fold and moving-reference support
alignment. It does not alter the policy, accepted trajectory or contact data.

The historic layouts were used in development, despite their legacy names.
Waypoint and support-proxy outcomes are recorded in
`Evidence/crow-remex-20261109/full-replay-state-summary.json`. They do not
prove biological flight or measured toe forces. The earlier uninterrupted
capture failure was bypassed by bounded rendering; its cause remains unknown.
A section-join flicker remains; the failed history warm-up experiment is
retained in `2026-11-09-crow-render-warmup-plan.md`. Remaining feather and
motion realism limitations are in `2026-11-09-crow-visual-reference-audit.md`.
The candidate remains off by default and is not qualified as a final model.
