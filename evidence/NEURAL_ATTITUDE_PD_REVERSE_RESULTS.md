# Reverse bounded pitch/rate probe

The isolated diagnostic reversed both feedback terms to `clamp(-0.12*(pitch-0.13)-0.04*pitch_rate,-0.04,0.04)` radians, added to each physical hip target after settling. This is privileged simulator feedback, not a neural action or a qualified teacher.

On consumed seed 20370113 it terminated on tilt at interval 272 (5.44 s), with a 144-interval longest strict grip streak. The original policy without the added feedback terminated at 263 with a 139-interval streak. On consumed seed 20370127 both runs avoided termination over 1000 intervals and had a 962-interval strict streak. Their physical q trajectories differed beginning at replay frame 50, with a maximum absolute q difference of 0.00331 in the recorded interval; matching outcomes therefore do not mean matching motion. The marginal gain on the harder case is not a reliable hold. Full traces, build inputs and resets are retained; these are reconstructed forced-perch tests with a scripted carrier.
