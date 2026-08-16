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

The `1,440` estimated body contour feathers now separate a concealed proximal
plumulaceous zone from the distal pennaceous vane that owns the visible shell.
Only the distal `56-64%` is emitted as a continuous vane. Thirty-six axial
courses and forty circumferential tracts replace the broad `24 x 24` plates;
identity-stable tract phase plus bounded root-angle jitter on the live
loft break aligned transverse and longitudinal rows. The smaller `0.45 mm`
shell clearance, flatter transverse crown, and narrower vane aspect keep axial
and circumferential overlap explicit. Paired downy barbs are retained as
output-coverage-driven geometry for close future renders and omitted when
subpixel. This two-zone organization follows observed contour-feather
morphology ([Ng et al. 2014](https://pmc.ncbi.nlm.nih.gov/articles/PMC4202321/))
and the layered optical role of hidden bases beneath exposed tips
([Eliason et al. 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC12285719/)); the
zone fractions are bounded presentation estimates, not American-crow
measurements.

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
This ordering follows the general folded-tail overlap described by
[Clark (2010)](https://academic.oup.com/auk/article/127/1/44/5148514); only the
ordering transfers here. All vane asymmetry, width, crown, and camber values are
bounded estimates rather than American-crow measurements. Full asset length,
stable ID/hash, and solver geometry remain unchanged.

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
existing crural tract. Five body-surface-rooted rows cross the dorsal/outer
upper thigh in seven overlapping courses and terminate inside the proximal
crural envelope. This organization follows the corvid pterylography reported
for Clark's Nutcracker by
[Mewaldt (1958)](https://sora.unm.edu/sites/default/files/journals/condor/v060n03/p0165-p0187.pdf);
only the tract relationship transfers here, not species dimensions. The layer
does not modify hip, hock, ankle, or digital support coordinates.

Standing crown, cheek, throat, and nape contour tracts are rooted directly on
the breathing cranial loft. Fifty-four compact overlapping vanes break the
analytic head silhouette while staying behind the orbit and bill base; the same
graded head-neck transform transports their roots, tips, and normals.
Final-output coverage selects deterministic `27`, `36`, or `54`-tract tiers so
subpixel vanes do not alias at current output sizes while future high-resolution
renders retain the complete cranial inventory.

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
realism. The present smooth body, approximate folded-feather layering, analytic
leg surface, and uncalibrated idle timing remain visible limitations.

## Mechanics references

- Backus et al., [Mechanical analysis of avian feet: multiarticular muscles in
  grasping and perching](https://doi.org/10.1098/rsos.140350), *Royal Society
  Open Science* 2:140350 (2015). This supports the multi-joint, opposing-digit
  mechanics model; it is not crow-specific calibration.
- Roderick et al., [Birds land reliably on complex surfaces by adapting their
  foot-surface interactions upon contact](https://doi.org/10.7554/eLife.46415),
  *eLife* 8:e46415 (2019). This supports explicit substrate/contact treatment;
  its parrotlet forces are not transferred to the crow.
