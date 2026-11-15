"""Independently restore archived scratch files from Git, checking every byte."""
from pathlib import Path
import hashlib,json,subprocess,tarfile,tempfile
gitdir='/private/tmp/crow-balance-evidence-verify-20261115.git'
ref='refs/verify/latest'
subprocess.run(['git',f'--git-dir={gitdir}','fetch','--filter=blob:none','--depth=1','origin','+refs/heads/agent/crow-neural-balance-evidence-20261115:'+ref],check=True)
commit=subprocess.check_output(['git',f'--git-dir={gitdir}','rev-parse',ref],text=True).strip()
assert len(commit)==40
archives=[]
for stem in ('crow-arrival-phase-control-development','crow-arrival-phase-history-control-development','crow-arrival-phase-history-update01-development','crow-arrival-phase-history-cont04-development'):
 for seed in (20370113,20370127):archives.append(f'{stem}-{seed}-20261115.tar.gz')
root='/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114/'
records=[]
for name in archives:
 manifest=json.loads(subprocess.check_output(['git',f'--git-dir={gitdir}','show',f'{ref}:evidence/{name}.manifest.json']))
 assert len(manifest['parts'])==1 and manifest['parts'][0]['name']==name
 with tempfile.NamedTemporaryFile(prefix='crow-git-verified-',suffix='.tar.gz') as f:
  subprocess.run(['git',f'--git-dir={gitdir}','show',f'{ref}:evidence/{name}'],stdout=f,check=True);f.flush()
  h=hashlib.sha256()
  with open(f.name,'rb') as source:
   for chunk in iter(lambda:source.read(1048576),b''):h.update(chunk)
  assert h.hexdigest()==manifest['archive_sha256'],name
  files=manifest['remote_files']
  assert all(path.startswith(root) for path in files)
  with tarfile.open(f.name,'r:gz') as t:
   members={x.name:x for x in t.getmembers() if x.isfile()};expected={path[len(root):]:digest for path,digest in files.items()}
   # macOS tar may emit AppleDouble metadata beside an explicitly named file.
   extras=set(members)-set(expected)
   assert set(expected).issubset(members) and all(Path(x).name.startswith('._') and str(Path(x).with_name(Path(x).name[2:])) in expected for x in extras),(name,extras)
   for path,digest in expected.items():
    z=t.extractfile(members[path]);h=hashlib.sha256()
    for chunk in iter(lambda:z.read(1048576),b''):h.update(chunk)
    assert h.hexdigest()==digest,(name,path)
  records.append({'archive':name,'archive_sha256':manifest['archive_sha256'],'remote_files':files})
 print(name,'verified',len(files),'files',flush=True)
Path('/private/tmp/crow-arrival-git-restore-verified.json').write_text(json.dumps({'commit':commit,'archives':records},indent=2)+'\n')
