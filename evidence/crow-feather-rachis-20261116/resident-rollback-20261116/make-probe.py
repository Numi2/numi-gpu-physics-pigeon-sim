from pathlib import Path
here=Path(__file__).resolve().parent
s=(here.parent/'resident-trajectory-20261116/resident-trajectory.mm').read_text()
s=s.replace('if(argc!=4)throw std::runtime_error("expected metallib, damping, steps");double damping=std::stod(argv[2]);unsigned steps=std::stoul(argv[3]);','if(argc!=5)throw std::runtime_error("expected metallib, damping, steps, injection");double damping=std::stod(argv[2]);unsigned steps=std::stoul(argv[3]);bool inject=std::stoi(argv[4])!=0;')
s=s.replace('using namespace metalrobo;','''using namespace metalrobo;
template<class T>std::string hexBytes(const std::vector<T>& v){static const char* digits="0123456789abcdef";auto p=reinterpret_cast<const unsigned char*>(v.data());std::string s;for(size_t i=0;i<v.size()*sizeof(T);++i){s.push_back(digits[p[i]>>4]);s.push_back(digits[p[i]&15]);}return s;}
''')
s=s.replace('for(unsigned step=0;step<steps;++step){MetalWorldSubmission submission;', 'for(unsigned step=0;step<steps;++step){cfg.quality.feasibilityTolerance=(inject && step==1)?1e-12f:2e-5f;MetalWorldSubmission submission;')
a=s.index('if(!d.succeeded()||!d.published||d.successfulStepCount!=1')
b=s.index('\n  auto state=initial;',a)
s=s[:a]+'''std::cout<<"{\\"event\\":\\"status\\",\\"step\\":"<<step+1<<",\\"succeeded\\":"<<(d.succeeded()?"true":"false")<<",\\"dispatched\\":"<<(d.dispatched?"true":"false")<<",\\"published\\":"<<(d.published?"true":"false")<<",\\"successful_steps\\":"<<d.successfulStepCount<<",\\"failed_steps\\":"<<d.failedStepCount<<",\\"gpu_status\\":"<<d.firstGPUStatusCode<<",\\"message\\":"<<std::quoted(d.message)<<"}"<<std::endl;
 if(!d.published||out.finalRodNodes.size()!=9||out.finalRodEdges.size()!=8||out.finalQ.size()!=bm.defaultQ.size()||out.finalV.size()!=bm.defaultV.size()){ok=false;break;}
 std::cout<<"{\\"event\\":\\"state_bytes\\",\\"step\\":"<<step+1<<",\\"q\\":"<<std::quoted(hexBytes(out.finalQ))<<",\\"v\\":"<<std::quoted(hexBytes(out.finalV))<<",\\"bodies\\":"<<std::quoted(hexBytes(out.finalSceneBodies))<<",\\"rod_nodes\\":"<<std::quoted(hexBytes(out.finalRodNodes))<<",\\"rod_edges\\":"<<std::quoted(hexBytes(out.finalRodEdges))<<"}"<<std::endl;''' + s[b:]
(here/'rollback-probe.mm').write_text(s)
