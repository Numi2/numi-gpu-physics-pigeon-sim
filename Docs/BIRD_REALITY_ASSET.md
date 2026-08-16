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

Both GPU stages are qualified against independent CPU interpolation and
deformation paths at multiple phases. Gates cover exact identity, finite state,
unit directions, current/previous motion, a bounded `0.75 m` radial envelope,
and a `1.10 m` conservative bilateral presentation envelope. These are
implementation and visual-sanity gates, not measured anatomy validation.

The next renderer milestone is HDR albedo, normal, material, identity, depth,
and deformation-motion-vector outputs. Those buffers are prerequisites for
temporal reconstruction, MetalFX, ray tracing, and neural appearance models.
The longer architecture is recorded in
[`BIRD_REALITY_ROADMAP.md`](BIRD_REALITY_ROADMAP.md).
