# Bird reality roadmap

The objective is a wholly simulated bird whose motion, silhouette, material,
and light transport can eventually withstand comparison with reality. Real crow
photographs are not product or README content. If licensed reference imagery is
used for offline measurement or held-out scoring, it remains provenance-locked,
non-shipping evaluation input; the renderer must produce the displayed result.

This is a representation roadmap, not a claim that the current estimated hybrid
is already photoreal or a quantitatively validated American crow.

## Durable architecture

The stable unit is the feather identity, not today's triangles:

```text
versioned anatomy + provenance
        |
fixed simulation-surface attachment
        |
current/previous oriented root state
        |
compact feather template + LOD policy
        |
GPU-generated raster / mesh-shader / ray geometry
        |
HDR material, normal, depth, identity, motion AOVs
        |
temporal reconstruction + physical lighting + optional neural residual
```

The present Apple M4 implementation realizes the first four boundaries with a
portable compute-generated triangle path. It expands one retained vane template
for all `54` persistent remiges and rectrices, producing current and previous
positions plus stable IDs. This is intentionally usable without a future-only
API. The same records can later feed object/mesh shaders, motion acceleration
structures, or learned appearance without rewriting anatomy or provenance.

## Ordered milestones

1. **Temporal render contract.** Render linear HDR color, view/world normal,
   material parameters, stable identity, depth, and true deformation motion.
   Qualify sign, units, disocclusion, loop closure, and exact feather-ID
   persistence before enabling temporal reconstruction. MetalFX explicitly
   consumes color, depth, and motion inputs, so those buffers precede any
   upscaler integration.

2. **Geometric feather LODs.** Replace the single blade with nested rachis,
   vane, barb-group, and silhouette-meshlet representations. Select LOD from
   projected coverage and motion, not a hard-coded device name. Object/mesh
   shaders can cull and emit only visible meshlets; the compute triangle path
   remains the deterministic fallback and parity oracle.

3. **Measured appearance, bounded claims.** Implement an energy-bounded,
   anisotropic feather BSDF with separate eumelanin absorption, longitudinal
   structure, roughness, and thin-film/nanostructure terms. The SIGGRAPH 2022
   rock-dove work demonstrates why generic fiber or texture models miss
   characteristic feather appearance. Crow parameters remain estimated until
   matched measurements exist.

4. **Physical light transport.** Add image-based lighting, multiple scattering,
   soft self-shadowing, and curve/triangle ray geometry. Metal supports curve
   primitives and motion triangle/curve acceleration structures, which map to
   rachises/barbs and moving vanes without baking motion blur into textures.

5. **Future-compute scaling.** Add mesh-shader emission, indirect visibility,
   residency-managed high LODs, and capability-gated ray tracing. Preserve a
   common asset and AOV contract across M4, later Apple GPU families, and offline
   reference rendering. Never make a new hardware path the only correctness
   oracle.

6. **Neural residual appearance.** Only after explicit geometry, material, and
   motion AOVs are stable, train a compact residual for unresolved barbule-scale
   appearance. Neural appearance models show that hierarchical textures and
   learned decoders can represent anisotropic, deeply layered materials at
   real-time rates. The network must condition on physical state and identity,
   be disableable, and be compared against the explicit renderer so it cannot
   hide anatomy, motion, or lighting errors. Metal 4 tensor/MPP paths are a
   future capability tier; the core renderer must continue to run on M4.

7. **Behavior and coupled motion.** Add feather overlap/contact, rachis bending,
   aerodynamic load transfer, covert response, eye/leg motion, and landing or
   maneuver sequences. Promote quantitative aerodynamic or species-specific
   claims only through matched measurements and held-out executable gates.

## Promotion gates

Every milestone must preserve source hashes, stable IDs, current/previous state,
and the separation between solver boundary and beauty geometry. Promotion needs:

- CPU/GPU parity for the compact representation and its expanded geometry;
- finite and bounded anatomy over the full sequence, including the loop seam;
- no feather teleportation, identity reassignment, or motion-vector sign drift;
- multi-view silhouette, landmark, material, and temporal scores on held-out
  references without publishing those references as simulated output;
- same-device frame time, peak resident bytes, and quality curves for each LOD;
- a rendered visual inspection of the simulated result, because passing numeric
  gates cannot establish perceptual quality;
- blinded human comparison before using "indistinguishable" language.

## Primary technical references

- Apple, [Transform your geometry with Metal mesh shaders](https://developer.apple.com/videos/play/wwdc2022/10162/)
  and [mesh-shader LOD sample](https://developer.apple.com/documentation/metal/adjusting-the-level-of-detail-using-metal-mesh-shaders).
- Apple, [ray tracing with acceleration structures](https://developer.apple.com/documentation/metal/ray-tracing-with-acceleration-structures)
  and [curve-primitive sample](https://developer.apple.com/documentation/metal/rendering-a-curve-primitive-in-a-ray-tracing-scene).
- Apple, [MetalFX temporal-scaler contract](https://developer.apple.com/documentation/metalfx/mtlfxtemporalscalerbase)
  and [Metal feature-set tables](https://developer.apple.com/metal/capabilities/).
- Apple, [Metal Performance Primitives programming guide](https://developer.apple.com/download/files/Metal-Performance-Primitives-Programming-Guide.pdf).
- Huang et al., [Rendering Iridescent Rock Dove Neck Feathers](https://light.informatik.uni-bonn.de/rendering-iridescent-rock-dove-neck-feathers/), SIGGRAPH 2022.
- Zeltner et al., [Real-Time Neural Appearance Models](https://research.nvidia.com/labs/rtr/neural_appearance_models/), SIGGRAPH 2024.
