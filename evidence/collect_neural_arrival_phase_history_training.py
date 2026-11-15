from pathlib import Path
import subprocess,hashlib,tarfile,json,shlex
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini'];root='/Users/n/Developer/numi-crow-rl-20261107';build=root+'/build/crow-v15-recorded-restart-20261114';artifact=root+'/artifacts/crow-v15-recorded-restart-20261114';prefix='neural-arrival-phase-history-update-01';files=[prefix+'.policypack',prefix+'.policypack.deployment.policypack',prefix+'.rollout',prefix+'.safetensors'];logs=['command.json','inputs.json','stdout','stderr','result.json'];paths=[build+'/'+x for x in files]+[artifact+'/'+prefix+'/'+x for x in logs]
raw=subprocess.check_output(host+['shasum -a 256 '+' '.join(map(shlex.quote,paths))],text=True);manifest={line.split('  ',1)[1]:line.split('  ',1)[0] for line in raw.splitlines()};out=Path('/private/tmp/crow-balance-evidence-20261115/evidence/crow-neural-arrival-phase-history-update-01-20261115.tar.gz');assert not out.exists()
with out.open('wb') as f:subprocess.run(host+[shlex.join(['tar','-C',build,'-czf','-',*files,'-C',artifact,*[prefix+'/'+x for x in logs]])],stdout=f,check=True)
with tarfile.open(out,'r:gz') as t:
 for name in files+[prefix+'/'+x for x in logs]:
  f=t.extractfile(name);h=hashlib.sha256()
  for data in iter(lambda:f.read(1048576),b''):h.update(data)
  assert h.hexdigest()==manifest[(build+'/'+name) if name in files else (artifact+'/'+name)],name
size=out.stat().st_size;fullhash=hashlib.sha256(out.read_bytes()).hexdigest();parts=[]
if size>40*1024*1024:
 with out.open('rb') as f:
  for i,part in enumerate(iter(lambda:f.read(40*1024*1024),b'')):
   p=out.with_name(out.name+f'.part{i:02d}');p.write_bytes(part);parts.append({'name':p.name,'sha256':hashlib.sha256(part).hexdigest()})
 out.unlink()
else:parts=[{'name':out.name,'sha256':fullhash}]
out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps({'archive_sha256':fullhash,'archive_size':size,'parts':parts,'remote_files':manifest},indent=2)+'\n');print('phase-history training verified',size,'parts',len(parts),flush=True)
