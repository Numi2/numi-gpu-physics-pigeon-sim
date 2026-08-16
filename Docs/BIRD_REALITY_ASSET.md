# Persistent bird-reality asset

`BirdRealityAsset` is the versioned boundary between BirdFlow's executable
physics surface and future high-density rendering. It gives anatomy and every
flight/tail feather a stable identity that survives changes in GPU storage,
geometry LOD, shading, and ray-tracing strategy.

The first committed instance is
[`american-crow-hybrid-reality-v1.json`](../ValidationInputs/american-crow-hybrid-reality-v1.json).
It is an **estimated hybrid**, not a measured crow. It locks the existing visual
profile, generation audit, and fixed-topology simulation manifest by SHA-256.

## Contract

The schema and runtime loader require:

- the BirdFlow right-handed, COM-centered SI coordinate frame;
- a single rooted joint hierarchy with normalized rest orientations;
- deterministic, globally unique feather identifiers;
- feather class, side, root joint, rest geometry, material, and evidence class;
- ordered rendering LODs from reference microstructure to silhouette meshlets;
- one distinct physics-surface root anchor for every expanded feather;
- hash-locked source artifacts and explicit readiness/claim boundaries.

The current asset expands five compact anatomical series into `54` persistent
feathers: bilateral sets of ten primaries and eleven secondaries, plus twelve
rectrices. Each expanded feather maps to a vertex owned by the correct wing or
tail component of the existing `2,157`-vertex physics surface.

Validate both the asset and all referenced source bytes with:

```bash
swift run birdflow validate reality-asset --json
```

The machine-readable shape is defined by
[`bird-reality-asset-v1.schema.json`](../Schemas/bird-reality-asset-v1.schema.json).
The Swift loader additionally enforces cross-record invariants JSON Schema
cannot express, including hierarchy acyclicity, generated-ID uniqueness,
bilateral surface-component ownership, and exact source hashes.

## Representation boundary

The root anchor is correspondence metadata, not a claim that the current flow
grid resolves a feather shaft. The existing 3,968-triangle surface remains the
solver boundary. Future vane, barb, and microstructure LODs may contain far more
primitives without entering the CFD mesh or changing quantitative claims.

The example's material values, joint locations, feather dimensions, and surface
anchors remain explicitly estimated. Its readiness flags therefore reject
measured crow geometry, measured crow kinematics, and quantitative crow
aerodynamics.

## Live renderer boundary

The estimated-crow capture now loads and validates this asset before rendering.
Its feather inventory and dimensions drive the current beauty mesh, while a
Metal compute pass evaluates all `54` locked surface anchors into retained,
triple-buffered private storage. Each output record carries current and previous
root position, morphology, surface ownership, class, side, inventory index, and
a deterministic stable-ID hash. The immutable surface sequence and feather
bindings are uploaded once rather than rebuilt per frame.

Each root also carries a fixed-topology surface triangle. Metal transports the
estimated rest direction through that triangle's current and previous tangent
frames, then expands one retained twelve-section vane template into `3,888`
triangle vertices. The primary, secondary, and tail vertices rendered by the
live capture now come from private GPU buffers; their previous positions and
stable feather IDs remain beside the current render attributes. The physical
wing/tail surface is rendered as a dark underlayer so the attachment boundary
stays visible rather than being hidden by a disconnected procedural wing.

Quiet standing uses the same identities and vane expansion through a separate
`poseStandingCrowFeatherRoots` kernel. That path folds primaries and secondaries
along the body and retains current/previous state for millimetric idle motion;
it does not misuse a slowed, outstretched flight frame. The visible leg, digit,
hallux, claw, and support-contact contract is documented in
[`CROW_STANDING_ANATOMY.md`](CROW_STANDING_ANATOMY.md).

Both GPU stages are qualified against independent CPU interpolation and
deformation paths at multiple phases. Gates cover exact identity, finite state,
unit directions, current/previous motion, a bounded `0.75 m` radial envelope,
and a `1.10 m` conservative bilateral presentation envelope. These are
implementation and visual-sanity gates, not measured anatomy validation.

The renderer now emits scene-linear HDR beauty, albedo/material,
normal/coverage, metric depth, current-to-previous pixel motion, and exact
integer identity. It keeps the integer pass outside MSAA resolution and
renormalizes filtered normals before exposing them. This is the baseline
contract for temporal reconstruction, MetalFX, ray tracing, and neural
appearance models. A capability-gated MetalFX temporal path now consumes the
linear HDR, resolved device depth, and motion buffers while a native-resolution
render remains the parity oracle. Exact formats, conventions, and audit fields
are documented in
[`CROW_TEMPORAL_AOVS.md`](CROW_TEMPORAL_AOVS.md). The longer architecture is
recorded in [`BIRD_REALITY_ROADMAP.md`](BIRD_REALITY_ROADMAP.md).

Procedural contour and covert vanes select a quantized tessellation tier from
their projected length in final-output pixels. The four retained asset
thresholds (`480`, `120`, `24`, and below `24 px`) map to curved reference
microstructure, barb ribbons, vane shells, and silhouette strips. Final-output
coverage keeps native and MetalFX frames on the same topology, while quantized
tiers prevent the quiet standing orbit from rebuilding different vertex counts
between current and previous temporal samples.

Persistent GPU vanes also retain their template-local axial and signed-width
coordinates through deformation. The Metal material pass uses those stable
coordinates for a narrow rachis response, vane-edge transmission, and aligned
barb modulation; the pattern therefore follows each feather through motion
instead of swimming in screen or world space. These are analytic appearance
cues, not measured barb geometry or microscopy-derived material calibration.

The persistent template is subdivided into four transverse bands as well as
twelve axial sections. A class-dependent crown bends the vane away from its
edge chord, while the existing rachis camber bends its centerline. Swift and
Metal compute surface normals from matched axial and transverse derivatives;
the qualification gate requires more than two final-output pixels of crown
depth in the canonical edge-on view. This prevents a flight feather from
collapsing into a single needle-width line without claiming physical feather
thickness or measured microstructure.
