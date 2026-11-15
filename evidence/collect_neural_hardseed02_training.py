from pathlib import Path
import subprocess,hashlib,tarfile,json,shlex
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini']; root='/Users/n/Developer/numi-crow-rl-20261107'; a='artifacts/crow-v15-recorded-restart-20261114'; b='build/crow-v15-recorded-restart-20261114'
files=[f'{a}/neural-hard-seed-continuation-01/{n}' for n in ('command.json','result.json','stdout','stderr')]+[f'{a}/neural-hard-seed-continuation-02/{n}' for n in ('command.json','environment.json','inputs.json','result.json','verification.json','stdout','stderr')]+[f'{b}/neural-hard-seed-continuation-02.{n}' for n in ('policypack','policypack.deployment.policypack','rollout','safetensors')]
raw=subprocess.check_output(host+['cd '+shlex.quote(root)+' && shasum -a 256 '+' '.join(map(shlex.quote,files))],text=True); hashes={line.split('  ',1)[1]:line.split('  ',1)[0] for line in raw.splitlines()};out=Path('/private/tmp/crow-balance-evidence-20261115/evidence/crow-neural-hardseed02-training-20261115.tar.gz'); assert not out.exists()
with out.open('wb') as f: subprocess.run(host+[shlex.join(['tar','-C',root,'-czf','-',*files])],stdout=f,check=True)
with tarfile.open(out,'r:gz') as tar:
 for name in files:
  h=hashlib.sha256();f=tar.extractfile(name)
  for data in iter(lambda:f.read(1048576),b''): h.update(data)
  assert h.hexdigest()==hashes[name],name
sha=hashlib.sha256(out.read_bytes()).hexdigest();out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps({'archive_sha256':sha,'archive_size':out.stat().st_size,'remote_root':root,'files':hashes},indent=2)+'\n');print(out.stat().st_size,sha,flush=True)
