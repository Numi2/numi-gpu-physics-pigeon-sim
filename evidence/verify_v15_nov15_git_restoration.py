from pathlib import Path
import subprocess,hashlib,tarfile,io,json
repo='/private/tmp/crow-balance-evidence-verify-20261115.git'
subprocess.run(['git','-C',repo,'fetch','origin','agent/crow-neural-balance-evidence-20261115'],check=True)
def read(path):return subprocess.check_output(['git','-C',repo,'show','FETCH_HEAD:evidence/'+path])
names=('crow-v15-resetfixed-checkpoint-training-20261115','crow-v15-resetfixed-lr30x-training-20261115','crow-v15-resetfixed-lr30x-continuation-20261115','crow-v15-resetfixed-continuation-render-20261115','crow-v15-toe-gate-telemetry-20261115','crow-v15-scripted-release-control-20261115','crow-v15-balanced-two-seed-training-20261115')
results=[]
for name in names:
 manifest=json.loads(read(name+'.tar.gz.manifest.json'));parts=[]
 for part in manifest['parts']:
  data=read(part['name']);assert hashlib.sha256(data).hexdigest()==part['sha256'],part['name'];parts.append(data)
 data=b''.join(parts);assert len(data)==manifest['archive_size'] and hashlib.sha256(data).hexdigest()==manifest['archive_sha256'],name
 with tarfile.open(fileobj=io.BytesIO(data),mode='r:gz') as archive:
  members=archive.getmembers();files=manifest['files'];assert all(m.isfile() for m in members) and len(members)==len(set(m.name for m in members)),name
  actual={m.name for m in members};expected=set(files);extras=actual-expected;assert not (expected-actual),name
  assert all(Path(x).name.startswith('._') and str(Path(x).parent / Path(x).name[2:]) in expected for x in extras),(name,extras)
  for m in members:
   if m.name in extras: continue
   file=archive.extractfile(m);h=hashlib.sha256()
   for chunk in iter(lambda:file.read(1048576),b''):h.update(chunk)
   assert h.hexdigest()==files[m.name],m.name
 results.append({'archive':name,'sha256':manifest['archive_sha256'],'restored_files':len(files),'appledouble_metadata_entries':len(extras)});print(name,'verified',len(files),flush=True)
v=read('crow-v15-latest-fall-earlier-hold-five-angles.mp4');sha=hashlib.sha256(v).hexdigest();assert sha=='b1502af90942fce6e5f6f7e447110a78a962634fe9099513368da58b99463c8d'
Path('evidence/v15-nov15-independent-git-restore.json').write_text(json.dumps({'git_commit':subprocess.check_output(['git','-C',repo,'rev-parse','FETCH_HEAD'],text=True).strip(),'archives':results,'video_sha256':sha,'method':'Independently fetched Git remote; hash each archive part, full reconstructed archive and every unique regular-file member; check exact member sets apart from macOS AppleDouble metadata whose data-file counterparts are present. No simulator claims.'},indent=2)+'\n')
