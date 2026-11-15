"""Link existing read-only target logging with the toe-sensing experiment host."""
from pathlib import Path
import hashlib, json, subprocess

r = Path('/Users/n/Developer/numi-crow-rl-20261107')
a = r / 'artifacts/crow-v15-recorded-restart-20261114'
b = r / 'build/crow-v15-recorded-restart-20261114'
source = json.loads((a / 'toe-sensing-host-build.json').read_text())
link = source['link'].copy()
old = str(b / 'MetalWorld-full-contact-observer.mm.o')
new = str(b / 'MetalWorld-drive-target-observer.mm.o')
assert link.count(old) == 1 and Path(new).is_file()
link[link.index(old)] = new
out = b / 'toe-sensing-target-observer/libmetalrobo.dylib'
out.parent.mkdir(exist_ok=True)
assert not out.exists()
link[link.index('-o') + 1] = str(out)
subprocess.run(link, cwd=r / 'build', check=True)
record = {'link': link, 'scope': 'read-only drive target observer; physical parity must be tested',
          'sha256': {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in (Path(new), out)}}
(a / 'toe-sensing-target-observer-build.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record['sha256'], indent=2))
