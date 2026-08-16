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
scute rings, claws, and a visible support so contact can be inspected rather
than inferred from floating geometry.

Standing feather motion is a separate retained Metal path:

```text
54 stable feather IDs
        |
class + side + order + morphology
        |
poseStandingCrowFeatherRoots (current and previous phase)
        |
shared 12-section vane expansion
        |
ordinary triangle raster fallback
```

This keeps persistent identity and temporal correspondence while folding the
flight feathers along the body. It does not claim feather contact dynamics or
measured folded-wing anatomy.

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
