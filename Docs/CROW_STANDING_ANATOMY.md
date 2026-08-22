# Crow standing anatomy contract

BirdFlowMetal's grounded crow is an explicitly estimated simulation pose. It
uses the supplied public video only as a private qualitative reference; the
repository stores the URL and written observations, not a frame, thumbnail, or
video byte. The machine-readable boundary is
[`american-crow-standing-reference-v1.json`](../ValidationInputs/american-crow-standing-reference-v1.json).

## What the reference contributes

The front-biased view supports only coarse visible constraints:

- two separated feet remain on the support while the bird moves slightly;
- the exposed tarsometatarsi are nearly vertical beneath feathered upper legs;
- three anterior digits spread over the support and a rear hallux opposes them;
- the projected body stays between the feet during quiet weight shifts;
- head, torso, and ankle motion is low amplitude and does not become a step.

These observations do not establish joint centers, center of mass, tendon
forces, exact motion frequencies, specimen scale, or even a taxonomically
verified American-crow individual. The simulation's `57 mm` tarsus remains the
selected value from the existing American-crow morphometric range, not a video
measurement.

## Executable representation

`CrowStandingPose` owns a loop-closed body/head/leg state. Both distal contact
sets stay fixed on the support while the body moves by less than `3 mm` and each
ankle by less than `1.5 mm`. Each foot has digit I behind the ankle and digits
II-IV in front. The renderer builds tapered, segmented leg and toe geometry,
an elliptical tarsometatarsus with localized anterior scutes, claws, and a
visible support so contact can be inspected rather than inferred from floating
geometry. The hock-to-ankle segment is constrained to the selected `57 mm`
tarsus estimate rather than inheriting the former tube endpoint spacing.

Digits I-IV retain the avian `2-3-4-5` phalangeal pattern. Every segment has a
tapered elliptical surface, each interphalangeal station carries a flattened
plantar pad whose lower surface meets the support, and a two-section claw
continues the distal tangent. These are estimated contact shapes; no tendon
force or measured joint-center claim is implied.

Standing feather motion is a separate retained Metal path:

```text
54 stable feather IDs
        |
class + side + order/count + morphology
        |
poseStandingCrowFeatherRoots (current and previous phase)
        |
shared 24 x 6-section vane expansion
        |
ordinary triangle raster fallback
```

This keeps persistent identity and temporal correspondence while folding the
flight feathers along the body. It does not claim feather contact dynamics or
measured folded-wing anatomy.

The standing primary and secondary directions converge into compact,
class-specific caudal envelopes. Roots remain in their estimated
shoulder-to-pelvis series, but lateral fanning is reduced so the folded tips do
not split into separated decks when viewed from behind. This is estimated
presentation anatomy and does not enter the solver.

The longest primary centerlines now converge to `9-10 mm` from the sagittal
plane where their tapered tips enter the lateral rectrix envelope. A retained
geometry gate evaluates the primary tip against the live lateral-tail vane
width at the same axial station, preventing the background-visible
primary-to-tail slit exposed by an underside-rear camera. These are estimated
standing-presentation coordinates; persistent identities, asset lengths, and
the solver surface are unchanged. The general partially stacked organization
of folded primaries follows the folded-wing observations of
[Egbert and Belthoff (2003)](https://academic.oup.com/condor/article/105/4/825/5563457);
their House Finch dimensions do not transfer to this crow estimate.

Five imbricated covert courses per side are sampled from the live asymmetric
body loft rather than a rectangular lateral grid. Their `130` stable roots sit
`1.2-1.45 mm` above that same trunk surface, overlap the following axial root,
and continue over the rump before extrapolating caudally. This seals the
scapular, axillary, and pelvic wing-body boundaries from front and rear cameras
without hiding a discontinuity through framing.

The `2,688` estimated body contour feathers now separate a concealed proximal
plumulaceous zone from the distal pennaceous vane that owns the visible shell.
Only the distal `56-64%` is emitted as a continuous vane. Forty-eight axial
courses and fifty-six circumferential tracts replace the broad `24 x 24` plates;
identity-stable tract phase plus bounded root-angle jitter on the live
loft break aligned transverse and longitudinal rows. The smaller `0.45 mm`
shell clearance, flatter transverse crown, and narrower vane aspect keep axial
and circumferential overlap explicit. The denser shell narrows nominal
dorsal/flank/ventral vanes while preserving the prior length and distal
visible-length gates. It enforces a `4.8 mm` minimum maximum half-width at
narrow loft rings and caps half-width below `24.9%` of vane length. Its inset
axial parameterization preserves physical tract staggering at both endpoint
courses instead of losing variation to a clamp. These values are estimated
presentation morphology; the increased density raises deterministic fallback
geometry cost and is intended to become cullable meshlet or curve work on
future hardware. Paired downy barbs are retained as
output-coverage-driven geometry for close future renders and omitted when
subpixel. Each visible vane now carries its own axial/width coordinates through
the temporal AOV path, so smooth geometric normals drive the highlight along
the rachis instead of the former flat-quad fallback direction. Bounded stable
inner/outer asymmetry (`+/-4.5%`), `1.2-3.0%` edge undulation, and low-amplitude
eumelanin color variation break cloned silhouettes without weakening the
directional adjacent-tract overlap gate. These optical and edge values are
presentation estimates, not measured crow microstructure. This two-zone
organization follows observed contour-feather
morphology ([Ng et al. 2014](https://pmc.ncbi.nlm.nih.gov/articles/PMC4202321/))
and the layered optical role of hidden bases beneath exposed tips
([Eliason et al. 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC12285719/)); the
zone fractions are bounded presentation estimates, not American-crow
measurements.

At the ordinary standing-camera coverage, each visible vane now emits ten
paired outer-barb aggregates plus five overlapping terminal aggregates. Their
roots remain inside the continuous vane, while their sub-millimetre overreach
breaks the former sealed polygon edge without cutting holes into the coverage
shell. The groups are one-quad ribbons whose width and overreach are bounded in
final-output pixels; at closer LODs they give way to full rachis-to-edge barbs
and optional barbules. This is a raster-scale silhouette representation of
unresolved barb populations, not individually resolved or measured crow barbs.

Body-vane barb, rachis, and edge energy is attenuated independently from the
larger remiges when it becomes unresolved by the half-resolution temporal
input. The retained native-versus-`2x` gate requires full-frame display RMSE
below `0.01`, foreground gradient-energy retention above `0.74`, and bird
silhouette intersection-over-union above `0.94`; these remain output contracts,
not evidence that the presentation geometry is measured.

The twelve retained rectrices form a closed standing stack: their bases remain
buried beneath the rump shell, their root and distal lateral spans are each
`12 mm`, and their distal envelope descends `25-31 mm` below the body center.
Within each side, every medial rectrix lies above its lateral neighbour and the
two sides form a shallow tent, avoiding both a coplanar sheet and an open fan.
The six mirrored pairs now retain explicit order/count metadata through the
Metal geometry pass. Pair-specific presentation profiles vary maximum vane
half-width from `18.4-19.4 mm` and longitudinal camber from `4.48-5.54 mm`;
the outer half-vane is `2.9-7.0%` narrower than its inner counterpart and each
pair shifts its camber peak slightly along the rachis. A multi-station coverage
gate evaluates the resulting asymmetric edge positions rather than the former
symmetric envelope, so the added feather identities cannot reopen the closed
tail. The denser `24 x 6` canonical surface resolves the curvature and crown as
geometry while remaining a conventional triangle fallback for future mesh or
ray-tracing paths.
The retained template now preserves a narrow terminal vane rather than
converging every rectrix to a needle. A smooth envelope begins at `84%` length
and retains `13-16%` of maximum half-width at the tip. The centerline keeps the
exact `166 mm` asset length while lateral edge vertices retreat quadratically
by `1.7-2.3 mm`, yielding a rounded end without changing the closed-tail root or
deployment schedule.
This ordering follows the general folded-tail overlap described by
[Clark (2010)](https://academic.oup.com/auk/article/127/1/44/5148514); only the
ordering transfers here. All vane asymmetry, width, crown, and camber values are
bounded estimates rather than American-crow measurements. Full asset length,
stable ID/hash, and solver geometry remain unchanged.

The initial takeoff hold also retains a paired deep-underplumage lobe from the
existing rump volume into each folded outer-wing/rectrix junction. Each lobe
now converges from an `8 mm` proximal radius to `1.5 mm` distally instead of
ending as an exposed constant-radius cylinder. Semantic class `16` keeps this
deep optical backing distinct from exposed ventral vanes: its cortex, sharp,
and anisotropic energy are suppressed, and a small rearward depth bias lets
nearly coincident remiges and coverts own the visible sample. The lobes remain
at full area through presentation phase `0.125` and collapse smoothly to zero
area by phase `0.375`, before free distal articulation. They do not widen an
exposed vane, move a feather root or tip, or enter the solver.
A 253-frame, 13-view native AOV audit introduced no silhouette-hole or expected
leg-aperture regression (`1,950 -> 1,923` total enclosed pixels); a separate
near-vertical underside probe reduced the folded junction's largest component
from `72` pixels to `1-3` pixels. These are presentation-geometry checks, not
evidence for measured American-crow underplumage dimensions.
Fresh 17-frame rear-starboard `(2.36,-0.24)` and low rear-port
`(-2.42,-0.36)` audits preserve their enclosed-hole totals exactly at
`45/29` and `53/40` pixels/components. Active identity coverage changes by
`-0.225%` and `-0.248%` as the former exposed tube ends retract; selected
phase-zero frames no longer show the bright oval and central slit produced by
those ends. This is deterministic raster ownership plus visual inspection of
two simulated views, not a perceptual-realism qualification.

The persistent rump-to-rectrix contour shell now resolves `168` vanes in seven
axial rows of `24`, up from `120` in five rows. Root stations span `5-62%` of
the same underlayer axis and the overlapping tips reach `35-92%`; tube radii,
shell clearance, material model, and underlayer bounds remain unchanged. Every
added vane inherits the existing deterministic camber, edge ripple, rachis,
barb, and future close-up barbule hierarchy. At the frozen 17-frame left-under,
right-under, and dorsal-quarter audits, all exterior class-`4`/class-`3` slot,
enclosed-hole, and expected leg-aperture metrics remain exact. Frame-`5`
inspection shows denser caudal surface breakup without a diagonal bridge or a
new wing-tail membrane. This qualifies simulated contour density, not measured
American-crow rump-feather counts.

The native AOV report schema is now version `13`. Each frame records
scene-linear luminance mean, standard deviation, maximum, and mean absolute
same-class neighbour difference for every visible bird feather class. These
statistics are computed before display tone mapping and exclude the support and
environment, allowing body-highlight refinements to be compared without
embedding or optimizing against a real-crow image.

The body-contour material now evaluates a broader, lower-energy sharp lobe than
the exposed flight feathers: its exponent is `44` rather than `92`, its
per-class amplitude is bounded to `0.20-0.32`, and its procedural barb-normal
tilt is reduced from `0.052` to `0.024` radians. Its additive anisotropic lobe
is scaled to `0.46` while the broader cortex sheen remains intact. The
flight-feather lobe, barbule direction signal, geometry, identities, and albedo
remain unchanged.
This preserves gloss instead of making the plumage matte: comparative glossy
black-feather measurements associate the response with a thin regular keratin
cortex over a continuous melanin layer
([Maia et al. 2011](https://pubmed.ncbi.nlm.nih.gov/21123257/)). The choice to
broaden the whole-bird body response is also consistent with a surface feather
model in which far-field appearance and subtle goniochromatism emerge from
angular masking between barbs and barbules
([Padrón-Griffe et al. 2024](https://graphics.unizar.es/projects/FeathersAppearance_2024/)).
The exact lobe bounds remain simulated presentation estimates, not measured
American-crow optical parameters.

The cortex return now stays in an eight-sample wavelength domain until display
conversion. Equal-energy samples span `400...680 nm` in `40 nm` steps and use
normalized CIE 1931/linear-sRGB quadrature weights, so a flat spectrum remains
neutral. The versioned optics profile keeps two evidence classes explicit.
Published comparative constraints supply complex keratin `1.56 - 0.03i` and
melanin `2.00 - 0.60i` indices plus a glossy-cortex `110...180 nm` interval;
the live shader uses them with complex Snell refraction, separate s/p Fresnel
amplitudes, and an Airy internal-reflection sum at the key-light half-vector.
Renderer estimates separately set a `160 +/- 18 nm` feather-local thickness
field, `0.08` coherent-film blend, eumelanin extinction
`1.32...0.88`, density `1.62...1.84`, and cortex scale `0.92...1.04`. Existing
barb-bank lobes still determine direction. This removes the former view-phase
interpolation between chosen blue and violet RGB endpoints. Maia et al.
measured low diffuse reflectance and a much stronger specular response across
comparative glossy black feathers, including common raven and fish crow
([Maia et al. 2011](https://pmc.ncbi.nlm.nih.gov/articles/PMC3107640/)); those
data constrain neutral glossy-black structure, but the paper exposes no raw
spectral table and does not calibrate the numerical American-crow parameters
above. No figure trace is relabelled as target-species measurement.

On the Mac mini, four alternating nine-frame `1280 x 720` takeoff captures at
yaw `0.46` and pitch `1.08` measured a pooled post-warm-up GPU median of
`13.971 ms` for the previous eight-band interface and `14.110 ms` for the
profile-driven transfer-matrix path (`+0.99%`). All non-appearance AOV fields
remained exact. Across inspected still, transition, and flight frames,
changed-pixel display-RGB chroma fell by `2.76%`, `2.82%`, and `2.86%`; this is
a renderer comparison, not a match to real-crow imagery.

The next angular-film pass replaces that normal-incidence film term without
changing the profile estimates. A Metal compute probe matches five independent
FP64 reference cases from normal incidence through cosine `0.05`, including
separate s/p powers and their unpolarized mean. The implementation follows the
complex Snell/Fresnel/Airy construction collected in the
[OpenPBR implementation notes](https://blog.selfshadow.com/publications/s2025-shading-course/openpbr/s2025_pbs_openpbr_notes_v1.3.pdf),
building on the microfacet thin-film treatment of
[Belcour and Barla 2017](https://belcour.github.io/blog/research/publication/2017/05/01/brdf-thin-film.html).
At a previously unused low
front-port camera `(-0.82,-0.62)`, four alternating nine-frame captures measure
pooled post-warm-up medians of `13.533 ms` for the normal-incidence film and
`13.888 ms` for the complex angular Airy path (`+2.62%`; pooled mean overhead
`+2.06%`). In inspected still, transition, and flight anchors, changed-pixel
display-RGB chroma increases by `4.39%`, `4.30%`, and `4.46%`; mean per-channel
changes remain below one display code and no isolated colored patch appears.
This is a physically motivated renderer delta, not target-image agreement.
Geometry and all non-appearance AOV fields remain exact at the fresh camera.
The five established 17-frame safety views likewise differ only in
feather-class luminance and GPU duration; their hole, component, expected
aperture, identity, depth, normal, motion, support, and coverage fields remain
exact.

Five established 17-frame safety views were also rerendered at `1280 x 720`:
elevated-port `(-2.92,0.52)`, low-starboard `(2.94,-0.18)`, rear-port
`(-2.28,0.16)`, rear-starboard `(2.36,-0.24)`, and steep underside
`(2.65,-0.88)`. Baseline and candidate reports are identical after removing
only GPU duration, HDR extrema, and per-class luminance statistics; geometry,
depth, normal, motion, coverage, identity, support, and aperture fields remain
exact.

At frozen frame `1` in the new rear-low, front-low, and dorsal-rear captures,
all body-class pixel counts remain exact. The first two low-light views retain
their scene-linear distributions within `0.49%`. In the revealing dorsal-rear
view, class-`5` luminance standard deviation falls `30.47%`, its maximum falls
`22.23%`, and same-class neighbour variation falls `24.65%`; class-`6`
standard deviation and neighbour variation fall `26.07%` and `24.19%` while
its mean falls `5.86%`. Frozen-frame inspection retains the black body volume,
flight-feather contrast, and silhouette while reducing the repeated silver-rib
response. These are renderer diagnostics at three simulated cameras, not a
perceptual equivalence claim.

The twelve procedural wingbeat rectrices resolve an LOD-selected,
piecewise-tapered rachis inside each coverage-preserving vane. Depending on
final-output coverage, the shaft is omitted or represented by `4`, `8`, or `12`
connected segments; it ends at `98.5%` chord and tapers to `18%` of its retained
asset radius so it cannot become a second tail silhouette. Pair-aware eumelanin
variation and feather-class `3` AOV ownership keep individual tail feathers
readable and auditable. Across the fixed 253-frame, 13-view orbit, enclosed-hole,
largest-hole, component, and expected lower-body aperture metrics remained
exact; the added interior shafts changed active coverage by only `240` pixels in
aggregate, with a maximum per-frame increase of `0.028%`. A proposed replacement
that held the persistent rectrices in one open pose throughout flight was
rejected: it exposed pre-existing body-wing cavities as large as `100` pixels
from other angles. The accepted takeoff path instead evolves the same stable
identities from the closed stack to that open endpoint, as described below. The
retained shaft radius, fan pose, and material variation remain presentation
estimates rather than measured American-crow microstructure.

The topology-bound dorsal flight coverts now carry the same contained-detail
principle. Each CPU vane adds a longitudinally cambered rachis only when its
final-output coverage selects a shaft tier; the shaft begins at `4%` chord,
ends at `96.5%`, and tapers to `16%` of its estimated base radius. It retains
feather-class `4` ownership and is generated from the same root, tip, normal,
and camber as the owning vane. Across the established 253-frame, 13-view orbit,
active and fully covered identity pixels, enclosed-hole totals, largest holes,
component counts, and expected lower-body apertures remained exact. Only `163`
already-covered class-`4` pixels changed visible surface ownership to the
brighter shaft triangles. A larger experiment that deployed 42 retained remex
identities on the articulated wing was rejected before publication. Although a
single underside diagnostic improved, the fixed orbit exposed the opposite
result: enclosed-hole pixels rose from `1,923` to `7,399` and the largest hole
rose from `36` to `1,147` pixels as the new fan closed exterior concavities into
cavities. It also did not replace the dominant broad covert silhouettes.

The retained covert geometry instead resolves paired aggregate-barb ribbons
inside each accepted vane. Their roots follow the cambered rachis crown; their
tips stop at `82%` of the local asymmetric, rippled half-width, and their count
quantizes from zero to `10`, `9`, or `18` pairs with final-output coverage.
Across the same 253-frame, 13-view orbit, expected apertures and hole-component
counts remained exact. One lower opposite-rear hole contracted from `6` to `5`
pixels; only `13` active and `11` fully covered identity pixels were added over
the full matrix, while `126` already-covered pixels changed to class-`4` detail
ownership. The ribbons are aggregate optical bundles, not a claim that
individual American-crow barbs have been measured. Shaft radii, bundle radii,
and color contrast remain presentation estimates.

The broad trailing course is no longer rendered as one exposed root-to-tip
plank. Every identity now contains a proximal rank over `0...72%` of the former
axis and a distal rank over `34...100%`; one rank retains full analytic coverage
at every station, while the accepted original envelope remains a darker hidden
covert bed. The exposed ranks retain a `2%` vane margin, sit `20` micrometres
above the bed, and separate by at most another `160` micrometres only inside
their shared roof-tile interval. Their deployment follows wing opening from
transition progress `0.25...0.85`, so the folded hold remains seated instead of
prematurely layering the free-wing course. Each shorter rank retains the full
coverage-tier axial density and carries its own LOD-selected shaft and paired
aggregate-barb groups.

The final 253-frame, 13-view comparison against the published single-rank bed
adds only `188` active and `168` fully covered pixels across `24,950,723`
baseline active pixels. Expected lower-body aperture pixels and components are
exact, enclosed-hole component counts are exact, the maximum hole remains `36`
pixels, and total enclosed-hole pixels improve from `1,922` to `1,921`; one
front-starboard hole contracts from `13` to `12` pixels. A new high
starboard-dorsal inspection at yaw `1.10`, pitch `0.88` found no second outline,
floating shaft, or exposed bed gap. Rank intervals, separations, margins, and
material contrast remain presentation estimates rather than measured
American-crow covert dimensions.

Flight and takeoff now promote those two exposed ranks into the retained Metal
geometry stream. Each side contributes `31` proximal and `31` distal roots, so
`124` new class-`14`/class-`15` temporal records join the `216` reverse-wing
coverts. The shared template maps rank-local coordinates back to the accepted
global vane intervals and evaluates current/previous morphology before one
indirect compute and draw submission. The CPU path keeps only the continuous
class-`4` bed for flight; standing retains its existing visible CPU ranks until
the grounded persistent-feather stream owns that tract.

Against the immediately preceding 253-frame, 13-view orbit, the retained-rank
pass increases active identity pixels from `24,950,911` to `24,956,584` and
fully covered identity pixels from `24,714,523` to `24,720,501`. The maximum
enclosed hole remains `36` pixels. One `31`-pixel planted lower-body aperture
at the short high-angle sequence changes audit category from expected aperture
to enclosed hole without changing its pixel area; therefore raw enclosed-hole
pixels move `1,921...1,949` while expected-aperture pixels move
`4,324...4,293`. The category-invariant combined pixels improve from `6,245`
to `6,242`, and combined components improve from `1,056` to `1,052`. A new
opposite-dorsal inspection at yaw `-1.82`, pitch `0.62` found no detached rank,
second outline, or exposed continuity-bed gap. These are raster qualification
results, not evidence that the estimated covert dimensions are measured crow
anatomy.

The cranial surface is not transported as a detached rigid shell during quiet
standing. Points buried in the trunk-facing nape remain body-anchored, a cubic
coupling field deforms the visible neck, and the field reaches rigid-head motion
before the orbit and bill. Cervical feather tracts use the same shoulder-to-head
continuity principle over this underlying surface.

The final body-loft rings retain a broad dorsal and lateral neck envelope where
they overlap the cranial loft. Those body vertices enter the same coupling field
as the nape, so the visible transition cannot collapse into a narrow static
collar while the head moves.

The pelvic-to-leg transition uses a distinct estimated femoral tract before the
existing crural tract. Fifteen body-surface-rooted rows cross the dorsal/outer
upper thigh in eighteen overlapping courses and advance toward the proximal
fourteen-by-seven crural envelope without converging onto one cylindrical tip
ring. Identity-stable root, length, radial phase,
width, and camber variation breaks the former broad cuff into `270` femoral and
`98` crural vanes per side without changing hip, hock, ankle, or digital support
coordinates. This organization follows the corvid pterylography reported
for Clark's Nutcracker by
[Mewaldt (1958)](https://sora.unm.edu/sites/default/files/journals/condor/v060n03/p0165-p0187.pdf);
only the tract relationship transfers here, not species dimensions. The layer
does not modify hip, hock, ankle, or digital support coordinates.

Standing crown, cheek, throat, and nape contour tracts are rooted directly on
the breathing cranial loft. The standing path now uses one `306`-vane field
instead of stacking the former `40`-vane legacy overlay over a sparse second
system. Eleven axial stations by thirty-two angular tracts are finite-difference
attached to the loft; explicit holes reserve both orbits, and the two anterior
stations retain only crown and throat coverage so the bill base remains clear.
Every non-reserved angular neighbour overlaps, every retained axial neighbour
is reached by the preceding vane, and the same graded head-neck transform
transports roots, tips, and normals. Alternating half-tract angular phase plus
bounded identity-stable length, camber, and eumelanin variation prevents the
field from collapsing into aligned bead rows. Final-output coverage selects
deterministic `82`, `152`, or `306`-tract tiers so subpixel vanes do not alias
while a `1280 x 720` standing render retains the complete inventory.

The cervical bridge likewise increases from `50` broad accents to `154`
narrower vanes in eleven circumferential rows and seven axial courses. Their
adjacent widths overlap around the live neck envelope, their axial reach remains
longer than root spacing, and head coupling still rises from the anchored
shoulder end to the cranial end without moving mantle or scapular tracts. These
densities and dimensions are presentation estimates, not measured crow feather
counts. The shoulder shell now carries `120` mantle and `196` scapular vanes in
staggered five-by-twelve and seven-by-fourteen tracts instead of the former
`48` and `72` broad accents. Identity-stable root phase, course position, length,
tip sweep, camber, width, and eumelanin variation break synchronized rows while
adjacent roots remain covered circumferentially and axially. Deterministic
low/medium/full output tiers retain `140`, `236`, or `470` combined cervical,
mantle, and scapular vanes. Throat tips also receive bounded tangential sweep so
the ventral cranial shell does not collapse into a single geometric fan.
The folded-wing shell now uses nine by twenty body-seated courses per side,
raising its inventory from `130` broad panels to `360` narrower coverts. Every
root remains on the asymmetric body loft, every axial and circumferential
neighbour overlaps, and bounded course, length, tip-sweep, width, and camber
variation prevents a regular tiled plate from replacing the former sparse grid.
Final-output coverage keeps the proven coarse `130` folded-coverts plus `35`
femoral and `50` crural vanes per side below `1400 px/m`, then switches to all
`360`, `270`, and `98` identities at full density. The full `1280 x 720`
standing view clears that gate and retains every high-quality identity.

The standing-to-flight presentation now preserves that body coverage while
changing ownership at the shoulder. Axillary roots and vane lengths remain
fixed to the trunk, but deployment rotates their directions and normals toward
the live inner wing with a stronger dorsal than ventral coupling. Folded-wing
coverts keep a topology-stable zero-area record after their visual handoff
instead of remaining as a second expanded shell beneath the open wing.
Humeral and scapular vanes whose projected length reaches `40 px` promote their
coarse edge aggregates into paired interior barb bundles without moving the
owning vane edge. In a new low rear-quarter 25-frame audit, enclosed-hole pixels
fell from `105` to `99` and components from `67` to `65`; the expected lower
body aperture remained `34,028` pixels. Three additional 17-frame dorsal-rear,
under-rear, and front-starboard probes reduced combined holes from `312` to
`310` and components from `218` to `216`, preserved the `6` expected-aperture
pixels, and kept the largest hole at `33` pixels. These are raster coverage
checks, not measured feather dynamics or proof of perceptual realism.

Tail ownership now follows the same continuity rule. The `12` persistent
rectrices keep full vane morphology while Metal blends their closed standing
root, direction, and normal into the open-flight endpoint from transition
progress `0.08` through `0.62`; their stable IDs and current/previous records do
not change. Only persistent primaries and secondaries collapse during the wing
handoff, and no second CPU tail is appended during takeoff. Against the prior
renderer, three complete 17-frame probes at yaw/pitch `(-3.05,0.05)`,
`(1.65,-0.38)`, and `(-0.15,0.68)` reduce aggregate enclosed-hole pixels from
`535` to `359`, components from `198` to `190`, and the largest hole from `38`
to `29` pixels. The `4` expected lower-body pixels remain exact, and the traced
`38`-pixel high-front class-`0`/`3`/`4` tail-wing cavity is gone. The remaining
largest high-front component belongs to planted leg/foot articulation. These
are deterministic raster and implementation gates, not measured feather motion
or proof of perceptual realism.

The folded live-wing sheet now converges into that retained stack rather than
remaining constant-width at its distal topology stations. A smooth spanwise
taper begins at `52%`, reaches its terminal `10-14 mm` lateral envelope by
`94%`, and transports every existing topology-bound covert without changing the
`9 x 33` inventory or its deployment endpoint. Three new 17-frame probes at
yaw/pitch `(-0.50,0.78)`, `(0.12,0.88)`, and `(0.62,0.72)` remove the paired
outer blade silhouette and reduce aggregate enclosed pixels from `1,019` to
`1,010`. Components change from `330` to `331`, zero expected apertures remain
exact, and the unchanged `156`-pixel worst component is not part of the tapered
wing. A subsequent identity trace found classes `0`, `6`, `8`, `10`, and `11`
around that near-vertical aperture but no femoral/crural class `7`; three small
camera changes removed it. It is therefore a cranial-to-pedal projection
aperture, not a body seam to fill. This qualifies the simulated raster
transition only; the taper values are not measured anatomy.

In steep-left, steep-right, and rear-overhead 17-frame A/B audits, the rounded
rectrix terminals change worst enclosed-hole counts only `38 -> 39`, `42 ->
41`, and `291 -> 291` pixels. Swift/Metal positions remain within `3e-6` and
normals within `1e-5`; these gates establish implementation parity and raster
continuity, not measured American-crow terminal morphology.

Three additional lateral/rear cameras traced the early deployment comb by
stable identity rather than silhouette alone. At the stressed frame, the two
terminal primary `9/10` records account for `593`, `8,633`, and `1,913` visible
pixels. Their identity-specific retained visibility now ends at progress
`0.28`, ahead of the generic remex endpoint `0.62`, reducing those counts to
`206`, `1,122`, and `126`. Across the same complete 17-frame sequences, hole
pixels/components/largest component remain exactly `152/73/46`, `143/71/17`,
and `53/33/3`. The pointed topology-bound live primaries remain unchanged;
only the duplicate folded presentation oracle transfers earlier.

The deployed chord-`3` live covert course now settles its proximal camber and
dorsal clearance to `48%` at the root, recovering to full relief across `12`
span stations while the folded hold, vane width, chord, and every feather
identity remain exact. A separate 17-frame low rear-quarter probe preserved
`264` enclosed-hole pixels, `72` components, `4` expected-aperture pixels, and
the `44`-pixel worst hole while increasing fully covered active pixels by `3`.
Across the prior three stress views it preserved `310` hole pixels, `216`
components, `6` expected-aperture pixels, and the `33`-pixel worst hole while
increasing fully covered active pixels by `13`. These are deterministic raster
coverage gates, not anatomical measurements.

The visible posterior class-`5` body owner now refines in two coupled layers.
Dorsal contour crown settles to `58%` and mantle camber to `62%` at their
posterior courses during deployment, with smooth anterior falloff and exact
standing roots, tips, widths, identities, and inventory. Posterior dorsal
contours resolving at least `48 px` replace `20` coarse edge aggregates with
contained interior barb pairs while retaining five terminal bundles and the
same record count. In a new 17-frame high-side view, `145` hole pixels, `75`
components, zero expected-aperture pixels, and the `33`-pixel worst hole stayed
exact. Across the four established stress views, `574` hole pixels, `288`
components, `10` expected-aperture pixels in `4` components, and the `44`-pixel
worst hole also stayed exact. These are deterministic raster gates, not proof
of measured feather behavior or perceptual realism.

The exposed class-`6` scapular layer now shares its deployed transverse crown
with retained rachis and barb geometry while preserving stable parent-class AOV
ownership. Interior barbs remain inside `97%` of the local vane width and only
five terminal bundles complete the feather tip. Across six 17-frame takeoff
audits at yaw/pitch `(-0.62,-0.22)`, `(-1.25,0.38)`, `(-2.42,0.28)`,
`(-1.82,0.62)`, `(2.65,-0.88)`, and `(0.85,0.18)`, aggregate enclosed holes
fell from `791` to `786` pixels and components from `408` to `405`. Expected
lower-body apertures remained exactly `10` pixels in `4` components and the
worst hole remained `44` pixels. The new first view, high-side, low-rear,
dorsal-rear, and front-starboard gap counts stayed exact; under-rear improved
from `92` to `87` pixels and `50` to `47` components. These are deterministic
raster-coverage checks for simulated geometry, not measured feather anatomy.

Interior class-`7` pectoral and abdominal records now keep their established
subvane continuity shaft and add a crown-following four-segment rachis, while
boundary rows, terminal axial courses, and edge-barb aggregates remain exact.
The `776` crown shafts are retained as `112`-byte analytic records and expanded
by Metal from a compact output-LOD interval list. At the current capture tier
this replaces `74,496` per-frame CPU-authored vertices with `3,104` curve
intervals while preserving the previous shaft oracle to sub-micrometre position
and `5e-6` normal error in the executable GPU parity test.
In a new 17-frame underbody view at yaw `0.20`, pitch `-0.65`, holes remained
`117` pixels in `70` components. Across that view plus the established
high-side, low-rear, dorsal-rear, under-rear, and front-starboard probes,
aggregate holes improved from `831` to `830` pixels and components from `430`
to `429`; expected apertures stayed `10` pixels in `4` components and the
worst hole stayed `44` pixels. Front-starboard supplied the one-pixel and
one-component improvement; the other five views were exact. This qualifies
simulated raster coverage, not anatomical rachis measurements.

Migrating the visible class-`7` shafts to Metal retained that accepted result.
Across complete 17-frame underbody, dorsal-rear, and front-starboard replays,
all active/fully-covered identity totals, `334` enclosed-hole pixels in `235`
components, and `6` expected-aperture pixels in `2` components stayed exact.
At underbody phase `0.5`, one covered pixel changed ownership from adjacent
class `6` to class `7`; no silhouette pixel changed. The nine visually inspected
hold/mid-transition/flight frames had SSIM `>= 0.999997` against the prior CPU
expansion. This is executable raster and parity evidence, not a performance
claim or an anatomical measurement.

The next body-gap trace separated an actual femoral insertion seam from the
larger intentional spaces bounded by class-`11` retracting toes. At high-side
phase `0.3125`, the temporal identity AOV mapped the nine-pixel class-`0`/
class-`7` opening to far-side femoral rows `6...11`, courses `8...9`. A bounded
overlap envelope now reaches `1.36x` vane width and `1.06x` tip length only in
that window, tapering to `1x` outside it. Roots, hip/hock/ankle/digit
coordinates, the `270`-vane-per-side inventory, and identities remain fixed.
The 17-frame high-side audit improves from `145` enclosed pixels in `75`
components to `135` in `73`; frame `5` improves from `19`/`9` to `9`/`2`, and
the targeted nine-pixel opening disappears without becoming an expected
aperture. The `33`-pixel articulated-foot maximum and zero expected-aperture
pixels remain exact. Underbody remains `117` pixels in `70` components with a
five-pixel maximum; front-starboard remains `102` in `71`, two expected-aperture
pixels, and a four-pixel maximum. Visual inspection of hold, transition, and
flight frames at all three angles found no padded thigh outline or covered
digital articulation. These are deterministic simulated-raster results, not
measured feather overlap.

The retained open-tail target now derives every rectrix plane from its local
fan geometry. At `55%` chord, the closed-form spanwise centerline derivative is
crossed with the root-to-tip tangent and oriented dorsally; all `12` normals
remain unit length, orthogonal to both local directions, and retain
`z = 0.950...0.992`. This replaces the prior constant `(0,-1,0.12)` target,
which rotated width toward a lateral plane as the tail deployed. In three fresh
17-frame probes at yaw/pitch `(3.14,0.08)`, `(-2.72,0.30)`, and
`(2.58,-0.34)`, aggregate hole pixels/components improve from `4/4` to `4/4`,
`18/12` to `15/9`, and `28/18` to `20/16`; the worst components improve from
`4`, `17`, and `22` pixels to `4`, `14`, and `13`. At stressed frame `5`,
visible rectrix pixels change from `1,289`, `2,333`, and `1,740` to `1,296`,
`2,253`, and `1,657`; by frame `10` they fall from `421`, `912`, and `637` to
`379`, `788`, and `325`. This qualifies the simulated fan orientation and
raster continuity, not measured rectrix kinematics or perceptual realism.

The apparent shoulder cavity in oblique transition views was then traced with
the packed identity AOV rather than filled from the silhouette. The fixed
class-`11` wing surface was already closed; the dominant plate was the live
class-`4`, chord-`0`, span-`5` covert (`82436`), which covered `425` pixels in
the canonical midpoint. Its first `12` span stations now recover smoothly from
`62%` root width, `58%` root camber, and `72%` leading-course chord to the
unchanged free-wing course. Roots, fixed surface, record count, identities,
trailing courses, and axillary coverage remain exact. At the same midpoint the
dominant plate falls to `288` pixels. High-front, rear-starboard, and
under-quarter probes reduce their largest targeted covert by `32.25%`,
`53.39%`, and `32.87%`, while active identity pixels change by less than
`0.62%` and the largest enclosed hole stays exactly `4`, `5`, and `3` pixels.
Across matched 72-frame, `2x` reconstruction audits, enclosed hole
pixels/components change from `130/106` to `131/107`, `177/156` to `188/162`,
and `43/35` to `41/37`; expected lower-body apertures stay exactly
`15/4`, `9/1`, and `19,760/25`, and every worst component remains unchanged.
This establishes topology ownership and bounded simulated raster continuity;
it does not establish measured covert dimensions or perceptual realism.
The body-contour flow pass then traced the visible standing "corduroy" pattern
to straight, uniformly crowned cervical, mantle, scapular, and ventral tracts.
Every root, tip, identity, inventory, and LOD threshold stays fixed, but each
vane now receives an identity-stable lateral sweep that returns to zero at both
ends. Lower contour shingles stay below `1.06 mm` sweep; body transverse crown
is `0.12`, deployed outer scapular crown is `0.08`, and ventral crown is `0.07`.
Rachises and barb groups follow the same curved centerline, including the
retained Metal-expanded ventral records.

Across fresh 17-frame low-port-forward and dorsal-rear-starboard audits at
yaw/pitch `(-0.92,-0.48)` and `(2.08,0.46)`, expected apertures remain exactly
`6,189/6` and `751/6` pixels/components, and the worst enclosed components stay
exactly `8` and `4` pixels. Low-port enclosed holes improve from `53/16` to
`50/15`; dorsal-rear changes from `59/42` to `62/44`. Mean same-class neighbour
luminance variation changes by class `5/6/7` by `-2.34%/+5.71%/-14.16%` in the
low view and `-8.66%/-12.87%/-4.81%` in the dorsal view. This is deterministic
simulated-raster evidence for reduced row coherence and continuity, not a
measurement of feather anatomy or proof of perceptual realism.

The subsequent body-optics pass keeps that topology and all follicle endpoints
fixed. A bounded `0.78...1.22` identity-stable scale varies the ventral crown
while driving both visible vanes and retained crown shafts, and paired
feather-local optical barb banks replace a single coherent body highlight.
Across fresh 17-frame front-low and front-high-quarter audits at yaw/pitch
`(0.08,-0.10)` and `(0.48,0.32)`, expected apertures, enclosed-hole pixels,
component counts, and worst components remain exact. Mean same-class neighbour
luminance variation changes by class `5/6/7` by `-1.96%/-0.89%/-0.002%` in the
front-low view and `-6.65%/-4.45%/-0.35%` in the high-quarter view. This is
deterministic simulated-raster material evidence, not measured feather optics
or a perceptual-realism qualification.

The pectoral-volume pass then relaxes lower-flank narrowing only through the
sternum and fades the field before the caudal pelvis. All axial ring stations,
vertical radii, hip/hock/foot coordinates, feather identities, and inventories
remain fixed. One femoral feather crossed the `24 px` detail threshold during
quiet pose motion at the small topology test resolution; standing and takeoff
now use the same `0.035 m` representative femoral LOD length, restoring exact
current/previous vertex counts while retaining the higher detail tier.

Across fresh 17-frame front-starboard and ventral-port audits at yaw/pitch
`(-0.32,0.06)` and `(0.66,-0.34)`, enclosed-hole pixels stay `6 -> 6` and
improve `36 -> 35`; components improve `5 -> 4` and `17 -> 16`; and the worst
components remain exactly `2` and `5` pixels. Fully covered active identity
pixels rise `0.396%` and `0.226%`, while fully covered class-`7` pectoral,
abdominal, and femoral pixels rise `1.493%` and `1.226%`. Expected lower-body
apertures remain zero in both views. These are simulated-raster continuity and
coverage results, not measured external dimensions or perceptual realism.

The upper-leg breakup pass adds deterministic, identity-seeded tip lift,
tangential splay, and signed centerline curvature to the full-density femoral
and crural vane fields. Femoral centerline sweep stays below `0.15x` vane width;
crural sweep stays below `0.17x`. The four anterior femoral junction vanes at
rows `5...6`, courses `16...17`, remain seated because they roof the projected
body/gular handoff during takeoff. Feather roots, counts, hip/hock/ankle/digit
coordinates, and topology remain unchanged. These amplitudes are bounded
presentation estimates, not measured American-crow feather geometry.

Fresh 17-frame hind-port and ventral-starboard audits at yaw/pitch
`(-2.05,-0.12)` and `(2.82,-0.52)` preserve enclosed-hole pixels/components
exactly at `81/41` and `7/7`. Active identity coverage changes
`364,982 -> 365,074` (`+0.025%`) and `339,311 -> 339,438` (`+0.037%`);
fully covered AOV pixels change `357,291 -> 357,412` (`+0.034%`) and
`333,257 -> 333,376` (`+0.036%`). A temporary primitive-ownership trace
identified and eliminated a one-pixel body/class-`7`/gular-class-`10` handoff
regression before publication. This qualifies simulated raster continuity, not
perceptual realism.

The cervical-density pass replaces the coarse `24 x 10` root lattice on each
side with a `32 x 14` field over the same anatomical neck span. Full-resolution
cervical inventory rises from `480` to `896` deterministic vanes. Individual
vanes narrow from about `4.2 mm` to below `3.5 mm` maximum half-width and
shorten modestly, while a coprime 16/33 course phase prevents repeated axial
stations. The shoulder and cranial boundary roots, shell clearance, surface
classes, head coupling, and pose-time inventory remain fixed. This is a
future-compute presentation refinement, not measured American-crow follicle
density or feather dimensions.

Fresh 17-frame dorsal-port and ventral-rear audits at yaw/pitch
`(-1.36,0.42)` and `(1.72,-0.44)` preserve the complete enclosed-hole time
series: aggregate pixels/components remain exactly `13/12` and `5/3`.
Expected lower-body aperture series are also exact. Active identity coverage
changes `348,190 -> 347,945` (`-0.070%`) and `399,833 -> 399,740`
(`-0.023%`); fully covered active pixels change `341,009 -> 340,786`
(`-0.065%`) and `392,469 -> 392,399` (`-0.018%`). The dorsal-port A/B changes
large countable nape scallops into a finer overlapping contour field without a
ventral-rear silhouette regression. This qualifies deterministic simulated
raster continuity and apparent feather scale, not perceptual realism.

The folded underplumage seating pass removes a detached class-`16` lobe that
became visible outside the tail from previously unused rear-port and steep
dorsal-starboard views. A temporary ownership render proved that the dark rod
was neither leg nor rectrix geometry: its hard-coded distal point remained at
`47 mm` lateral while the folded terminal primary had already swept inward.
The endpoint now follows the live terminal-primary centerline at `158 mm`
axial distance with a `3.5 mm` underside-normal inset. Bilateral symmetry,
`8 -> 1.5 mm` taper, release phases, class, vertex inventory, and the rump
anchor remain unchanged. These offsets are presentation estimates, not
measured underplumage anatomy.

Across fresh 17-frame rear-port and dorsal-starboard audits at yaw/pitch
`(-2.28,0.16)` and `(1.34,0.60)`, enclosed-hole pixels/components and worst
components remain exactly `187/141/4` and `24/15/5`; expected aperture totals
remain `7/3` and `1,300/6`. Active identity coverage changes
`334,522 -> 334,385` (`-0.041%`) and `416,242 -> 416,001` (`-0.058%`) as the
exposed backing disappears. The original rear-starboard `(2.36,-0.24)` and
low rear-port `(-2.42,-0.36)` qualification views also remain exact at
`45/29/4` and `52/39/4`, and a steep underside `(2.65,-0.88)` stress view
remains exact at `25/11/9`. This qualifies hidden simulated backing and raster
continuity, not perceptual realism.

The retained trailing-covert pass removes an artificial deployment dependency
from the two anatomical dorsal ranks. Their stable class-`14` and class-`15`
Metal records now remain visible through the folded hold and the entire
standing-to-flight transition instead of appearing only after wing opening.
Roots, rank intervals, vane widths, surface clearance, identity count, and
expanded topology remain unchanged; the already-retained class-`4` continuity
bed stays underneath rather than becoming the exposed rear-wing surface. This
is a simulated feather-layer ownership correction, not measured covert motion.

Fresh 17-frame elevated-port and low-starboard audits at yaw/pitch
`(-2.92,0.52)` and `(2.94,-0.18)` produce aggregate enclosed-hole
pixels/components/worst component of `56/28/6` and `12/9/2`; expected
lower-body apertures remain `0/0` and `4/1`. Earlier safety views improve from
`187/141/4` to `165/120/4` at rear-port, `45/29/4` to `35/25/3` at
rear-starboard, and `25/11/9` to `20/10/9` at the steep underside. This
qualifies deterministic simulated raster continuity and retained feather
ownership, not perceptual realism.

The body optical-bank pass addresses the manufactured diagonal highlight bands
seen from a previously unused high-port grazing view at yaw/pitch
`(-1.55,0.84)`. A temporary non-shipping class render localized the exposed
dorsum and flank to classes `5` and `6`; hidden contour-detail and follicle
stagger candidates were rejected after producing no perceptible improvement.
The retained shader instead broadens identity-stable barb-bank orientation,
normal, and roughness variation in feather-local coordinates. Across the fresh
nine-frame audit, pixel-weighted same-class neighbour luminance difference
changes from `0.00295060` to `0.00293924` for class `5` and from `0.00246946`
to `0.00246504` for class `6`, reducing coherent bands without flattening mean
class luminance. Geometry, depth, motion, normal, identity, support, and hole
AOV fields remain exact on the fresh view and all five established 17-frame
safety views. These are deterministic optical-coherence checks, not a claim of
measured American-crow reflectance or perceptual realism.

The feather-visibility path separates two physical direction dependencies that
the earlier shader conflated. The keratin-cortex-melanin spectrum is evaluated
independently for the key, fill, and sun half vectors. A second view-only
calculation returns normalized barb, proximal barbule, distal barbule, and
transmission weights. The initial projected-ellipse and projected-segment
approximation remains available as a deterministic fallback.

The promoted path now ports the constant-time analytic discontinuity-ray mask
from Padrón-Griffe et al.'s
[pennaceous-feather model](https://doi.org/10.1111/cgf.15235) and the authors'
[MIT implementation](https://github.com/juanraul8/PennaceousFeathersRendering)
at source revision `9af1a04`. Ellipse tangencies partition neighboring barb
and barbule intervals into visible, transmitted, and occluded projected area.
This is exact for the paper's idealized regular-cross-section construction; it
does not claim measured American-crow cross sections or explicit individual
curve self-occlusion. All profile shape values remain renderer estimates.

The live Metal probes match four complete authors-reference mixtures plus eight
barbule intervals and four unnormalized barb interval cases within `2e-5`. A
`1,088`-direction spherical sweep keeps every channel finite, nonnegative,
bounded, and normalized. At a previously unused high front-port yaw/pitch
`(0.88,0.96)`, exact and fallback 17-frame takeoff captures keep every
nonappearance AOV field identical after excluding luminance, HDR, and duration.
The exact path changes `24,749` of `360,000` beauty pixels at the inspected
mid-transition frame while preserving geometry, depth, motion, identity,
support, and silhouette metrics. The fresh view totals `73` enclosed pixels in
`54` components, with a `22`-pixel per-frame maximum and `19`-pixel largest
component. On the same Apple-M4 workload, exact masking costs `15.10%` more
mean GPU time and `10.13%` more median GPU time after the warm-up frame. That
cost is accepted for the future-compute appearance tier; it is not a
performance win or a claim of perceptual realism.

The first projected-size geometry handoff now replaces that analytic-only
far-field ownership when an interior class-`7` feather reaches `480` output
pixels. The existing `776` crown records remain the authority. Each active
record emits `72` identity-varied barb pairs per side; four connected intervals
follow the changing transverse crown from the rachis to `95.5...96.7%` of the
local edge, and four radial sides taper from an estimated `26` to `4 um` before
identity variation. The old individual barb, barbule, and coarse edge-aggregate
fallbacks are suppressed only while this explicit tier owns the feather.
Current and previous body centers, normals, parent class, procedural owner, and
unique primitive IDs are written by the same Metal expansion.

At the deliberately extreme `0.035 m`, `800 x 450` diagnostic, output coverage
is `14,438.8 px/m`; `746` records activate, producing `429,696` intervals and
`10,312,704` temporal/AOV vertices. A previously unused oblique flank view at
yaw/pitch `(1.42, 0.08)` and target `(0.05, 0.060, 0.020) m` rejected the first
regular, ladder-like candidate. The retained denser tier changes `13,290` of
`360,000` beauty pixels at the inspected quiet-stance frame, confined to the
visible close-up feather bank, and replaces protruding aggregate bars with a
continuous fine curve field. A five-frame normal-distance A/B produces exact
PNG hashes and exact non-duration AOV JSON with the tier enabled and disabled,
confirming that ordinary rendering emits no dormant vertices and that the
canonical simulated hold-to-flight GIF remains current.

Executable tests lock the ordinary empty work list, the close-up active-record,
interval, and vertex counts, curve connectivity and taper, packed-work
uniqueness, fallback ownership, and CPU/Metal temporal-tube parity. The close-up
capture is a visual and ownership diagnostic, not a GPU benchmark: the present
unindexed triangle stream intentionally spends future compute to establish the
geometry oracle. These dimensions and densities are renderer estimates, not
measured American-crow barb anatomy. Previous-depth occlusion, indexed or
mesh-stage emission, per-feather dynamics, and curve-aware physical
self-shadowing remain open.

An independently gated `800 px` tier now gives every explicit parent barb six
barbules on each of two crossed branches. Stable packed work records identify
record, parent pair, vane side, branch, and barbule index. Both endpoints remain
at or inside `0.93` normalized vane width and the estimated radius tapers
`12 -> 4 um`, so this tier cannot become a new body-silhouette owner. The lower
branch carries a bounded `0.82...0.90` local occlusion factor and the upper a
`0.93...0.98` factor; this approximates unresolved paired-branch blockage and
is not a cast-shadow solution.

At `1200 x 675`, distance `0.035 m`, yaw/pitch `(0.90, -0.12)`, `484` records
cross the barbule threshold, `392` are visible, `16,257,024` barbule vertices
are procedurally pulled, and geometry kind `4` wins `369` identity pixels. The
ordinary and prior `800 x 450` close paths are exact against `dcc638f`, with
zero detailed owners. CPU/Metal endpoint parity, stable work uniqueness, vane
containment, and the occlusion bounds are executable tests. The inspected frame
is a sparse exterior grazing diagnostic, not evidence that the renderer is
photoreal or that the estimated microgeometry matches a biological specimen.

The first visibility-scaling pass removes the CPU-authored close-up work list.
Metal evaluates a conservative sphere for every retained record against six
normalized world-space frustum planes, scans the `776` flags in stable record
order, emits non-overlapping interval ranges, and writes indirect expansion and
draw arguments. This preserves primitive IDs and avoids atomic ordering noise.
At a fresh front-flank yaw/pitch `(0.92, -0.22)`, target
`(0.05, 0.060, 0.020) m`, the inspected quiet-stance frame compacts `746`
projected-size candidates to `432` visible records and `10,312,704` candidate
vertices to `5,971,968` expanded vertices, a `42.09%` work reduction. Visible
record counts over the five-frame loop are `429, 429, 432, 446, 429`.

All five beauty PNGs are byte-exact and every pre-existing non-duration AOV
field is exact against revision `c6f3add`; the schema-`14` counters expose
candidate records, visible records, expanded vertices, and capacity bytes.
Normal-distance rendering remains five-frame PNG/AOV exact with all four
counters zero. The short GPU timings are noisy and support no speed claim.
The second scaling pass removes that candidate-sized output allocation. A
single non-inlined Metal helper now owns procedural vertex construction for
both the compute audit oracle and production raster-stage vertex pulling. The
GPU-compacted work list and indirect draw remain authoritative; production no
longer expands the list into a separate buffer. At a fresh yaw/pitch
`(0.80, -0.15)` with the same target and distance, frame `2` compacts `746`
candidates to `487` visible records and generates `6,732,288` raster vertices
with zero materialized-output bytes. Counts over the five-frame loop are
`481, 489, 487, 512, 481` visible records and `6,649,344`, `6,759,936`,
`6,732,288`, `7,077,888`, `6,649,344` generated vertices.

All five close beauty PNGs are byte-exact and every pre-existing non-duration
AOV field is exact against revision `7709775`; five normal-distance PNGs and
AOVs are also exact with zero active work. Schema `14` adds the explicit
`gpu-procedural-vertex-pulling` mode and reports zero output capacity. The
compute expansion remains executable under audit readback and still matches
the CPU temporal-tube oracle. No speed claim follows from these short runs.
The previous-depth gate now retains the resolved device depth as an `r32Float`
max hierarchy. Because uncovered depth clears to one, any background within a
record's conservative projected AABB propagates upward and rejects the cull.
History resets, camera-matrix motion beyond jitter, bounds touching a viewport
edge, near/far uncertainty, and projections spanning more than the bounded mip
footprint also fail open. Current body bounds are reprojected through the prior
camera, so known quiet-stance translation cannot reuse the record's stale
position. The serial stable scan separately counts frustum-visible,
occlusion-tested, culled, and retained records before emitting indirect work.

At a previously unused yaw/pitch `(0.98, -0.05)`, target
`(0.05, 0.060, 0.020) m`, the five-frame close loop begins and ends with reset
frames of `621` retained records. Its three history-valid frames classify
`620`, `622`, and `638` frustum-visible records and conservatively cull `2` on
each, avoiding `27,648` procedural vertices per frame. The `800 x 450`
hierarchy occupies `1,919,424` bytes. All five beauty PNGs are byte-exact and
every pre-existing raster/non-duration AOV field is exact against revision
`e266f5f`; normal distance remains five-frame exact with no hierarchy or barb
work. Schema `16` exposes the hierarchy mode/bytes and all four visibility
counts. Synthetic Metal tests separately prove foreground culling, background
fail-open behavior, reset-disabled testing, and max-depth propagation. No speed
claim follows from this small accepted cull. Indexed or mesh-stage emission and
curve-aware physical self-shadowing remain next.

Schema `16` resolves that rear-port priority to exact packed identities around
the largest enclosed component. The early `21-28`-pixel channels are bounded
by rectrix orders `1`, `2`, and `3`; only frames `2-3` additionally touch the
outermost proximal trailing covert. A broad presentation-tail width experiment
left every metric exact and was rejected. The retained correction instead adds
a terminal-only `5.5%` maximum-width envelope to those three sublateral pairs
and their bilateral counterparts. Medial and outermost rectrices retain their
prior shape; length, rachis, root pose, stable identity, and template topology
remain exact.

At the same 17-frame yaw/pitch `(-2.28,0.16)` stress view, enclosed-hole
pixels/components/worst component fall from `593/157/28` to `165/121/8`.
The previously unused rear-port grazing view `(-2.56,0.34)` records
`74/44/10`, and the opposite rear-starboard safety view `(2.36,-0.24)` records
`55/35/4`. Rendered inspection at the new view retains individual tail tips
without an inflated plate or membrane. These gates establish deterministic
simulated terminal ownership and raster continuity, not measured rectrix
morphology or perceptual realism.

The canonical README sequence is fully simulated and contains the native hold,
transition, and flight path: `800 x 450`, `72` frames at `24 fps`, `7,999,691`
bytes, SHA-256
`8e7cad46fa9e5e28df39f7d6b3e7e8b9208c7e65689f60ec66e38a4d56938ca3`.
The audited stage PNGs at frames `0`, `35`, and `71` are distinct and retain
the simulated hold, geometric deployment, and sustained-flight states.

Run the presentation with:

```bash
./Scripts/capture-crow-showcase.sh \
  /tmp/american-crow-standing.mp4 \
  /tmp/american-crow-standing.png \
  standing
```

## Gates

- exact phase-zero/phase-one pose and pixel closure;
- four planted distal contacts per foot over the entire loop;
- body projection inside the bilateral support interval;
- CPU/Metal equality for all current/previous feather-root records;
- `54` unique identities in both flight and standing modes;
- folded-root lateral extent below `70 mm` from the body center;
- a readable nonempty simulated capture, with no reference image in output.

Passing these gates establishes an executable grounded pose, not perceptual
realism. Approximate folded-feather layering, the analytic cranial coverage
surface beneath the contour shell, analytic leg surface, and uncalibrated idle
timing remain visible limitations.

## Mechanics references

- Backus et al., [Mechanical analysis of avian feet: multiarticular muscles in
  grasping and perching](https://doi.org/10.1098/rsos.140350), *Royal Society
  Open Science* 2:140350 (2015). This supports the multi-joint, opposing-digit
  mechanics model; it is not crow-specific calibration.
- Roderick et al., [Birds land reliably on complex surfaces by adapting their
  foot-surface interactions upon contact](https://doi.org/10.7554/eLife.46415),
  *eLife* 8:e46415 (2019). This supports explicit substrate/contact treatment;
  its parrotlet forces are not transferred to the crow.
