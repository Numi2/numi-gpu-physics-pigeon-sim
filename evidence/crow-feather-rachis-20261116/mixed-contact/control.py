import json,hashlib,sys,platform,math
from pathlib import Path
import numpy as np
def mm(a,b):
 a=np.asarray(a);b=np.asarray(b);flat=b.ndim==1
 if flat:b=b[:,None]
 c=np.array([[math.fsum(float(x)*float(y) for x,y in zip(row,col)) for col in b.T] for row in a]);return c[:,0] if flat else c
base=Path('/private/tmp/crow-balance-evidence-20261115/evidence/crow-feather-rachis-20261116');hp=base/'coupled-3d/crow-3d-hessian.json';bp=base/'articulated-hand-response/crow-articulated-hand-response.json';h=json.loads(hp.read_text());b=json.loads(bp.read_text());n=b['nv'];M=np.array(b['M']).reshape(n,n);Jb=np.array(b['J']).reshape(3,n);Xb=np.array(b['X']).reshape(3,n).T;K0=np.array(h['hessian']);m=np.array(h['masses']);dt=.000125;z=np.arange(9)/8;shape=np.minimum(z,1-z);x0=np.array([[.2e-6*np.sin(np.pi*t),25e-6*(3*u-4*u**3),8e-6*np.sin(np.pi*t)] for t,u in zip(z,shape)]).flatten();vr=np.array([[.01*np.cos(np.pi*t),.02*np.cos(2*np.pi*t),.01*np.sin(np.pi*t)] for t in z]).flatten();vb=np.zeros(n);vb[:6]=[.01,-.005,.004,.2,-.1,.15];names={v['name']:v['v'] for v in b['dofs']};vb[names['crow_left_elbow_flex']]=.1;vb[names['crow_left_wrist_flex']]=-.1
out={}
for scenario,rv,bv in [('rest',np.zeros(27),np.zeros(n)),('incoming',vr,vb)]:
 for reverse in (False,True):
  nodes=np.arange(8,-1,-1) if reverse else np.arange(9);perm=np.array([3*i+a for i in nodes for a in range(3)]);inv=np.argsort(perm);mass=np.repeat(m[nodes],3);K=K0[np.ix_(perm,perm)];Ar=np.diag(mass/dt**2)+K;Ab=M/dt**2;br=mass/dt**2*(x0[perm]+dt*rv[perm]);bb=mm(M,bv)/dt;Jr=np.zeros((3,27));Jr[:,3*int(np.flatnonzero(nodes==0)[0]):3*int(np.flatnonzero(nodes==0)[0])+3]=np.eye(3);J=np.c_[Jr,-Jb];C=np.zeros((1,27+n));C[0,3*int(np.flatnonzero(nodes==8)[0])+2]=1
  A=np.zeros((27+n,27+n));A[:27,:27]=Ar;A[27:,27:]=Ab;rhs=np.r_[br,bb];free=np.r_[np.linalg.solve(Ar,br),dt*bv];R=np.r_[np.linalg.solve(Ar,Jr.T),-dt**2*Xb];W=mm(J,R);lf=np.linalg.solve(W,-mm(J,free));eq=free+mm(R,lf);Qcontact=np.r_[np.linalg.solve(Ar,C[0,:27]),np.zeros(n)];proj=Qcontact-mm(R,np.linalg.solve(W,mm(J,Qcontact)));D=mm(C,proj)[0];assert D>0
  for active in (False,True):
   target=mm(C,eq)[0]+(1e-5 if active else -1e-5);mu=max(0.,(target-mm(C,eq)[0])/D);x=eq+proj*mu;lam=lf-np.linalg.solve(W,mm(J,Qcontact))*mu;gap=mm(C,x)[0]-target
   if active:
    Jall=np.r_[J,C];mat=np.block([[A,-Jall.T],[Jall,np.zeros((4,4))]]);direct=np.linalg.solve(mat,np.r_[rhs,np.zeros(3),target]);reference=direct[:27+n]
   else:
    mat=np.block([[A,-J.T],[J,np.zeros((3,3))]]);reference=np.linalg.solve(mat,np.r_[rhs,np.zeros(3)])[:27+n]
   res=mm(A,x)-rhs-mm(J.T,lam)-C[0]*mu;label=scenario+('_reverse_' if reverse else '_forward_')+('active' if active else 'inactive');out[label]={'active_expected':active,'normal_force_N':float(mu),'gap_m':float(gap),'complementarity_N_m':float(abs(mu*gap)),'equality_max_m':float(np.max(np.abs(mm(J,x)))),'generalized_residual_max':float(np.max(np.abs(res))),'direct_difference_max':float(np.max(np.abs(x-reference))),'mapped_configuration':np.r_[x[:27][inv],x[27:]].tolist()}
for s in ('rest','incoming'):
 for c in ('active','inactive'):
  out[s+'_'+c+'_order_gap']=float(np.max(np.abs(np.array(out[s+'_forward_'+c]['mapped_configuration'])-np.array(out[s+'_reverse_'+c]['mapped_configuration']))))
ok=True
for name,v in out.items():
 if not isinstance(v,dict):ok=ok and v<1e-6;continue
 ok=ok and v['normal_force_N']>=0 and v['gap_m']>=-1e-9 and v['complementarity_N_m']<1e-9 and v['equality_max_m']<1e-9 and v['generalized_residual_max']<.01 and v['direct_difference_max']<1e-6 and ((v['normal_force_N']>0)==v['active_expected'])
print(json.dumps({'platform':platform.platform(),'numpy':np.__version__,'pass':ok,'dt_s':dt,'hessian_sha256':hashlib.sha256(hp.read_bytes()).hexdigest(),'bird_data_sha256':hashlib.sha256(bp.read_bytes()).hexdigest(),'results':out},indent=2));sys.exit(0 if ok else 2)
