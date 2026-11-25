# Numi Lab bird simulation research

BirdFlowMetal owns the Crow and Dove research collected here. The imported source covers the articulated wing fixture, Crow environments and policies, navigation, foraging, and the Dove replay bridge. The files retain their Numi Lab paths under [`sources/`](sources/) so they can be compared with or overlaid onto the pinned engine checkout. The fixtures use Numi Lab’s C++ and Metal interfaces. BirdFlowMetal’s Swift package continues to build its own runtime.

## Source and evidence

| Numi Lab branch | Exact source revision |
| --- | --- |
| `agent/crow-articulated-wing-20261116` | [`20b8f43ab1b8`](https://github.com/Numi2/numi-lab/tree/20b8f43ab1b8bcfc8d2297a2118f56c823248912) |
| `agent/crow-v15-flight-evidence-20261112` | [`fd2739e81654`](https://github.com/Numi2/numi-lab/tree/fd2739e81654bb72c09d4f9eeecc9d2e7e068907) |
| `agent/american-crow-rl-20261107` | [`4ab800743a06`](https://github.com/Numi2/numi-lab/tree/4ab800743a06cc955774b1812849c720ae19d24f) |
| `agent/crow-world-model-navigation` | [`577c54ff9075`](https://github.com/Numi2/numi-lab/tree/577c54ff90756f99b936a1d136c1768332022af5) |
| `agent/crow-numi-integration` | [`cea10e9bfd2d`](https://github.com/Numi2/numi-lab/tree/cea10e9bfd2d36e8436c349e81d301ab13f26ca9) |
| `agent/birdflow-dove-numi` | [`638874bf11a7`](https://github.com/Numi2/numi-lab/tree/638874bf11a74853d540b806fc874df635edd1e3) |

The wing and flight revisions together contain all six histories. This import copies 265 files, including the [flight diagnostic package](artifacts/crow-v15-flight-diagnostic-state-isolation-20261112/) and selected [flight reports](artifacts/crow-v15-recorded-restart-20261114/), and records their original modes, paths and contents in the Git trees and [source manifest](source-files.tsv). The [evidence index](evidence-index.tsv) pins 2,379 source directories to exact Git tree IDs. The bulk flight evidence, including replay frames, videos, and model checkpoints, is preserved in [the original flight archive](https://github.com/Numi2/numi-lab/tree/fd2739e81654bb72c09d4f9eeecc9d2e7e068907/artifacts). Follow-up wing and balance experiments already live in [the separate BirdFlowMetal evidence history](https://github.com/Numi2/numi-gpu-physics-pigeon-sim/tree/7d1c6dbf5216fb86fe7e1b2e55670b746e6da386).

To verify the copied files, run this from the BirdFlowMetal root.

```sh
cd Integrations/NumiLab
shasum -a 256 -c source-files.sha256
shasum -a 256 -c artifacts/crow-v15-flight-diagnostic-state-isolation-20261112/SHA256SUMS
```

To verify an indexed directory in a Numi Lab checkout, use `git ls-tree <source_revision> -- <path>` and compare its tree ID with the index. The source notices remain in [`sources/THIRD_PARTY_NOTICES.md`](sources/THIRD_PARTY_NOTICES.md).

## Run the articulated wing checks

Use a disposable checkout of Numi Lab at the pinned wing revision on Apple silicon, with Xcode, the Metal Toolchain, CMake, and Ninja. A sparse checkout can omit the bulk `artifacts` directory. Copy the BirdFlowMetal fixture into that checkout before configuring the build. All five checks passed on Apple M4 at the pinned revision during this import.

```sh
numi_bird_sources=/path/to/BirdFlowMetal/Integrations/NumiLab/sources
cp "$numi_bird_sources/include/metalrobo/CrowArticulatedWing.hpp" include/metalrobo/
cp "$numi_bird_sources/src/core/CrowArticulatedWing.cpp" src/core/
cp -R "$numi_bird_sources/tests/crow_v15_wing_fixture/." tests/crow_v15_wing_fixture/
cmake -S . -B build/wing-check -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/wing-check --target crow_v15_wing_structure_check crow_v15_wing_dynamics_check crow_v15_wing_reference_check crow-feather-split-stretch
ctest --test-dir build/wing-check --output-on-failure -R 'metalrobo\.crow\.(v15_wing_|rod_split_stretch_reference)'
```

See the [original wing fixture notes](sources/tests/crow_v15_wing_fixture/README.md) for the model assumptions, known failures, and limits of the tests. Shared solver, ABI, and shader changes remain in the pinned Numi Lab engine. The wing fixture requires that revision’s ABI and candidate mechanics.
