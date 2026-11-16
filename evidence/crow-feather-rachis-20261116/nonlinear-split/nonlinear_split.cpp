#include <fstream>
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


struct Inputs {float U[729],root[27],omega[27],q[27],v[27],dt;};
int main(int argc,char**argv){try{
 if(argc!=3)throw std::runtime_error("expected modal input and GPU trajectory");Inputs in{};std::ifstream f(argv[1],std::ios::binary);f.read(reinterpret_cast<char*>(&in),sizeof(in));if(!f||f.peek()!=std::char_traits<char>::eof())throw std::runtime_error("bad modal input");std::vector<float> gpu(80*81);std::ifstream g(argv[2],std::ios::binary);g.read(reinterpret_cast<char*>(gpu.data()),gpu.size()*sizeof(float));if(!g||g.peek()!=std::char_traits<char>::eof())throw std::runtime_error("bad GPU trajectory");
 auto m=model(9);auto rest=makeDiscreteElasticRodDefaultState(m);double eff[9];for(int i=0;i<9;++i)eff[i]=m.nodeMasses[i];eff[0]+=.00012;eff[4]+=.00015;eff[8]+=.00012;
 auto energy=[&](const DiscreteElasticRodState&s){DiscreteElasticRodEnergy e;auto d=evaluateDiscreteElasticRodEnergy(m,s,e);if(!d.succeeded())throw std::runtime_error("energy failed");return e.total();};
 using Vec27=std::array<double,27>;auto physical=[&](const Vec27&mode){Vec27 x{};for(int i=0;i<27;++i){for(int j=0;j<27;++j)x[i]+=double(in.U[i*27+j])*mode[j];x[i]/=in.root[i];}return x;};
 Vec27 qinit{},vinit{};for(int j=0;j<27;++j)for(int i=0;i<27;++i){double basis=double(in.U[i*27+j])*in.root[i];qinit[j]+=basis*in.q[i];vinit[j]+=basis*in.v[i];}
 auto evaluate=[&](const Vec27&q,const Vec27&v){auto x=physical(q),vel=physical(v);auto state=rest;double kinetic=0;for(int i=0;i<27;++i){state.positions[i/3][i%3]+=x[i];kinetic+=.5*eff[i/3]*vel[i]*vel[i];}return energy(state)+kinetic;};
 auto kick=[&](const Vec27&q,Vec27&v){auto x=physical(q);auto state=rest;for(int i=0;i<27;++i)state.positions[i/3][i%3]+=x[i];Vec27 delta{};for(int i=0;i<27;++i){auto plus=state,minus=state;plus.positions[i/3][i%3]+=1e-9;minus.positions[i/3][i%3]-=1e-9;double grad=(energy(plus)-energy(minus))/(2e-9),linear=0;for(int j=0;j<27;++j)linear+=double(in.U[i*27+j])*in.omega[j]*in.omega[j]*q[j];delta[i]=in.root[i]*linear-grad;}for(int j=0;j<27;++j){double f=0;for(int i=0;i<27;++i)f+=double(in.U[i*27+j])*delta[i]/in.root[i];v[j]+=.5*double(in.dt)*f;}};
 auto step=[&](Vec27&q,Vec27&v,bool corrected){if(corrected)kick(q,v);for(int j=0;j<27;++j){double w=in.omega[j],p=q[j],u=v[j];if(w==0){q[j]=p+in.dt*u;v[j]=u;}else{double c=std::cos(w*double(in.dt)),s=std::sin(w*double(in.dt));q[j]=c*p+s*u/w;v[j]=-w*s*p+c*u;}}if(corrected)kick(q,v);};
 std::cout<<std::setprecision(17);for(int mode=0;mode<2;++mode){auto q=qinit,v=vinit;double initial=evaluate(q,v),maxEnergy=0,maxGpu=0;for(int k=0;k<80;++k){step(q,v,mode!=0);double total=evaluate(q,v),drift=std::abs(total-initial)/initial;maxEnergy=std::max(maxEnergy,drift);auto x=physical(q);if(mode==0)for(int i=0;i<27;++i)maxGpu=std::max(maxGpu,std::abs(x[i]-gpu[k*81+i]));std::cout<<"{\"mode\":\""<<(mode?"nonlinear_split":"linear")<<"\",\"step\":"<<k+1<<",\"total_energy_J\":"<<total<<",\"relative_energy_error\":"<<drift<<",\"position_m\":[";for(int i=0;i<27;++i){if(i)std::cout<<',';std::cout<<x[i];}std::cout<<"]}"<<std::endl;}
 for(double &x:v)x=-x;for(int k=0;k<80;++k)step(q,v,mode!=0);auto x=physical(q),original=physical(qinit);double reverse=0;for(int i=0;i<27;++i)reverse=std::max(reverse,std::abs(x[i]-original[i]));std::cout<<"{\"event\":\"summary\",\"mode\":\""<<(mode?"nonlinear_split":"linear")<<"\",\"max_energy_error\":"<<maxEnergy<<",\"max_gpu_position_difference_m\":"<<maxGpu<<",\"reversal_position_error_m\":"<<reverse<<"}"<<std::endl;}
 return 0;}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}}
