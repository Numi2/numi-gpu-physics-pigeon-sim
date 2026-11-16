import hashlib,json,subprocess,time
from pathlib import Path
root=Path('/Users/n/Developer/numi-crow-articulated-wing-20261116');out=root/'build/feather-midpoint-oracle-20261116';out.mkdir(exist_ok=False)
exe=root/'build/wing-capacity-48/crow-feather-midpoint-oracle';files=[exe,root/'build/wing-capacity-48/lib/libmetalrobo.dylib',root/'tests/crow_v15_wing_fixture/feather-midpoint-oracle.cpp']
(out/'inputs.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2)+'\n');cmd=[str(exe)];start=time.monotonic()
with (out/'stdout.jsonl').open('wb') as o,(out/'stderr.log').open('wb') as e:r=subprocess.run(cmd,cwd=root,stdout=o,stderr=e)
(out/'command.json').write_text(json.dumps({'argv':cmd,'exit':r.returncode,'elapsed_s':time.monotonic()-start},indent=2)+'\n');print('completed, exit=',r.returncode,flush=True)
