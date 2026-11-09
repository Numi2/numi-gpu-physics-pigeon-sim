# Temporal warm-up at bounded render joins

The complete replay videos retain every state but reset the renderer history
at each 600-frame capture boundary. Comparing the last two frames before each
join with the first two after shows a visible cold-start change during the
stationary landing: mean absolute RGB differences of approximately 0.003,
0.818 and 0.099 for layout I at frame 2400. The images show a temporary loss
of surface detail. The simulation itself is not reset.

Hypothesis: render the preceding ten accepted states as warm-up without
writing them, reset only on the first warm-up frame, then capture the requested
segment. A 10-frame 2400–2409 trial should reduce the join difference relative
to the cold first frame while retaining precisely those ten output states.
This is optional, bounded to replay captures, and not enabled for AOV audits.

Result: rejected as a fix. The warm-up trial at the same boundary measured
0.003, 0.816, and 0.099 mean absolute RGB difference, essentially unchanged
from the cold join. The test does not establish the source of the flicker.
The option remains off in the complete revised video captures. The warm-up
trial, audit and comparison are retained as negative evidence.
