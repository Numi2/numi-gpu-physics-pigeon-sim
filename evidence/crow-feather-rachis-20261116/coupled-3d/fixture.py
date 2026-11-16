import hashlib,json,struct,sys
from pathlib import Path
import numpy as np
repo=Path('/private/tmp/crow-balance-evidence-20261115');hp=repo/'evidence/crow-feather-rachis-20261116/coupled-3d/crow-3d-hessian.json';h=json.loads(hp.read_text());K=np.array(h['hessian']);rod_m=np.array(h['masses']);indices=np.array([0,4,8]);support=np.array([.00012,.00015,.00012]);m=rod_m.copy();m[indices]+=support;mass=np.repeat(m,3);root=np.sqrt(mass);x=np.arange(9)/8;shape=np.minimum(x,1-x);q0=np.array([[.2e-6*np.sin(np.pi*t),25e-6*(3*u-4*u**3),8e-6*np.sin(np.pi*t)] for t,u in zip(x,shape)]).flatten();v0=np.array([[.01*np.cos(np.pi*t),.02*np.cos(2*np.pi*t),.01*np.sin(np.pi*t)] for t in x]).flatten();w2,U=np.linalg.eigh(K/root[:,None]/root[None,:]);w=np.sqrt(np.where(w2>max(w2)*1e-10,w2,0));dt=.000125;sym=float(np.max(np.abs(K-K.T))/np.max(np.abs(K)));negative=float(abs(min(w2[0],0))/max(w2))
if sys.argv[1]=='generate':
 if sym>=1e-10 or negative>=1e-8:raise SystemExit('Hessian stability criterion failed')
 Path(sys.argv[2]).write_bytes(struct.pack('<838f',*U.flatten(),*root,*w,*q0,*v0,dt))
elif sys.argv[1]=='analyze':
 data=Path(sys.argv[2]).read_bytes();assert len(data)==80*81*4;states=np.array(struct.unpack('<6480f',data)).reshape((80,81));initial=.5*q0@K@q0+.5*np.sum(mass*v0*v0);c=U.T@(root*q0);d=U.T@(root*v0);maximum={'position_error_m':0.,'energy_relative_error':0.,'momentum_error_kg_m_s':0.,'force_residual_N':0.};samples=[]
 for i,row in enumerate(states):
  t=(i+1)*dt;co=np.cos(w*t);si=np.sin(w*t);safe=np.divide(si,w,out=np.full_like(w,t),where=w>0);reference=(U@(co*c+safe*d))/root;q=row[:27];v=row[27:54];a=row[54:81];energy=.5*q@K@q+.5*np.sum(mass*v*v);position=float(np.max(np.abs(q-reference)));e=float(abs(energy-initial)/initial);momentum=float(np.linalg.norm(np.sum((mass*(v-v0)).reshape(9,3),axis=0)));body_force=support[:,None]*a.reshape(9,3)[indices,:];support_on_rod=np.zeros((9,3));support_on_rod[indices,:]=-body_force;residual=float(np.max(np.abs(np.repeat(rod_m,3)*a+K@q-support_on_rod.flatten())))
  maximum['position_error_m']=max(maximum['position_error_m'],position);maximum['energy_relative_error']=max(maximum['energy_relative_error'],e);maximum['momentum_error_kg_m_s']=max(maximum['momentum_error_kg_m_s'],momentum);maximum['force_residual_N']=max(maximum['force_residual_N'],residual)
  if i in (0,7,79):samples.append({'step':i+1,'time_s':t,'position_error_m':position,'energy_relative_error':e,'momentum_error_kg_m_s':momentum,'force_residual_N':residual,'support_force_N':body_force.tolist()})
 passed=bool(sym<1e-10 and negative<1e-8 and np.all(np.isfinite(states)) and maximum['position_error_m']<1e-6 and maximum['energy_relative_error']<.01 and maximum['momentum_error_kg_m_s']<1e-8 and maximum['force_residual_N']<.01)
 print(json.dumps({'hessian_sha256':hashlib.sha256(hp.read_bytes()).hexdigest(),'numpy':np.__version__,'hessian_asymmetry_relative':sym,'max_negative_eigenvalue_ratio':negative,'eigenvalues_rad2_s2':w2.tolist(),'support_masses_kg':support.tolist(),'initial_energy_J':initial,'dt_s':dt,'steps':80,'passed':passed,'maxima':maximum,'samples':samples,'constraint_note':'support positions eliminated as identical to node positions'},indent=2));
 if not passed:raise SystemExit(2)
else:raise ValueError('expected generate or analyze')
