"""Regenerate the owner-test oracle from the archived native two-way fixture."""
import hashlib,json
from pathlib import Path
repo=Path('/private/tmp/crow-balance-evidence-20261115')
fixture=repo/'evidence/crow-feather-rachis-20261116/native-two-way/fixture.py'
source=fixture.read_text().split("if sys.argv[1]=='generate':")[0]
g={};exec(compile(source,str(fixture),'exec'),g)
cases=[]
for label,inv,mass,x0,v0,k,A,b,J,target,direct in g['cases']:
 cases.append({'label':label,'inverse':inv.tolist(),'mass':mass.tolist(),'x0':x0.tolist(),'v0':v0.tolist(),'K':k.tolist(),'A':A.tolist(),'b':b.tolist(),'J':J.tolist(),'target':target.tolist(),'reference':direct[:12].tolist()})
ip=fixture.parent/'input.bin'
print(json.dumps({'hessian_sha256':hashlib.sha256(g['hp'].read_bytes()).hexdigest(),'input_sha256':hashlib.sha256(ip.read_bytes()).hexdigest(),'dt_s':g['step'],'cases':cases},separators=(',',':')))
