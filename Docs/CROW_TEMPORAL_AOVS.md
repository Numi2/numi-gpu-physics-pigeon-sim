# Crow HDR and temporal AOV contract

The native crow capture renders a typed scene-linear frame before producing its
display PNG. This is executable infrastructure for later temporal
reconstruction, ray tracing, dataset generation, and neural residual work. It
does not claim photorealism or measured crow appearance.

## Render products

| Product | Metal format | Meaning |
|---|---|---|
| HDR beauty | `rgba16Float` | Scene-linear, extended-range radiance; alpha is one |
| Albedo/material | `rgba16Float` | Linear base color in RGB; estimated material class scalar in W |
| Normal/coverage | `rgba16Float` | Renormalized world normal in XYZ; resolved geometric coverage in W |
| Motion | `rg16Float` | Current pixel to previous pixel, in upper-left-origin pixel units |
| Metric depth | `r32Float` | Euclidean camera-to-surface distance in meters; background is zero |
| Device depth | `depth32Float` | Projection depth for MetalFX; zero is near and one is far |
| Identity | `rgba32Uint` | Exact stable surface or feather identity |
| Display | `bgra8Unorm_srgb` | Tone-mapped output used for PNG/video presentation |

The surface vertex stream pairs each current procedural vertex with the same
topological vertex from the prior frame. Retained and live topology-bound
feather geometry already contains current and previous positions. The live
underwing record additionally carries previous length, width, rachis radius,
and camber so geometric deployment cannot reuse current-frame dimensions.
These paths therefore encode deformation motion rather than camera reprojection
alone. For the first captured frame, previous state equals current state
deliberately.

Motion is `previousPixel - currentPixel`. A positive or negative value is never
inferred from optical flow. The viewport scale is one pixel per stored unit,
matching the direct MetalFX convention.

Four-sample rasterization resolves the float attachments. Resolved normals are
renormalized in the display/resolve pass, while their W component retains
coverage so a consumer can exclude mixed edge samples from strict geometry
checks. Integer identity is rendered in a separate single-sample depth-tested
pass because categorical IDs must never be averaged by MSAA. The multisample
depth attachment resolves its nearest sample into a shader-readable
`depth32Float` texture; metric depth stays a separate scientific/debug channel.

## Capability-gated temporal reconstruction

`--capture-crow-temporal-scale N` requests MetalFX temporal reconstruction from
an internal width and height reduced by `N` to the declared capture size. Scale
`1` keeps the native path as the default correctness oracle. A value above one
fails closed if the current Metal device or requested factor is unsupported.

The renderer retains one scaler across the sequence, applies an eight-sample
Halton projection jitter, transports the previous jitter through true
current/previous geometry transforms, and supplies linear HDR, resolved device
depth, and pixel-unit motion directly to MetalFX. History resets on the first
frame and the duplicate loop-closure probe. On macOS 14.4 and later, a separate
pass derives a reactive mask from resolved coverage edges, motion
discontinuities, and fast motion. It is never filled with an uninformative
constant.

The duplicate endpoint is still rerendered and included in the AOV/native
audit. Its presentation PNG is canonicalized to frame zero after that audit so
device-level MetalFX reset variance cannot create an encoded loop seam when
the pose, camera, topology, and audited buffers have closed.

Surface identity is `(UInt32.max, triangle + 1, materialCode, packedClass)`.
Wing-scaffold triangles pack part/span/chord cell ownership, and procedural
dorsal coverts pack side/chord/span ownership while keeping the class in the
low byte. Other procedural surfaces retain a zero or class-only fourth word. Feather
identity retains the inventory index, deterministic ID, surface ownership, and
packed class/side/order/count record. Reality-asset feathers use their locked
hash; live underwing coverts use topology-derived side/course/span IDs. Both
remain stable across current and previous samples. Background identity is zero.

## Executable audit

Pass an audit path to the capture executable:

```bash
.build/release/birdflow-viewer \
  --capture-crow-frames /tmp/crow-frames \
  --capture-crow-presentation standing \
  --capture-crow-temporal-scale 2 \
  --capture-crow-aov-audit /tmp/crow-aov-audit.json \
  --capture-frames 49
```

Or use the optional fourth and fifth arguments of the showcase script for the
audit path and temporal scale:

```bash
./Scripts/capture-crow-showcase.sh \
  /tmp/crow.mp4 /tmp/crow.png standing /tmp/crow-aov-audit.json 2
```

The schema-29 JSON report records format and coordinate conventions plus per-frame
finite-pixel count, HDR values above one, exact active IDs, visible feather IDs,
fully covered samples, unit-normal error, depth range, moving-pixel count,
maximum motion, and bird/support vertical centroids. It also records exact
visible/full-coverage counts and screen bounds for every persistent feather,
wing-surface cell, and topology-bound dorsal covert. Up to `128` longest
exterior-connected background runs bracketed by bird pixels on image rows or
columns retain both boundary class codes, surface-primitive identifiers, and
full packed anatomical identities. Visible feather classes retain scene-linear
luminance mean, standard deviation, maximum, the maximum's exact pixel
coordinate, and same-class neighbour variation before tone mapping. Every
right/down adjacency between different visible feather classes is also retained
as one ordered pair with edge count, image bounds, mean absolute and ordered
lower-class-minus-upper-class luminance jump, maximum absolute jump, and the
maximum-jump coordinate. The sign distinguishes a dark lower-code tract from a
bright one without depending on scan direction. This localizes optical seams such
as the class-`7` body/bridge to class-`10` gular handoff without storing a
segmentation image or any real-crow target. At most four samples per axis and
ordered class pair are retained, so one large projection cannot erase other
anatomical owners. Wing-cell ownership additionally requires the scaffold's
low-alpha material code, preventing the bare class-`11` pedal identity from
aliasing the first left-wing cell. For the largest enclosed component, schema
`24` also
retains the sorted packed identities adjacent to its boundary. This resolves a
gap directly to persistent class/side/order/count or live covert ownership
without inferring the owner from color or a temporary debug render.
Schema `24` records the body-vane immutable morphology count and bytes,
Metal-selected morphology count and bytes, per-frame pose bytes, retained
morphology/pose/indirect capacity, active topology-bin count, morphology-buffer
allocations, raster invocations, and the
`gpu-resident-morphology-pose-instanced-indirect` generation mode. The
morphology inventory is retained once; only pose input uses three in-flight
slots. CPU temporal records and expanded geometry exist only during explicit
audit readback. This makes pose ownership, selection, allocation stability, and
residency executable without treating them as a speed result.
The retained body path now allocates second and third indirect-argument sets for
the vane-contained rachis and body-detail hierarchy, increasing three-slot
indirect capacity from `336` to `1,008` bytes. Dedicated Metal/Swift parity and
indirect-storage tests qualify the rachis's `0/4/8/12`-section tube expansion
and the detail path's `0/0/43/43/41/41/167` compact temporal segments. The
additional `18` segments are six deterministic three-section proximal
plumulaceous chains, contained beneath each resolved feather's unchanged vane.
The initial `96`-byte segment store retains `39,777,408` bytes over three
in-flight slots and grows to `154,484,352` bytes only for the future `480 px`
topology.
Schema `25` adds exact visible/full-coverage ownership and image bounds for each
of the `3,212` retained body-vane identities. Inventory index and stable hash
remain coupled to tract region, bilateral side, row, and column, so a dorsal or
flank patch can be traced to its owning simulated feather without a target
image or color inference. Vane-contained rachis and detail primitives retain
their parent identity.
Schema `27` extends that census and the retained inventory to the `1,304`
class-`7` pectoral/abdominal vane owners. Identity family `2` remains the
`3,212` dorsal/body records; family `3` maps its own inventory index back to
ventral region, side, row, and column. The subsequent femoral-retention pass
adds `540` family-`4` records whose inventory index maps to bilateral side,
row, and course. The
crural-retention pass adds `324` family-`5` records mapping bilateral side,
radial tract, and axial station. The throat-bridge pass adds `88` family-`6`
records mapping bilateral side, interdigitated row, and one of four graded
neck-coupling columns. Family `7` adds `711` cranial records mapping region,
axial loft station, angular tract, and derived side. Aggregate
retained-morphology counters now report `6,179` records and `790,912` bytes,
and the `225` gular records reuse those family-`7` identities for `1,575`
procedural rachis/barb tubes without a new identity namespace or retained
segment buffer. Dedicated ventral fields
continue to report
`1,304` records, selected work, procedural raster invocations, eliminated CPU
surface bytes, and `gpu-retained-identity-stable-procedural-vane` generation.
At the current `7 x 3` tier this is `164,304` raster vertices and `15,773,184`
eliminated `CrowSurfaceTemporalVertexGPU` bytes per frame. Femoral family `4`
adds `68,040` raster vertices and eliminates another `6,531,840` bytes per
frame. Crural family `5` adds `46,656` raster vertices and eliminates another
`4,478,976` bytes per frame. Throat family `6` adds `11,088` raster vertices
and eliminates another `1,064,448` bytes per frame. Exact retained-family
selected counts are recoverable from the family census and aggregate selected
count without widening the already large frame-audit ABI.
Schema `29` carries explicit family-`7` execution evidence: cranial-vane and
gular-detail candidate, frustum-visible, post-occlusion, tested, culled, and
raster-invocation counts plus retained-work and depth-hierarchy bytes. The
shared compactor preserves ascending inventory order inside each topology bin
and feeds beauty and exact-identity passes from the same work. A separate gular
list contains only class-`10` throat records, reducing the full-density detail
submission from `711` instances / `89,586` vertices to the exact `225` owners /
`28,350` vertices. Previous-pose bounds test the prior max-device-depth pyramid
only under stable camera history and fail open at viewport edges, invalid clip
or depth, clear background, and uncertain mip coverage. A fixed-camera
`1280 x 720` probe tests all `711` cranial and `225` gular records but culls zero
in the ordinary view; synthetic constant-depth GPU tests prove rejection and
background retention. This is an ownership/off-screen-work boundary, not a
claimed normal-view speedup. Coarse tiers report zero because CPU remains their
declared owner.
This is a data-flow and residency audit, not a GPU-time or throughput result.
Schema `24` deliberately keeps the existing body-vane counters: rachis and
detail inherit their parent vane's stable identity, and the integer pass
retains that underlying vane identity rather than issuing redundant subpixel
fiber draws. Beauty ownership is nevertheless Metal-native. These storage and
parity observations are not a performance result.
At near-front standing yaw/pitch `(0.12, 0.16)`, distance `0.55 m`, and
`800 x 450`, the five-frame underlayer A/B preserves exact enclosed-hole pixels
`1, 0, 1, 2, 1`, components `1, 0, 1, 1, 1`, and zero expected lower-body
aperture in every frame. Minimum beauty SSIM is `0.999999`, with at most `11`
pixel values changed in a frame. The underlayer carries the parent vane
identity, so these fibers do not add an integer-identity draw.
Schema `24` also records projected-size ventral-barb candidate,
frustum-visible, prior-depth-tested, occlusion-culled, and retained record
counts; logical triangle-stream vertex count; actual raster vertex invocations;
materialized output-capacity bytes; generation mode; and max-depth hierarchy
mode/bytes. Supported Metal 3 devices report
`gpu-mesh-threadgroup-8-vertex-indexed`; unsupported devices fall back to
`gpu-procedural-vertex-pulling`, which also remains the explicit audit oracle.
Both paths retain zero materialized bytes, and compute expansion remains the
audit-readback geometry oracle. Prior-depth classification reports
`previous-max-device-depth-fail-open` only when close-up candidates own a
hierarchy; coverage below the `40 px` aggregate-curve threshold reports
`inactive` and zero bytes. These are executable work/residency counters, not a
GPU speed claim; duration still requires a controlled repeated benchmark.
Ventral curve records now use the previously reserved second lateral-sweep
component for a pre-terminal-flow reference length. CPU LOD work generation and
Metal barb/barbule classification consume that value, falling back to endpoint
distance for older or synthetic zero-reserved records. This keeps projected
`40/480/800 px` topology stable while the beauty vane's class-`7` surface tip is
dephased; actual endpoint distance still owns conservative frustum and depth
bounds. Record stride, identities, curve counts, and indirect layout are
unchanged.

Schema `26` separates all ventral-barb candidates from the subset promoted to
the `480 px` close tier. The new `40 px` rung gives each eligible interior
pectoral or abdominal record ten paired four-interval curves; it retires that
record's coarse edge ribbons without changing boundary-feather geometry. At
the `1280 x 720` near-level rear-port gate, all `776` retained records qualify
for the aggregate rung, zero qualify for the close or barbule rungs, and
`62,080` emitted intervals correspond to `1,489,920` logical vertices or
`496,640` indexed mesh-raster vertices. Materialized output remains zero. The
complete standing and takeoff hole/component/largest-hole/expected-aperture
series is exact against schema `25`; active-identity changes are bounded to
five pixels. These fields establish LOD ownership and work, not biological
barb counts or measured GPU speed.
Body-vane cervical flow follows the same classification boundary without
adding a packed field. The immutable morphology's reference tip still owns
projected-length topology; the dynamic CPU oracle and Metal state reconstruct
the same row/column/side terminal displacement after selection and before the
existing cervical affine transform. At the `1200 x 675`, five-frame
lateral-front standing audit `(0.38, -0.05)` from `0.50 m`, selected body-vane
owners remain `3,212`, raster invocations remain `685,530`, maximum normal-unit
error is exact, and the complete hole/component/largest-hole/aperture series is
unchanged. Fully covered AOV deltas are `+7,+1,-2,-3,+7`; the localized beauty
change has minimum SSIM `0.999853`. This is a topology and temporal-parity gate,
not a claim that the remaining visible collar has been eliminated.
The ordered class-boundary records localize that collar to class `7/10`, with
class `7` darker by a five-frame signed mean of `-0.0033948848`. The retained
posterior/distal gular optical handoff lowers mean absolute contrast from
`0.0060948643` to `0.0052184042` (`14.3803%`) while every top-level field other
than class luminance, class-boundary luminance, and GPU duration remains exact.
The maximum jump changes only from `0.03567496` to `0.03602520`; class `8/10`
mean contrast changes `+1.3609%`. The five-frame beauty minimum SSIM is
`0.999981`. A rear-high `(2.45, 0.30)` safety view is pixel-exact and AOV-exact
apart from duration, demonstrating that the class-`10` tag does not alter
occluded geometry or leak into other tracts. These statistics qualify
localization and bounded optical effect, not perceptual realism.
The persistent-identity ledger at rear-high frame `2` separately reveals that
one side-`1`, order-`9` primary owns `18,723 / 18,887` class-`1` pixels. After
the standing-only imbrication correction it owns `14,199` (`-24.1628%`), while
orders `7/8` rise from `100/48` to `163/62` pixels and class `4` gains `2,470`
pixels. Every hole/component/largest-hole/aperture count remains exact over the
five frames. At new opposite rear-quarter yaw/pitch `(-2.18, 0.18)`, the same
topology fields are exact and minimum SSIM is `0.994816`. The takeoff A/B is
topology-exact, has minimum SSIM `0.999305`, and becomes pixel-exact in frames
`3...4`, proving the standing morphology does not leak into sustained flight.
These records diagnose raster ownership and temporal release; they do not
measure biological primary overlap.
Schema `24` reserves the high byte of the persistent feather physics-part AOV
channel for detail kind `0/1/2` (vane/rachis/barb). The stable anatomical census
normalizes that byte away, while `persistentFeatherPrimitives` reports exact
visible and fully covered pixels per feather and detail kind. At the existing
opposite rear-quarter `1200 x 675` view, the former persistent LOD path emitted
only vane ownership even though its `1,378 px/m` coverage belonged to the
rachis tier. Restoring the middle tier exposes `355,357,355` visible and fully
covered primary-rachis pixels over the three-frame loop. Hole pixels,
components, largest component, and expected lower-body aperture remain exact;
minimum beauty SSIM is `0.999819`. The GPU-selected prefix now draws only vane
plus rachis work at this density and retains full barb geometry above the
existing `1,400 px/m` threshold. This is projected geometry evidence, not a
claim that the estimated shafts match a measured specimen.

The same primitive ledger qualifies the first denser-remex full tier without
changing the rectrix or live-covert templates. Twenty established barb pairs
remain shared; primaries and secondaries alone resolve `28` interlaced
supplemental pairs as kind `2` ownership. At rear-high `1280 x 720`, standing
remex-barb ownership rises from `115...160` to `291...339` pixels and early
takeoff from `47,47,3` to `125,118,4`. The complete hole/aperture series and
class-`3` primitive arrays remain exact. Beauty minimum SSIM is `0.999954` for
standing and `0.999978` for the changed early-takeoff frames; frames `2...4`
of takeoff are pixel-exact. This proves contained projected contribution and
phase-bounded release, not biological barb density or a performance result.

Class `17` now separates the CPU-authored throat bridge from class-`7` ventral
plumage while preserving body-contour shading semantics. This makes the bridge
visible in the existing 32-bin class and boundary ledgers without changing its
surface geometry. A binary diagnostic of the raw surface primitive ID at the
dorsal port-quarter patch maps triangle `818,478` to negative-side bridge row
`4`, posterior column `3`. The retained class-specific optical handoff reduces
the exact owning display pixel from `(39,50,64)` to `(30,40,52)` and the local
thresholded patch from `1,933` to `1,823` pixels. Standing minimum SSIM is
`0.999908`; takeoff minimum SSIM is `0.999975`. All recorded hole and expected
aperture fields remain exact in both A/Bs. These are semantic ownership and
bounded optical-continuity results, not a measured plumage reflectance fit.

The same persistent-identity ledger now separates the broad folded-primary
handoff into stable layers without shrinking its accepted raster envelope. At
the low starboard-quarter mid-phase, near-side primary order `8` rises from
`25` to `383` visible pixels while terminal order `9` changes from `11,456` to
`11,164`; total active identity coverage remains exactly `157,562`. Widening
only the terminal primary's already-contained aggregate barb ribbons raises
their primitive-kind-`2` census from `230` to `424` pixels. All standing and
takeoff hole, component, largest-hole, expected-aperture, and active-coverage
fields remain exact; later takeoff frames are pixel-exact. The fresh low
rear-port audit exposes three primary orders on the far wing and keeps its
largest enclosed component at `2,3,2` pixels. This establishes retained
geometry ownership and containment, not measured feather-layer spacing or
perceptual equivalence.

The subsequent lower-lobe audit uses those same packed identities to reject an
underlayer-gap diagnosis. Broadening only the intermediate-primary lift
envelope at its unchanged `2.2 mm` maximum raises far-side penultimate order
`8` from `368` to `1,313` visible pixels and near-side order `8` from `1,713`
to `1,759` at the low rear-port mid-phase. Total active ownership changes by
six pixels there; the complete topology ledger is exact. The independent low
starboard gate raises penultimate ownership from `383` to `1,330` with three
additional active pixels and exact topology. Takeoff active ownership and
topology remain exact, with later frames pixel-identical. A new near-level
rear-port audit bounds all enclosed components to at most four pixels while
showing the penultimate course inside the terminal outline. These counters
localize and bound the simulated overlap change; they do not validate a
biological spacing measurement or whole-bird realism.

Schema `24` separately records projected-size barbule candidates,
frustum-visible and retained detailed owners, procedural barbule vertex count,
and the exact number of identity pixels won by geometry kind `4`. This
distinguishes allocated work from raster contribution. The `800 px` handoff is
independent of the `480 px` parent-barb handoff, so established close captures
can prove zero barbule work while a higher-resolution diagnostic proves stable
mixed-LOD ownership.
These runs expose shoulder and feather-course slots that diagonal exterior
flooding intentionally excludes from enclosed-hole counts. They are
localization evidence, not a rule that every silhouette concavity should be
filled. When temporal scaling is
active, the audit also renders a separate full-resolution native oracle and
records whole-frame RMSE, bird-foreground RMSE, maximum channel error, and bird
silhouette intersection-over-union plus foreground gradient-energy retention.
The standing gate at `2x` requires RMSE below `0.01` globally and `0.025` on the
bird foreground, silhouette IoU above `0.94`, gradient retention above `0.74`,
reset/loop closure, and the support centroid below the bird in Metal's
upper-left pixel coordinates. These gates qualify reconstruction and buffer
semantics; rendered inspection remains required for anatomy, material,
lighting, and perceptual quality.

The audit also records command-buffer GPU duration and renderer-owned target
bytes for both paths. These are same-device comparative measurements, not total
process residency or a cross-device performance claim. In the 2026-08-16
release Apple M4 standing qualification at 1280×720 with `2x` reconstruction,
frames `1...47` had median GPU durations of `2.454 ms` temporal versus
`3.499 ms` native. Tracked render targets were `56.47 MiB` versus `186.33 MiB`;
MetalFX-internal storage is not included. The worst visual gates over all 49
audit frames were `0.00579` whole-frame RMSE, `0.0142` bird-foreground RMSE,
`0.9748` silhouette IoU, and `0.7510` foreground gradient-energy retention.

The same `2x` setting is **not promoted for wingbeat**. In its 49-frame Apple M4
probe, motion reached roughly `61.7 px`, minimum gradient retention fell to
`0.621`, and median temporal GPU duration (`3.77 ms`) did not beat native
(`3.73 ms`). Wingbeat therefore remains on native resolution until a stronger
fast-feather disocclusion strategy passes both quality and time gates.
