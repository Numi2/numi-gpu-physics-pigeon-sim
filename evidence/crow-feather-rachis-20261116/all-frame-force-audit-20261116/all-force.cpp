#include "metalrobo/DiscreteElasticRod.hpp"
#include <algorithm>
#include <array>
#include <iomanip>
#include <iostream>
#include <stdexcept>
using namespace metalrobo;
int main(){try{
 constexpr double L=.025,E=2.129e9,I=3.960e-12,area=3.449e-6,radius=.00185,density=1200;
 DiscreteRodMaterial mat{.radius=radius,.density=density,.youngModulus=E,.poissonRatio=.35};
 auto m=makeStraightSutureRod(9,L,mat);std::fill(m.bendStiffness.begin(),m.bendStiffness.end(),E*I);std::fill(m.stretchStiffness.begin(),m.stretchStiffness.end(),E*area);
 double dm=density*area*L/8;for(unsigned i=0;i<9;++i)m.nodeMasses[i]=(i==0||i==8)?.5*dm:dm;
 const std::array hs{3e-9,1e-9,3e-10};std::cout<<std::setprecision(17);unsigned frame;
 while(std::cin>>frame){auto state=makeDiscreteElasticRodDefaultState(m);
  for(auto& p:state.positions)for(double& x:p)if(!(std::cin>>x))throw std::runtime_error("missing position");
  for(double& t:state.twists)if(!(std::cin>>t))throw std::runtime_error("missing twist");
  std::cout<<"{\"frame\":"<<frame<<",\"samples\":[";
  for(unsigned k=0;k<hs.size();++k){if(k)std::cout<<',';double h=hs[k];std::cout<<"{\"h\":"<<h<<",\"forces\":[";
   for(unsigned i=0;i<9;++i){if(i)std::cout<<',';std::cout<<'[';
    for(unsigned j=0;j<3;++j){if(j)std::cout<<',';auto pos=state;pos.positions[i][j]+=h;DiscreteElasticRodEnergy plus,minus;
     if(!evaluateDiscreteElasticRodEnergy(m,pos,plus).succeeded())throw std::runtime_error("plus energy");
     pos.positions[i][j]-=2*h;if(!evaluateDiscreteElasticRodEnergy(m,pos,minus).succeeded())throw std::runtime_error("minus energy");
     std::cout<<-(plus.total()-minus.total())/(2*h);
    }std::cout<<']';
   }std::cout<<"]}";
  }std::cout<<"]}"<<std::endl;
 }return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}}
