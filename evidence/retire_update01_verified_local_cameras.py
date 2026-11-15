from pathlib import Path
import hashlib,json,subprocess
base=Path('/Users/home/Documents/Codex/2026-11-07/c/crow-48s-landing-checkpoint-20261114/neural-update01-video');root=Path('/private/tmp/crow-balance-evidence-20261115/evidence');paths=[]
for seed,group in [('20310201','failure'),('20310221','hold')]:
 m=json.loads((root/f'update01-restored-manifest-{seed}.json').read_text())['remote_files'];expected={Path(k).name:v for k,v in m.items() if k.endswith('.mp4')};assert set(expected)=={x+'.mp4' for x in ('front','back','above','below','feet')}
 for name,digest in expected.items():
  p=base/group/name;assert p.is_file() and not p.is_symlink() and hashlib.sha256(p.read_bytes()).hexdigest()==digest;paths.append(p)
p=subprocess.run(['lsof','-nP',*map(str,paths)],capture_output=True,text=True);assert p.returncode==1 and not p.stdout and not p.stderr,(p.returncode,p.stdout,p.stderr)
size=sum(x.stat().st_size for x in paths)
for x in paths:x.unlink()
print(json.dumps({'files_removed':len(paths),'logical_bytes':size,'verification':'matched individually restored Git archive members','preserved_delivered_video':str(base/'crow-update01-balance-five-angles.mp4')},indent=2))
