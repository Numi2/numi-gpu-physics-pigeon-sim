#include "metalrobo/MetalUnifiedQualitySolver.hpp"
#include <array>
#include <iostream>
#include <limits>
int main() {
  for (bool hard : {true, false}) {
    MRUnifiedQualityBlockGPU block{};
    block.layout = {0u, 1u, MR_UNIFIED_QUALITY_SCALAR_INTERVAL,
        hard ? MR_UNIFIED_QUALITY_BLOCK_HARD_EQUALITY : 0u};
    block.stableKey = {501u, 0u, 0u, 0u};
    block.scale0 = block.scale1 = {1.0f,1.0f,1.0f,1.0f};
    block.regularization0 = {0.02f,1.0f,1.0f,1.0f};
    block.regularization1 = {1.0f,1.0f,1.0f,1.0f};
    block.boundsAndShift = {-std::numeric_limits<float>::max(),
                            std::numeric_limits<float>::max(),0.0f,0.0f};
    const std::array blocks{block};
    const std::array mass{1.0f}, jacobian{1.0f}, bias{0.08f}, zero{0.0f};
    metalrobo::MetalUnifiedQualityProblem problem;
    problem.problemCount=1u; problem.generalizedVelocityCount=1u; problem.rowCount=1u;
    problem.blocks=blocks; problem.dynamics=mass; problem.jacobian=jacobian;
    problem.bias=bias; problem.freeVelocity=zero; problem.warmVelocity=zero; problem.warmImpulses=zero;
    metalrobo::MetalUnifiedQualityConfig config;
    config.maximumNewtonIterations=40u; config.optimalityTolerance=1.0e-5f;
    config.feasibilityTolerance=2.0e-5f; config.directMaximumGeneralizedVelocities=64u;
    metalrobo::MetalUnifiedQualityResult result;
    auto d=metalrobo::solveMetalUnifiedQuality(problem,result,config);
    if (!d.succeeded() || result.statuses.size()!=1) {std::cerr << d.message << '\n'; return 2;}
    const auto &s=result.statuses[0];
    std::cout << "hard=" << hard << " code=" << s.code << " path=" << s.solvePath
              << " eq=" << s.certificates0.z << " vel=" << result.velocity[0]
              << " impulse=" << result.impulses[0] << '\n';
  }
}
