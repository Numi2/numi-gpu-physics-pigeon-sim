#include "v15_fixture.hpp"
#include "metalrobo/CrowArticulatedWing.hpp"
#include "metalrobo/ArticulatedDynamics.hpp"
#include <iomanip>
#include <algorithm>
#include <vector>
#include <string>
using namespace metalrobo;
template<class T> static void array(const T& a){std::cout<<'[';bool first=true;for(const auto& x:a){if(!first)std::cout<<',';first=false;std::cout<<x;}std::cout<<']';}
int main(){try{
 auto p=makeCrowArticulatedWingMechanicsFixture(crowHipRollModel());auto& m=p.mechanics;
 auto it=std::find(m.bodyNames.begin(),m.bodyNames.end(),"crow_left_hand");crowToeNeed(it!=m.bodyNames.end(),"hand missing");unsigned body=unsigned(it-m.bodyNames.begin());const auto& a=m.articulations.at(0);size_t n=a.nv;
 std::vector<double> q(m.defaultQ.begin(),m.defaultQ.end()),v(m.defaultV.begin(),m.defaultV.end()),J(3*n),M(n*n),X(3*n);
 std::vector<ArticulatedBodyKinematics> bodies(a.bodyCount);ArticulatedPointQuery point{body,{.008,.012,.003}};ArticulatedPointKinematics pk;
 auto k=computeArticulatedBodyKinematics(m,0,q,v,bodies);auto j=computeArticulatedPointJacobians(m,0,q,v,std::span(&point,1),std::span(&pk,1),J);auto mass=computeArticulatedMassMatrix(m,0,q,M);auto response=computeArticulatedInverseMassResponses(m,0,q,J,X);
 crowToeNeed(k.succeeded()&&j.succeeded()&&mass.succeeded()&&response.succeeded(),"native reference query failed");auto bt=std::find_if(bodies.begin(),bodies.end(),[&](const auto& b){return b.bodyIndex==body;});crowToeNeed(bt!=bodies.end(),"missing hand kinematics");
 std::cout<<std::setprecision(17)<<"{\"nv\":"<<n<<",\"body\":"<<body<<",\"hand_position\":";array(bt->centerOfMassPosition);std::cout<<",\"hand_orientation_xyzw\":";array(bt->orientation);std::cout<<",\"point\":";array(pk.position);std::cout<<",\"J\":";array(J);std::cout<<",\"M\":";array(M);std::cout<<",\"X\":";array(X);std::cout<<",\"dofs\":[";for(size_t i=0;i<m.dofNames.size();++i){if(i)std::cout<<',';std::cout<<"{\"name\":"<<std::quoted(m.dofNames[i])<<",\"v\":"<<m.dofs[i].vIndex<<'}';}std::cout<<"]}\n";
 return 0;
}catch(const std::exception& e){std::cerr<<"error "<<e.what()<<'\n';return 1;}}
