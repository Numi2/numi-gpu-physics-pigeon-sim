from pathlib import Path
import hashlib,json,subprocess,time
w=Path('/Users/n/Developer/numi-crow-articulated-wing-20261116');out=w/'build/wing-aero-passivity-20261116';out.mkdir(exist_ok=False)
exe=w/'build/wing-capacity-48/crow-aero-passivity';engine=w/'build/wing-capacity-48/shaders/MetalRobo.metallib';aero=w/'build/wing-aero-element-20261116/wing-aero.metallib';src=w/'tests/crow_v15_wing_fixture'
paths=[exe,engine,aero,w/'build/wing-capacity-48/lib/libmetalrobo.dylib',src/'aero-passivity.mm',src/'articulated-wing-aero.metal',src/'v15_fixture.hpp',src/'wing_model.hpp',w/'src/core/CrowArticulatedWing.cpp']
(out/'inputs.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},indent=2)+'\n');cmd=[str(exe),str(engine),str(aero)];(out/'command.json').write_text(json.dumps(cmd,indent=2)+'\n');t=time.time()
with (out/'stdout.json').open('w') as so,(out/'stderr.log').open('w') as se:q=subprocess.run(cmd,cwd=w,stdout=so,stderr=se)
result={'exit':q.returncode,'elapsed_s':time.time()-t};(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2),flush=True)
