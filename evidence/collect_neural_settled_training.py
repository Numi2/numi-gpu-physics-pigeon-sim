from pathlib import Path
import sys,subprocess,hashlib,tarfile,json,shlex
name=sys.argv[1];assert name in ('diagnostic','minimum-noise','carrier-aligned')
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini'];root='/Users/n/Developer/numi-crow-rl-20261107';build=root+'/build/crow-v15-recorded-restart-20261114';artifact=root+'/artifacts/crow-v15-recorded-restart-20261114';stem=f'neural-settled-training-{name}';logdir=f'{stem}-20270511';shader='neural-settled-carrier-aligned' if name=='carrier-aligned' else 'neural-settled-training-diagnostic';pack='neural-exploration-control-minimum-balance.policypack' if name=='minimum-noise' else 'neural-exploration-control-low-balance.policypack';files=[pack,shader+'.metallib',stem+'.policypack',stem+'.policypack.deployment.policypack',stem+'.rollout',stem+'.safetensors'];logs=[logdir+'/'+x for x in ('command.json','stdout','stderr','result.json')]+[shader+'.metal',shader+'-build.json'];paths=[build+'/'+x for x in files]+[artifact+'/'+x for x in logs]
raw=subprocess.check_output(host+['shasum -a 256 '+' '.join(map(shlex.quote,paths))],text=True);manifest={line.split('  ',1)[1]:line.split('  ',1)[0] for line in raw.splitlines()};out=Path('/private/tmp/crow-balance-evidence-20261115/evidence')/f'crow-settled-training-{name}-20261115.tar.gz';assert not out.exists()
with out.open('wb') as f:subprocess.run(host+[shlex.join(['tar','-C',build,'-czf','-',*files,'-C',artifact,*logs])],stdout=f,check=True)
with tarfile.open(out,'r:gz') as t:
 for n in files+logs:
  f=t.extractfile(n);h=hashlib.sha256()
  for data in iter(lambda:f.read(1048576),b''):h.update(data)
  assert h.hexdigest()==manifest[(build if n in files else artifact)+'/'+n],n
out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps({'archive_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'remote_files':manifest},indent=2)+'\n');print(name,'verified',out.stat().st_size,flush=True)
