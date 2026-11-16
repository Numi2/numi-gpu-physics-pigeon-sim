import json,struct,math
from pathlib import Path
import numpy as np
p=Path(__file__).resolve().parent;oracle=json.loads((p/'articulated-kkt-oracle.json').read_text());summary=[]
for pose in ('0.6','1.2','1.8'):
 data=(p/f'input-pose-{pose}.bin').read_bytes();native=json.loads((p/f'crow-pose-quality-{pose}.json').read_text())['cases'];mapped={}
 for i,(out,ref) in enumerate(zip(native,oracle['cases'])):
  z=np.array(struct.unpack_from('<5624f',data,i*22496),dtype=np.float64);A=z[:5329].reshape(73,73);b=z[5329:5402];J=z[5402:5621].reshape(3,73);target=z[5621:5624];K=np.block([[A,-J.T],[J,np.zeros((3,3))]]);x=np.array(out['velocity']);lam=np.array(out['impulse']);direct=np.linalg.solve(K,np.r_[b,target]);r=max(abs(math.fsum(float(A[k,j])*float(x[j]) for j in range(73))-float(b[k])-math.fsum(float(J[a,k])*float(lam[a]) for a in range(3))) for k in range(73));eq=max(abs(math.fsum(float(J[a,j])*float(x[j]) for j in range(73))-float(target[a])) for a in range(3));dx=float(np.max(abs(x-direct[:73])));name=ref['name'];mapped[name]=np.r_[x[np.array(ref['inverse_permutation'])],x[27:]]
  summary.append({'pose':pose,'name':name,'path':out['path'],'finite':bool(np.isfinite(x).all() and np.isfinite(lam).all()),'force_residual':r,'equality_error':eq,'max_reference_difference':dx,'pass':bool(out['path']==3 and np.isfinite(x).all() and np.isfinite(lam).all() and r<.01 and eq<1e-9 and dx<1e-6)})
 for name in ('rest','incoming'):
  gap=float(np.max(abs(mapped[name+'_forward']-mapped[name+'_reverse'])));summary.append({'pose':pose,'permutation':name,'max_difference':gap,'pass':gap<1e-6})
(p/'analysis.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2));print('ALL_PASS',all(x['pass'] for x in summary))
