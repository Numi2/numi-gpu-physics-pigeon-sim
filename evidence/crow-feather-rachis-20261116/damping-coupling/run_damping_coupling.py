import hashlib,json,subprocess,time
from pathlib import Path
root=Path('/Users/n/Developer/numi-crow-articulated-wing-20261116')
out=Path('/tmp/crow-damping-coupling-evidence');out.mkdir(exist_ok=False)
files=[Path('/tmp/crow-damping-coupling'),root/'build/wing-capacity-48/shaders/MetalRobo.metallib',root/'build/wing-capacity-48/lib/libmetalrobo.dylib',Path('/tmp/crow-damping-coupling.mm'),Path('/tmp/crow-schur-prototype.patch'),root/'src/metal/MetalUnifiedQualitySolver.metal']
(out/'inputs.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2)+'\n')
for label,damping in [('configured','100'),('undamped','0')]:
 cmd=[str(files[0]),str(files[1]),damping]; t=time.monotonic(); print('starting',label,flush=True)
 with (out/(label+'.jsonl')).open('wb') as so,(out/(label+'.stderr')).open('wb') as se:
  try: p=subprocess.run(cmd,cwd=root,stdout=so,stderr=se,timeout=120); status=p.returncode
  except subprocess.TimeoutExpired: status='timeout'
 (out/(label+'.command.json')).write_text(json.dumps({'argv':cmd,'exit':status,'elapsed_s':time.monotonic()-t},indent=2)+'\n')
 print('finished',label,status,flush=True)
