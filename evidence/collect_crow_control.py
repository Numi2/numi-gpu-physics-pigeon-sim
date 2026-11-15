from pathlib import Path
import sys,subprocess,hashlib,tarfile,json,shlex
family,name=sys.argv[1:3];assert family in ('exploration','narrow') and name in ('baseline','low-balance','low-head','low-both');assert family!='narrow' or name in ('baseline','low-balance')
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini'];root='/Users/n/Developer/numi-crow-rl-20261107';build=root+'/build/crow-v15-recorded-restart-20261114';artifact=root+'/artifacts/crow-v15-recorded-restart-20261114';result=f'neural-{family}-result-{name}';inp=f'neural-exploration-control-{name}.policypack';logdir=f'neural-{family}-control-{name}-20270511'
files=[inp,result+'.policypack',result+'.policypack.deployment.policypack',result+'.rollout',result+'.safetensors'];logs=['command.json','stdout','stderr','result.json'];paths=[build+'/'+x for x in files]+[artifact+'/'+logdir+'/'+x for x in logs]
raw=subprocess.check_output(host+['shasum -a 256 '+' '.join(map(shlex.quote,paths))],text=True);manifest={line.split('  ',1)[1]:line.split('  ',1)[0] for line in raw.splitlines()}
out=Path('/private/tmp/crow-balance-evidence-20261115/evidence')/f'crow-neural-{family}-control-{name}-20270511.tar.gz';assert not out.exists()
cmd=shlex.join(['tar','-C',build,'-czf','-',*files,'-C',artifact,*[logdir+'/'+x for x in logs]])
with out.open('wb') as f:subprocess.run(host+[cmd],stdout=f,check=True)
with tarfile.open(out,'r:gz') as t:
 for name2 in files+[logdir+'/'+x for x in logs]:
  f=t.extractfile(name2);h=hashlib.sha256()
  for data in iter(lambda:f.read(1048576),b''):h.update(data)
  full=(build+'/'+name2) if name2 in files else (artifact+'/'+name2)
  assert h.hexdigest()==manifest[full],name2
m=out.with_suffix(out.suffix+'.manifest.json');m.write_text(json.dumps({'archive_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'remote_files':manifest},indent=2)+'\n');print(family,name,'verified',out.stat().st_size,flush=True)
