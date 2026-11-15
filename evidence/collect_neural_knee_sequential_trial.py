from pathlib import Path
import sys,subprocess,hashlib,tarfile,json,shlex
idx=int(sys.argv[1]);assert 0<=idx<15
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini']
base='/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114';directory=f'neural-knee-sequential-screen-20370113/variant-{idx:02d}'
files=[directory+'/'+n for n in ('command.json','inputs.json','result.json','stdout','stderr.gz','replay.json','trace.tsv','first-episode-analysis.json')];paths=[base+'/'+n for n in files]
raw=subprocess.check_output(host+['shasum -a 256 '+' '.join(map(shlex.quote,paths))],text=True);manifest={line.split('  ',1)[1]:line.split('  ',1)[0] for line in raw.splitlines()}
out=Path('/private/tmp/crow-balance-evidence-20261115/evidence')/f'crow-knee-sequential-20370113-variant-{idx:02d}.tar.gz';assert not out.exists()
with out.open('wb') as f:subprocess.run(host+[shlex.join(['tar','-C',base,'-czf','-',*files])],stdout=f,check=True)
with tarfile.open(out,'r:gz') as t:
    for name in files:
        stream=t.extractfile(name);h=hashlib.sha256()
        for chunk in iter(lambda:stream.read(1048576),b''):h.update(chunk)
        assert h.hexdigest()==manifest[base+'/'+name],name
digest=hashlib.sha256(out.read_bytes()).hexdigest();out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps({'archive_sha256':digest,'archive_size':out.stat().st_size,'remote_files':manifest},indent=2)+'\n')
print('variant',idx,'verified',out.stat().st_size,flush=True)
