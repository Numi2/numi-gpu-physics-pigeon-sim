#!/usr/bin/env python3
import sys,os,json,stat
root='/Users/n/Developer/numi-crow-rl-20261107/build/crow-v15-long-perch-host-20261110'
assert os.path.isdir(root) and not os.path.islink(root) and os.path.realpath(root)==root
m=json.load(open(sys.argv[1])); es=m['entries'];files=[e for e in es if e['type']=='file'];assert len(es)==52 and len(files)==51 and all('/' not in e['path'] and e['path'] not in ('.','..') for e in files)
assert set(os.listdir(root))=={e['path'] for e in files}
states={}
for e in files:
 p=os.path.join(root,e['path']);s=os.lstat(p);assert stat.S_ISREG(s.st_mode) and s.st_nlink==1 and s.st_size==e['size'] and s.st_mtime_ns==e['mtime_ns'] and stat.S_IMODE(s.st_mode)==e['mode'];states[p]=(s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_mode)
for p,expected in states.items():
 s=os.lstat(p);assert (s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_mode)==expected,p
 os.unlink(p)
os.rmdir(root)
print(json.dumps({'removed_directory':root,'files':len(files),'logical_bytes':sum(e['size'] for e in files)}))
