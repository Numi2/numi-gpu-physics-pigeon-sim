# Toe-sensor learning: matched clipping diagnosis

The combined and separate-clipping updates consumed byte-identical rollout packs (SHA-256 `40cf459e4897d0c4dd8493a6aedcfaeb7cbfe1a69b59e6ceaf079c8ee4b8a9f8`). Both retained every inherited actor parameter and exploration parameter bit-for-bit; only the 12 new first-layer columns changed. The mean preclip actor and critic gradient norms were about 0.01177 and 4.930. Separate clipping restored the reported actor gradient norm from 0.00335 to 0.01177, but Adam's extension-weight displacement changed from 0.007695 to 0.007892 L2, not by the gradient ratio.

On identical retained observations, the largest RMS change in physical joint target was about 1.51e-6 radians for combined clipping and 1.56e-6 for separate clipping; toe changes were smaller and the physical toe gate can suppress them entirely. The RMS difference between variants was at most 1.39e-7 radians across the eight channels. This single matched update shows that critic-dominated combined gradient clipping was present but its removal did not produce a large actor update under Adam. It does not prove that clipping is never relevant, nor does it resolve reward attribution or establish whether tiny shifts matter in contact dynamics. Physical paired evaluations are pending; no policy is promoted based on these numbers or KL.

First-episode physical development evaluations, in 20 ms intervals (later automatic-reset episodes excluded):

| Starting-state seed | Starting long-horizon policy | Combined clip | Separate clip |
| --- | ---: | ---: | ---: |
| 20370113 | fell at 266 | fell at 269 | fell at 264 |
| 20370127 | no fall through 1000 | fell at 300 | fell at 295 |

The sensor-only candidates fail both starts and lose the previously observed 20-second hold. The small target changes and sharply different outcomes demonstrate sensitivity in this fixture; these consumed development trials cannot establish that one clipping approach is superior. Each raw run, per-substep contacts and first-episode summary is archived. The starting checkpoint remains retained. The observation includes external toe-group contacts, while the strict grip metric separately requires opposing contact on the branch.
