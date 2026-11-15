from pathlib import Path
import hashlib, json, shlex, subprocess, tarfile

host = ['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini']
base = '/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114'
files = ['toe-sensing-target-observer-build.json']
for name in ('full','ablated'):
    files += [f'neural-toe-target-observer-{name}-20370113/{x}' for x in ('command.json','inputs.json','result.json','stdout','stderr.gz','replay.json','trace.tsv')]
paths = [base+'/'+f for f in files]
raw = subprocess.check_output(host+['shasum -a 256 '+' '.join(map(shlex.quote,paths))], text=True)
manifest = {line.split('  ',1)[1]:line.split('  ',1)[0] for line in raw.splitlines()}
out = Path('/private/tmp/crow-balance-evidence-20261115/evidence/crow-toe-target-observer-20261115.tar.gz')
assert not out.exists()
with out.open('wb') as f:
    subprocess.run(host+[shlex.join(['tar','-C',base,'-czf','-',*files])], stdout=f, check=True)
with tarfile.open(out,'r:gz') as t:
    for name in files:
        f = t.extractfile(name); h = hashlib.sha256()
        for data in iter(lambda:f.read(1048576),b''): h.update(data)
        assert h.hexdigest() == manifest[base+'/'+name], name
size = out.stat().st_size
h = hashlib.sha256(out.read_bytes()).hexdigest()
assert size < 40*1024*1024
out.with_suffix(out.suffix+'.manifest.json').write_text(json.dumps({'archive_sha256':h,'archive_size':size,'remote_files':manifest},indent=2)+'\n')
print('verified',size,h)
