import hashlib,json,math
from pathlib import Path
import numpy as np
r=Path(__file__).resolve().parents[3]
hp=r/'evidence/crow-feather-rachis-20261116/phase-analysis/feather-phase-hessian-20261116/stdout.jsonl'
gp=r/'evidence/crow-feather-rachis-20261116/schur-prototype/feather-world-substep-schur-20261116/stdout.jsonl'
h=json.loads(hp.read_text().strip());gpu=[json.loads(s) for s in gp.read_text().splitlines() if json.loads(s).get('event')=='run' and json.loads(s).get('substeps')==8][0]
k=np.array(h['hessian']);m=np.array(h['masses']);y0=np.array(h['initial_y']);fixed=np.array([0,4,8]);free=np.array([1,2,3,5,6,7]);dt=.000125
results={}
for damping in (0,100):
 y=y0.copy();v=np.zeros(9)
 mat=k[np.ix_(free,free)]+np.diag(m[free]/dt**2)
 for _ in range(80):
  rhs=(m[free]/dt**2)*(y[free]+dt*v[free])-k[np.ix_(free,fixed)]@y0[fixed]
  yn=y.copy();yn[free]=np.linalg.solve(mat,rhs);yn[fixed]=y0[fixed]
  v=(yn-y)/dt*math.exp(-damping*dt);v[fixed]=0;y=yn
 f=-(k@y); gy=np.array(gpu['state'])[:,1];gv=np.array(gpu['state'])[:,4]
 results[str(damping)]={'positions_m':y.tolist(),'velocities_m_s':v.tolist(),'elastic_forces_N':f.tolist(),'max_free_force_N':float(np.max(abs(f[free]))),'end_reaction_difference_N':float(abs(f[0]-f[8])),'max_free_position_difference_m':float(np.max(abs(y[free]-gy[free]))),'max_free_velocity_difference_m_s':float(np.max(abs(v[free]-gv[free])))}
out={'inputs_sha256':{str(x.relative_to(r)):hashlib.sha256(x.read_bytes()).hexdigest() for x in (hp,gp)},'numpy':np.__version__,'dt_s':dt,'steps':80,'free_nodes':free.tolist(),'fixed_nodes':fixed.tolist(),'results':results}
print(json.dumps(out,indent=2))
