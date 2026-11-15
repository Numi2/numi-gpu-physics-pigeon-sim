# First-update balance checkpoint: development comparison

The previously retained first update of v5-slow was evaluated without further training on four consumed arrival-reset seeds, each for 1000 intervals of 0.02 seconds. Counts below stop at the first done; qualifying streaks require opposed toe contacts, both feet supported, no ground or nonfoot contact, speed at most 0.12 m/s, and tilt at most 0.35 radians using all 16 substeps per interval.

| Seed | V3 first done / longest qualifying streak | Update 01 first done / longest qualifying streak |
| --- | --- | --- |
| 20310111 | none by 1000 / 963 | none by 1000 / 963 |
| 20310129 | none by 1000 / 960 | none by 1000 / 961 |
| 20310201 | tilt at 596 / 478 | tilt at 986 / 869 |
| 20310221 | tilt at 563 / 446 | none by 1000 / 961 |

This checkpoint preserves the two previously successful starts and improves both difficult starts. It is the strongest of these development candidates, but seed 20310201 still terminates, so the controller is not qualified or reliable. In the three completed holds, the final 250 intervals satisfy the strict gate; the failed seed cannot satisfy a 1000-step terminal hold. The result identifies later PPO updates as associated with the final candidate's regressions; it does not establish their cause. No unused seed or layout was tested here. The setup retains a relocated branch, forced terminal phase, scripted carrier and a partially reconstructed state; it is not an autonomous landing or a validated biological crow model. All first episodes and any later automatic resets are preserved in the archived traces, with resets excluded from the statistics.
