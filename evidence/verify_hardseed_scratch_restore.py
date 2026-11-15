from pathlib import Path
import json,subprocess,tarfile,tempfile,hashlib
repo='/private/tmp/crow-balance-evidence-verify-20261115.git';commit=subprocess.check_output(['git','-C',repo,'rev-parse','FETCH_HEAD'],text=True).strip();records=[]
for seed in (20370113,20370127):
 name=f'crow-hardseed02-{seed}-development-20261115.tar.gz';manifest=json.loads(subprocess.check_output(['git','-C',repo,'show',f'{commit}:evidence/{name}.manifest.json']))
 with tempfile.TemporaryFile() as f:
  subprocess.run(['git','-C',repo,'show',f'{commit}:evidence/{name}'],stdout=f,check=True);f.seek(0);h=hashlib.sha256()
  for data in iter(lambda:f.read(1048576),b''):h.update(data)
  assert h.hexdigest()==manifest['archive_sha256'];f.seek(0)
  with tarfile.open(fileobj=f,mode='r:gz') as t:
   for path,expected in manifest['remote_files'].items():
    name=Path(path).parent.name+'/'+Path(path).name;stream=t.extractfile(name);h=hashlib.sha256()
    for data in iter(lambda:stream.read(1048576),b''):h.update(data)
    assert h.hexdigest()==expected,path
 records.append({'remote_files':manifest['remote_files']})
Path('/private/tmp/crow-hardseed-git-restore-verified.json').write_text(json.dumps({'commit':commit,'archives':records},indent=2)+'\n');print(commit,'restored and verified',len(records),'archives')
