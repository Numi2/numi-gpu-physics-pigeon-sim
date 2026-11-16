#define main crow_v15_structural_fixture_main
#include "test-wing-mechanics.cpp"
#undef main
#include "metalrobo/MetalWorld.hpp"
#include <iomanip>
#include <sstream>

static void array(const std::vector<float>& v) {
    std::cout << '[';
    for (size_t i=0;i<v.size();++i) { if(i) std::cout << ','; std::cout << v[i]; }
    std::cout << ']';
}

int main(int argc,char**argv) {
 try {
  if(argc!=2) throw std::runtime_error("expected metallib path");
  auto candidate=metalrobo::makeCrowArticulatedWingMechanicsFixture(crowHipRollModel());
  auto &m=candidate.mechanics;
  m.world.gravityAndTimestep.x=m.world.gravityAndTimestep.y=m.world.gravityAndTimestep.z=0;
  metalrobo::CompiledWorld compiled;
  auto compile=metalrobo::compileMetalWorld(m,0u,compiled);
  std::cout<<std::setprecision(9)<<"{\"compile_ok\":"<<(compile.succeeded()?"true":"false")<<",\"compile_message\":"<<std::quoted(compile.message)<<",\"fingerprint\":"<<compile.fingerprint;
  if(!compile.succeeded()) { std::cout<<"}\n"; return 2; }
  const auto &a=m.articulations.at(0);
  const auto it=std::find(m.dofNames.begin(),m.dofNames.end(),"crow_left_elbow_flex");
  if(it==m.dofNames.end()) throw std::runtime_error("left elbow missing");
  const auto &d=m.dofs.at(it-m.dofNames.begin());
  std::vector<float> initialQ=m.defaultQ,initialV=m.defaultV,zero(10*a.nv,0),pulse=zero;
  for(unsigned step=0;step<10;++step) pulse[step*a.nv+d.vIndex]=0.001f;
  metalrobo::MetalWorldConfig settings; settings.metallibPath=argv[1]; settings.preferParallelABA=false;
  metalrobo::MetalWorldContext context(settings);
  metalrobo::MetalWorldStepConfig cfg; cfg.timestepSeconds=0.001f;cfg.physicsSubsteps=8;cfg.solverMode=metalrobo::MetalWorldSolverMode::freeMotionABA;
  metalrobo::MetalWorldResult results[2];metalrobo::MetalWorldDiagnostics diagnostics[2];
  for(int i=0;i<2;++i) {
   metalrobo::MetalWorldBatch batch;batch.environmentCount=1;batch.controlStepCount=10;batch.initialQ=initialQ;batch.initialV=initialV;batch.efforts=i?std::span<const float>(pulse):std::span<const float>(zero);
   diagnostics[i]=context.run(compiled,batch,cfg,results[i]);
  }
  std::cout<<",\"nq\":"<<a.nq<<",\"nv\":"<<a.nv<<",\"elbow_q\":"<<d.qIndex<<",\"elbow_v\":"<<d.vIndex<<",\"runs\":[";
  for(int i=0;i<2;++i) {
   if(i)std::cout<<',';const auto &s=diagnostics[i];const auto &v=results[i];
   std::cout<<"{\"succeeded\":"<<(s.succeeded()?"true":"false")<<",\"dispatched\":"<<(s.dispatched?"true":"false")<<",\"published\":"<<(s.published?"true":"false")<<",\"successful_steps\":"<<s.successfulStepCount<<",\"failed_steps\":"<<s.failedStepCount<<",\"first_gpu_status\":"<<s.firstGPUStatusCode<<",\"message\":"<<std::quoted(s.message)<<",\"q\":";array(v.finalQ);std::cout<<",\"v\":";array(v.finalV);std::cout<<'}';
  }
  std::cout<<"]}\n";
  return diagnostics[0].succeeded()&&diagnostics[1].succeeded()?0:3;
 } catch(const std::exception& e) { std::cerr<<"exception: "<<e.what()<<'\n';return 4; }
}
