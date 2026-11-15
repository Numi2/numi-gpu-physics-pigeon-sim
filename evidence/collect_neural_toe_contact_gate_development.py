from pathlib import Path
import sys,subprocess,hashlib,tarfile,json,shlex
seed=int(sys.argv[1]);name='v1-contact-gated';assert seed in (20310111,20310129,20310201,20310221)
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini'];base='/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114';directory=f'neural-toe-contact-gated-v1-development-{seed}-1000';filenames=['command.json','inputs.json','result.json','stdout','stderr.gz','replay.json','trace.tsv'];files=[directory+'/'+n for n in filenames];paths=[base+'/'+n for n in files]
raw=subprocess.check_output(host+['shasum -a 256 '+' '.join(map(shlex.quote,paths))],text=True);manifest={line.split('  ',1)[1]:line.split('  ',1)[0] for line in raw.splitlines()};out=Path('/private/tmp/crow-balance-evidence-20261115/evidence')/f'crow-toe-action-{seed}-{name}-development-20261115.tar.gz';assert not out.exists()
with out.open('wb') as f:subprocess.run(host+[shlex.join(['tar','-C',base,'-czf','-',*files])],stdout=f,check=True)
with tarfile.open(out,'r:gz') as t:
 for name2 in files:
  f=t.extractfile(name2);h=hashlib.sha256()
  for data in iter(lambda:f.read(1048576),b''):h.update(data)
  assert h.hexdigest()==manifest[base+'/'+name2],name2
size=out.stat().st_size;fullhash=hashlib.sha256(out.read_bytes()).hexdigest();partnames=[]
if size>40*1024*1024:
 with out.open('rb') as f:
  for i,part in enumerate(iter(lambda:f.read(40*1024*1024),b'')):
   p=out.with_name(out.name+f'.part{i:02d}');p.write_bytes(part);partnames.append({'name':p.name,'sha256':hashlib.sha256(part).hexdigest()})
 out.unlink()
else:partnames=[{'name':out.name,'sha256':fullhash}]
out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps({'archive_sha256':fullhash,'archive_size':size,'parts':partnames,'remote_files':manifest},indent=2)+'\n');print(seed,name,'verified',size,'parts',len(partnames),flush=True)
