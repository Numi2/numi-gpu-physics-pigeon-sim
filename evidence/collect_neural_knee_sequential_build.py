from pathlib import Path
import subprocess,hashlib,tarfile,json,shlex
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini'];root='/Users/n/Developer/numi-crow-rl-20261107';a=root+'/artifacts/crow-v15-recorded-restart-20261114';b=root+'/build/crow-v15-recorded-restart-20261114'
names=[f'neural-knee-sequential-screen-{i:02d}.metal' for i in range(15)];libs=[f'neural-knee-sequential-screen-{i:02d}.metallib' for i in range(15)];build='neural-knee-sequential-screen-build.json'
paths=[a+'/'+x for x in names+[build]]+[b+'/'+x for x in libs]
raw=subprocess.check_output(host+['shasum -a 256 '+' '.join(map(shlex.quote,paths))],text=True);manifest={line.split('  ',1)[1]:line.split('  ',1)[0] for line in raw.splitlines()}
out=Path('/private/tmp/crow-balance-evidence-20261115/evidence/crow-neural-knee-sequential-build-20261115.tar.gz');assert not out.exists()
with out.open('wb') as f:subprocess.run(host+[shlex.join(['tar','-czf','-','-C',a,*names,build,'-C',b,*libs])],stdout=f,check=True)
with tarfile.open(out,'r:gz') as t:
    for name in names+[build]+libs:
        z=t.extractfile(name);h=hashlib.sha256()
        for c in iter(lambda:z.read(1048576),b''):h.update(c)
        assert h.hexdigest()==manifest[(b if name in libs else a)+'/'+name],name
size=out.stat().st_size;digest=hashlib.sha256(out.read_bytes()).hexdigest();parts=[]
if size>40*1024*1024:
    with out.open('rb') as f:
        for i,chunk in enumerate(iter(lambda:f.read(40*1024*1024),b'')):
            p=out.with_name(out.name+f'.part{i:02d}');p.write_bytes(chunk);parts.append({'name':p.name,'sha256':hashlib.sha256(chunk).hexdigest()})
    out.unlink()
else:parts=[{'name':out.name,'sha256':digest}]
out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps({'archive_sha256':digest,'archive_size':size,'parts':parts,'remote_files':manifest},indent=2)+'\n')
print('verified build',size,'parts',len(parts),flush=True)
