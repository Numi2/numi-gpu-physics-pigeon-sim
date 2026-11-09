# Support-triggered landing presentation trial

The recorded layout-I support reward becomes positive around step 2028. The
existing renderer waits for 0.2 s of support, then eases a scalar phase to zero
over 0.5 s. Since the flight phase is still above the takeoff transition range,
most of the visible fold is compressed into a few frames. The saved full-I
video shows a rapid change around 40.9–41.1 s.

Hypothesis: map the same confirmed support weight through the inverse of the
takeoff transition, with a smoothly decaying flight-phase component. This will
spread the visible fold across more of the existing support window while
preserving continuity and the exact simulator states. Prediction at flight
phase 0.86 and 50 Hz: the largest transition-progress change over one frame is
below 0.11, compared with approximately 0.26 for the prior mapping.

The trigger remains recorded support, not tracked contact points. This is a
visual hypothesis, not evidence of a realistic pre-contact flare, foot
placement, force, or animal landing. Compare the same full landing window and
course camera to candidate 5; reject visible floating, penetration, popping,
or any claim that this changes the trajectory or policy. Keep the new path
opt-in until both trajectory and visual inspections are complete.

The first smoother-phase trial passes the numeric fold-continuity prediction,
but course-camera inspection shows legs ending without readable toes during
the transition. It is not accepted. Inspection also found that the existing
flight retraction maps every digit to the same target line, collapsing their
separate shapes. A follow-up will preserve distinct, partially curled digit
chains through retraction. It must retain the planted pose, preserve bilateral
shape and avoid a new collision or floating appearance. This still cannot
prove toe contact: the simulation supplies support-group rewards, not tracked
avian toe surfaces.
