import hashlib,json,subprocess,time
from pathlib import Path
root=Path('/Users/n/Developer/numi-crow-articulated-wing-20261116');out=root/'build/feather-gate-regression-20261116';out.mkdir(exist_ok=False);build=root/'build/wing-capacity-48';shader=build/'shaders/MetalRobo.metallib';exe=build/'crow-feather-equality-gate';stationary=build/'crow-feather-predicted-position';ctest='/opt/homebrew/bin/ctest'
files=[shader,exe,stationary,build/'lib/libmetalrobo.dylib',build/'crow_v15_wing_dynamics_check'];(out/'inputs.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2)+'\n')
for name,cmd in [('damping0',[str(exe),str(shader),'0']),('damping100',[str(exe),str(shader),'100']),('stationary',[str(stationary),str(shader),'1','0']),('crow_ctest',[ctest,'--test-dir',str(build),'-R','^metalrobo.crow.v15_wing','--output-on-failure'])]:
 start=time.monotonic()
 with (out/(name+'.stdout')).open('wb') as o,(out/(name+'.stderr')).open('wb') as e:r=subprocess.run(cmd,cwd=root,stdout=o,stderr=e)
 (out/(name+'.command.json')).write_text(json.dumps({'argv':cmd,'exit':r.returncode,'elapsed_s':time.monotonic()-start},indent=2)+'\n');print(name,r.returncode,flush=True)
