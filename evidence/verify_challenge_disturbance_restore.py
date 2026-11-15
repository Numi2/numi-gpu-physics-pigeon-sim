import hashlib,subprocess,tarfile,tempfile,os
from pathlib import Path
repo='/private/tmp/crow-balance-evidence-verify-20261115.git'
expected={'neural-v3-long-challenge-20261115.tar.gz':'05c980f65b587b10444f3909a6b5a0a50763019a569209edfa6464af340ec0a9','neural-v3-disturbance-20261115.tar.gz':'069d5d545a8b3e97f54d3a520d7db1d25b0908f9fa51393a722cb03f9b394d00'}
for name,want in expected.items():
 h=hashlib.sha256()
 with tempfile.NamedTemporaryFile(prefix='crow-restored-',suffix='.tar.gz',dir='/private/tmp') as out:
  for i in range(2):
   proc=subprocess.Popen(['git',f'--git-dir={repo}','show',f'FETCH_HEAD:evidence/{name}.part{i:02d}'],stdout=subprocess.PIPE)
   for data in iter(lambda:proc.stdout.read(1024*1024),b''):h.update(data);out.write(data)
   assert proc.wait()==0
  out.flush();assert h.hexdigest()==want,(name,h.hexdigest())
  with tarfile.open(out.name,'r:gz') as tar:
   count=0
   for m in tar:
    if not m.isfile() or Path(m.name).name.startswith('._'):continue
    src=tar.extractfile(m);digest=hashlib.sha256()
    for data in iter(lambda:src.read(1024*1024),b''):digest.update(data)
    live=Path('/Users/home/Documents/Codex/2026-11-07/c/crow-48s-landing-checkpoint-20261114')/m.name
    other=hashlib.sha256()
    with live.open('rb') as f:
     for data in iter(lambda:f.read(1024*1024),b''):other.update(data)
    assert digest.digest()==other.digest(),m.name
    count+=1
 print(name,'reconstructed sha',h.hexdigest(),'matched files',count,flush=True)
