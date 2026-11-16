import hashlib
import json
import subprocess
import time
from pathlib import Path

root=Path('/Users/n/Developer/numi-crow-articulated-wing-20261116')
out=root/'build/feather-world-duration-20261116'
out.mkdir(exist_ok=False)
exe=root/'build/wing-capacity-48/crow-feather-world-duration'
shader=root/'build/wing-capacity-48/shaders/MetalRobo.metallib'
files=[exe,shader,root/'build/wing-capacity-48/lib/libmetalrobo.dylib',root/'tests/crow_v15_wing_fixture/feather-world-duration.mm']
(out/'inputs.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2)+'\n')
cmd=[str(exe),str(shader)]
start=time.monotonic()
with (out/'stdout.jsonl').open('wb') as stdout,(out/'stderr.log').open('wb') as stderr:
    r=subprocess.run(cmd,cwd=root,stdout=stdout,stderr=stderr)
(out/'command.json').write_text(json.dumps({'argv':cmd,'exit':r.returncode,'elapsed_s':time.monotonic()-start},indent=2)+'\n')
print(f'completed, exit={r.returncode}',flush=True)
