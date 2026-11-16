import sys,json,struct,math,hashlib
from pathlib import Path
import numpy as np
base=Path('/private/tmp/crow-balance-evidence-20261115/evidence/crow-feather-rachis-20261116');hp=base/'coupled-3d/crow-3d-hessian.json';bp=base/'articulated-hand-response/crow-articulated-hand-response.json';h=json.loads(hp.read_text());b=json.loads(bp.read_text());n=b['nv'];assert n==46;M=np.array(b['M']).reshape(n,n);Jb=np.array(b['J']).reshape(3,n);K0=np.array(h['hessian']);m=np.array(h['masses']);dt=.000125;z=np.arange(9)/8;shape=np.minimum(z,1-z);x0=np.array([[.2e-6*np.sin(np.pi*t),25e-6*(3*u-4*u**3),8e-6*np.sin(np.pi*t)] for t,u in zip(z,shape)]).flatten();vr=np.array([[.01*np.cos(np.pi*t),.02*np.cos(2*np.pi*t),.01*np.sin(np.pi*t)] for t in z]).flatten();vb=np.zeros(n);vb[:6]=[.01,-.005,.004,.2,-.1,.15];names={v['name']:v['v'] for v in b['dofs']};vb[names['crow_left_elbow_flex']]=.1;vb[names['crow_left_wrist_flex']]=-.1
def mv(a,b):return np.array([math.fsum(float(x)*float(y) for x,y in zip(row,b)) for row in a])
cases=[]
for name,rv,bv in [('rest',np.zeros(27),np.zeros(n)),('incoming',vr,vb)]:
 for reverse in (False,True):
  nodes=np.arange(8,-1,-1) if reverse else np.arange(9);perm=np.array([3*i+a for i in nodes for a in range(3)]);inv=np.argsort(perm);mass=np.repeat(m[nodes],3);K=K0[np.ix_(perm,perm)];A=np.zeros((73,73));A[:27,:27]=np.diag(mass/dt**2)+K;A[27:,27:]=M/dt**2;rhs=np.r_[mass/dt**2*(x0[perm]+dt*rv[perm]),mv(M,bv)/dt];Jr=np.zeros((3,27));anchor=int(np.flatnonzero(nodes==0)[0]);Jr[:,3*anchor:3*anchor+3]=np.eye(3);J=np.c_[Jr,-Jb];ref=np.linalg.solve(np.block([[A,-J.T],[J,np.zeros((3,3))]]),np.r_[rhs,np.zeros(3)]);cases.append((name+('_reverse' if reverse else '_forward'),inv,A,rhs,J,ref))
if sys.argv[1]=='generate':
 with open(sys.argv[2],'wb') as f:
  for _,_,A,rhs,J,_ in cases:f.write(struct.pack('<5624f',*A.flatten(),*rhs,*J.flatten(),0,0,0))
elif sys.argv[1]=='analyze':
 data=Path(sys.argv[2]).read_bytes();assert len(data)==4*308;out={}
 for i,(name,inv,A,b,J,ref) in enumerate(cases):
  vals=struct.unpack_from('<76fI',data,i*308);x=np.array(vals[:73]);lam=np.array(vals[73:76]);mapped=np.r_[x[:27][inv],x[27:]];out[name]={'status':vals[76],'position_and_joints':mapped.tolist(),'lambda_force_N':lam.tolist(),'generalized_residual_max':float(np.max(np.abs(mv(A,x)-b-mv(J.T,lam)))),'attachment_error_max_m':float(np.max(np.abs(mv(J,x)))),'difference_vs_fp64_max':float(np.max(np.abs(x-ref[:73])))}
 for name in ('rest','incoming'):out[name+'_order_gap']=float(np.max(np.abs(np.array(out[name+'_forward']['position_and_joints'])-np.array(out[name+'_reverse']['position_and_joints']))))
 passed=all(v['status']==0 and v['generalized_residual_max']<.01 and v['attachment_error_max_m']<1e-9 and v['difference_vs_fp64_max']<1e-6 for v in out.values() if isinstance(v,dict)) and all(out[name+'_order_gap']<1e-6 for name in ('rest','incoming'));print(json.dumps({'pass':passed,'dt_s':dt,'results':out},indent=2));sys.exit(0 if passed else 2)
else:raise ValueError('expected generate or analyze')
