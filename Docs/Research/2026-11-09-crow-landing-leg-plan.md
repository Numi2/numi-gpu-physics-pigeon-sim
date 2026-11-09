# Exploratory landing-leg presentation

The existing presentation waits for confirmed support before folding the wings,
while the visible feet remain tucked on approach. Test a separate, bounded
pre-contact leg-extension cue driven by accepted navigation completion and the
recorded position of the body relative to the perch. The cue is a visual
estimate, not a measured foot trajectory or contact. Preserve the recorded body,
wing and leg-link states, do not infer contact from the cue, and do not change
the flight controller or support criterion. Check that extension is zero before
completion and outside the perch approach region, continuous as the bird
descends, and present before support on both development replays; inspect the
actual rendered approach and reject it if it makes contact less credible.

The general idea that birds can reach for a landing surface before contact is
supported by observed parrotlet landings, but those measurements do not provide
an American crow landing model: https://pmc.ncbi.nlm.nih.gov/articles/PMC6684272/.
