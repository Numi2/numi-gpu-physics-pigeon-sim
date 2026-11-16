import hashlib
import json
import subprocess
import time
from pathlib import Path

root = Path('/Users/n/Developer/numi-crow-articulated-wing-20261116')
out = root / 'build/wing-aero-extended-hold-20261116'
out.mkdir(exist_ok=False)
exe = root / 'build/wing-capacity-48/crow-aero-extended-hold'
audit = root / 'build/wing-capacity-48/crow-audit-wing-fold-path'
engine = root / 'build/wing-capacity-48/shaders/MetalRobo.metallib'
aero = root / 'build/wing-aero-element-20261116/wing-aero.metallib'
inputs = [exe, audit, engine, aero, root / 'tests/crow_v15_wing_fixture/aero-extended-hold.mm', root / 'tests/crow_v15_wing_fixture/audit-wing-fold-path.cpp', root / 'build/wing-capacity-48/lib/libmetalrobo.dylib']
(out / 'inputs.json').write_text(json.dumps({str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}, indent=2)+'\n')
def run(label, command):
    start=time.monotonic()
    r=subprocess.run([str(x) for x in command], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (out/f'{label}.json').write_bytes(r.stdout)
    (out/f'{label}.stderr').write_bytes(r.stderr)
    (out/f'{label}.command.json').write_text(json.dumps({'argv':[str(x) for x in command],'exit':r.returncode,'elapsed_s':time.monotonic()-start},indent=2)+'\n')
    print(f'{label}: exit={r.returncode}',flush=True)
    return r
r=run('fold',[exe,engine,aero])
try:
    data=json.loads(r.stdout)
    trajectory=data['trajectory']; nq=data['nq']; nv=data['nv']; stride=nq+nv
    if len(trajectory)!=960*3*stride:
        raise ValueError('no complete trajectory available for audit')
    for lane in range(3):
        qfile=out/f'poses-{lane}.txt'
        with qfile.open('w') as f:
            for step in range(1,960,2):
                start=(step*3+lane)*stride
                f.write(' '.join(map(str,trajectory[start:start+nq]))+'\n')
        run(f'audit-{lane}',[audit,engine,qfile])
except (ValueError,KeyError) as e:
    (out/'audit-skipped.txt').write_text(str(e)+'\n')
    print(f'audit skipped: {e}',flush=True)
