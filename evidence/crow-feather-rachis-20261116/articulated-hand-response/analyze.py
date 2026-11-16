import json,sys
import numpy as np
from scipy.spatial.transform import Rotation
p=json.load(open(sys.argv[1]));n=p['nv'];J=np.array(p['J']).reshape(3,n);M=np.array(p['M']).reshape(n,n);X=np.array(p['X']).reshape(3,n).T;W=J@X
rotation=Rotation.from_quat(p['hand_orientation_xyzw']).as_matrix();r=rotation@np.array([.008,.012,.003]);cross=np.array([[0,-r[2],r[1]],[r[2],0,-r[0]],[-r[1],r[0],0]])
m=.008925423026;inertia=np.array([6.192050932e-6,2.725229024e-6,8.822075870e-6]);free=np.eye(3)/m-cross@rotation@np.diag(1/inertia)@rotation.T@cross
v=np.linalg.solve(W,np.eye(3));rows={x['name']:int(x['v']) for x in p['dofs'] if 'left_' in x['name'] and ('wing' in x['name'] or 'elbow' in x['name'] or 'wrist' in x['name'])}
result={'mass_response_max_abs_residual':float(np.max(np.abs(M@X-J.T))),'symmetry_max_abs':float(np.max(np.abs(W-W.T))),'point_response_eigenvalues':np.linalg.eigvalsh(W).tolist(),'unit_velocity_solve_max_abs':float(np.max(np.abs(W@v-np.eye(3)))),'W':W.tolist(),'free_hand_W':free.tolist(),'free_vs_full_relative_frobenius':float(np.linalg.norm(W-free)/np.linalg.norm(W)),'selected_joint_response_norm':{k:float(np.linalg.norm(X[i,:])) for k,i in rows.items()}}
result['pass']=result['mass_response_max_abs_residual']<1e-8 and result['symmetry_max_abs']<1e-8 and min(result['point_response_eigenvalues'])>0 and result['unit_velocity_solve_max_abs']<1e-9 and max(result['selected_joint_response_norm'].values(),default=0)>1e-12
print(json.dumps(result,indent=2,sort_keys=True));sys.exit(0 if result['pass'] else 2)
