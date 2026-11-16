import sys,json,hashlib
from pathlib import Path
root=Path('/private/tmp/crow-balance-evidence-20261115/evidence/crow-feather-rachis-20261116/articulated-metal-kkt');source=(root/'fixture.py').read_text().split("if sys.argv[1]=='generate':")[0];env={};exec(compile(source,str(root/'fixture.py'),'exec'),env);cases=env['cases'];out={'input_sha256':hashlib.sha256((root/'input.bin').read_bytes()).hexdigest(),'cases':[{'name':name,'inverse_permutation':inv.tolist(),'reference':ref[:73].tolist()} for name,inv,A,rhs,J,ref in cases]};print(json.dumps(out,separators=(',',':'),sort_keys=True))
