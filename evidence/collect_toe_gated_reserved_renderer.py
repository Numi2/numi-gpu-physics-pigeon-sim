from pathlib import Path
import subprocess,hashlib,tarfile,json,shlex,sys
seed=sys.argv[1];assert seed in ('20360117','20360206');directory=f'render-phase-comparison-neural-toe-gated-reserved-{seed}-gated-1000';base='/tmp/crow-48s-multiview-20261114';host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini'];raw=subprocess.check_output(host+[shlex.join(['find',base+'/'+directory,'-type','f','-print'])],text=True).splitlines();assert len(raw)==17 and all(x.startswith(base+'/'+directory+'/') for x in raw);hashes=subprocess.check_output(host+['shasum -a 256 '+' '.join(map(shlex.quote,raw))],text=True);manifest={line.split('  ',1)[1]:line.split('  ',1)[0] for line in hashes.splitlines()};out=Path('/private/tmp/crow-balance-evidence-20261115/evidence')/f'crow-toe-gated-reserved-renderer-bundle-{seed}.tar.gz';assert not out.exists()
with out.open('wb') as f:subprocess.run(host+[shlex.join(['tar','-C',base,'-czf','-',directory])],stdout=f,check=True)
with tarfile.open(out,'r:gz') as t:
 for full,h in manifest.items():
  stream=t.extractfile(full[len(base)+1:]);hasher=hashlib.sha256()
  for chunk in iter(lambda:stream.read(1048576),b''):hasher.update(chunk)
  assert hasher.hexdigest()==h,full
size=out.stat().st_size;digest=hashlib.sha256(out.read_bytes()).hexdigest();parts=[]
if size>40*1024*1024:
 with out.open('rb') as f:
  for i,part in enumerate(iter(lambda:f.read(40*1024*1024),b'')):
   p=out.with_name(out.name+f'.part{i:02d}');p.write_bytes(part);parts.append({'name':p.name,'sha256':hashlib.sha256(part).hexdigest()})
 out.unlink()
else:parts=[{'name':out.name,'sha256':digest}]
out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps({'archive_sha256':digest,'archive_size':size,'parts':parts,'remote_files':manifest},indent=2)+'\n');print(seed,'verified',len(manifest),'files',size,'parts',len(parts),flush=True)
