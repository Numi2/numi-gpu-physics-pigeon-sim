# American-crow estimated simulation model

BirdFlowMetal's crow is a high-quality native Metal **estimated hybrid**, not a
measured crow. Its machine-readable parameter and provenance record is
[`american-crow-hybrid-visual-v1.json`](../ValidationInputs/american-crow-hybrid-visual-v1.json).
The persistent anatomy, stable feather identities, rendering LOD contract, and
physics-surface anchors are defined separately in
[`BIRD_REALITY_ASSET.md`](BIRD_REALITY_ASSET.md).

![Native Metal American-crow simulation frame](Media/american-crow-hybrid-native-v1.png)

[View the two-second native Metal wingbeat](Media/american-crow-hybrid-native-v1.mp4).
This page shows only output from the executable renderer; reference photographs
and generated appearance targets are not displayed or distributed.

## What is real, inferred, and artistic

| Layer | Evidence | Use in the crow |
|---|---|---|
| Deetjen OB F03 surface sequence | 144 source frames at 1000 Hz; 2,157 vertices; 3,968 triangles | Real non-rigid articulation scaffold after translation removal and allometric remapping |
| American-crow CT screening | Three folded `Corvus brachyrhynchos` public-viewer volumes | Gross skeletal proportion and physical-extent plausibility only |
| Jackson and Dial corvid experiment | Three American crows, synchronized 250 Hz three-view capture, takeoff and muscle measurements | Burst-flight context and frequency plausibility; no unavailable crow landmarks are reconstructed or implied |
| Published and museum morphometrics | Adult mass, wing chord, tail, bill, tarsus, total-length and wingspan ranges | Selected midpoint-scale target with ranges retained in the JSON |
| American-crow plumage study and current flight photographs | Region-dependent black plumage, gloss, UV/visible hue, flight-feather and squared-tail silhouette | Procedural feather layering and view-dependent blue/violet sheen |
| Renderer additions | Head, bill, eyes, nostril bristles, explicit primaries/secondaries/retrices, contour-feather relief | Artistic geometry constrained by the sources above |

The selected visual target is a `0.46 m`, `0.45 kg` adult with a `0.91 m`
wingspan, `0.174 m` tail, and `0.049 m` bill. These are useful central estimates,
not a same-specimen measurement. The display wingbeat is `4.6 Hz`; the original
dove sequence supplies phase shape, not crow timing.

The standing presentation uses an asymmetric axial body loft whose final neck
stations overlap a seven-station cranial loft. Separate dorsal and ventral
envelopes form the mantle, shoulder, breast/sternum, nape, raised crown, bill
transition, and pelvic taper, while the contained neck junction avoids exposing
an intersection seam. Overlapping contour and folded-wing covert rows then
break up the analytic surface. These remain estimated presentation geometry;
they are not inferred skeletal landmarks or a measured body scan.

The grounded silhouette keeps the folded primaries, secondaries, and rectrices
in compact, nearly parallel stacks instead of fanning a flight pose downward.
The body envelope is intentionally horizontal, with a distinct elevated neck
transition, deeper sternum, feathered upper legs, and thicker scaled toes. These
are qualitative anatomy corrections; they do not change the fixed-topology
solver surface, prescribed motion, or aerodynamic claims.

Within that compact envelope, persistent primary and secondary roots occupy
separate lateral layers and fan gradually inward and downward toward the rear.
The retained feather lengths and stable identities do not change; only the
estimated grounded rest pose prevents all vanes from collapsing into one
planar flank slab.

The flight presentation draws the fixed-topology wing and tail surface as a
dark underlayer beneath the retained feather inventory. That live surface owns
deformation and every persistent root, closes sub-feather gaps, and makes the
attachment boundary inspectable; it is not asserted to be a literal smooth
crow skin or resolved plumage surface.

Four staggered covert rows are sampled from each wing's fixed `9 x 33`
topology. Both ends of every blade follow current surface vertices, and adjacent
rows overlap chordwise and spanwise, so the retained outer flight feathers read
as one articulated wing instead of a detached comb. The coverts remain
estimated presentation geometry and do not enter the moving-boundary, force,
or power calculation.

Persistent flight-feather roots remain attached to their exact fixed-topology
surface vertices. Vane direction now uses one shoulder-to-tip span plus a fixed
topology chord anchor per wing (and one base-to-tip frame for the tail),
evaluated independently for current and previous phases on Metal. This removes
triangle-scale rotational noise and world-axis drift during large strokes; it
does not change the solver surface or assert measured crow kinematics.

Sparse diagnostic captures can set `--capture-crow-camera-yaw` in radians so a
geometry milestone is checked from a new view without changing the release
camera or multiplying appearance-only review frames.

Procedural contour and folded-wing feathers select quantized tessellation from
their projected length at the final output resolution. The four asset LOD
thresholds drive silhouette, curved vane shell, rachis, paired-barb, and
close-up barbule budgets. Body contour mesostructure is derived from the same
root, tip, plane, width, and camber envelope as its visible vane; it is not a
detached decoration. Current and previous temporal geometry share one tier for
stable motion vectors. The crow material derives a local feather axis from
live vane coordinates where present and uses a surface-projected fallback on
the body for a restrained anisotropic black-feather highlight.

## Native Metal capture

The native renderer consumes both locked inputs. Its encoding, input hashes,
Apple-Metal execution record, seam check, and claim boundary are locked in
[`american-crow-hybrid-native-v1.json`](../ValidationArtifacts/american-crow-hybrid-native-v1.json).

```bash
swift build -c release --product birdflow-viewer
.build/release/birdflow-viewer \
  --capture-crow-frames /tmp/birdflow-crow \
  --capture-crow-surface-manifest \
    ValidationInputs/american-crow-hybrid-surface-v1/manifest.json \
  --capture-crow-surface-generation-audit \
    ValidationArtifacts/american-crow-hybrid-surface-generation-v1.json \
  --capture-crow-profile \
    ValidationInputs/american-crow-hybrid-visual-v1.json \
  --capture-crow-reality-asset \
    ValidationInputs/american-crow-hybrid-reality-v1.json \
  --capture-width 1600 \
  --capture-height 900 \
  --capture-frames 48
```

It verifies the reality asset, crow-surface manifest, generating profile, and
their SHA-256 locks before rendering. One retained Metal pass evaluates current
and previous part frames for all `54` persistent flight/tail feather roots; a
second expands a shared twelve-by-four-section vane template into `15,552`
renderable vertices. Current and previous positions plus stable feather IDs
stay GPU-side. The fixed-topology wing/tail surface supplies root positions and
a dark gap-closing underlayer, while the smooth body/head, topology-bound
coverts, and contour feathers remain procedural estimates. Four-sample Metal
rasterization and a dedicated
eumelanin shader provide view-dependent cool sheen while keeping the bird
neutral-black instead of allowing the warm key light to dominate its very low
albedo. The native result is an executable motion and material estimate, not a
photograph.
Before display tone mapping, the same pass emits a scene-linear HDR image and
typed albedo/material, normal/coverage, metric-depth, and deformation-motion
AOVs. A separate single-sample integer pass preserves exact surface and feather
identity. The executable conventions and qualification are in
[`CROW_TEMPORAL_AOVS.md`](CROW_TEMPORAL_AOVS.md). A capability-gated MetalFX
path reconstructs lower-resolution inputs only when explicitly requested; the
native-resolution renderer remains its executable parity oracle.
The beauty mesh and fluid boundary mesh are intentionally distinct: the former
adds feather detail, while the latter remains the fixed-topology coupling input.

The same executable renderer also has a distinct `standing` presentation. It
does not freeze or slow the flight surface. A dedicated Metal kernel folds the
same `54` persistent feathers against the body and retains current/previous
state, while an analytic leg chain supplies feathered upper legs, scaled
tarsometatarsi, three anterior digits, an opposing hallux, claws, and explicit
support contact. The qualitative source observations and exclusions are in
[`CROW_STANDING_ANATOMY.md`](CROW_STANDING_ANATOMY.md); no source-media bytes
are stored or displayed.

```bash
./Scripts/capture-crow-showcase.sh \
  /tmp/american-crow-standing.mp4 \
  /tmp/american-crow-standing.png \
  standing
```

## Apple-GPU simulation surface

The solver-facing crow is a separate fixed-topology asset generated from the
same profile:

- `49` frames over one estimated `4.6 Hz` presentation cycle;
- `2,157` vertices and `3,968` triangles in canonical body, left-wing,
  right-wing, and tail ranges;
- exact endpoint closure and bilaterally symmetrized wing vertices;
- `uint16` indexing below the live Metal `4,096`-triangle identifier limit;
- locked profile, dove-scaffold, position-stream, triangle-stream, and manifest
  SHA-256 values.

Regenerate it deterministically with:

```bash
./Scripts/build-american-crow-surface.py
```

Exercise the live Apple-GPU path with:

```bash
swift build -c release --product birdflow
.build/release/birdflow simulate american-crow \
  --archive ValidationArtifacts/american-crow-hybrid-metal-sim-readiness-v1.json
```

The committed Apple M4 run passed all-frame indexed preparation and
rasterization, exact CPU/GPU occupancy at five milestone frames, and the
production moving-boundary/TRT coupling gate. Its `8` fluid steps produced
`25` newly covered and `25` newly uncovered events, zero topology-counter
mismatch, wall Mach `0.0693`, and a relative RMS impulse-closure residual of
`4.28e-6`. This makes the asset executable simulation plumbing, not calibrated
crow aerodynamics: developed flow, grid convergence, force accuracy, mass
properties, trim, and free flight remain open.

The generation record is
[`american-crow-hybrid-surface-generation-v1.json`](../ValidationArtifacts/american-crow-hybrid-surface-generation-v1.json),
and the owning live-Metal result is
[`american-crow-hybrid-metal-sim-readiness-v1.json`](../ValidationArtifacts/american-crow-hybrid-metal-sim-readiness-v1.json).

## Sources

- Deetjen et al., *eLife* (2024), DOI `10.7554/eLife.89968` and Dryad DOI
  `10.5061/dryad.wwpzgmsqs`.
- Jackson and Dial, *Journal of Experimental Biology* 214:452-461, DOI
  `10.1242/jeb.046789`.
- Yorzinski and Clark, *Journal of Avian Biology* (2026), DOI
  `10.1002/jav.03604`.
- Cornell Lab of Ornithology / Macaulay Library American-crow flight and profile
  assets `59858031`, `93750891`, and `421209111`. They were used as viewing
  references and are not redistributed.
- The local rights-aware CT and data audit:
  [`corvid-public-source-screening.json`](../ValidationArtifacts/corvid-public-source-screening.json).

## Claim boundary

The crow can support visual design, renderer testing, and explicitly hybrid
sensitivity work. It cannot establish measured crow aerodynamics, force, power,
inertia, free flight, or same-specimen anatomy. Any future quantitative crow
solver input still needs bilateral flight surfaces, synchronized kinematics,
mass, center of mass, and inertia from a traceable specimen.
