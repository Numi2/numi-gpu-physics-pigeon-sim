# Matched tests of the lane-13 hip feedback

The lane-13 screen candidate added `clamp(-0.18*(pitch-0.13),-0.04,0.04)` radians to both physical hip targets after settling. This uses privileged simulator feedback and is a diagnostic teacher candidate, not learned neural control.

On development seed 20370113 it terminated on tilt at interval 274 (5.48 s), with a 146-interval longest strict grip streak. The original policy terminated at 263 with a 139-interval streak. On seed 20370127 neither the candidate nor the original terminated during 1000 intervals; both had a 962-interval strict streak. The small gain on the hard start does not establish a reliable teacher. Full traces and subsequent resets are retained. This is a reconstructed forced-perch fixture with a scripted carrier, not an uninterrupted landing.
