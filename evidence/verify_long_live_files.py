from pathlib import Path
import hashlib,json
base=Path(__import__('sys').argv[1]);out={}
for d in ('neural-long-20310201-initial-1000','neural-long-20310201-trained-1000','neural-long-20310221-initial-1000','neural-long-20310221-trained-1000'):
 for p in sorted((base/d).rglob('*')):
  if p.is_file():
   h=hashlib.sha256()
   with p.open('rb') as f:
    for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
   out[str(p.relative_to(base))]={'size':p.stat().st_size,'sha256':h.hexdigest()}
print(json.dumps(out,sort_keys=True,indent=2))
