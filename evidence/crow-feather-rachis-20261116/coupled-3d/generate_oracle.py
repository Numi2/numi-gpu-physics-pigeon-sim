import hashlib,json
from pathlib import Path
import numpy as np
repo=Path('/private/tmp/crow-balance-evidence-20261115');fixture=repo/'evidence/crow-feather-rachis-20261116/coupled-3d/fixture.py';g={};exec(compile(fixture.read_text().split("if sys.argv[1]=='generate':")[0],str(fixture),'exec'),g)
U,root,w,q0,v0,K,rod_m,mass,indices,support,dt=(g[x] for x in ('U','root','w','q0','v0','K','rod_m','mass','indices','support','dt'));c=U.T@(root*q0);d=U.T@(root*v0);states=[]
for i in range(80):
 t=(i+1)*dt;co=np.cos(w*t);si=np.sin(w*t);safe=np.divide(si,w,out=np.full_like(w,t),where=w>0);states.append(((U@(co*c+safe*d))/root).tolist())
ip=fixture.parent/'input.bin';print(json.dumps({'hessian_sha256':hashlib.sha256(g['hp'].read_bytes()).hexdigest(),'input_sha256':hashlib.sha256(ip.read_bytes()).hexdigest(),'K':K.tolist(),'rod_mass':rod_m.tolist(),'effective_mass':mass.tolist(),'support':support.tolist(),'indices':indices.tolist(),'q0':q0.tolist(),'v0':v0.tolist(),'expected_positions':states},separators=(',',':')))
