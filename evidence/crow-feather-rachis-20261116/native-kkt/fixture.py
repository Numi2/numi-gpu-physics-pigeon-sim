import json,struct,sys,hashlib
from pathlib import Path
import numpy as np
r=Path('/private/tmp/crow-balance-evidence-20261115');hp=r/'evidence/crow-feather-rachis-20261116/phase-analysis/feather-phase-hessian-20261116/stdout.jsonl';rp=r/'evidence/crow-feather-rachis-20261116/constrained-kkt/result.json';h=json.loads(hp.read_text());ref=json.loads(rp.read_text())['results'];k=np.array(h['hessian']);m=np.array(h['masses']);y=np.array(h['initial_y']);hstep=.000125;fixed=np.array([0,4,8]);vel=np.array([0,.03,-.02,.01,0,-.01,.02,-.03,0]);cases=[]
for label,v in [('rest',np.zeros(9)),('incoming',vel)]:
 for rev in (False,True):
  perm=np.arange(8,-1,-1) if rev else np.arange(9);ix=np.flatnonzero(np.isin(perm,fixed));A=np.diag(m[perm]/hstep**2)+k[np.ix_(perm,perm)];b=m[perm]/hstep**2*(y[perm]+hstep*v[perm]);target=y[perm][ix];cases.append((label+('_reverse' if rev else '_forward'),perm,ix,A,b,target))
if sys.argv[1]=='generate':
 with open(sys.argv[2],'wb') as f:
  for _,_,ix,A,b,target in cases:f.write(struct.pack('<93f3I',*A.flatten(),*b,*target,*ix))
elif sys.argv[1]=='analyze':
 data=Path(sys.argv[2]).read_bytes();assert len(data)==4*52;out={}
 for i,(label,perm,ix,A,b,target) in enumerate(cases):
  vals=struct.unpack_from('<12fI',data,i*52);state=np.array(vals[:9]);lam=np.array(vals[9:12]);status=vals[12];mapped=state[np.argsort(perm)];j=np.eye(9)[ix]
  out[label]={'status':status,'position_m':mapped.tolist(),'support_force_on_rod_N':(j.T@lam)[np.argsort(perm)].tolist(),'max_force_residual_N':float(np.max(np.abs(A@state-b-j.T@lam))),'max_support_error_m':float(np.max(np.abs(j@state-target))),'max_position_error_vs_fp64_m':float(np.max(np.abs(mapped-np.array(ref[label]['position_m']))))}
 for key in ('rest','incoming'):out[key+'_order_gap_m']=float(np.max(np.abs(np.array(out[key+'_forward']['position_m'])-np.array(out[key+'_reverse']['position_m']))))
 passed=all(out[k]['status']==0 and out[k]['max_force_residual_N']<.01 and out[k]['max_support_error_m']<1e-9 and out[k]['max_position_error_vs_fp64_m']<.05e-6 for k,_,_,_,_,_ in cases) and all(out[k+'_order_gap_m']<.05e-6 for k in ('rest','incoming'))
 print(json.dumps({'input_hessian_sha256':hashlib.sha256(hp.read_bytes()).hexdigest(),'numpy':np.__version__,'passed':passed,'results':out},indent=2))
 if not passed:raise SystemExit(2)
else:raise ValueError('expected generate or analyze')
