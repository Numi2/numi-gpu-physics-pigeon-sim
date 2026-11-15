from pathlib import Path
import subprocess,hashlib,tarfile,json,shlex
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini'];root='/Users/n/Developer/numi-crow-rl-20261107';a='artifacts/crow-v15-recorded-restart-20261114';b='build/crow-v15-recorded-restart-20261114'
names=['crow_v15_resetfixed_training_checkpoint_seed27.py','v15-resetfixed-training-checkpoint-source-20370127-50','crow_v15_balanced_two_seed_training.py','crow_v15_balanced_two_seed_evaluate.py','crow_v15_balanced_two_seed_verify.py','crow_v15_balanced_rollout_analyze.py','v15-balanced-two-seed-rollout-analysis.json','v15-balanced-two-seed-update04-evaluation-20370113-250','v15-balanced-two-seed-update04-evaluation-20370127-250']+[f'v15-balanced-two-seed-update-{i:02d}' for i in range(1,5)]
paths=[f'{a}/{n}' for n in names]+[f'{b}/v15-balanced-two-seed-update-{i:02d}.{ext}' for i in range(1,5) for ext in ('policypack','policypack.deployment.policypack','policypack.incumbent.policypack','rollout','safetensors')]

find='cd '+shlex.quote(root)+' && find '+ ' '.join(map(shlex.quote,paths))+' -type f -print'
files=subprocess.check_output(host+[find],text=True).splitlines();assert files and len(files)==len(set(files));raw=subprocess.check_output(host+['cd '+shlex.quote(root)+' && shasum -a 256 '+' '.join(map(shlex.quote,files))],text=True);hashes={line.split('  ',1)[1]:line.split('  ',1)[0] for line in raw.splitlines()};assert set(files)==set(hashes)
out=Path('/private/tmp/crow-balance-evidence-20261115/evidence/crow-v15-balanced-two-seed-training-20261115.tar.gz');assert not out.exists()
with out.open('wb') as f:subprocess.run(host+[shlex.join(['tar','-C',root,'-czf','-',*files])],stdout=f,check=True)
with tarfile.open(out,'r:gz') as tar:
 for name in files:
  h=hashlib.sha256();f=tar.extractfile(name)
  for data in iter(lambda:f.read(1048576),b''):h.update(data)
  assert h.hexdigest()==hashes[name],name
size=out.stat().st_size;sha=hashlib.sha256(out.read_bytes()).hexdigest();parts=[]
if size>40*1024*1024:
 with out.open('rb') as f:
  for i,data in enumerate(iter(lambda:f.read(40*1024*1024),b'')):
   p=out.with_name(out.name+f'.part{i:02d}');p.write_bytes(data);parts.append({'name':p.name,'sha256':hashlib.sha256(data).hexdigest()})
 out.unlink()
else:parts=[{'name':out.name,'sha256':sha}]
out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps({'archive_sha256':sha,'archive_size':size,'parts':parts,'remote_root':root,'files':hashes},indent=2)+'\n');print('files',len(files),'bytes',size,'parts',len(parts),'sha256',sha,flush=True)
