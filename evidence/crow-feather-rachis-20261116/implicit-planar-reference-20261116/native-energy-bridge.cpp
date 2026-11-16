#include "metalrobo/DiscreteElasticRod.hpp"
#include <algorithm>
#include <cmath>
using namespace metalrobo;
extern "C" double crow_native_energy(const double* q) {
 try {
  static auto m=[] { DiscreteRodMaterial mat{.radius=.00185,.density=1200,.youngModulus=2.129e9,.poissonRatio=.35}; auto model=makeStraightSutureRod(9,.025,mat);std::fill(model.bendStiffness.begin(),model.bendStiffness.end(),2.129e9*3.960e-12);std::fill(model.stretchStiffness.begin(),model.stretchStiffness.end(),2.129e9*3.449e-6);double mass=1200*3.449e-6*.025/8; for(int i=0;i<9;++i)model.nodeMasses[i]=(i==0||i==8)?.5*mass:mass;return model; }();
  auto s=makeDiscreteElasticRodDefaultState(m);for(int i=0;i<27;++i)s.positions[i/3][i%3]+=q[i];DiscreteElasticRodEnergy e;return evaluateDiscreteElasticRodEnergy(m,s,e).succeeded()?e.total():NAN;
 } catch (...) { return NAN; }
}
