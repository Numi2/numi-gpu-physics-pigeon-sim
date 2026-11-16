import hashlib,json
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[3]; path=root/'evidence/crow-feather-rachis-20261116/phase-analysis/feather-phase-hessian-20261116/stdout.jsonl';h=json.loads(path.read_text())
k0=np.array(h['hessian']);m0=np.array(h['masses']);y0=np.array(h['initial_y']);dt=.000125; original_fixed=np.array([0,4,8]);velocity=np.array([0,.03,-.02,.01,0,-.01,.02,-.03,0]);results={}
for case,v0 in [('rest',np.zeros(9)),('incoming',velocity)]:
 for reverse in (False,True):
  perm=np.arange(8,-1,-1) if reverse else np.arange(9); inv=np.argsort(perm);k=k0[np.ix_(perm,perm)];mass=m0[perm];x0=y0[perm];v=v0[perm];fixed=np.flatnonzero(np.isin(perm,original_fixed));free=np.flatnonzero(~np.isin(perm,original_fixed));j=np.eye(9)[fixed];target=x0[fixed]
  mat=np.diag(mass/dt**2)+k;b=(mass/dt**2)*(x0+dt*v)
  free_state=np.linalg.solve(mat,b);response=np.linalg.solve(mat,j.T);w=j@response;lam=np.linalg.solve(w,target-j@free_state);schur=free_state+response@lam
  full=np.block([[mat,-j.T],[j,np.zeros((3,3))]]);direct=np.linalg.solve(full,np.r_[b,target]);xd=direct[:9];force_residual=mat@schur-b-j.T@lam
  results[case+'_'+('reverse' if reverse else 'forward')]={'position_m':schur[inv].tolist(),'velocity_m_s':((schur-x0)/dt)[inv].tolist(),'constraint_force_N':(j.T@lam)[inv].tolist(),'max_dynamic_residual_N':float(np.max(np.abs(force_residual))),'max_free_residual_N':float(np.max(np.abs(force_residual[free]))),'max_attachment_error_m':float(np.max(np.abs(j@schur-target))),'max_direct_schur_difference_m':float(np.max(np.abs(schur-xd))),'condition_A':float(np.linalg.cond(mat)),'condition_Schur':float(np.linalg.cond(w))}
for case in ('rest','incoming'):
 a=np.array(results[case+'_forward']['position_m']);b=np.array(results[case+'_reverse']['position_m']);gap=float(np.max(np.abs(a-b)));results[case+'_permutation_gap_m']=gap
out={'hessian_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'numpy':np.__version__,'equation':'A x = M/h^2 (x0+h v0)+J^T lambda, A=M/h^2+K; Jx=target','dt_s':dt,'results':results}
for key,value in results.items():
 if isinstance(value,dict):
  assert value['max_dynamic_residual_N']<1e-8 and value['max_attachment_error_m']<1e-12 and value['max_direct_schur_difference_m']<1e-12
 else: assert value<1e-12
print(json.dumps(out,indent=2))
