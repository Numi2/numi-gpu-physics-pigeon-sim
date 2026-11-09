# Crow motion presentation study

This is an exploratory visualization of an estimated American crow, not a
biomechanically validated crow model. The standing walk is a camera-following,
procedural cycle with alternating swing and stance, two-link leg placement,
toe clearance, body sway and a counter-moving head. It does not advance a Numi
physics state or train a walking policy. The moving ground marks visualize the
implied forward motion; there is no ground-contact solver in this presentation.
A crow can both walk and hop, with gait selection depending on speed
(https://doi.org/10.1111/j.1469-7998.1983.tb05784.x). The numeric gait used
here is an authoring estimate, not a measured American-crow motion capture.

For flight, the world-upright camera exposes pitch and roll from the retained
root orientation. Wing, body and limb-link states remain the existing replay;
feather movement and takeoff/landing shape are estimated visual reconstructions.
An opt-in leg-preparation cue uses accepted perch-relative position after the
recorded final waypoint to extend the presentation legs before support. It does
not establish foot contact, toe grip, load-bearing, or realistic landing forces.
The support signal is the task reward proxy described in the earlier study.

The original replay identifiers say `reserved-final`, but layouts I and J were
subsequently used in development. The viewer now labels these as development
layouts; neither is evidence of performance on unused layouts. The sequences
replay existing simulated trajectories and do not establish new policy performance.

Verification covers alternating support, stance toe positions in the implied
world, swing clearance, continuity and upper/lower leg lengths, camera behavior
under recorded body attitude, backwards-compatible camera decoding, bounded
landing preparation, and Metal feather-root agreement. In the retained inputs,
the exploratory preparation begins at accepted step 1728 on I and 1644 on J;
the recorded support proxy first becomes positive at steps 1942 and 1676,
respectively. These are timing observations, not direct measurements of feet.

The first ground-mark rendering attempt failed at frame 14 because the number
of geometry vertices changed as marks crossed the platform edge. The revised
version maintains a fixed number of marks. The failed log is retained alongside
the successful checks; the incomplete video is not a valid render.

Remaining gaps: v15 needs an actuated, physically supported walking policy,
measured crow-specific gait and body kinematics, contact-aware toe placement and
grip, force-coupled takeoff and landing transitions, and evaluation against
independent video or motion capture. Earlier carrier-based walking code belongs
to a different body/task and is not qualification of v15. Successful replay or
visual checks do not close these gaps.

Reproduce the walking presentation with `CROW_EXPERIMENTAL_WALK=1` and a
`standing` capture. The full replay renders use
`CROW_EXPERIMENTAL_FLIGHT_REMEX=1`, `CROW_EXPERIMENTAL_LANDING=1`,
`CROW_EXPERIMENTAL_FLIGHT_DIGITS=1`, `CROW_EXPERIMENTAL_SUPPORT_PLANT=1`,
`CROW_EXPERIMENTAL_PRELANDING_LEGS=1`, and `CROW_WORLD_UP_CAMERA=1` with
`Scripts/render-crow-v15-video-sections.sh`. These switches affect rendering,
not the accepted replay or controller. Video evidence and check logs are stored
under `Docs/Research/Evidence/crow-motion-20261109`.

Visual review of the development landing views shows that the extended feet
approach the perch, but the toes are still simplified and do not visibly wrap a
branch. Some wing tips leave the upper edge of the camera frame during the
largest flaps. These are remaining presentation defects, not validation of
anatomy or contact. The renderer also refused a first re-render when the target
video already existed; the separate-output retry preserves that safeguard.

The two full recordings are concatenations of sequential render sections, not
new simulator runs. Each retains all 3,000 replay frames at 50 fps. The retained
source was neural-only and each final record reports five waypoints and a
positive support proxy. The file/frame check does not prove real foot contact.
In layout I near accepted step 1943, the overlapping wing surfaces obscure much
of the head during the landing stroke. This is an unresolved rig/registration
or camera-projection issue; the footage should not be described as photorealistic.
