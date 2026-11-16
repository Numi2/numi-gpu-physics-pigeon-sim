# Continuous fold, hold, unfold, hold screen

The initial v3 480-step fold was finite and reached the target window, but joint velocities remained nonzero. The separate 480-state static probe found zero contacts at the sampled states; it is not a swept collision or actual-force measurement.

Run one uninterrupted 1920-step temporal-cone trajectory at 240 Hz with four substeps, zero gravity, no aero, task, teacher, or policy. Hold all other joint position targets at default; ramp both elbow/wrist targets smoothly from 0 to (1.8, 1.575) rad during the first two seconds, hold two seconds, ramp back to zero over the next two seconds, and hold two seconds. Start from default q/v exactly once with no reset. Use the same native bounded implicit drives and keep the root free. Record all q/v, targets, per-step contact and solver statuses, and final contact evidence.

Predict every step is accepted and finite; at the end of each two-second hold, all four target joints are within 0.12 rad of their targets and below 0.1 rad/s in absolute velocity. The trajectory must respect authored velocity limits to within 0.5 rad/s. Report any contact counts and failures regardless of outcome; accepted steps do not demonstrate continuous clearance or safe contact force. This is an exploratory zero-gravity bare-bone mechanics check and cannot qualify biological fold, feathers, perch balance or flight.
