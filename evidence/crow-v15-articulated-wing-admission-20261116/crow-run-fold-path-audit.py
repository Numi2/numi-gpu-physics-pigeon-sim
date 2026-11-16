from pathlib import Path
import hashlib,json,subprocess,time
w=Path('/Users/n/Developer/numi-crow-articulated-wing-20261116');out=w/'build/wing-fold-path-audit-20261116';out.mkdir(exist_ok=False)
source=w/'build/wing-continuous-fold-20261116/stdout.json';x=json.loads(source.read_text());assert x['steps']==480 and x['nq']==47 and x['nv']==46
trajectory=x['trajectory_qv'];assert len(trajectory)==480*93
table=out/'recorded_q.tsv';table.write_text(''.join(' '.join(str(v) for v in trajectory[i*93:i*93+47])+'\n' for i in range(480)))
exe=w/'build/wing-capacity-48/crow-audit-wing-fold-path';shader=w/'build/wing-capacity-48/shaders/MetalRobo.metallib';cmd=[str(exe),str(shader),str(table)]
paths=[source,table,exe,shader,w/'build/wing-capacity-48/lib/libmetalrobo.dylib',w/'tests/crow_v15_wing_fixture/audit-wing-fold-path.cpp',w/'tests/crow_v15_wing_fixture/v15_fixture.hpp',w/'tests/crow_v15_wing_fixture/wing_model.hpp',w/'src/core/CrowArticulatedWing.cpp']
(out/'inputs.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},indent=2)+'\n');(out/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
t=time.time()
with (out/'stdout.json').open('w') as so,(out/'stderr.log').open('w') as se:q=subprocess.run(cmd,cwd=w,stdout=so,stderr=se)
result={'exit':q.returncode,'elapsed_s':time.time()-t}
if q.returncode==0:
 audit=json.loads((out/'stdout.json').read_text());result['model_identity_matches']=audit['fingerprint']==x['fingerprint'];result['samples']=len(audit['samples'])
(out/'run.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
