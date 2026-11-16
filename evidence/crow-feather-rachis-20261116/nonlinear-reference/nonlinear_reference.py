import ctypes,hashlib,json,os,struct,sys,time
from pathlib import Path
import numpy as np
import scipy
from scipy.integrate import solve_ivp
root=Path('/private/tmp/crow-balance-evidence-20261115/evidence/crow-feather-rachis-20261116');out=root/'nonlinear-reference';out.mkdir(exist_ok=True);ip=root/'coupled-3d/input.bin';gp=root/'coupled-3d/crow-3d-modal-output.bin';sp=root/'nonlinear-split/crow-nonlinear-split.jsonl';lp=Path('/private/tmp/crow-nonlinear-ref-libs/crow-nonlinear-reference-bridge.dylib');lib=ctypes.CDLL(str(lp));ptr=ctypes.POINTER(ctypes.c_double);lib.crow_native_acceleration.argtypes=[ptr,ptr];lib.crow_native_acceleration.restype=ctypes.c_int;lib.crow_native_energy.argtypes=[ptr];lib.crow_native_energy.restype=ctypes.c_double
values=np.array(struct.unpack('<838f',ip.read_bytes()),dtype=np.float64);q0=values[783:810];v0=values[810:837];initial=np.r_[q0,v0];dt=.000125;times=np.arange(1,81)*dt;h=json.loads((root/'coupled-3d/crow-3d-hessian.json').read_text());m=np.array(h['masses']);m[[0,4,8]]+=np.array([.00012,.00015,.00012]);mass=np.repeat(m,3)
def ep(q):return lib.crow_native_energy(q.ctypes.data_as(ptr))
def rhs(t,y):
 a=np.empty(27,dtype=np.float64);status=lib.crow_native_acceleration(y.ctypes.data_as(ptr),a.ctypes.data_as(ptr))
 if status or not np.all(np.isfinite(a)):raise RuntimeError('native acceleration failed')
 return np.r_[y[27:],a]
init_energy=ep(q0)+.5*np.sum(mass*v0*v0)
for label,rtol,pa,va in [('standard',1e-8,1e-12,1e-7),('tight',2e-10,1e-13,1e-8)]:
 print('starting',label,flush=True);start=time.monotonic();sol=solve_ivp(rhs,(0.,.01),initial,method='DOP853',t_eval=times,rtol=rtol,atol=np.r_[np.full(27,pa),np.full(27,va)]);elapsed=time.monotonic()-start
 energies=[(ep(np.ascontiguousarray(row[:27]))+.5*np.sum(mass*row[27:]**2)) for row in sol.y.T];data={'label':label,'method':'DOP853','rtol':rtol,'position_atol_m':pa,'velocity_atol_m_s':va,'success':bool(sol.success),'message':sol.message,'nfev':sol.nfev,'elapsed_s':elapsed,'initial_energy_J':init_energy,'max_relative_energy_error':float(max(abs(x-init_energy) for x in energies)/init_energy),'times_s':sol.t.tolist(),'states':sol.y.T.tolist()};(out/(label+'.json')).write_text(json.dumps(data,indent=2)+'\n');print('finished',label,'nfev',sol.nfev,'seconds',round(elapsed,2),'energy_error',data['max_relative_energy_error'],flush=True)
 if not sol.success or len(sol.t)!=80:raise SystemExit(2)
a=json.loads((out/'standard.json').read_text());b=json.loads((out/'tight.json').read_text());A=np.array(a['states']);B=np.array(b['states']);gpu=np.array(struct.unpack('<6480f',gp.read_bytes())).reshape(80,81)[:,:27];rows=[json.loads(line) for line in sp.read_text().splitlines()];split=np.array([x['position_m'] for x in rows if x.get('mode')=='nonlinear_split' and x.get('step')]);gap=lambda x,y:float(np.max(np.abs(x-y)))
result={'numpy':np.__version__,'scipy':scipy.__version__,'host':os.uname().machine,'bridge_sha256':hashlib.sha256(lp.read_bytes()).hexdigest(),'input_sha256':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ip,gp,sp)},'reference_position_gap_m':gap(A[:,:27],B[:,:27]),'standard_energy_error':a['max_relative_energy_error'],'tight_energy_error':b['max_relative_energy_error'],'gpu_linear_position_error_m':gap(gpu,B[:,:27]),'split_position_error_m':gap(split,B[:,:27])};result['reference_passed']=bool(result['reference_position_gap_m']<.05e-6 and result['standard_energy_error']<.001 and result['tight_energy_error']<.001);result['candidate_prediction_passed']=bool(result['reference_passed'] and result['split_position_error_m']<1e-6 and result['split_position_error_m']<.8*result['gpu_linear_position_error_m']);(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2),flush=True)
