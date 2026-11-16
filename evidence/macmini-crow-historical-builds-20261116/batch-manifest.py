#!/usr/bin/env python3
import json,subprocess,sys,os
from pathlib import Path
base=Path(sys.argv[1]);selection=json.loads(Path(sys.argv[2]).read_text());tool=Path(__file__).parent/'manifest.py';assert len(set(selection))==len(selection)
out={}
for name in selection:
 assert name and '/' not in name and name not in ('.','..')
 p=base/name;assert p.is_dir() and not p.is_symlink()
 out[name]=json.loads(subprocess.check_output([sys.executable,str(tool),str(p)]))
print(json.dumps({'schema':1,'roots':out},sort_keys=True,indent=2))
