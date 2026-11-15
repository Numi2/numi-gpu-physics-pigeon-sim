# Direct toe residual ablation

The same trained direct-residual policy was compared with a copy in which only the newly learned toe-output projection was zeroed. The learned leg residual, inherited actor outputs, scripted toe carrier, simulator and reconstructed starting procedure were retained. These are consumed development starts on one reconstructed, forced-perch fixture, not independent layouts or an uninterrupted landing.

| Seed | Full policy first fall | Toe-residual ablation first fall | Full / ablated longest strict grip streak |
|---|---:|---:|---:|
| 20370113 | interval 263 (5.26 s) | interval 263 (5.26 s) | 139 / 139 intervals |
| 20370127 | no fall in 1000 intervals (20 s) | no fall in 1000 intervals (20 s) | 962 / 962 intervals |

The strict test independently samples all 16 substeps and requires bilateral upward support, opposed front/rear toe normals on the perch, tilt at most 0.35 rad, root speed at most 0.12 m/s, and no ground or nonfoot support. Analysis stops at the first episode termination. Identical summary outcomes do not imply identical trajectories, and removing this residual does not remove physical toe actuation or prove that toes are unnecessary. These results do not demonstrate that the newly learned toe-output projection improved balance on either tested start.

The unmodified policy pack has SHA-256 `24b4852831844510ba9adece3587ad63401db9319e50559ad0c917ab7b955242`; the ablated pack has SHA-256 `75e5ebca1339465dbcfa40b33002508481a9b8ab2249a549dd8d52f555f0891f`. The individual retained full and ablated run archives include command, inputs, replay, physical traces and failure evidence. The controller gates the toe residual on bilateral accepted support and established contact ramps and clamps its resulting target to joint limits; consequently output size alone does not measure effective joint-target authority.
