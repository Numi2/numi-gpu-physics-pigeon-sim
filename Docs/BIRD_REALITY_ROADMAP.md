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

The present Apple M4 implementation realizes the first five boundaries with a
portable compute-generated triangle path. It expands one retained vane template
for all `54` persistent remiges and rectrices and a second live stream of `340`
wing-covert roots, including `124` interval-mapped dorsal trailing-rank roots.
Both produce current and previous positions plus stable IDs. This is
intentionally usable without a future-only API. The same records can later feed
object/mesh shaders, motion acceleration structures, or learned appearance
without rewriting anatomy or provenance.
The grounded-pose path now proves that identity contract across a second motion
regime: it folds the same inventory on Metal rather than treating quiet standing
as a slowed flight loop, and keeps toe contacts fixed while the body, head, and
ankles move by millimetres.
The takeoff path now extends that contract through a third regime: the `12`
retained rectrices unfold continuously from their closed stack into the
open-flight endpoint on Metal, while remiges use a complementary zero-area
handoff to the articulated surface. This removes duplicate CPU tail ownership
without changing the compact record contract that future mesh, curve, or
ray-tracing emitters will consume.
The folded live-wing surface now preserves its complete `9 x 33` topology while
converging its distal lateral envelope into the retained feather stack. Because
all topology-bound covert identities inherit that deformation, a future GPU
surface evaluator can reproduce the same taper without adding a third feather
inventory or view-dependent patch geometry.

## Ordered milestones

1. **Temporal render contract.** Render linear HDR color, view/world normal,
   material parameters, stable identity, depth, and true deformation motion.
   Qualify sign, units, disocclusion, loop closure, and exact feather-ID
   persistence before enabling temporal reconstruction. MetalFX explicitly
   consumes color, depth, and motion inputs, so those buffers precede any
   upscaler integration.

   **Implemented baseline:** the native capture now writes five float AOVs plus
   a separate exact `rgba32Uint` identity pass. Current and previous procedural
   surface positions are paired by stable topology; retained feather vertices
   already carry both positions and stable IDs. A JSON audit qualifies finite
   pixels, extended-range highlights, normalized fully covered normals, metric
   depth, ID visibility, motion sign/magnitude, and standing support orientation.
   A capability-gated MetalFX path now reconstructs from HDR, resolved device
   depth, and motion with Halton jitter and explicit history resets. It is
   promoted only against a separately rendered native-resolution oracle;
   opaque geometry does not receive a cosmetic reactive mask.

2. **Geometric feather LODs.** Replace the single blade with nested rachis,
   vane, barb-group, and silhouette-meshlet representations. Select LOD from
   projected coverage and motion, not a hard-coded device name. Object/mesh
   shaders can cull and emit only visible meshlets; the compute triangle path
   remains the deterministic fallback and parity oracle.

   **Implemented contour baseline:** final-output coverage now selects a closed
   vane, rachis, edge-barb aggregates, full barbs, and close-up barbules. At the
   standing showcase distance, thin overlapping ribbons root inside the vane
   and extend slightly beyond its side and terminal edges, so a hard plate is
   no longer the only silhouette primitive. The continuous vane remains the
   occlusion/coverage layer beneath them. These aggregates are estimated
   presentation geometry; future mesh-shader or curve emission can consume the
   same stable feather identity and LOD contract without changing anatomy.
   The current body fallback carries `2,688` stable contour identities at full
   showcase coverage; it deliberately remains a deterministic triangle oracle,
   while a future indirect meshlet path should visibility-cull the same records
   rather than lowering anatomical density to recover frame time.
   Showcase-scale humeral and scapular vanes now reuse that hierarchy but
   promote edge-only aggregates into paired interior barb bundles at `40 px`
   projected length. The topology-stable fallback is deliberately more costly;
   a future curve/meshlet path should emit and cull the same stable records.
   Live chord-`3` covert relief now settles against the proximal wing during
   deployment without changing width, chord, or identity. Future per-feather
   rachis/contact dynamics should replace this bounded presentation blend while
   preserving the same deterministic geometry and coverage oracle.
   Posterior class-`5` dorsal and mantle crown now shares that deployment state;
   projected dorsal vanes promote coarse edge aggregates into contained
   interior barb pairs without changing identity or detail-record count. A
   future curve/meshlet implementation should emit those same records directly
   and replace the bounded crown blend with coupled feather contact and airflow.
   Outer class-`6` scapular vanes now seat their visible crown beneath the live
   wing and carry parent-class rachis/barb identity through the triangle oracle.
   Interior barbs remain vane-bounded while terminal bundles preserve tip
   coverage. Future hardware should consume these same compact records in a
   GPU-resident curve or meshlet expansion, visibility-cull emitted detail, and
   replace the prescribed transverse blend with per-feather contact, bending,
   and airflow without reducing identity density or changing the AOV oracle.
   The class-`14`/class-`15` trailing-covert ranks now remain retained through
   the folded hold rather than deploying over an exposed continuity bed.
   Future per-feather contact should replace this always-present prescribed
   ownership while preserving the same identities, rank intervals, and exact
   expanded topology.
   Class-`7` ventral body feathers now expose separate stable subvane-continuity
   and visible-crown rachis records for `776` interior feathers, while boundary
   records preserve the accepted silhouette. The visible layer now uses
   `112`-byte retained analytic curves plus compact LOD interval records and a
   Metal temporal/AOV expansion pass; the continuity layer remains an occlusion
   oracle in the accepted surface stream. A first output-space handoff now
   activates at `480 px` feather length: `72` hashed barb pairs per side follow
   the changing crown in four connected curve intervals, replace the coarse
   edge aggregates, and retain temporal/AOV ownership. At ordinary coverage the
   curve work list is exactly empty. Metal now frustum-classifies conservative
   record bounds, performs a deterministic scan, emits compact interval work,
   and indirectly expands/draws only selected records. The next future-compute
   step is previous-depth occlusion, visibility-sized residency, and indirect
   meshlet or hardware-curve emission from the same `1,304`-feather tract
   inventory; the current expanded triangle stream remains the high-cost
   correctness oracle, not the final scaling path.
   The `270`-identity-per-side femoral field now has a compact, AOV-localized
   insertion-overlap oracle over rows `6...11`, courses `8...9`; the bounded
   width/tip envelope closes a transition seam without moving follicles or leg
   joints. The future-compute path should retain those root/vane records on the
   GPU, visibility-cull them into indirect curve or meshlet work, and replace
   the prescribed envelope with per-feather contact and bending while matching
   the accepted three-angle silhouette oracle.

3. **Measured appearance, bounded claims.** Implement an energy-bounded,
   anisotropic feather BSDF with separate eumelanin absorption, longitudinal
   structure, roughness, and thin-film/nanostructure terms. The SIGGRAPH 2022
   rock-dove work demonstrates why generic fiber or texture models miss
   characteristic feather appearance. Crow parameters remain estimated until
   matched measurements exist.

   **Implemented optical baseline:** body classes resolve two feather-local
   barb banks with identity-stable orientation, normal, and bounded roughness
   variation. The field follows retained vane coordinates through standing and
   takeoff, so it cannot swim in world or screen space, and it leaves geometry,
   depth, motion, and identity AOVs exact. The former blue/violet endpoint blend
   is now an eight-band `400...680 nm` visible-spectrum quadrature with
   broadband eumelanin absorption and a final normalized CIE 1931/linear-sRGB
   projection. A versioned profile separates Maia et al.'s comparative
   glossy-corvid constraints from renderer-only estimates, and the live shader
   evaluates complex Snell refraction, polarized Fresnel amplitudes, and an Airy
   internal-reflection sum using the published complex refractive indices and
   `110...180 nm` cortex interval. Key, fill, and sun now evaluate separate
   angular half-vector paths rather than sharing a normal-incidence or
   key-light result; an on-GPU probe matches independent FP64
   normal-through-grazing reference cases.
   A second versioned profile block drives normalized barb, proximal barbule,
   distal barbule, and transmission visibility. Its promoted path is a
   constant-time MSL port of Padrón-Griffe et al.'s analytic discontinuity-ray
   mask, source-pinned to the authors' MIT implementation. Independent barb and
   barbule interval probes match that implementation, while a dense spherical
   sweep enforces finite, nonnegative, bounded, normalized output. The previous
   projected-area regular-cross-section approximation remains a deterministic
   fallback. Analytic exactness applies to the paper's idealized cross section,
   not measured crow anatomy or explicit individual barb curves. The local
   thickness variation, coherence blend, volume
   return, and target-species mapping remain estimates: this is a
   wavelength-domain deterministic fallback, not a measured American-crow
   BSDF. The next material milestone is same-specimen American-crow
   gonioreflectance and cortex microscopy under measured illumination, followed
   by a fitted angular cortex/medulla/transmission model. The first
   projected-size hybrid handoff to explicit barb geometry now exists; the next
   renderer milestone is curve-aware self-shadowing and explicit barbules when
   those structures exceed their own pixel thresholds. Do not substitute
   further hand tuning for either measurement or geometry-aware visibility.

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
- Padrón-Griffe et al., [A Surface-based Appearance Model for Pennaceous Feathers](https://doi.org/10.1111/cgf.15235), *Computer Graphics Forum* 43(4), 2024, and the authors' [MIT reference implementation](https://github.com/juanraul8/PennaceousFeathersRendering).
- Harvey et al., [Measuring Spatially- and Directionally-varying Light Scattering from Biological Material](https://doi.org/10.3791/50254), *Journal of Visualized Experiments* 75 (2013).
- Zeltner et al., [Real-Time Neural Appearance Models](https://research.nvidia.com/labs/rtr/neural_appearance_models/), SIGGRAPH 2024.
