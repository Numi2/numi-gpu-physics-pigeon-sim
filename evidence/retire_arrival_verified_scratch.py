"""Retire only independently restored, unchanged trial scratch; keep models."""
import json,shlex,subprocess
from pathlib import Path
verified=Path('/private/tmp/crow-arrival-git-restore-verified.json')
payload=json.loads(verified.read_text());assert len(payload['commit'])==40 and len(payload['archives'])==8
remote=r'''
import hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
p=json.load(sys.stdin);base=Path('/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114');groups=[]
assert len(p['archives'])==8
for rec in p['archives']:
 files=rec['remote_files'];roots={str(Path(f).parent) for f in files};assert len(roots)==1
 root=Path(roots.pop());assert root.parent==base and root.is_dir() and not root.is_symlink()
 assert root.name.startswith(('neural-arrival-phase-control-', 'neural-arrival-phase-history-')) and root.name.endswith('-1000')
 assert all(not f.is_symlink() for f in root.rglob('*'))
 actual={str(f) for f in root.rglob('*') if f.is_file()};assert actual==set(files),(str(root),'file set changed')
 for name,expected in files.items():
  h=hashlib.sha256()
  with open(name,'rb') as f:
   for chunk in iter(lambda:f.read(1048576),b''):h.update(chunk)
  assert h.hexdigest()==expected,name
 check=subprocess.run(['lsof','-nP','+D',str(root)],capture_output=True,text=True)
 assert check.returncode==1 and not check.stdout and not check.stderr,(str(root),check.returncode,check.stdout,check.stderr)
 groups.append((root,files))
assert len({str(root) for root,_ in groups})==8
before=shutil.disk_usage(base).free;records=[]
for root,files in groups:
 size=sum(Path(x).stat().st_size for x in files);shutil.rmtree(root);records.append({'directory':str(root),'file_count':len(files),'logical_bytes':size})
after=shutil.disk_usage(base).free
print(json.dumps({'verified_git_commit':p['commit'],'free_before':before,'free_after':after,'removed':records},indent=2))
'''
host=['ssh','-4','-o','BatchMode=yes','-o','HostName=192.168.1.141','macmini']
result=subprocess.run(host+['python3 -c '+shlex.quote(remote)],input=json.dumps(payload),text=True,capture_output=True)
print(result.stdout,end='')
if result.returncode:
 print(result.stderr,file=__import__('sys').stderr);raise SystemExit(result.returncode)
Path('/private/tmp/crow-arrival-scratch-retirement.json').write_text(result.stdout)
