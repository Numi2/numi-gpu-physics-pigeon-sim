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

The schema-21 JSON report records format and coordinate conventions plus per-frame
finite-pixel count, HDR values above one, exact active IDs, visible feather IDs,
fully covered samples, unit-normal error, depth range, moving-pixel count,
maximum motion, and bird/support vertical centroids. It also records exact
visible/full-coverage counts and screen bounds for every persistent feather,
wing-surface cell, and topology-bound dorsal covert. Up to `128` longest
exterior-connected background runs bracketed by bird pixels on image rows or
columns retain both boundary class codes, surface-primitive identifiers, and
full packed anatomical identities. Visible feather classes retain scene-linear
luminance mean, standard deviation, maximum, the maximum's exact pixel
coordinate, and same-class neighbour variation before tone mapping. At most four samples per axis and
ordered class pair are retained, so one large projection cannot erase other
anatomical owners. Wing-cell ownership additionally requires the scaffold's
low-alpha material code, preventing the bare class-`11` pedal identity from
aliasing the first left-wing cell. For the largest enclosed component, schema
`21` also
retains the sorted packed identities adjacent to its boundary. This resolves a
gap directly to persistent class/side/order/count or live covert ownership
without inferring the owner from color or a temporary debug render.
Schema `21` records the body-vane immutable morphology count and bytes,
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
Schema `21` deliberately keeps the existing body-vane counters: rachis and
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
Schema `21` also records projected-size ventral-barb candidate,
frustum-visible, prior-depth-tested, occlusion-culled, and retained record
counts; logical triangle-stream vertex count; actual raster vertex invocations;
materialized output-capacity bytes; generation mode; and max-depth hierarchy
mode/bytes. Supported Metal 3 devices report
`gpu-mesh-threadgroup-8-vertex-indexed`; unsupported devices fall back to
`gpu-procedural-vertex-pulling`, which also remains the explicit audit oracle.
Both paths retain zero materialized bytes, and compute expansion remains the
audit-readback geometry oracle. Prior-depth classification reports
`previous-max-device-depth-fail-open` only when close-up candidates own a
hierarchy; ordinary coverage reports `inactive` and zero bytes. These are
executable work/residency counters, not a GPU speed claim; duration still
requires a controlled repeated benchmark.
Ventral curve records now use the previously reserved second lateral-sweep
component for a pre-terminal-flow reference length. CPU LOD work generation and
Metal barb/barbule classification consume that value, falling back to endpoint
distance for older or synthetic zero-reserved records. This keeps projected
`480/800 px` topology stable while the beauty vane's class-`7` surface tip is
dephased; actual endpoint distance still owns conservative frustum and depth
bounds. Record stride, identities, curve counts, and indirect layout are
unchanged.
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
Schema `17` separately records projected-size barbule candidates,
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
