from pathlib import Path
p=Path('include/metalrobo/MetalDiscreteElasticRod.hpp');s=p.read_text();needle='''[[nodiscard]] const char* metalDiscreteElasticRodHostStatusName(''';block='''// Experimental free-rod local-origin submission. Positions are recentered in
// double precision before GPU packing and restored on publication. Attachments,
// rigid bindings, and tool collision are rejected; this does not implement
// local-frame coupling for MetalWorld or articulated wings.
[[nodiscard]] MetalDiscreteElasticRodDiagnostics
runMetalDiscreteElasticRodFreeLocalFrame(
    const DiscreteElasticRodModel& model,
    const MetalDiscreteElasticRodInput& input,
    MetalDiscreteElasticRodResult& output,
    const MetalDiscreteElasticRodConfig& config = {}
);

''';assert s.count(needle)==1;p.write_text(s.replace(needle,block+needle))
p=Path('src/metal/MetalDiscreteElasticRod.mm');s=p.read_text();needle='''const char* metalDiscreteElasticRodHostStatusName(''';block='''MetalDiscreteElasticRodDiagnostics
runMetalDiscreteElasticRodFreeLocalFrame(
    const DiscreteElasticRodModel& model,
    const MetalDiscreteElasticRodInput& input,
    MetalDiscreteElasticRodResult& output,
    const MetalDiscreteElasticRodConfig& config
) {
    MetalDiscreteElasticRodDiagnostics diagnostics;
    if (input.attachmentCount != 0u || !input.attachments.empty() ||
        input.rigidBodyCount != 0u || !input.rigidBodies.empty() ||
        !input.rigidBindings.empty() || input.toolModel != nullptr ||
        !input.toolPairs.empty() || !input.previousToolContacts.empty() ||
        config.tool.enabled) {
        return reject(std::move(diagnostics),
            MetalDiscreteElasticRodHostStatus::invalidConfiguration,
            "local-frame free rod does not support attachments, rigid bodies, or tool contact");
    }
    std::vector<DiscreteElasticRodState> localStates(input.states.begin(), input.states.end());
    std::vector<Vec3> origins;
    origins.reserve(localStates.size());
    for (auto& state : localStates) {
        if (state.positions.empty() || !finite(state.positions.front())) {
            return reject(std::move(diagnostics),
                MetalDiscreteElasticRodHostStatus::invalidState,
                "local-frame rod requires a finite origin node");
        }
        const Vec3 origin = state.positions.front();
        origins.push_back(origin);
        for (auto& position : state.positions) {
            for (std::size_t axis = 0u; axis < 3u; ++axis) position[axis] -= origin[axis];
        }
    }
    MetalDiscreteElasticRodInput localInput = input;
    localInput.states = localStates;
    MetalDiscreteElasticRodResult staged;
    diagnostics = runMetalDiscreteElasticRod(model, localInput, staged, config);
    if (!diagnostics.succeeded()) return diagnostics;
    for (std::size_t env = 0u; env < staged.states.size(); ++env) {
        for (auto& position : staged.states[env].positions) {
            for (std::size_t axis = 0u; axis < 3u; ++axis) position[axis] += origins[env][axis];
            if (!finite(position)) {
                diagnostics.published = false;
                return reject(std::move(diagnostics),
                    MetalDiscreteElasticRodHostStatus::internalFailure,
                    "local-frame world position is non-finite");
            }
        }
    }
    output = std::move(staged);
    return diagnostics;
}

''';assert s.count(needle)==1;p.write_text(s.replace(needle,block+needle))
