from pathlib import Path
import subprocess,hashlib,tarfile,json,shlex
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini'];root='/Users/n/Developer/numi-crow-rl-20261107';a='artifacts/crow-v15-recorded-restart-20261114/';b='build/crow-v15-recorded-restart-20261114/'
files=[a+x for x in ('neural-toe-action-eval.metal','neural-toe-action-train.metal','neural-toe-action-build.json','neural-toe-action-zero-packs.json','neural-toe-action-probe-pack.json')]+[b+x for x in ('neural-toe-action-eval.metallib','neural-toe-action-train.metallib','neural-toe-action-zero-stochastic.policypack','neural-toe-action-zero-deterministic.policypack','neural-toe-action-zero-stochastic-failedcheck.policypack','neural-toe-action-zero-deterministic-failedcheck.policypack','neural-toe-action-fixed-negative-probe.policypack','neural-toe-python/metalrobo/mlx_policy_learning.py')]
paths=[root+'/'+x for x in files];raw=subprocess.check_output(host+['shasum -a 256 '+' '.join(map(shlex.quote,paths))],text=True);manifest={line.split('  ',1)[1]:line.split('  ',1)[0] for line in raw.splitlines()};out=Path('/private/tmp/crow-balance-evidence-20261115/evidence/crow-toe-action-assets-20261115.tar.gz');assert not out.exists()
with out.open('wb') as f:subprocess.run(host+[shlex.join(['tar','-C',root,'-czf','-',*files])],stdout=f,check=True)
with tarfile.open(out,'r:gz') as t:
 for name in files:
  f=t.extractfile(name);h=hashlib.sha256()
  for data in iter(lambda:f.read(1048576),b''):h.update(data)
  assert h.hexdigest()==manifest[root+'/'+name],name
m={'archive_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'size':out.stat().st_size,'remote_files':manifest};assert out.stat().st_size<40*1024*1024
out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps(m,indent=2)+'\n');print('verified assets',out.stat().st_size,flush=True)
