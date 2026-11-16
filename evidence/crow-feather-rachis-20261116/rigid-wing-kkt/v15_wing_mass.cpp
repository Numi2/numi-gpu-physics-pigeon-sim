#include "v15_fixture.hpp"
#include "metalrobo/CrowArticulatedWing.hpp"
#include <iostream>
#include <iomanip>
int main(){auto fixture=metalrobo::makeCrowArticulatedWingMechanicsFixture(crowHipRollModel());const auto&m=fixture.mechanics;std::cout<<std::setprecision(17);for(size_t i=0;i<m.bodies.size();++i){auto name=i<m.bodyNames.size()?m.bodyNames[i]:"";if(name.find("wing")==std::string::npos&&name.find("hand")==std::string::npos&&name.find("forearm")==std::string::npos)continue;auto b=m.bodies[i];std::cout<<"{\"index\":"<<i<<",\"name\":\""<<name<<"\",\"mass_kg\":"<<b.massAndInverseMass.x<<",\"inertia_diagonal_kg_m2\":["<<b.inertiaRow0.x<<','<<b.inertiaRow1.y<<','<<b.inertiaRow2.z<<"]}"<<std::endl;}}
