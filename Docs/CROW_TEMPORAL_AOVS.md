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

The schema-17 JSON report records format and coordinate conventions plus per-frame
finite-pixel count, HDR values above one, exact active IDs, visible feather IDs,
fully covered samples, unit-normal error, depth range, moving-pixel count,
maximum motion, and bird/support vertical centroids. It also records exact
visible/full-coverage counts and screen bounds for every persistent feather,
wing-surface cell, and topology-bound dorsal covert. Up to `128` longest
exterior-connected background runs bracketed by bird pixels on image rows or
columns retain both boundary class codes, surface-primitive identifiers, and
full packed anatomical identities. Visible feather classes retain scene-linear
luminance mean, standard deviation, maximum, and same-class neighbour variation
before tone mapping. At most four samples per axis and
ordered class pair are retained, so one large projection cannot erase other
anatomical owners. For the largest enclosed component, schema `17` also
retains the sorted packed identities adjacent to its boundary. This resolves a
gap directly to persistent class/side/order/count or live covert ownership
without inferring the owner from color or a temporary debug render.
Schema `17` additionally records projected-size ventral-barb candidate,
frustum-visible, prior-depth-tested, occlusion-culled, and retained record
counts; logical triangle-stream vertex count; actual raster vertex invocations;
materialized output-capacity bytes; generation mode; and max-depth hierarchy
mode/bytes. Production reports
`gpu-procedural-vertex-pulling` and zero materialized bytes; compute expansion
remains the audit-readback oracle. Prior-depth classification reports
`previous-max-device-depth-fail-open` only when close-up candidates own a
hierarchy; ordinary coverage reports `inactive` and zero bytes. These are
executable work/residency counters, not a GPU speed claim; duration still
requires a controlled repeated benchmark.
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
