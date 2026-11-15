from pathlib import Path
import sys,subprocess,hashlib,tarfile,json,shlex
version=sys.argv[1];slot=int(sys.argv[2]);assert (version,slot) in (('v1',4),('v1',7),('v2',5),('v2',7));seed=20310129 if version=='v1' else 20310201;name=f'{version}-slot-{slot}'
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini'];base='/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114';directory=f'neural-toe-{version}-zero-slot-{slot}-{seed}-400';filenames=['command.json','inputs.json','result.json','stdout','stderr.gz','replay.json','trace.tsv'];files=[directory+'/'+n for n in filenames];paths=[base+'/'+n for n in files]
raw=subprocess.check_output(host+['shasum -a 256 '+' '.join(map(shlex.quote,paths))],text=True);manifest={line.split('  ',1)[1]:line.split('  ',1)[0] for line in raw.splitlines()};out=Path('/private/tmp/crow-balance-evidence-20261115/evidence')/f'crow-toe-{name}-{seed}-ablation-20261115.tar.gz';assert not out.exists()
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
