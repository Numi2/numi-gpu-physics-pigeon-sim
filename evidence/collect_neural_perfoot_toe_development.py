from pathlib import Path
import sys,subprocess,hashlib,tarfile,json,shlex
seed=int(sys.argv[1]);assert seed in (20370113,20370127)
variant=sys.argv[2] if len(sys.argv)>2 else 'baseline';assert variant in ('baseline','update01')
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini'];base='/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114';directory=f'neural-toe-perfoot-development-{seed}-1000' if variant=='baseline' else f'neural-toe-perfoot-update01-development-{seed}-1000';filenames=['command.json','inputs.json','result.json','stdout','stderr.gz','replay.json','trace.tsv','first-episode-analysis.json'];files=[directory+'/'+n for n in filenames];paths=[base+'/'+n for n in files]
raw=subprocess.check_output(host+['shasum -a 256 '+' '.join(map(shlex.quote,paths))],text=True);manifest={line.split('  ',1)[1]:line.split('  ',1)[0] for line in raw.splitlines()};out=Path('/private/tmp/crow-balance-evidence-20261115/evidence')/(f'crow-toe-perfoot-development-{seed}-20261115.tar.gz' if variant=='baseline' else f'crow-toe-perfoot-update01-development-{seed}-20261115.tar.gz');assert not out.exists()
with out.open('wb') as f:subprocess.run(host+[shlex.join(['tar','-C',base,'-czf','-',*files])],stdout=f,check=True)
with tarfile.open(out,'r:gz') as t:
 for name in files:
  f=t.extractfile(name);h=hashlib.sha256()
  for data in iter(lambda:f.read(1048576),b''):h.update(data)
  assert h.hexdigest()==manifest[base+'/'+name],name
size=out.stat().st_size;fullhash=hashlib.sha256(out.read_bytes()).hexdigest();parts=[]
if size>40*1024*1024:
 with out.open('rb') as f:
  for i,part in enumerate(iter(lambda:f.read(40*1024*1024),b'')):
   p=out.with_name(out.name+f'.part{i:02d}');p.write_bytes(part);parts.append({'name':p.name,'sha256':hashlib.sha256(part).hexdigest()})
 out.unlink()
else:parts=[{'name':out.name,'sha256':fullhash}]
out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps({'archive_sha256':fullhash,'archive_size':size,'parts':parts,'remote_files':manifest},indent=2)+'\n');print(seed,'verified',size,'parts',len(parts),flush=True)
