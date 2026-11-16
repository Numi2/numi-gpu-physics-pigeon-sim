import json,numpy as np
from pathlib import Path
p=Path(__file__).parent;d=json.loads((p/'hessian.json').read_text());data=[json.loads(x) for x in (p/'midpoint.jsonl').read_text().splitlines()];states=[x for x in data if x.get('backend','').startswith('midpoint_')];K=np.array(d['hessian']);mass=np.array(d['masses']);q0=np.array(d['initial_y']);root=np.sqrt(mass);A=K/root[:,None]/root[None,:];w2,U=np.linalg.eigh(A);maxw2=max(w2);safe=np.where(w2>maxw2*1e-10,w2,0);w=np.sqrt(safe);c=U.T@(root*q0);out=[]
for i,row in enumerate(states,1):
 t=i*.000125;q=(U@(np.cos(w*t)*c))/root;actual=np.array([x[1] for x in row['state']]);out.append({'step':i,'time_s':t,'max_displacement_error_um':float(np.max(np.abs(actual-q))*1e6),'center_expected_um':float(q[4]*1e6),'center_midpoint_um':float(actual[4]*1e6)})
result={'hessian_symmetry_relative':float(np.max(np.abs(K-K.T))/np.max(np.abs(K))),'eigenvalues_rad2_s2':w2.tolist(),'frequencies_hz':(w/(2*np.pi)).tolist(),'reconstructed_initial_max_error_m':float(np.max(np.abs((U@c)/root-q0))),'steps':out};(p/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
