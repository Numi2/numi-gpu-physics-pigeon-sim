import hashlib,json
from pathlib import Path
repo=Path('/private/tmp/crow-balance-evidence-20261115');fixture=repo/'evidence/crow-feather-rachis-20261116/rigid-wing-kkt/fixture.py';g={};exec(compile(fixture.read_text().split("if sys.argv[1]=='generate':")[0],str(fixture),'exec'),g)
cases=[]
for label,nodes,inv,mass,K,A,b,x0,v0,J,target,direct in g['cases']:
 cases.append({'label':label,'nodes':nodes.tolist(),'inverse':inv.tolist(),'mass':mass.tolist(),'K':K.tolist(),'A':A.tolist(),'b':b.tolist(),'x0':x0.tolist(),'v0':v0.tolist(),'J':J.tolist(),'target':target.tolist(),'reference':direct[:33].tolist()})
ip=fixture.parent/'input.bin';print(json.dumps({'input_sha256':hashlib.sha256(ip.read_bytes()).hexdigest(),'native_hessian_sha256':hashlib.sha256(g['hp'].read_bytes()).hexdigest(),'wing_properties_sha256':hashlib.sha256(g['wp'].read_bytes()).hexdigest(),'anchor':g['r'].tolist(),'length_m':g['L'],'dt_s':g['dt'],'cases':cases},separators=(',',':')))
