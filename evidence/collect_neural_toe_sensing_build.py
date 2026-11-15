from pathlib import Path
import subprocess,hashlib,tarfile,json,shlex
root='/Users/n/Developer/numi-crow-rl-20261107';b=root+'/build/crow-v15-recorded-restart-20261114';a=root+'/artifacts/crow-v15-recorded-restart-20261114';host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini']
bfiles=['toe-sensing-experiment-host/libmetalrobo.dylib','neural-toe-sensing-zero-stochastic.policypack','neural-toe-sensing-zero-deterministic.policypack'];afiles=['neural-toe-sensing-zero-packs.json','toe-sensing-host-build.json','c_api-toe-sensing-experiment.cpp']+[d+'/'+f for d in ('toe-sensing-contract-probe','toe-sensing-contract-old-policy-probe') for f in ('command.json','inputs.json','stdout','stderr','result.json')];paths=[b+'/'+x for x in bfiles]+[a+'/'+x for x in afiles]
raw=subprocess.check_output(host+['shasum -a 256 '+' '.join(map(shlex.quote,paths))],text=True);manifest={line.split('  ',1)[1]:line.split('  ',1)[0] for line in raw.splitlines()};out=Path('/private/tmp/crow-balance-evidence-20261115/evidence/crow-toe-sensing-build-and-probes-20261115.tar.gz');assert not out.exists()
with out.open('wb') as f:subprocess.run(host+[shlex.join(['tar','-C',b,'-czf','-',*bfiles,'-C',a,*afiles])],stdout=f,check=True)
with tarfile.open(out,'r:gz') as t:
 for name in bfiles+afiles:
  f=t.extractfile(name);h=hashlib.sha256()
  for data in iter(lambda:f.read(1048576),b''):h.update(data)
  assert h.hexdigest()==manifest[(b if name in bfiles else a)+'/'+name],name
out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps({'archive_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'remote_files':manifest},indent=2)+'\n');print('toe sensing build and failures verified',out.stat().st_size)
