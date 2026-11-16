#include "metalrobo/DiscreteElasticRod.hpp"
#include <algorithm>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <vector>
using namespace metalrobo;
constexpr double L=.025,E=2.129e9,I=3.960e-12,A=3.449e-6,R=.00185,rho=1200,delta=.000025,h=.001;
int main(int argc,char**argv) {
 if(argc!=2) return 1; const double damping=std::stod(argv[1]);
 DiscreteRodMaterial mat{.radius=R,.density=rho,.youngModulus=E,.poissonRatio=.35};
 auto m=makeStraightSutureRod(9,L,mat);
 std::fill(m.bendStiffness.begin(),m.bendStiffness.end(),E*I);
 std::fill(m.stretchStiffness.begin(),m.stretchStiffness.end(),E*A);
 double mass=rho*A*L/8; for(int i=0;i<9;++i)m.nodeMasses[i]=(i==0||i==8)?.5*mass:mass;
 auto s=makeDiscreteElasticRodDefaultState(m);
 for(auto&p:s.positions){double x=p[0]/L; if(x>.5)x=1-x; p[1]=delta*(3*x-4*x*x*x);}
 auto initial=s;
 std::vector<DiscreteRodAttachment> supports{{.nodeIndex=0,.targetPosition={0,0,0}},{.nodeIndex=4,.targetPosition={L/2,delta,0}},{.nodeIndex=8,.targetPosition={L,0,0}}};
 DiscreteElasticRodStepConfig c; c.timestep=h;c.gravity={0,0,0};c.solverIterations=4096;c.constraintTolerance=1e-10;c.linearDamping=damping;c.twistDamping=100;
 auto d=stepDiscreteElasticRodCpu(m,s,supports,c);
 std::cout<<std::setprecision(17)<<"{\"damping\":"<<damping<<",\"ok\":"<<(d.succeeded()?"true":"false")<<",\"status\":"<<static_cast<int>(d.status)<<",\"iterations\":"<<d.iterations<<",\"before\":"<<d.before.total()<<",\"after\":"<<d.after.total()<<",\"positions\":[";
 for(int i=0;i<9;++i){if(i)std::cout<<',';std::cout<<'['<<s.positions[i][0]<<','<<s.positions[i][1]<<','<<s.positions[i][2]<<']';}
 std::cout<<"],\"velocities\":[";for(int i=0;i<9;++i){if(i)std::cout<<',';std::cout<<'['<<s.velocities[i][0]<<','<<s.velocities[i][1]<<','<<s.velocities[i][2]<<']';}
 std::cout<<"],\"forces_y\":[";double maxres=0;
 for(int i=0;i<9;++i){auto p=s;DiscreteElasticRodEnergy ep,em;p.positions[i][1]+=1e-9;if(!evaluateDiscreteElasticRodEnergy(m,p,ep).succeeded())return 2;p.positions[i][1]-=2e-9;if(!evaluateDiscreteElasticRodEnergy(m,p,em).succeeded())return 2;double f=-(ep.total()-em.total())/2e-9;if(i)std::cout<<',';std::cout<<f;if(i!=0&&i!=4&&i!=8)maxres=std::max(maxres,std::abs(m.nodeMasses[i]*(s.positions[i][1]-initial.positions[i][1])/(h*h)-f));}
 std::cout<<"],\"max_configuration_force_residual\":"<<maxres<<"}\n";return d.succeeded()?0:3;
}
