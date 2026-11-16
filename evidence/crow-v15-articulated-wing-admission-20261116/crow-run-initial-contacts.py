from pathlib import Path
import hashlib,json,subprocess,time
w=Path('/Users/n/Developer/numi-crow-articulated-wing-20261116')
out=w/'build/wing-initial-contacts-20261116';out.mkdir(exist_ok=False)
exe=w/'build/wing-capacity-48/crow-initial-wing-contacts';shader=w/'build/wing-capacity-48/shaders/MetalRobo.metallib'
cmd=[str(exe),str(shader)]
paths=[exe,shader,w/'build/wing-capacity-48/lib/libmetalrobo.dylib',w/'tests/crow_v15_wing_fixture/initial-wing-contacts.cpp',w/'tests/crow_v15_wing_fixture/v15_fixture.hpp',w/'tests/crow_v15_wing_fixture/wing_model.hpp',w/'src/core/CrowArticulatedWing.cpp']
(out/'inputs.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},indent=2)+'\n')
(out/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
t=time.time()
with (out/'stdout.json').open('w') as so,(out/'stderr.log').open('w') as se:q=subprocess.run(cmd,cwd=w,stdout=so,stderr=se)
print(json.dumps({'exit':q.returncode,'elapsed_s':time.time()-t},indent=2))
(out/'run.json').write_text(json.dumps({'exit':q.returncode,'elapsed_s':time.time()-t},indent=2)+'\n')
