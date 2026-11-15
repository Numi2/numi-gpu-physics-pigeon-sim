# Reactive hip and wing screen: no recovery

On the reused hard-start checkpoint, all four corrected feedback shaders reproduced the control's q/v and drive targets exactly through interval 435. At interval 436, after the previous accepted pitch reached 0.200234 rad, the specified hip or flap pair changed by the expected signed 0.001502 rad. Initial observations matched; all changes were bounded through the existing joint targets. The earlier invalid sensor-mapping and checkpoint-identity attempts are separately archived.

| Feedback arm | First tilt >= 0.35 rad | First termination | Longest bilateral opposed-normal proxy |
| --- | ---: | ---: | ---: |
| Fixed -0.75 control | 541 | 625 | 578 |
| Hip positive | 476 | 555 | 505 |
| Hip negative | 498 | 590 | 545 |
| Wing positive | 540 | 624 | 576 |
| Wing negative | 541 | 625 | 576 |

No arm returned from >=0.24 rad to <0.20 rad for 50 consecutive intervals, and all failed before the 750-interval gate. Both feet retained net upward branch impulse through each first episode; the opposing toe-normal proxy was lost before termination. The hip corrections worsened this start and the wing corrections had negligible effect. The results rule out these specific bounded, delayed feedback variants, not all whole-body recovery strategies. Preserve post-termination frames without counting them as valid balance. Full source, four shader-compatible physical checkpoints, commands, hashes, target traces and 16-substep contacts are archived. The fixture remains a forced perch with reconstructed branch and scripted carrier; no autonomous landing or neural recovery is shown.
