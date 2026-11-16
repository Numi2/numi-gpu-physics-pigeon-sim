import hashlib,json,struct,sys
from pathlib import Path
import numpy as np
root=Path('/private/tmp/crow-balance-evidence-20261115');hp=root/'evidence/crow-feather-rachis-20261116/phase-analysis/feather-phase-hessian-20261116/stdout.jsonl';h=json.loads(hp.read_text());K=np.array(h['hessian']);rod_m=np.array(h['masses']);rod_x=np.array(h['initial_y']);fixed=np.array([0,4,8]);support_m=np.array([.00012,.00015,.00012]);step=.000125;v_rod=np.array([0,.03,-.02,.01,0,-.01,.02,-.03,0]);v_support=np.array([.02,-.01,.015]);cases=[]
for label,rv,sv in [('rest',np.zeros(9),np.zeros(3)),('incoming',v_rod,v_support)]:
 for reverse in (False,True):
  perm=np.arange(8,-1,-1) if reverse else np.arange(9);inverse=np.argsort(perm);mass=np.r_[rod_m[perm],support_m];x0=np.r_[rod_x[perm],rod_x[fixed]];v0=np.r_[rv[perm],sv];k=np.zeros((12,12));k[:9,:9]=K[np.ix_(perm,perm)];A=np.diag(mass/step**2)+k;b=mass/step**2*(x0+step*v0);J=np.zeros((3,12))
  for row,original in enumerate(fixed):J[row,np.flatnonzero(perm==original)[0]]=1;J[row,9+row]=-1
  target=np.zeros(3);mat=np.block([[A,-J.T],[J,np.zeros((3,3))]]);direct=np.linalg.solve(mat,np.r_[b,target]);cases.append((label+('_reverse' if reverse else '_forward'),inverse,mass,x0,v0,k,A,b,J,target,direct))
if sys.argv[1]=='generate':
 with open(sys.argv[2],'wb') as f:
  for _,_,_,_,_,_,A,b,J,target,_ in cases:f.write(struct.pack('<195f',*A.flatten(),*b,*J.flatten(),*target))
elif sys.argv[1]=='analyze':
 data=Path(sys.argv[2]).read_bytes();assert len(data)==4*64;out={}
 for i,(label,inv,mass,x0,v0,k,A,b,J,target,direct) in enumerate(cases):
  vals=struct.unpack_from('<15fI',data,i*64);x=np.array(vals[:12]);lam=np.array(vals[12:15]);status=vals[15];mapped=np.r_[x[:9][inv],x[9:]];ref=np.r_[direct[:9][inv],direct[9:12]];velocity=(x-x0)/step;mom=np.sum(mass*(velocity-v0))+step*np.sum(k@x);reaction=J.T@lam
  out[label]={'status':status,'position_m':mapped.tolist(),'support_forces_on_rod_N':lam.tolist(),'body_forces_N':reaction[9:].tolist(),'max_force_residual_N':float(np.max(np.abs(A@x-b-reaction))),'max_equality_error_m':float(np.max(np.abs(J@x-target))),'max_position_error_vs_fp64_m':float(np.max(np.abs(mapped-ref))),'momentum_balance_error_kg_m_s':float(abs(mom))}
 for key in ('rest','incoming'):out[key+'_order_gap_m']=float(np.max(np.abs(np.array(out[key+'_forward']['position_m'])-np.array(out[key+'_reverse']['position_m']))))
 passed=all(out[label]['status']==0 and out[label]['max_force_residual_N']<.01 and out[label]['max_equality_error_m']<1e-9 and out[label]['max_position_error_vs_fp64_m']<.05e-6 and out[label]['momentum_balance_error_kg_m_s']<1e-8 for label,*_ in cases) and all(out[k+'_order_gap_m']<.05e-6 for k in ('rest','incoming'))
 print(json.dumps({'hessian_sha256':hashlib.sha256(hp.read_bytes()).hexdigest(),'numpy':np.__version__,'support_masses_kg':support_m.tolist(),'dt_s':step,'passed':passed,'results':out},indent=2));
 if not passed:raise SystemExit(2)
else:raise ValueError('expected generate or analyze')
