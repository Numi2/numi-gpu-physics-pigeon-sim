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

The lower-flank field now retains more of that width through the sternum before
tapering toward the pelvis, while the upper shoulder coefficient rises only
from `0.10` to `0.12`. Jackson and Dial report pectoralis mass averaging
`14.7%` of body mass across their four corvid species, supporting a substantial
ventral flight-muscle envelope but not determining its external cross-section.
Accordingly, the bounded `0.075` pectoral relief coefficient remains an
estimated visual constraint; ring stations, vertical radii, and skeletal joint
coordinates stay unchanged.

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

That grounded secondary course now ends in a posterior-only sixth-power tuck.
Its anterior tip offset remains `27 mm`, while the terminal tip converges to
`11 mm` and its standing width to `82%` before meeting the rectrix stack. An
exact identity-AOV trace showed that one terminal class-`2` vane, rather than a
body-surface gap, owned the broad lower-tail lobe visible from the reverse
quarter. Accepted `800 x 450` reverse-quarter and opposite-rear gates retain
closed body/wing-root silhouettes with worst enclosed components of `5` and
`3` pixels respectively. The live flight wing, retained feather lengths,
follicles, and stable identities remain unchanged. These values are bounded
simulated presentation morphology, not measured American-crow folded-secondary
dimensions.

Grounded coverts are seated directly on the asymmetric trunk loft in five
overlapping courses per side. Rectrix bases remain inside the rump coverage and
the standing tail closes to a narrow caudal stack. These all-angle attachment
constraints were qualified from simulated front and near-rear cameras; no
reference image is rendered or stored.

The separate folded live-wing topology now retains its full `9 x 33` inventory
while narrowing laterally from `52%` through `94%` span. Its distal chord
stations converge to a `10-14 mm` envelope beside the retained primary and
rectrix stack instead of carrying the proximal `40-50 mm` envelope to a pair of
isolated tips. Every surface-bound covert follows the same positions and stable
submission order. The taper is an all-angle presentation correction, not a
measured American-crow folded-wing profile or a solver-surface change.

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

The full tier now also activates the retained aggregate-barb ribbons for all
`12` persistent rectrices: `20` bilateral barb pairs per feather, or `2,880`
triangle vertices, without allocating a second stream or changing stable
identity. Lower coverage collapses them to the root. Rectrix rachis ribbons
remain suppressed because a tested depth-owned shaft pass produced long
parallel wires across the closed tail; the accepted pass depth-orders only the
short contained barbs over their owning vane. At a previously unused elevated
rear-quarter camera `(yaw 2.64, pitch 0.42, distance 0.48 m)`, the matched
`1200 x 675` A/B keeps `216,275` active pixels, `3/3/1` enclosed
pixels/components/largest component, zero expected lower-body aperture, and
zero rectrix-to-rectrix exterior slots. Class-`3` maximum scene-linear
luminance remains `0.105038`, while mean same-class neighbour difference rises
from `0.001235` to `0.001502`. The count and placement are estimated rendering
mesostructure, not measured American-crow barb anatomy.

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

All `12` retained rectrix identities also remain authoritative through takeoff.
Metal blends each root, direction, and normal from the closed standing stack to
the existing open-flight target over transition progress `0.08...0.62`, while
the closed tail's identity-specific length graduation returns continuously to
the open-flight asset lengths; width, rachis, camber, morphology, and
current/previous state remain continuous. The open target's dorsal vane normal
is reconstructed at `55%` chord from the analytic spanwise derivative of the
continuous tail fan and its longitudinal feather tangent. This replaces the
prior nearly lateral constant with identity-specific normals whose
current `z` components span `0.950...0.992`, so future denser vane templates
inherit the same curved semantic surface instead of a view-facing sheet.
Primaries and secondaries still collapse on their complementary handoff
schedule, and the separate procedural tail is emitted only in the wingbeat
presentation. Independent Swift parity checks cover the retained GPU state at
four phases. This is a continuity and coverage result, not measured rectrix
deployment kinematics.

The folded remex stack now transfers to the live wing from the exposed distal
identities inward. Primary endpoints begin at `0.20` and advance by `0.08` per
identity; secondary endpoints begin at `0.30` and advance by `0.06`. Both
courses cap at the original `0.62` proximal endpoint. This removes redundant
crossing vanes as the same feather courses become represented by the opening
topology-bound wing. It does not blunt primary tips, change standing geometry,
or alter rectrix deployment. The dorsal folded-wing quad collapses over
presentation phase `0.20...0.30`, while the narrow terminal axillary bridge
overlaps live underwing deployment until progress `0.30`; this prevents either
bridge from becoming a free-flight slab or exposing the root aperture. Crow AOV
schema `21` carries exact visible and
fully covered pixels plus image bounds per persistent feather, wing-surface
cell, and topology-bound dorsal-covert identity. Ownership can therefore be
traced to class/side/order or side/chord/span without inferring it from a beauty
image. It also records each class-luminance maximum's pixel and requires the
scaffold material code before decoding a wing cell, so pedal class `11` cannot
alias the first left-wing cell.

The retained rectrix surface preserves a nonzero width envelope over its
terminal `16%` of length. Medial and outermost pairs remain at `13-16%`; a
smooth radial mask raises only the three sublateral bilateral pairs to
`19.0-20.1%` at the exact wing-tip handoff exposed by the packed-identity AOV.
Lateral vane vertices still retreat quadratically by at most `1.0-1.4%` of
length while the rachis centerline retains the exact asset tip. This retains
discrete, rounded simulated rectrix ends without changing stable IDs, root
poses, or storage topology. Full-chord finite-difference normals run in both
Swift and Metal and retain the existing `< 1e-5` CPU/GPU normal-parity gate.

The quiet stack preserves its `4 mm` root-layer depth while converging to a
`2 mm` terminal depth instead of `6 mm`. Adult American-crow rectrices are
reported as smooth and squared or truncated by
[Ludwig et al. (2010)](https://doi.org/10.22621/cfn.v123i2.691); the
[U.S. Fish and Wildlife Service Feather Atlas](https://www.fws.gov/lab/featheratlas/id-position.html)
also distinguishes rectrices from finger-tipped primaries. The exact `2 mm`
value is an estimated standing-presentation constraint, not a measurement.
At the matched `1200 x 675` reverse-quarter gate it reduces enclosed
pixels/components/worst component from `47/30/5` to `4/2/3` and exact
rectrix-to-rectrix exterior slots from `7` runs totaling `10` pixels to one
`1`-pixel run. A fresh elevated rear-starboard view retains separate vane
layers with zero rectrix slots. Flight targets, widths, lengths, and identities
are unchanged, and no reference pixels are stored or rendered.

The closed rectrix stack now graduates from `0.166 m` medially to `0.160 m`
laterally and returns continuously to the retained open-flight lengths during
deployment. This replaces the camera-dependent straight terminal bar with a
shallow rounded tail edge while preserving all `12` identities. The last four
dorsal trailing coverts also converge to pointed tips and shorten in discrete
roof-tile steps toward the wingtip; the fixed wing surface remains their
coverage owner.

Procedural contour and folded-wing feathers select quantized tessellation from
their projected length at the final output resolution. The four asset LOD
thresholds drive silhouette, curved vane shell, rachis, paired-barb, and
close-up barbule budgets. Body contour mesostructure is derived from the same
root, tip, plane, width, and camber envelope as its visible vane; it is not a
detached decoration. Current and previous temporal geometry share one tier for
stable motion vectors. The crow material derives a local feather axis from
live vane coordinates where present and uses a surface-projected fallback on
the body for a restrained anisotropic black-feather highlight.

The retained class-`7` curve path now has a second `800 px` output-space
handoff. Each parent barb owns two crossed six-segment barbule branches with
stable primitive identity, an endpoint bound of `0.93` vane half-width, and an
estimated `12 -> 4 um` taper. A branch-order term supplies bounded local
occlusion without altering opacity. The work scan supports mixed barb-only and
barbule records, and production keeps zero materialized output capacity. These
are renderer estimates and an ownership/scaling contract, not measured
American-crow barbule anatomy or physical self-shadowing.

The rump-to-rectrix shell uses seven overlapping axial rows rather than five,
raising its deterministic inventory from `120` to `168` contour vanes while
retaining `24` circumferential courses, the same underlayer, and the same
projected-length LOD policy. Root/tip axis fractions are `0.05...0.62` and
`0.35...0.92`, respectively, so the added rows densify the existing body
surface instead of spanning the intentional open space between wing and tail.
At future close-up tiers the new vanes inherit the same rachis, paired-barb,
and barbule hierarchy as the prior shell.

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

The outer class-`6` scapular course now receives a separate transverse
deployment relief. Beyond `40%` of the seven-row course, the visible vane crown
settles smoothly from the standing `0.12` width ratio to `0.08` at the outer
row. Retained detail uses `96%` of that transverse ratio plus the existing
`0.12 mm` raster separation, keeping its tubes on the visible crown without
coplanar flicker. Promoted interior barbs terminate at `97%` of their local
owning-vane half-width; the five terminal aggregates alone retain a bounded
tip extension below `1.2 mm`. The generated tubes and ribbons now propagate
their parent class-`6` surface code rather than reporting class `0`. Standing
vane geometry, follicle and centerline-tip positions, widths, stable identities,
inventory, and mesostructure record counts remain exact. This relief is an
estimated presentation constraint, not measured scapular contact mechanics.

The class-`7` pectoral and abdominal tracts now resolve shaft depth explicitly.
All `1,304` ventral vanes preserve their established subvane continuity rachis;
the `776` interior records, excluding two boundary rows and two terminal axial
courses on every side, add a second four-segment rachis at the visible `0.07`
transverse crown. An identity-stable `0.78...1.22` crown multiplier is shared
by the visible vane and retained crown shaft, preventing coherent breast-row
highlights without moving roots or tips. Edge-barb aggregates, vane geometry,
roots, tips, identities, LOD thresholds, and boundary silhouettes remain
unchanged. Each visible crown shaft is retained as a `112`-byte analytic record
carrying its lateral
centerline sweep; a `16`-byte-per-interval LOD
list selects four, eight, or twelve shaft intervals, and Metal expands their
four-sided tubes directly into temporal/AOV vertices. The current showcase tier
therefore emits `3,104` intervals and `74,496` vertices without CPU triangle
construction. The paired continuity/crown hierarchy remains an estimated
rendering model, not evidence of measured American-crow rachis depth.

The ventral tips now leave their formerly bilateral terminal stations while
all `1,304` follicle roots remain exact. A deterministic low-discrepancy phase
combines row, column, region, side, and stable identity; the resulting surface
attachment offsets stay within `+/-1.9 mm` axially and `+/-0.014 rad`
circumferentially, below half a pectoral row interval. The pre-offset tip length
is retained in `lateralSweepAndReserved.y`, preserving the established
projected-size topology owner without growing the `112`-byte curve record.
CPU and Metal therefore keep the exact `746` future-close barb owners and
`429,696` interval work items at the established diagnostic while endpoint
parity stays below `5e-7 m` and sampled normal-vector distance below `1e-4`.
At the new oblique-underside standing gate `(-0.52, -0.24)`, `0.46 m`, and
`1200 x 675`, five-frame enclosed-hole pixels/components/largest components
remain exactly `20,18,24,29,20` / `4,6,10,10,4` / `14,11,13,16,14`; expected
apertures remain `0,0,2,0,0`. Fully covered AOV pixels change by `+1,0,+2,+8,+1`.
Minimum beauty SSIM is `0.996480`, with no more than `20,548 / 810,000` changed
pixels. The inspected frame has continuous lower-breast and leg insertion
coverage; the upper cervical collar remains a separate unresolved body target.
These offsets are renderer estimates, not measured American-crow pteryla
coordinates or perceptual-realism evidence.

The following cervical-terminal pass keeps the same `896` follicles and the
compact `128`-byte immutable body-vane morphology. The uploaded tip remains the
reference chord consumed by CPU and Metal projected-length classification;
only the dynamic state applies a deterministic row/column/side displacement.
Offsets remain below `2.3 mm`, and a `1.2 mm` tapered extension over shoulder
columns `0...2` overlaps the mantle root field without moving either root
field. The full owner count (`3,212`) and per-frame vane work (`685,530` raster
vertex invocations at this gate) remain exact.

At a fresh lateral-front standing view `(0.38, -0.05)`, `0.50 m`, and
`1200 x 675`, baseline and candidate five-frame enclosed-hole pixels,
components, largest components, and expected apertures are exact at
`4,5,4,3,4`, `3,5,4,3,3`, `2,1,1,1,2`, and all zero. Fully covered AOV pixels
move by `+7,+1,-2,-3,+7`; minimum full-frame SSIM is `0.999853` with no more
than `1,960 / 810,000` changed pixels. The inspected frame shows de-locked
cervical terminals and no new shoulder aperture, but the collar remains
readable. This rejects additional terminal amplitude as a complete solution;
the next pass must localize the material or neighboring-tract handoff instead.
This is executable simulated morphology, not an anatomical measurement.

Schema `23` next measured every ordered cross-class adjacency in scene-linear
luminance. Across that same lateral-front sequence, the collar arc is the
class-`7` body/throat bridge against class-`10` gular vanes; class `8/10` is a
separate, higher cranial boundary and class `6/7` spans the flank. Uniformly
brightening class `10` increased the target mean jump by roughly `9...18%`.
Uniformly reducing its sheen could lower the mean by as much as `31.5%`, but
increased the maximum jump by `29%`, so those global material experiments were
rejected.

The retained pass encodes a `0...1` posterior-gular weight in the otherwise
body-range `0.14...0.15` material tag and reconstructs it only for class `10`.
The optical weight is then multiplied by a distal-vane smoothstep over axial
coordinates `0.35...0.88`; geometry, semantic class, projected-size LOD, and
all non-optical AOV fields remain unchanged. Mean class-`7/10` boundary
contrast over five frames falls from `0.0060948643` to `0.0052184042`
(`14.3803%`), and its signed class-`7` minus class-`10` difference moves from
`-0.0033948848` to `-0.0023696415`. The maximum changes from `0.03567496` to
`0.03602520`. Class-`8/10` mean contrast changes by `+1.3609%`; class-`6/10`
falls `7.6966%`. Minimum full-frame SSIM is `0.999981`.

At the previously unused rear-high yaw/pitch `(2.45, 0.30)`, distance `0.55 m`,
the five beauty frames are pixel-exact and every AOV field except duration is
exact. The inspected simulated frame retains the existing back, folded-wing,
tail, leg, and substrate silhouette. It also keeps visible future targets,
notably smoother wing-layer transitions and under-tail/body continuity. The
pass therefore qualifies a local optical handoff and rejects broad material
tuning; it does not establish perceptual equivalence or a measured crow BSDF.

At showcase material quality, body-feather anisotropy now resolves two bounded
optical barb banks around a stable feather-local axis. The lobe pair follows
the same identity and axial phase as its vane while body-class transverse
roughness remains broader than the flight-feather response. Feather-local bank
turn now spans at most `0.14 rad`, bank separation varies from `0.075` to
`0.170 rad`, and longitudinal/transverse microfacet widths vary by at most
`10%` and `12%`. A bounded identity-normal tilt below `0.06 rad` prevents
adjacent body vanes from sharing one manufactured specular band. All phases
remain attached to the local vane coordinates rather than world or screen
space. This is a future-compute optical approximation: it adds no geometry,
does not alter the AOV topology owner, and is not measured American-crow
barbule microstructure.

Body-tract vane crowns now retain at least five transverse strips when a
feather spans `24` final-output pixels. The former three-strip tier represented
the parabolic crown with one broad central plane; repeated cervical and mantle
planes formed coherent ribs at an oblique view. Far silhouettes remain one
strip, the `120 px` close tier remains five, and the `480 px` offline tier
remains seven. Roots, tips, widths, feather identities, LOD thresholds, and
mesostructure are unchanged. At yaw/pitch `(-1.74,0.38)`, distance `0.52 m`,
and `1200 x 675`, active coverage remains `164,876` pixels, all `8` enclosed
components remain single pixels, and the expected lower-body aperture remains
zero; fully covered pixels change `163,811 -> 163,814`. Class-`5` and class-`6`
peak luminance are exact, while their local same-class neighbour variation
changes `0.002910 -> 0.003034` and `0.001899 -> 0.001999`. The implementation
is an estimated rendering discretization. General pennaceous feather hierarchy
is supported by [Ng et al. (2014)](https://pmc.ncbi.nlm.nih.gov/articles/PMC4202321/)
and [Widelitz et al. (2019)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6953487/),
but neither source supplies these American-crow crown sections or thresholds.

The body-tract rachis representation now uses vane width, rather than feather
length, as its resolution owner. The analytic lobe is zero below `12` projected
pixels across the full vane and reaches full strength at `24`; the retained
tubular shaft is emitted only from `24 px` onward. Thus whole-bird and grazing
views retain vane edges, barb aggregates, and optical banks without drawing a
sub-resolution longitudinal wire, while close and future offline views restore
both shaft layers. At the new high rear-port yaw/pitch `(-1.08,0.58)`, distance
`0.48 m`, and `1200 x 675`, active coverage changes `193,941 -> 193,927`, fully
covered pixels `192,879 -> 192,856`, enclosed one-pixel holes improve `7 -> 6`,
and expected aperture remains zero. Class-`5`/`6` maxima are exact; local
same-class neighbour variation changes `0.002467 -> 0.002264` and
`0.001729 -> 0.001163`. A GPU probe locks the `0/0.5/1` response at
`12/18/24 px`. These thresholds and the perceptual interpretation remain
estimated rendering choices, not measured American-crow acuity or rachis size.

The aggregate body-barb tier now varies station placement per persistent
feather instead of instancing the same ten axial fractions everywhere. A stable
identity phase offsets each bilateral station by at most `0.18` of the base
spacing; because adjacent stations can close by at most `0.36` spacing, their
ordering cannot invert. Counts remain `20` bilateral edge segments plus five
terminal bundles for coarse cervical/mantle vanes, or `20` contained barbs plus
five terminal bundles for promoted humeral/scapular vanes. A 48-feather replay
test proves deterministic equality, paired-side axial agreement, bounded
offsets, strict ordering, and more than `100` distinct quantized offsets. At
yaw/pitch `(-0.34,0.46)`, distance `0.36 m`, and `1200 x 675`, active pixels
remain `307,367`, fully covered pixels change `305,712 -> 305,713`, the worst
hole remains `6` pixels, and expected aperture remains `3` pixels. Enclosed
holes change `27/18 -> 29/19` pixels/components; the matched image SSIM is
`0.998958`, localizing the variation to feather-edge structure. The station
phase and amplitude are estimated rendering morphology, not measured barb
coordinates.

The five terminal aggregate-barb bundles on each body-tract vane now start from
a deterministic identity-derived axial fan spanning at most `0.858...0.902` of
feather length. Their count, radii, and exact pre-existing tip endpoints remain
unchanged; contour, ventral, tail, and leg feather paths retain the former
shared `0.88` root. A 48-feather replay test checks byte-equivalent generation,
more than `100` distinct quantized offsets, exact root-envelope containment,
and unchanged non-body roots. At the new rear-dorsal yaw/pitch `(2.18,0.72)`,
distance `0.38 m`, and `1200 x 675`, active coverage changes
`314,829 -> 314,828`, fully covered active pixels `313,826 -> 313,822`, and
small enclosed holes change `26/20 -> 27/21` pixels/components while the worst
hole remains `3` pixels and expected lower-body aperture remains zero. Matched
full-frame SSIM is `0.999930`. This is bounded estimated rendering morphology
qualified from one simulated view, not measured barb coordinates or all-angle
perceptual realism.

Body-tract vane tips no longer all use the same `0.015` terminal-width ratio and
`3.2` distal taper exponent. Stable independent identities now select terminal
width ranges of `0.008...0.016`, `0.010...0.020`, `0.012...0.022`, and
`0.012...0.024` for cervical, mantle, humeral, and scapular tracts, respectively;
their corresponding curvature ranges are `3.00...3.45`, `2.95...3.55`,
`3.05...3.60`, and `3.00...3.65`. The visible blade and its retained
mesostructure consume the same pair. Inventory, roots, tips, maximum widths,
surface classes, and LOD selection remain unchanged. Replay and distribution
tests reach both bounds in every region, retain more than `100` quantized values
per region, and give over `90%` of mirrored coordinates independently shaped
tips. At the new low rear-quarter yaw/pitch `(2.30,-0.48)`, distance `0.42 m`,
and `1200 x 675`, active coverage changes `266,721 -> 266,724`, fully covered
active pixels `264,979 -> 264,987`, enclosed pixels improve `33 -> 32`, and the
largest hole improves `4 -> 2` pixels. Components change `25 -> 26`, expected
lower-body aperture remains zero, and full-frame SSIM is `0.999815`. The
amplified A/B difference is localized to distal dorsal/body feather edges.
These bounds are estimated morphology, not measured American-crow tip profiles.
The stable scalars now live in the retained Metal morphology inventory; Metal
reconstructs current and previous vane pose from the compact per-frame body,
deployment, and cervical-transform inputs without changing identity or
topology.

The estimated femoral field keeps its `15 x 18` body-surface-rooted inventory
(`270` vanes per side) and all root and joint coordinates. A temporal-identity
trace of the high-side transition opening localized the owning geometry to
far-side rows `6...11`, courses `8...9`. Only that compact window receives a
smooth-edged overlap envelope: width reaches at most `1.36x`, tip length at most
`1.06x`, and both taper to exactly `1x` outside the window. The bounded change
closes the nine-pixel body/femoral opening without adding a row or covering the
intentional negative space between articulated digits. It is a presentation
continuity estimate, not measured American-crow femoral dimensions or contact
mechanics.

At the five-by-seven distance LOD, a rear-right temporal-identity trace at
yaw/pitch `(2.28, 0.38)` resolves the residual pelvic insertion owners to
anterior course `6`: rows `1...2` receive a `1.52x` width and `1.06x` length
ceiling, while rows `0` and `3` taper those values halfway back to unity. All
other coarse rows and courses remain exact. The existing hip-to-hock tube now
also carries femoral surface class `7`, making its AOV ownership truthful.
Across five standing-through-flight frames, enclosed pixels/components improve
from `46/28` to `38/27`; the targeted `5`- and `3`-pixel openings become `2`
and `0` pixels. The `654`-pixel planted inter-leg aperture is exact, later
expected-aperture counts remain zero, and the unrelated `10`-pixel flight
wing/pedal component is unchanged. Minimum full-frame beauty SSIM is
`0.999519`. This is a topology-stable presentation estimate, not measured
American-crow thigh plumage.

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
  --capture-crow-plumage-optics \
    ValidationInputs/american-crow-plumage-optics-estimated-v1.json \
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
and barb ribbons into `145,152` renderable vertices. Takeoff keeps the retained
rectrix subset live and unfolds it continuously while its retained remiges hand
off to the articulated wing. Wingbeat keeps the retained asset root-state path
diagnostic-only while Metal expands the separate live wing-covert inventory,
including the two exposed dorsal trailing ranks; the remaining coherent
topology-bound wing courses and asset-length procedural wingbeat rectrices
remain presentation geometry. The fixed-topology
wing surface supplies a dark gap-closing layer, while the smooth body/head,
coverts, and contour feathers remain procedural estimates. Four-sample Metal
rasterization and a dedicated black-plumage shader keep the bird neutral-black
instead of allowing the warm key light to dominate its very low albedo. The
shader samples `400`, `440`, `480`, `520`, `560`, `600`, `640`, and `680 nm`,
then projects a keratin-film/eumelanin-volume response to linear sRGB with
equal-energy-normalized CIE 1931 weights. The versioned
`american-crow-plumage-optics-estimated-v1.json` profile keeps published
comparative-corvid constraints separate from renderer estimates. Its live
air/keratin/melanin solver uses complex Snell refraction, separate s/p Fresnel
amplitudes, and an Airy internal-reflection sum at the key-light half-vector.
The published complex indices and `110...180 nm` glossy-cortex interval remain
inputs; the `160 +/- 18 nm` local thickness field, `0.08` coherence blend, and
volume parameters remain bounded simulation choices. An on-GPU probe locks
normal, oblique, and grazing cases to independent FP64 evaluations of the
angular equations. This replaces a direct blue/violet RGB blend, but it is not
a measured American-crow spectrum, measured angular BSDF, calibrated
illumination path, or ultraviolet model. The native result is an executable
motion and material estimate, not a photograph.
Before display tone mapping, the same pass emits a scene-linear HDR image and
typed albedo/material, normal/coverage, metric-depth, and deformation-motion
AOVs. A separate single-sample integer pass preserves exact surface and feather
identity. The executable conventions and qualification are in
[`CROW_TEMPORAL_AOVS.md`](CROW_TEMPORAL_AOVS.md). A capability-gated MetalFX
path reconstructs lower-resolution inputs only when explicitly requested; the
native-resolution renderer remains its executable parity oracle.
The beauty mesh and fluid boundary mesh are intentionally distinct: the former
adds feather detail, while the latter remains the fixed-topology coupling input.

The body-tract vane surface is evaluated from retained morphology in the live
Metal raster vertex stage. At full inventory, `3,212` cervical, mantle,
humeral, and scapular vanes each contribute one immutable `128`-byte record
containing local roots, tips, normals, base camber, transverse crown inputs,
asymmetric width, ripple, terminal taper, color, and stable identity. A compact
pose stream reconstructs current and previous body translation, neck transport,
deployment camber, and transverse settling. Projected-size topology remains
quantized exactly as before, but the CPU no longer appends those vane triangles
or their vane-contained tubular rachis, aggregate barbs, terminal bundles, or
future-close barbules to `CrowSurfaceTemporalVertexGPU`, nor does it author
production temporal records. Failure to create the required Metal pipelines
restores the former complete CPU body-feather path. A
compute-only audit invokes the same Metal pose/point/normal helpers used by
raster; sampled positions including nonzero neck pose agree with the
independent Swift temporal oracle within `2 um`, and terminal normals agree
within `0.06 degrees` with fast math enabled. The earlier temporal-record
renderer's front-dorsal `800 x 450` gate at yaw/pitch `(0.52, 0.64)` and
`0.44 m` retained `92,467` active pixels, `91,727` fully covered AOV pixels,
`14`
enclosed pixels in `7` components, an `8`-pixel largest component, and `17`
expected lower-body aperture pixels in `3` components. Beauty SSIM is
`0.999997`; exact per-feather body identity raises the visible-identity census
from the legacy surface aggregate rather than changing coverage. This is an
executable ownership/parity result, not a performance measurement or an
American-crow anatomical measurement.

Body-vane morphology is retained once rather than triple-buffered per pose. The
`3,212` immutable `128`-byte records occupy `411,136` bytes; three in-flight
pose slots retain `4,128` bytes total and each receives only `1,376` bytes of
current/previous body, deployment, and cervical affine transforms. Metal
reproduces the established whole/half/quarter density predicate, classifies
each active morphology into one of seven topology bins, scans stable offsets,
emits compact inventory indices, and prepares vane, rachis, and body-detail
`DrawPrimitivesIndirectArguments`. CPU temporal-record construction and
grouping run only for explicit audit readback. Schema `21` reports morphology,
pose, selected work, retained capacity, indirect bytes, allocations, raster
invocations, and generation mode separately. At the left-flank yaw/pitch
`(-1.12, 0.26)`, `0.50 m` diagnostic, Metal selects the CPU-oracle-exact
`1,606` records in two active bins and requests `285,984` vane raster vertices;
the retained indirect arguments occupy `1,008` bytes. GPU identities and indirect
counts are exact against the CPU oracle at `800`, `1,000`, `1,600`, and
`20,000 px/m`. A nonzero-neck/deployment compute audit agrees with CPU temporal
geometry within `2 um`. A new five-frame release diagnostic at rear-right
yaw/pitch `(2.28, 0.38)` and `0.62 m` spans the grounded pose, deployment, and
flight. Beauty SSIM against the previous temporal-record renderer is at least
`0.999997`, and the middle frame is byte-identical. Enclosed-hole totals are
`9, 11, 4, 3, 19` pixels with largest components `5, 3, 1, 1, 10`; the final
component is bounded by wing class `4` and pedal class `11`, not body-vane
ownership. Visual inspection shows continuous neck, shoulder, flank, and tail
coverage. Audit-expanded buffers are excluded, and no timing improvement is
claimed.

The rachis tier uses `0`, `4`, `8`, or `12` axial tube sections according to
the selected vane topology. Current and previous positions, flat tube normals,
material, parameters, and stable identity match the independent Swift oracle;
sampled Metal positions agree within `2 um`. A five-frame low-side release gate
at yaw/pitch `(1.55, -0.30)` and `0.60 m` preserves the predecessor's exact
enclosed-hole counts (`9, 2, 0, 4, 1`), largest components (`3, 1, 0, 1, 1`),
active identities, and fully covered AOV pixels. Minimum beauty SSIM is
`0.999853`, with no more than `394 / 360,000` changed pixels in a frame. The
tube carries its parent vane identity and stays on the vane centerline, so the
integer pass retains the underlying vane identity instead of issuing a second
indirect tube draw. This is ownership and parity evidence, not a speed or
measured-anatomy claim.

The remaining body mesostructure is now Metal-owned as compact temporal
segments. Each `96`-byte record retains current and previous endpoints, taper,
surface normal, and detail kind, then the vertex stage expands it into either a
six-vertex ribbon or a three-sided tube within the established fixed
`18`-vertex segment stride. The seven vane topologies retain
`0/0/43/43/41/41/167` segments
(`0/0/774/774/738/738/3,006` raster vertices) per selected feather. The added
`18` segments form three bilateral basal barbs, each reconstructed as a
continuous three-section curve beneath the unchanged outer shell. Initial
three-slot capacity is `39,777,408` bytes; a future `480 px` feather grows it
to `154,484,352` bytes without materializing
the expanded triangle stream. The independent Swift oracle reproduces the
former CPU edge groups, promoted shoulder barbs, five terminal bundles, and
barbules at `3,000`, `10,000`, and `30,000 px/m`, then independently verifies
that all basal chains remain proximal, taper monotonically, and join exactly.
A direct Metal future-close
`16 x 7` probe agrees with current/previous positions within `2 um` and normals
within `1e-3` vector distance. The integer pass deliberately retains the
underlying vane identity instead of drawing every subpixel fiber again.

A five-frame release diagnostic at the previously unused high-front yaw/pitch
`(-0.72, 0.52)` and `0.48 m` preserves the predecessor's exact enclosed-hole
pixels (`5, 10, 1, 0, 1`), components (`3, 5, 1, 0, 1`), largest components
(`3, 6, 1, 0, 1`), and expected lower-body apertures (`4, 5, 2, 5, 2`). Beauty
SSIM is at least `0.999796`; no frame changes more than `1,320 / 360,000`
pixels. The inspected held frame retains continuous simulated neck, shoulder,
and flank overlap. This qualifies ownership and bounded visual continuity, not
performance, measured anatomy, or perceptual equivalence to a real crow.

Unlike the earlier rejected proximal-vane split, this underlayer does not move,
shorten, or cut the accepted pennaceous coverage shell. A new five-frame
near-front standing gate at yaw/pitch `(0.12, 0.16)` and `0.55 m` preserves
exact enclosed-hole pixels (`1, 0, 1, 2, 1`), components (`1, 0, 1, 1, 1`),
largest components (`1, 0, 1, 2, 1`), and zero expected lower-body aperture.
Minimum beauty SSIM is `0.999999`; at most `11 / 360,000` pixel values change.
The six-chain density, `4-50%` half-width reach, and `37-317 permille` axial
envelope are bounded renderer estimates. General contour-feather separation
into a fluffy proximal plumulaceous region and structured distal pennaceous
vane is supported by [Ng et al. (2014)](https://pmc.ncbi.nlm.nih.gov/articles/PMC4202321/)
and [Widelitz et al. (2019)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6953487/),
but neither source measures these American-crow counts or dimensions.

The same executable renderer also has a distinct `standing` presentation. It
does not freeze or slow the flight surface. A dedicated Metal kernel folds the
same `54` persistent feathers against the body and retains current/previous
state, while an analytic leg chain supplies feathered upper legs, scaled
tarsometatarsi, three anterior digits, an opposing hallux, claws, and explicit
support contact. The qualitative source observations and exclusions are in
[`CROW_STANDING_ANATOMY.md`](CROW_STANDING_ANATOMY.md); no source-media bytes
are stored or displayed.

The two exposed trailing-covert ranks are retained anatomical Metal records,
not a deployment effect. They remain visible from the folded hold through
takeoff and flight, preserving stable class-`14`/class-`15` identities above
the hidden class-`4` continuity bed. The transition's still frame therefore
uses the same feather hierarchy as open flight without changing roots, rank
intervals, vane widths, or expanded topology.

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
