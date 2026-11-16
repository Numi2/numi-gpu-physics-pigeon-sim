#include "metalrobo/DiscreteElasticRod.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <stdexcept>
using namespace metalrobo;
int main() {
 try {
  constexpr double L=.025,E=2.129e9,I=3.960e-12,area=3.449e-6,radius=.00185,density=1200;
  DiscreteRodMaterial mat{.radius=radius,.density=density,.youngModulus=E,.poissonRatio=.35};
  auto m=makeStraightSutureRod(9,L,mat);
  std::fill(m.bendStiffness.begin(),m.bendStiffness.end(),E*I);
  std::fill(m.stretchStiffness.begin(),m.stretchStiffness.end(),E*area);
  double dm=density*area*L/8; for(unsigned i=0;i<9;++i)m.nodeMasses[i]=(i==0||i==8)?0.5*dm:dm;
  auto state=makeDiscreteElasticRodDefaultState(m);
  for(unsigned i=0;i<9;++i) for(unsigned j=0;j<3;++j) if(!(std::cin>>state.positions[i][j]))throw std::runtime_error("missing position");
  for(unsigned i=0;i<8;++i) if(!(std::cin>>state.twists[i]))throw std::runtime_error("missing twist");
  std::cout<<std::setprecision(17)<<"[";
  const std::array steps{1e-8,3e-9,1e-9,3e-10,1e-10,3e-11};
  for(std::size_t hidx=0;hidx<steps.size();++hidx){
   if(hidx)std::cout<<',';double h=steps[hidx];std::cout<<"{\"h\":"<<h<<",\"forces\":[";
   for(unsigned i=0;i<9;++i){
    auto p=state;p.positions[i][1]+=h;DiscreteElasticRodEnergy plus,minus;
    if(!evaluateDiscreteElasticRodEnergy(m,p,plus).succeeded())throw std::runtime_error("plus energy failed");
    p.positions[i][1]-=2*h;
    if(!evaluateDiscreteElasticRodEnergy(m,p,minus).succeeded())throw std::runtime_error("minus energy failed");
    if(i)std::cout<<',';std::cout<<-(plus.total()-minus.total())/(2*h);
   }
   std::cout<<"]}";
  }
  std::cout<<"]\n";
 }catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}
}
