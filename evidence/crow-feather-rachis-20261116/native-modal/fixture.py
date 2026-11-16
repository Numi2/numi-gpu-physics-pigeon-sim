import hashlib,json,struct,sys
from pathlib import Path
import numpy as np
repo=Path('/private/tmp/crow-balance-evidence-20261115');hp=repo/'evidence/crow-feather-rachis-20261116/phase-analysis/feather-phase-hessian-20261116/stdout.jsonl';h=json.loads(hp.read_text());K=np.array(h['hessian']);m=np.array(h['masses']);q0=np.array(h['initial_y']);v0=np.zeros(9);root=np.sqrt(m);w2,U=np.linalg.eigh(K/root[:,None]/root[None,:]);w=np.sqrt(np.where(w2>np.max(w2)*1e-10,w2,0));dt=.000125
if sys.argv[1]=='generate':
 Path(sys.argv[2]).write_bytes(struct.pack('<118f',*U.flatten(),*root,*w,*q0,*v0,dt))
elif sys.argv[1]=='analyze':
 data=Path(sys.argv[2]).read_bytes();assert len(data)==80*18*4;states=np.array(struct.unpack('<1440f',data)).reshape((80,18));initial=.5*q0@K@q0+.5*np.sum(m*v0*v0);c=U.T@(root*q0);d=U.T@(root*v0);maximum={'position_error_m':0.,'energy_relative_error':0.,'momentum_error_kg_m_s':0.};samples=[]
 for i,row in enumerate(states):
  t=(i+1)*dt;cos=np.cos(w*t);sin=np.sin(w*t);safe=np.divide(sin,w,out=np.full_like(w,t),where=w>0);qr=(U@(cos*c+safe*d))/root;vr=(U@(-w*sin*c+cos*d))/root;q=row[:9];v=row[9:];energy=.5*q@K@q+.5*np.sum(m*v*v);position=float(np.max(np.abs(q-qr)));e=float(abs(energy-initial)/initial);momentum=float(abs(np.sum(m*(v-v0))));maximum['position_error_m']=max(maximum['position_error_m'],position);maximum['energy_relative_error']=max(maximum['energy_relative_error'],e);maximum['momentum_error_kg_m_s']=max(maximum['momentum_error_kg_m_s'],momentum)
  if i in (0,7,79):samples.append({'step':i+1,'time_s':t,'position_error_m':position,'energy_relative_error':e,'momentum_error_kg_m_s':momentum})
 passed=bool(np.all(np.isfinite(states)) and maximum['position_error_m']<1e-6 and maximum['energy_relative_error']<.01 and maximum['momentum_error_kg_m_s']<1e-8)
 print(json.dumps({'hessian_sha256':hashlib.sha256(hp.read_bytes()).hexdigest(),'numpy':np.__version__,'initial_energy_J':initial,'eigenvalues_rad2_s2':w2.tolist(),'frequencies_hz':(w/(2*np.pi)).tolist(),'dt_s':dt,'steps':80,'passed':passed,'maxima':maximum,'samples':samples},indent=2))
 if not passed:raise SystemExit(2)
else:raise ValueError('expected generate or analyze')
