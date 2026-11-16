from pathlib import Path
import hashlib,json,subprocess,time
w=Path('/Users/n/Developer/numi-crow-articulated-wing-20261116')
out=w/'build/wing-v3-bone-capsule-trial-20261116';out.mkdir(exist_ok=False)
shader=w/'build/wing-capacity-48/shaders/MetalRobo.metallib'
executables=[w/'build/wing-capacity-48/crow-initial-wing-contacts',w/'build/wing-capacity-48/crow_v15_wing_dynamics_check',w/'build/wing-capacity-48/crow-wing-fold-sweep']
paths=[*executables,shader,w/'build/wing-capacity-48/lib/libmetalrobo.dylib',w/'tests/crow_v15_wing_fixture/initial-wing-contacts.cpp',w/'tests/crow_v15_wing_fixture/direct-wing-dynamics.cpp',w/'tests/crow_v15_wing_fixture/wing-fold-sweep.cpp',w/'tests/crow_v15_wing_fixture/v15_fixture.hpp',w/'tests/crow_v15_wing_fixture/wing_model.hpp',w/'src/core/CrowArticulatedWing.cpp']
(out/'inputs.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},indent=2)+'\n')
for name,cmd in [('initial',[str(executables[0]),str(shader)]),('ten_step',[str(executables[1]),str(shader),'contact']),('fold_sweep',[str(executables[2]),str(shader)])]:
 (out/(name+'.command.json')).write_text(json.dumps(cmd,indent=2)+'\n')
 start=time.time()
 with (out/(name+'.stdout.json')).open('w') as so,(out/(name+'.stderr')).open('w') as se:q=subprocess.run(cmd,cwd=w,stdout=so,stderr=se)
 result={'exit':q.returncode,'elapsed_s':time.time()-start};(out/(name+'.result.json')).write_text(json.dumps(result,indent=2)+'\n');print(name,result,flush=True)
