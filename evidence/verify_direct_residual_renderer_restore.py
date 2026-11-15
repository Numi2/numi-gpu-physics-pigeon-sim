from pathlib import Path
import subprocess,hashlib,json,tarfile,io
repo='/private/tmp/crow-balance-evidence-verify-20261115.git';root='refs/verify/latest:evidence/';result={}
def show(path):return subprocess.check_output(['git','--git-dir='+repo,'show',root+path])
for seed in ('20370113','20370127'):
 name=f'crow-toe-residual-development-renderer-bundle-{seed}.tar.gz';manifest=json.loads(show(name+'.manifest.json'));data=show(name);assert hashlib.sha256(data).hexdigest()==manifest['archive_sha256'];assert len(data)==manifest['archive_size'];prefix='/tmp/crow-48s-multiview-20261114/'
 with tarfile.open(fileobj=io.BytesIO(data),mode='r:gz') as t:
  for full,digest in manifest['remote_files'].items():
   f=t.extractfile(full[len(prefix):]);assert hashlib.sha256(f.read()).hexdigest()==digest,full
 Path(f'/private/tmp/crow-toe-residual-restored-manifest-{seed}.json').write_text(json.dumps(manifest,indent=2)+'\n');result[seed]={'archive_sha256':manifest['archive_sha256'],'members':len(manifest['remote_files']),'all_hashes_match':True}
print(json.dumps(result,indent=2))
