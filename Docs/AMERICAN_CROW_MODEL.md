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

Grounded coverts are seated directly on the asymmetric trunk loft in five
overlapping courses per side. Rectrix bases remain inside the rump coverage and
the standing tail closes to a narrow caudal stack. These all-angle attachment
constraints were qualified from simulated front and near-rear cameras; no
reference image is rendered or stored.

The flight presentation draws the complete fixed-topology wing surface as a
dark gap-closing layer and closes the tail with asset-length rectrices. The
solver sequence's lower reversal sweeps the distal dove-derived surface forward
of the bill, and its nominal wing-root row collapses behind the estimated crow
pelvis. The beauty pass therefore samples one topology state, translates its
distal shape into the shoulder frame, and lofts the first fourteen span stations
onto a broad scapular-to-flank body curve. Flap rotation ramps in across the
first twelve stations instead of rotating a point hinge, so the proximal wing
remains seated on the torso throughout the stroke. This presentation retarget
does not alter the solver surface, prescribed simulation motion, or any
aerodynamic result, and the frame overlay names the distinction.

Three broad covert courses are sampled from each wing's fixed `9 x 33`
topology. Both ends of every blade follow current presentation-surface vertices,
the trailing course extends beyond the sheet, and adjacent blades overlap
chordwise and spanwise. This replaces the crossed persistent-vane comb that was
visible at the steep stroke reversal. The coverts remain estimated presentation
geometry and do not enter the moving-boundary, force, or power calculation.

The reverse face adds four inset marginal/median/greater/primary-covert courses
per wing (`216` stable bilateral roots). The two exposed dorsal trailing ranks
add another `124` stable roots over the continuous class-`4` bed, for `340`
live covert roots in flight and takeoff. The CPU uploads one `128`-byte record
per root with current and previous position, direction, normal, and morphology.
Metal then expands the shared `48 x 8` vane template plus rachis and paired-barb
ribbons into `913,920` vertices at full density. The dorsal identities map the
local template axis back onto the accepted `0...72%` and `34...100%` intervals,
including overlap taper and sub-millimetre rank separation. This replaces the
visible dorsal ranks' twice-per-frame CPU tessellation while retaining the
hidden continuity bed. A Metal prepass now quantizes final-output coverage into
triangle-major prefixes: vane only (`783,360` live-covert vertices), vane plus
rachis (`832,320`), or the full paired-barb stream (`913,920`). It writes both
indirect compute and draw arguments, so unresolved detail is neither deformed
nor rasterized while all `340` stable roots remain present. The same compact
contract remains ready for mesh shaders or ray-tracing geometry without
changing feather identity.
The full tier preserves the established root-major submission order exactly;
only reduced tiers switch to the triangle-major density prefixes.

Deployment now settles only the chord-`3` live covert course into the proximal
wing surface. Its camber and dorsal clearance blend from the unchanged folded
state to `48%` at the root and recover smoothly to `100%` by span station `12`.
The operation does not change vane width, chord, root/tip identity, vertex
inventory, or the caudal chord-`5`/`6` handoff; the closed wing surface remains
the coverage owner. This is presentation-only relief, not measured covert
compression or a solver-boundary change.

Those `340` root identities select bounded vane profiles in the shared
Swift/Metal geometry path. The three reverse secondary-covert courses, one
reverse primary-covert course, and two dorsal rank classes vary inner/outer
width asymmetry, longitudinal camber, crown, root width, and two-frequency
distal edge structure while bilateral counterparts mirror the exposed edge.
The reverse courses retain analytic derivatives; the interval-mapped dorsal
ranks use the same bounded finite-difference tangent construction on Swift and
Metal, with measured CPU/GPU position parity below `3e-6 m`. The amplitudes are
estimated presentation morphology: [Ng et al. (2014)](https://pmc.ncbi.nlm.nih.gov/articles/PMC4202321/)
and [Eliason et al. (2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12285719/)
support a layered feather with a structured exposed pennaceous region, but do
not supply these exact American-crow covert measurements.

Persistent flight-feather roots remain attached to their exact fixed-topology
solver vertices and continue to evaluate current and previous phases on Metal.
Their long vane shells are retained for standing and diagnostic deformation,
but the wingbeat beauty pass uses the topology-bound courses above because the
asset rest directions cross under the source's large stroke. This does not
assert measured crow kinematics.

Sparse diagnostic captures can set `--capture-crow-camera-yaw` and
`--capture-crow-camera-pitch` in radians so a geometry milestone is checked
from side, front, rear, overhead, and underside views without changing the
release camera or multiplying appearance-only review frames.

During takeoff, body-owned axillary follicles retain their exact roots and
estimated lengths while their vane direction and normal rotate toward targets
sampled from the live inner-wing topology. Dorsal rows carry more of this
bounded handoff than ventral rows. The folded body-seated shell simultaneously
collapses in area while retaining its vertex inventory, avoiding a temporal
topology change when the articulated wing becomes visible. This is an
estimated presentation coupling. [Hieronymus (2016)](https://pmc.ncbi.nlm.nih.gov/articles/PMC5055087/)
supports the general role of covert linkages and smooth muscle in a morphing
avian wing, but its rock-pigeon anatomy does not provide American-crow
attachment coordinates or the encoded blend weights.

Procedural contour and folded-wing feathers select quantized tessellation from
their projected length at the final output resolution. The four asset LOD
thresholds drive silhouette, curved vane shell, rachis, paired-barb, and
close-up barbule budgets. Body contour mesostructure is derived from the same
root, tip, plane, width, and camber envelope as its visible vane; it is not a
detached decoration. Current and previous temporal geometry share one tier for
stable motion vectors. The crow material derives a local feather axis from
live vane coordinates where present and uses a surface-projected fallback on
the body for a restrained anisotropic black-feather highlight.

Posterior class-`5` plumage now carries a topology-stable deployment relief.
Beyond `30%` of the dorsal contour tract, crown settles smoothly to `58%` at
the posterior course; beyond `25%` of the mantle tract, camber settles to
`62%`. Standing remains exact, and roots, tips, widths, identities, vane count,
and the closed loft do not change. At `48 px` projected length, posterior
dorsal contour vanes beyond `45%` axial extent promote `20` coarse edge
segments into contained interior barb pairs while retaining five terminal
bundles and the same detail-record count. Derived rachis and barb geometry uses
the same scaled camber as its vane. These are presentation estimates, not
measured crow feather compression or aerodynamic response.

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
and previous part frames for all `54` persistent flight/tail feather roots.
Standing expands those roots through the shared `48 x 8` vane template, rachis,
and barb ribbons into `145,152` renderable vertices. Wingbeat keeps the retained
asset root-state path diagnostic-only while Metal expands the separate live
wing-covert inventory, including the two exposed dorsal trailing ranks; the
remaining coherent topology-bound wing courses and asset-length tail rectrices
remain presentation geometry. The fixed-topology
wing surface supplies a dark gap-closing layer, while the smooth body/head,
coverts, and contour feathers
remain procedural estimates. Four-sample Metal rasterization and a dedicated
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
