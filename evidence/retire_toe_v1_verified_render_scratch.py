from pathlib import Path
import hashlib,json,shutil,subprocess
base=Path('/tmp/crow-48s-multiview-20261114');records=[]
for seed in ('20310129','20310201'):
 root=base/f'render-phase-comparison-neural-toe-action-v1-development-{seed}-1000';manifest=json.loads((base/f'toe-v1-restored-manifest-{seed}.json').read_text())['remote_files'];assert root.is_dir() and not root.is_symlink()
 actual={str(x) for x in root.rglob('*') if x.is_file()};assert actual==set(manifest),(seed,'file set changed')
 assert all(not x.is_symlink() for x in root.rglob('*'))
 for path,digest in manifest.items():assert hashlib.sha256(Path(path).read_bytes()).hexdigest()==digest,path
 p=subprocess.run(['lsof','-nP','+D',str(root)],capture_output=True,text=True);assert p.returncode==1 and not p.stdout and not p.stderr,(p.returncode,p.stdout,p.stderr)
 before=shutil.disk_usage(base).free;size=sum(Path(p).stat().st_size for p in manifest);shutil.rmtree(root);after=shutil.disk_usage(base).free;records.append({'seed':seed,'files_verified':len(manifest),'logical_bytes':size,'free_before':before,'free_after':after})
print(json.dumps({'source':'independently restored matching archive manifests from Git; renderer output scratch only','removed':records},indent=2))
