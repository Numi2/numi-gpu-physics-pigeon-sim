import sys,json,subprocess,hashlib,tarfile,tempfile
from pathlib import Path
git='/private/tmp/crow-balance-evidence-verify-20261115.git'
subprocess.run(['git','--git-dir='+git,'fetch','--depth=1','origin','agent/crow-neural-balance-evidence-20261115'],check=True)
for archive in sys.argv[1:]:
 manifest=json.loads(subprocess.check_output(['git','--git-dir='+git,'show','FETCH_HEAD:evidence/'+archive+'.manifest.json']))
 with tempfile.TemporaryFile() as out:
  total=hashlib.sha256()
  for part in manifest['parts']:
   data=subprocess.check_output(['git','--git-dir='+git,'show','FETCH_HEAD:evidence/'+part['name']]);assert hashlib.sha256(data).hexdigest()==part['sha256'];total.update(data);out.write(data)
  assert total.hexdigest()==manifest['archive_sha256'];assert out.tell()==manifest['archive_size'];out.seek(0)
  with tarfile.open(fileobj=out,mode='r:gz') as tar:
   for name,expected in manifest['files'].items():
    f=tar.extractfile(name);h=hashlib.sha256()
    for data in iter(lambda:f.read(1048576),b''):h.update(data)
    assert h.hexdigest()==expected,name
 print(archive,'verified',len(manifest['files']),'files',flush=True)
