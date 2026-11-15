from pathlib import Path
import json,subprocess,shlex,sys
here=Path('evidence');proof=json.loads((here/'v15-nov15-independent-git-restore.json').read_text());verified={x['archive']:x for x in proof['archives']};selection={
'crow-v15-toe-gate-telemetry-20261115':['v15-gate-telemetry-checkpoint-roundtrip-20370113-49-100','v15-gate-telemetry-continuation04-evaluation-20370113-250','v15-gate-telemetry-v2-checkpoint-roundtrip-20370113-49-100','v15-gate-telemetry-v2-continuation04-evaluation-20370113-250'],
'crow-v15-scripted-release-control-20261115':['v15-no-scripted-release-checkpoint-roundtrip-20370113-49-100','v15-no-scripted-release-checkpoint-roundtrip-20370127-50-100','v15-no-scripted-release-continuation04-evaluation-20370113-250','v15-no-scripted-release-continuation04-evaluation-20370127-250']}
base='artifacts/crow-v15-recorded-restart-20261114/';entries=[]
for archive,names in selection.items():
 m=json.loads((here/(archive+'.tar.gz.manifest.json')).read_text());assert verified[archive]['sha256']==m['archive_sha256']
 for name in names:
  prefix=base+name+'/';files={p:v for p,v in m['files'].items() if p.startswith(prefix)};assert files;entries.append({'root':base+name,'files':files})
remote=r'''
import hashlib,json,shutil,subprocess,sys
from pathlib import Path
p=json.load(sys.stdin);repo=Path('/Users/n/Developer/numi-crow-rl-20261107');base=repo/'artifacts/crow-v15-recorded-restart-20261114';ready=[]
for x in p['entries']:
 root=repo/x['root'];assert root.parent==base and root.name.startswith(('v15-gate-telemetry','v15-no-scripted-release')) and root.is_dir() and not root.is_symlink()
 assert all(not f.is_symlink() for f in root.rglob('*'))
 files={str(f.relative_to(repo)) for f in root.rglob('*') if f.is_file()};assert files==set(x['files']),(str(root),'file set changed')
 for f,digest in x['files'].items():
  h=hashlib.sha256()
  with (repo/f).open('rb') as src:
   for data in iter(lambda:src.read(1048576),b''):h.update(data)
  assert h.hexdigest()==digest,f
 q=subprocess.run(['lsof','-nP','+D',str(root)],capture_output=True,text=True);assert q.returncode==1 and not q.stdout and not q.stderr,(str(root),q.returncode,q.stdout,q.stderr)
 ready.append((root,files))
assert len(ready)==8 and len(set(str(x[0]) for x in ready))==8
before=shutil.disk_usage(base).free;out=[]
for root,files in ready:
 size=sum((repo/f).stat().st_size for f in files);shutil.rmtree(root);out.append({'directory':str(root),'file_count':len(files),'logical_bytes':size})
print(json.dumps({'verified_git_commit':p['git_commit'],'free_before':before,'free_after':shutil.disk_usage(base).free,'removed':out},indent=2))
'''
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini'];q=subprocess.run(host+['python3 -c '+shlex.quote(remote)],input=json.dumps({'git_commit':proof['git_commit'],'entries':entries}),capture_output=True,text=True);print(q.stdout,end='')
if q.returncode:print(q.stderr,file=sys.stderr);raise SystemExit(q.returncode)
(here/'v15-verified-diagnostic-scratch-retirement.json').write_text(q.stdout)
