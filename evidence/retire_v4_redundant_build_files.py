from pathlib import Path
import hashlib,json,subprocess
m=json.loads(Path('/tmp/v4-redundant-build-files-sha256.json').read_text());assert len(m)==28
for raw,want in m.items():
 p=Path(raw);assert p.is_file() and not p.is_symlink() and '/build/crow-v15-recorded-restart-20261114/neural-balance-v4-update-0' in str(p)
 assert not any(f'update-0{i}' in str(p) for i in (8,9))
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 assert h.hexdigest()==want,p
 q=subprocess.run(['/usr/sbin/lsof',str(p)],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
 assert q.returncode==1 and not q.stdout,(p,q.returncode,q.stderr)
print('verified 28 archived inactive files',flush=True);subprocess.run(['df','-k',str(Path(next(iter(m))).parent)],check=True)
for raw in m:Path(raw).unlink()
subprocess.run(['df','-k',str(Path(next(iter(m))).parent)],check=True)
