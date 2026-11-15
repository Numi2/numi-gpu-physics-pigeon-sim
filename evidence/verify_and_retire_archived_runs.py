from pathlib import Path
import hashlib,json,shutil,subprocess
root=Path('/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114')
expected=json.loads(Path('/tmp/crow-six-remote-manifest.json').read_text())
names=['neural-v3-long-challenge-20310201-v3-1000','neural-v3-long-challenge-20310221-v3-1000']+['neural-v3-disturbance-20310111-'+m+'-500' for m in ('plus-live','minus-live','plus-frozen','minus-frozen')]
actual={}
for name in names:
 d=root/name
 assert d.is_dir() and not d.is_symlink()
 probe=subprocess.run(['/usr/sbin/lsof','+D',str(d)],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
 assert probe.returncode==1 and not probe.stdout,('open files or lsof failure',name,probe.returncode,probe.stderr)
 for p in d.rglob('*'):
  assert not p.is_symlink(),p
  if p.is_file():
   h=hashlib.sha256()
   with p.open('rb') as f:
    for data in iter(lambda:f.read(1048576),b''):h.update(data)
   actual[str(p.relative_to(root))]=h.hexdigest()
assert actual==expected,'file set or hashes changed; nothing deleted'
print('verified before removal',len(actual),'files, 6 completed directories',flush=True)
subprocess.run(['df','-k',str(root)],check=True)
for name in names:shutil.rmtree(root/name)
subprocess.run(['df','-k',str(root)],check=True)
