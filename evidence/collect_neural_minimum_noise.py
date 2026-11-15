from pathlib import Path
import subprocess,hashlib,tarfile,json,shlex
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini'];root='/Users/n/Developer/numi-crow-rl-20261107';build=root+'/build/crow-v15-recorded-restart-20261114';artifact=root+'/artifacts/crow-v15-recorded-restart-20261114';logdir='neural-exploration-control-minimum-balance-20270511'
files=['neural-exploration-control-minimum-balance.policypack','neural-exploration-result-minimum-balance.policypack','neural-exploration-result-minimum-balance.policypack.deployment.policypack','neural-exploration-result-minimum-balance.rollout','neural-exploration-result-minimum-balance.safetensors'];logs=[logdir+'/'+x for x in ['command.json','stdout','stderr','result.json']]+['neural-minimum-noise-control-pack.json'];paths=[build+'/'+x for x in files]+[artifact+'/'+x for x in logs]
raw=subprocess.check_output(host+['shasum -a 256 '+' '.join(map(shlex.quote,paths))],text=True);manifest={line.split('  ',1)[1]:line.split('  ',1)[0] for line in raw.splitlines()};out=Path('/private/tmp/crow-balance-evidence-20261115/evidence/crow-minimum-noise-20261115.tar.gz');assert not out.exists()
with out.open('wb') as f:subprocess.run(host+[shlex.join(['tar','-C',build,'-czf','-',*files,'-C',artifact,*logs])],stdout=f,check=True)
with tarfile.open(out,'r:gz') as t:
 for name in files+logs:
  f=t.extractfile(name);h=hashlib.sha256()
  for data in iter(lambda:f.read(1048576),b''):h.update(data)
  assert h.hexdigest()==manifest[(build if name in files else artifact)+'/'+name],name
out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps({'archive_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'remote_files':manifest},indent=2)+'\n');print('verified',out.stat().st_size)
