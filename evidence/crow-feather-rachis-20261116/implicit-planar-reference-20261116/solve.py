import ctypes, hashlib, json, os, sys
import numpy as np, scipy
from scipy.optimize import minimize
from pathlib import Path
base=Path(__file__).resolve().parent
libpath=Path('/private/tmp/crow-planar-reference-libs/crow-planar-energy-bridge.dylib')
lib=ctypes.CDLL(str(libpath));ptr=ctypes.POINTER(ctypes.c_double);lib.crow_native_energy.argtypes=[ptr];lib.crow_native_energy.restype=ctypes.c_double
q0=np.zeros(27); L=.025; h=.001; m=1200*3.449e-6*L/8; scale=1e-5; escale=1e-6
for i in range(9):
 x=min(i/8,1-i/8);q0[3*i+1]=.000025*(3*x-4*x*x*x)
free=np.array([3*i+a for i in (1,2,3,5,6,7) for a in (0,1)])
def native(q): return lib.crow_native_energy(np.ascontiguousarray(q,dtype=np.float64).ctypes.data_as(ptr))
def state(z):
 q=q0.copy();q[free]+=scale*z;return q
def obj(z):
 q=state(z);return (native(q)+.5*m*np.dot(q[free]-q0[free],q[free]-q0[free])/h**2)/escale
def force(z,ds):
 q=state(z);g=[]
 for j in free:
  p=q.copy();p[j]+=ds;a=native(p);p[j]-=2*ds;b=native(p);g.append((a-b)/(2*ds)+m*(q[j]-q0[j])/h**2)
 return np.array(g)
results=[]
for ds in (1e-9,3e-10):
 res=minimize(obj,np.zeros(len(free)),jac=lambda z:force(z,ds)*scale/escale,method='BFGS',options={'gtol':1e-9,'maxiter':1000})
 q=state(res.x);energy=native(q);kinetic=.5*m*np.dot(q[free]-q0[free],q[free]-q0[free])/h**2
 results.append({'gradient_step_m':ds,'optimizer_success':bool(res.success),'message':str(res.message),'iterations':int(res.nit),'evaluations':int(res.nfev),'objective_joule':float(res.fun*escale),'elastic_joule':float(energy),'kinetic_joule':float(kinetic),'max_free_force_residual_n':float(max(abs(force(res.x,ds)))),'max_other_step_force_residual_n':float(max(abs(force(res.x,3e-10 if ds==1e-9 else 1e-9)))),'positions_m':[[float((i*L/8 if a==0 else 0)+q[3*i+a]) for a in range(3)] for i in range(9)]})
A=np.array(results[0]['positions_m']);B=np.array(results[1]['positions_m']);initial=native(q0)
out={'host':os.uname().machine,'numpy':np.__version__,'scipy':scipy.__version__,'library_sha256':hashlib.sha256(Path('/private/tmp/crow-planar-reference-libs/libmetalrobo.dylib').read_bytes()).hexdigest(),'bridge_sha256':hashlib.sha256(libpath.read_bytes()).hexdigest(),'dt_s':h,'initial_elastic_j':float(initial),'max_reference_gap_m':float(np.max(abs(A-B))),'runs':results}
out['predeclared_checks_pass']=bool(out['max_reference_gap_m']<=1e-8 and all(r['max_free_force_residual_n']<=.01 and r['elastic_joule']+r['kinetic_joule']<=initial for r in results))
(base/'result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
