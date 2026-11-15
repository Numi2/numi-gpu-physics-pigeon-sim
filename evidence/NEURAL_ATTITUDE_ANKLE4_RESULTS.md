# Matched ankle-feedback candidate

The screen's lane-4 candidate applied `clamp(-0.06*(pitch-0.13)+0.06*pitch_rate,-0.04,0.04)` radians to both physical ankle targets after settling. It is privileged diagnostic feedback, not neural control.

On consumed development seed 20370113 the candidate tipped at interval 255 (5.10 s) with a 131-interval longest strict grip streak; the original tipped at 263 with a streak of 139. On seed 20370127 the candidate tipped at interval 601 (12.02 s) with a 485-interval streak, while the original had no termination within 1000 intervals and a streak of 962. The ankle candidate therefore regressed both matched cases despite a better first-termination time than hip feedback in its original screen lane. Its traces and source are retained. These are reconstructed forced-perch tests with a scripted carrier, not autonomous landings.
