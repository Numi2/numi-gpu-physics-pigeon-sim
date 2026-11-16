#!/usr/bin/env python3
import os,sys,json,hashlib,stat,base64,subprocess
from pathlib import Path
root=Path(sys.argv[1]); assert root.is_dir() and not root.is_symlink(); result=[]
for directory,dirs,files in os.walk(root,topdown=True,followlinks=False):
 dirs.sort();files.sort(); d=Path(directory)
 for path in [d]+[d/n for n in files]+[d/n for n in dirs if (d/n).is_symlink()]:
  s=path.lstat(); rel=str(path.relative_to(root)) or '.'; kind='directory' if stat.S_ISDIR(s.st_mode) else ('file' if stat.S_ISREG(s.st_mode) else ('symlink' if stat.S_ISLNK(s.st_mode) else 'unsupported'))
  if kind=='unsupported':raise RuntimeError('unsupported file '+str(path))
  attrs={}
  for key in sorted(subprocess.check_output(["/usr/bin/xattr",str(path)],text=True).splitlines()):
   raw=subprocess.check_output(["/usr/bin/xattr","-px",key,str(path)],text=True)
   attrs[key]=base64.b64encode(bytes.fromhex(raw)).decode()
  entry={'path':rel,'type':kind,'mode':stat.S_IMODE(s.st_mode),'mtime_ns':s.st_mtime_ns,'xattrs':attrs,'size':s.st_size if kind=='file' else 0}
  if kind=='file':
   if s.st_nlink!=1:raise RuntimeError('hardlink requires special handling '+str(path))
   if s.st_flags & 0x40000000:raise RuntimeError('dataless '+str(path))
   h=hashlib.sha256()
   with open(path,'rb') as f:
    for chunk in iter(lambda:f.read(4*1024*1024),b''):h.update(chunk)
   entry['sha256']=h.hexdigest()
  elif kind=='symlink':entry['target']=os.readlink(path)
  result.append(entry)
  dirs[:]=[x for x in dirs if not (d/x).is_symlink()]
print(json.dumps({'schema':1,'entries':sorted(result,key=lambda x:x['path'])},sort_keys=True,indent=2))
