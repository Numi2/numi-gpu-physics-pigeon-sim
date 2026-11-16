import hashlib,json
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[3];hp=root/'evidence/crow-feather-rachis-20261116/phase-analysis/feather-phase-hessian-20261116/stdout.jsonl';rp=root/'evidence/crow-feather-rachis-20261116/constrained-kkt/result.json';h=json.loads(hp.read_text());reference=json.loads(rp.read_text())['results'];k0=np.array(h['hessian']);m0=np.array(h['masses']);y0=np.array(h['initial_y']);dt=.000125;fixed=np.array([0,4,8]);vin=np.array([0,.03,-.02,.01,0,-.01,.02,-.03,0]);res={}
for case,v0 in [('rest',np.zeros(9)),('incoming',vin)]:
 for reverse in (False,True):
  perm=np.arange(8,-1,-1) if reverse else np.arange(9);inv=np.argsort(perm);k=k0[np.ix_(perm,perm)];m=m0[perm];x=y0[perm];v=v0[perm];ix=np.flatnonzero(np.isin(perm,fixed));j=np.eye(9)[ix];target=x[ix];A=np.diag(m/dt**2)+k;b=m/dt**2*(x+dt*v)
  a32=A.astype(np.float32);b32=b.astype(np.float32);j32=j.astype(np.float32);t32=target.astype(np.float32);free=np.linalg.solve(a32,b32);response=np.linalg.solve(a32,j32.T);w=j32@response;lam=np.linalg.solve(w,t32-j32@free);state=free+response@lam;state64=state.astype(np.float64);l64=lam.astype(np.float64);mapped=state64[inv];label=case+'_'+('reverse' if reverse else 'forward');ref=np.array(reference[label]['position_m'])
  res[label]={'position_m':mapped.tolist(),'force_on_rod_N':(j.T@l64)[inv].tolist(),'max_force_residual_N':float(np.max(np.abs(A@state64-b-j.T@l64))),'max_support_error_m':float(np.max(np.abs(j@state64-target))),'max_position_error_vs_fp64_m':float(np.max(np.abs(mapped-ref)))}
for c in ('rest','incoming'):res[c+'_permutation_gap_m']=float(np.max(np.abs(np.array(res[c+'_forward']['position_m'])-np.array(res[c+'_reverse']['position_m']))))
out={'input_sha256':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (hp,rp)},'numpy':np.__version__,'results':res};print(json.dumps(out,indent=2))
