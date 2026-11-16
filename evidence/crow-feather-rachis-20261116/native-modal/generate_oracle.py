import hashlib,json
from pathlib import Path
import numpy as np
repo=Path('/private/tmp/crow-balance-evidence-20261115');fixture=repo/'evidence/crow-feather-rachis-20261116/native-modal/fixture.py';g={};exec(compile(fixture.read_text().split("if sys.argv[1]=='generate':")[0],str(fixture),'exec'),g)
U,root,w,q0,v0,K,m,dt=(g[x] for x in ('U','root','w','q0','v0','K','m','dt'));c=U.T@(root*q0);d=U.T@(root*v0);states=[]
for i in range(80):
 t=(i+1)*dt;cos=np.cos(w*t);sin=np.sin(w*t);safe=np.divide(sin,w,out=np.full_like(w,t),where=w>0);states.append(((U@(cos*c+safe*d))/root).tolist())
ip=fixture.parent/'input.bin';print(json.dumps({'hessian_sha256':hashlib.sha256(g['hp'].read_bytes()).hexdigest(),'input_sha256':hashlib.sha256(ip.read_bytes()).hexdigest(),'K':K.tolist(),'mass':m.tolist(),'q0':q0.tolist(),'v0':v0.tolist(),'expected_positions':states},separators=(',',':')))
