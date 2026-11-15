from pathlib import Path
import hashlib,json,subprocess
base=Path('/Users/home/Documents/Codex/2026-11-07/c/crow-48s-landing-checkpoint-20261114/neural-phase-comparison-video');m=json.loads((base/'camera-source-sha256.json').read_text());paths=[]
for group,views in m.items():
 for view,h in views.items():
  p=base/group/(view+'.mp4');assert p.is_file() and not p.is_symlink() and hashlib.sha256(p.read_bytes()).hexdigest()==h;paths.append(p)
assert len(paths)==10
p=subprocess.run(['lsof','-nP',*map(str,paths)],capture_output=True,text=True);assert p.returncode==1 and not p.stdout and not p.stderr,(p.returncode,p.stdout,p.stderr)
before=sum(x.stat().st_size for x in paths)
for x in paths:x.unlink()
print(json.dumps({'files_removed':len(paths),'logical_bytes':before,'verification':'exact bytes independently restored from Git and matched against source camera hashes','preserved':str(base/'crow-phase-balance-comparison-five-angles.mp4')},indent=2))
