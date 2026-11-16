#include <cmath>
#include <algorithm>
#include "metalrobo/DiscreteElasticRod.hpp"
#include "metalrobo/MetalDiscreteElasticRod.hpp"
#include <array>
#include <iomanip>
#include <iostream>
#include <string>
#include <vector>

using namespace metalrobo;
constexpr double L=.025,E=2.129e9,I=3.960e-12,area=3.449e-6,radius=.00185,density=1200,delta=.000025,dh=.00000001;
DiscreteElasticRodModel model(unsigned n){DiscreteRodMaterial mat{.radius=radius,.density=density,.youngModulus=E,.poissonRatio=.35};auto m=makeStraightSutureRod(n,L,mat);m.name="related_crow_rachis_energy_instrument";m.fidelityBoundary="uniform short-segment surrogate; carrion crow sample";std::fill(m.bendStiffness.begin(),m.bendStiffness.end(),E*I);std::fill(m.stretchStiffness.begin(),m.stretchStiffness.end(),E*area);double dm=density*area*L/(n-1);for(unsigned j=0;j<n;++j)m.nodeMasses[j]=(j==0||j==n-1)?.5*dm:dm;return m;}
DiscreteElasticRodState shaped(const DiscreteElasticRodModel&m,double d){auto s=makeDiscreteElasticRodDefaultState(m);for(auto& p:s.positions){double x=p[0]/L;if(x>.5)x=1-x;p[1]=d*(3*x-4*x*x*x);}return s;}
double energy(const DiscreteElasticRodModel&m,double d){auto s=shaped(m,d);DiscreteElasticRodEnergy e;auto diag=evaluateDiscreteElasticRodEnergy(m,s,e);if(!diag.succeeded())throw std::runtime_error("energy reference failed");return e.total();}
void stateJson(const DiscreteElasticRodState&s){std::cout<<"[";for(size_t i=0;i<s.positions.size();++i){if(i)std::cout<<',';std::cout<<'[';for(int j=0;j<3;++j)std::cout<<s.positions[i][j]<<',';for(int j=0;j<3;++j){if(j)std::cout<<',';std::cout<<s.velocities[i][j];}std::cout<<']';}std::cout<<']';}
void emit(const char*backend,unsigned n,bool ok,const std::string&msg,const DiscreteElasticRodModel&m,const DiscreteElasticRodState&s){DiscreteElasticRodEnergy e;auto d=evaluateDiscreteElasticRodEnergy(m,s,e);if(!d.succeeded())throw std::runtime_error("cannot evaluate post energy");double k=0;for(size_t i=0;i<s.positions.size();++i)for(int a=0;a<3;++a)k+=.5*m.nodeMasses[i]*s.velocities[i][a]*s.velocities[i][a];for(size_t i=0;i<s.twists.size();++i)k+=.5*m.edgeRotationalInertias[i]*s.twistRates[i]*s.twistRates[i];std::cout<<"{\"backend\":"<<std::quoted(backend)<<",\"nodes\":"<<n<<",\"success\":"<<(ok?"true":"false")<<",\"message\":"<<std::quoted(msg)<<",\"elastic\":"<<e.total()<<",\"kinetic\":"<<k<<",\"state\":";stateJson(s);std::cout<<",\"twists\":[";for(size_t i=0;i<s.twists.size();++i){if(i)std::cout<<',';std::cout<<'['<<s.twists[i]<<','<<s.twistRates[i]<<']';}std::cout<<"]}\n";}

// Research-only planar fixed-x/z numerical oracle for the native rod energy.
// This is not a physical 3D feather or a production integration path.
constexpr int N=9; constexpr double h=.000125, gradStep=1e-9, jacStep=1e-7;
using Vec=std::array<double,N>;using Mat=std::array<std::array<double,N>,N>;
double potential(const DiscreteElasticRodModel&m,DiscreteElasticRodState s,const Vec& y){for(int i=0;i<N;++i)s.positions[i][1]=y[i];DiscreteElasticRodEnergy e;auto d=evaluateDiscreteElasticRodEnergy(m,s,e);if(!d.succeeded())throw std::runtime_error("energy");return e.total();}
Vec residual(const DiscreteElasticRodModel&m,const DiscreteElasticRodState&s,const Vec&q){Vec mid{},r{};for(int i=0;i<N;++i)mid[i]=.5*(s.positions[i][1]+q[i]);for(int i=0;i<N;++i){auto p=mid;p[i]+=gradStep;double ep=potential(m,s,p);p[i]-=2*gradStep;double em=potential(m,s,p);double force=(ep-em)/(2*gradStep);r[i]=2*m.nodeMasses[i]*(q[i]-s.positions[i][1]-h*s.velocities[i][1])/(h*h)+force;}return r;}
bool solve(Mat a,Vec b,Vec&x){for(int k=0;k<N;++k){int p=k;for(int i=k+1;i<N;++i)if(std::abs(a[i][k])>std::abs(a[p][k]))p=i;if(!(std::abs(a[p][k])>1e-12))return false;std::swap(a[p],a[k]);std::swap(b[p],b[k]);for(int i=k+1;i<N;++i){double v=a[i][k]/a[k][k];for(int j=k;j<N;++j)a[i][j]-=v*a[k][j];b[i]-=v*b[k];}}for(int i=N-1;i>=0;--i){double v=b[i];for(int j=i+1;j<N;++j)v-=a[i][j]*x[j];x[i]=v/a[i][i];}return true;}


extern "C" double crow_native_energy(const double*q){try{static auto m=model(9);auto s=makeDiscreteElasticRodDefaultState(m);for(int i=0;i<27;++i)s.positions[i/3][i%3]+=q[i];DiscreteElasticRodEnergy e;auto d=evaluateDiscreteElasticRodEnergy(m,s,e);return d.succeeded()?e.total():NAN;}catch(...){return NAN;}}
extern "C" int crow_native_acceleration(const double*q,double*out){try{static auto m=model(9);auto state=makeDiscreteElasticRodDefaultState(m);for(int i=0;i<27;++i)state.positions[i/3][i%3]+=q[i];for(int i=0;i<27;++i){double &x=state.positions[i/3][i%3];x+=1e-9;DiscreteElasticRodEnergy plus;auto a=evaluateDiscreteElasticRodEnergy(m,state,plus);x-=2e-9;DiscreteElasticRodEnergy minus;auto b=evaluateDiscreteElasticRodEnergy(m,state,minus);x+=1e-9;if(!a.succeeded()||!b.succeeded())return 1;double mass=m.nodeMasses[i/3];if(i/3==0||i/3==8)mass+=.00012;if(i/3==4)mass+=.00015;out[i]=-(plus.total()-minus.total())/(2e-9*mass);}return 0;}catch(...){return 2;}}
