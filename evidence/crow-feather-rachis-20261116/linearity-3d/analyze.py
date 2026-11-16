import hashlib,json
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[1];hp=root/'coupled-3d/crow-3d-hessian.json';ep=root/'linearity-3d/crow-3d-linearity.jsonl';K=np.array(json.loads(hp.read_text())['hessian']);out=[]
for line in ep.read_text().splitlines():
 d=json.loads(line);q=np.array(d['q']);e=.5*q@K@q;out.append({'scale':d['scale'],'native_J':d['total_J'],'quadratic_J':e,'relative_error':abs(e-d['total_J'])/d['total_J'],'native_stretch_J':d['stretch_J'],'native_bend_J':d['bend_J']})
print(json.dumps({'input_sha256':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (hp,ep)},'numpy':np.__version__,'results':out},indent=2))
