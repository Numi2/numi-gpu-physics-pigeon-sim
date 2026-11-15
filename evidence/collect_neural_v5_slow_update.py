from pathlib import Path
import sys,subprocess,hashlib,tarfile,json,shlex
version='v5-slow';idx=int(sys.argv[1]);assert 1<=idx<=4
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini'];root='/Users/n/Developer/numi-crow-rl-20261107';build=root+'/build/crow-v15-recorded-restart-20261114';artifact=root+'/artifacts/crow-v15-recorded-restart-20261114';prefix=f'neural-balance-{version}-update-{idx:02d}';logdir=f'neural-balance-{version}/update-{idx:02d}'
files=[prefix+'.policypack',prefix+'.policypack.deployment.policypack',prefix+'.rollout',prefix+'.safetensors'];logs=['command.json','stdout','stderr','result.json']; paths=[build+'/'+x for x in files]+[artifact+'/'+logdir+'/'+x for x in logs]
cmd='shasum -a 256 '+ ' '.join(map(shlex.quote,paths));raw=subprocess.check_output(host+[cmd],text=True);manifest={line.split('  ',1)[1]:line.split('  ',1)[0] for line in raw.splitlines()}
out=Path('/private/tmp/crow-balance-evidence-20261115/evidence')/f'crow-neural-{version}-update-{idx:02d}-20261115.tar.gz';assert not out.exists()
cmd=shlex.join(['tar','-C',build,'-czf','-',*files,'-C',artifact,*[logdir+'/'+x for x in logs]])
with out.open('wb') as f:subprocess.run(host+[cmd],stdout=f,check=True)
with tarfile.open(out,'r:gz') as t:
 for name in files+[logdir+'/'+x for x in logs]:
  f=t.extractfile(name);h=hashlib.sha256()
  for data in iter(lambda:f.read(1048576),b''):h.update(data)
  full=(build+'/'+name) if name in files else (artifact+'/'+name)
  assert h.hexdigest()==manifest[full],name
m=out.with_suffix(out.suffix+'.manifest.json');m.write_text(json.dumps({'archive_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'remote_files':manifest},indent=2)+'\n');print(version,idx,'verified',out.stat().st_size,'bytes',flush=True)
