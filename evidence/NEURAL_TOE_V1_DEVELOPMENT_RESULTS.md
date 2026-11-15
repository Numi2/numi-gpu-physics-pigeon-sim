# Eight-output policy: first development evaluation

All four starts were previously consumed. Each test ran 1000 intervals at 0.02 s, with automatic resets excluded after first done. Strict streaks require both feet supported, opposing front/rear toe contacts, no ground/nonfoot contact, all 16 substeps, body tilt <= 0.35 rad and root speed <= 0.12 m/s.

| Seed | Previous leg-only first done / longest strict streak | New leg-and-toe first done / longest strict streak |
| --- | --- | --- |
| 20310111 | none by 1000 / 963 | none by 1000 / 964 |
| 20310129 | none by 1000 / 961 | tilt at 307 / 187 |
| 20310201 | tilt at 986 / 869 | none by 1000 / 961 |
| 20310221 | none by 1000 / 961 | none by 1000 / 961 |

The candidate improves 20310201 but regresses 20310129 substantially and is rejected for promotion. The observed toe-action outputs on seed 20310111 are roughly -0.0013 to +0.0015, scaled by 0.25 rad at the target before clamping; the carrier still drives toe closure. Matched toe-output ablations are in progress and must not be inferred from this table. These are controlled reconstructed perch starts with a relocated branch and scripted carrier, not continuous autonomous landings, and do not qualify on unused seeds or layouts.
