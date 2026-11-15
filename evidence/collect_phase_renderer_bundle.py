from pathlib import Path
import subprocess,hashlib,tarfile,json,shlex,sys
seed=sys.argv[1];assert seed in ('20310111','20310129');directory=f'render-phase-comparison-neural-v3-settled-reset-{seed}-action-history-phase-500';base='/tmp/crow-48s-multiview-20261114';host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini'];raw=subprocess.check_output(host+[shlex.join(['find',base+'/'+directory,'-type','f','-print'])],text=True).splitlines();assert raw and all(x.startswith(base+'/'+directory+'/') for x in raw);hashes=subprocess.check_output(host+['shasum -a 256 '+' '.join(map(shlex.quote,raw))],text=True);manifest={line.split('  ',1)[1]:line.split('  ',1)[0] for line in hashes.splitlines()};out=Path('/private/tmp/crow-balance-evidence-20261115/evidence')/f'crow-phase-renderer-bundle-{seed}.tar.gz';assert not out.exists()
with out.open('wb') as f:subprocess.run(host+[shlex.join(['tar','-C',base,'-czf','-',directory])],stdout=f,check=True)
with tarfile.open(out,'r:gz') as t:
 for full,h in manifest.items():
  member=full[len(base)+1:];stream=t.extractfile(member);hasher=hashlib.sha256()
  for chunk in iter(lambda:stream.read(1048576),b''):hasher.update(chunk)
  assert hasher.hexdigest()==h,member
out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps({'archive_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'remote_files':manifest},indent=2)+'\n');print(seed,'verified',len(manifest),'files',out.stat().st_size,flush=True)
