import hashlib
import json
import subprocess
import time
from pathlib import Path

root = Path('/Users/n/Developer/numi-crow-articulated-wing-20261116')
out = root / 'build/wing-aero-timestep-20261116'
out.mkdir(exist_ok=False)
exe = root / 'build/wing-capacity-48/crow-aero-timestep'
engine = root / 'build/wing-capacity-48/shaders/MetalRobo.metallib'
aero = root / 'build/wing-aero-element-20261116/wing-aero.metallib'
source = root / 'tests/crow_v15_wing_fixture/aero-timestep.mm'
inputs = [exe, engine, aero, source, root / 'build/wing-capacity-48/lib/libmetalrobo.dylib']
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
(out / 'inputs.json').write_text(json.dumps({str(p): digest(p) for p in inputs}, indent=2) + '\n')
for microsteps in (4, 8, 16, 32):
    command = [str(exe), str(engine), str(aero), str(microsteps)]
    start = time.monotonic()
    result = subprocess.run(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (out / f'stdout-{microsteps}.json').write_bytes(result.stdout)
    (out / f'stderr-{microsteps}.log').write_bytes(result.stderr)
    (out / f'command-{microsteps}.json').write_text(json.dumps({'argv': command, 'exit': result.returncode, 'elapsed_s': time.monotonic()-start}, indent=2)+'\n')
    print(f'microsteps={microsteps} exit={result.returncode}', flush=True)
