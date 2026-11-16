import hashlib,json,subprocess,time
from pathlib import Path
root=Path('/tmp/crow-correction-control-20261116')
out=root/'evidence';out.mkdir(exist_ok=False)
files=[root/'build/crow-correction-stop',root/'build/shaders/MetalRobo.metallib',root/'build/lib/libmetalrobo.dylib',Path('/tmp/crow-correction-stop.mm'),Path('/tmp/crow-schur-prototype.patch')]
(out/'inputs.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2)+'\n')
for label,tol in [('baseline','1e-10'),('tight','1e-12')]:
 cmd=[str(files[0]),str(files[1]),tol]; t=time.monotonic(); print('starting',label,flush=True)
 with (out/(label+'.jsonl')).open('wb') as so,(out/(label+'.stderr')).open('wb') as se:
  try: p=subprocess.run(cmd,cwd=root,stdout=so,stderr=se,timeout=180); status=p.returncode
  except subprocess.TimeoutExpired: status='timeout'
 (out/(label+'.command.json')).write_text(json.dumps({'argv':cmd,'exit':status,'elapsed_s':time.monotonic()-t},indent=2)+'\n')
 print('finished',label,status,flush=True)
