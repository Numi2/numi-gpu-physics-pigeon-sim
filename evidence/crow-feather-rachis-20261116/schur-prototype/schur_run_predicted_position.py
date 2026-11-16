import hashlib,json,subprocess,time
from pathlib import Path
root=Path('/Users/n/Developer/numi-crow-articulated-wing-20261116')
out=root/'build/feather-predicted-position-schur-20261116';out.mkdir(exist_ok=False)
exe=root/'build/wing-capacity-48/crow-feather-predicted-position';shader=root/'build/wing-capacity-48/shaders/MetalRobo.metallib'
files=[exe,shader,root/'build/wing-capacity-48/lib/libmetalrobo.dylib',root/'tests/crow_v15_wing_fixture/feather-predicted-position.mm']
(out/'inputs.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2)+'\n')
for mode in (0,1):
 for sign in (-1,1):
  cmd=[str(exe),str(shader),str(mode),str(sign*0.01)];start=time.monotonic();name=f'mode{mode}_sign{sign}'
  with (out/(name+'.jsonl')).open('wb') as stdout,(out/(name+'.stderr')).open('wb') as stderr:r=subprocess.run(cmd,cwd=root,stdout=stdout,stderr=stderr)
  (out/(name+'.command.json')).write_text(json.dumps({'argv':cmd,'exit':r.returncode,'elapsed_s':time.monotonic()-start},indent=2)+'\n')
  print(name,r.returncode,flush=True)
