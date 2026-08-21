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

The initial takeoff hold also retains a paired `8 mm` deep-underplumage lobe
from the existing rump volume into each folded outer-wing/rectrix junction.
The lobes remain at full area through presentation phase `0.125` and collapse
smoothly to zero area by phase `0.375`, before free distal articulation. They
do not widen an exposed vane, move a feather root or tip, or enter the solver.
A 253-frame, 13-view native AOV audit introduced no silhouette-hole or expected
leg-aperture regression (`1,950 -> 1,923` total enclosed pixels); a separate
near-vertical underside probe reduced the folded junction's largest component
from `72` pixels to `1-3` pixels. These are presentation-geometry checks, not
evidence for measured American-crow underplumage dimensions.

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
The `776` crown shafts are retained as `96`-byte analytic records and expanded
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
