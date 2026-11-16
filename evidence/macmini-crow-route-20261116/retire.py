#!/usr/bin/env python3
import sys,os,json,stat
root='/Users/n/Developer/numi-crow-rl-20261107/build/crow-v15-integrated-route-baseline-20261110'
assert os.path.isdir(root) and not os.path.islink(root) and os.path.realpath(root)==root
m=json.load(open(sys.argv[1])); entries=m['entries']; expected={e['path']:e for e in entries};assert len(expected)==71 and sum(e['type']=='file' for e in entries)==69
actual={'.'}
for parent,dirs,files in os.walk(root,followlinks=False):
 for name in dirs+files:
  p=os.path.join(parent,name); assert not os.path.islink(p);actual.add(os.path.relpath(p,root))
assert actual==set(expected),(actual-set(expected),set(expected)-actual)
states={}
for relative,e in expected.items():
 assert relative=='.' or (not os.path.isabs(relative) and all(x not in ('.','..','') for x in relative.split('/')))
 p=root if relative=='.' else os.path.join(root,relative);s=os.lstat(p);assert stat.S_IMODE(s.st_mode)==e['mode'] and s.st_mtime_ns==e['mtime_ns']
 if e['type']=='file':assert stat.S_ISREG(s.st_mode) and s.st_nlink==1 and s.st_size==e['size']
 else:assert e['type']=='directory' and stat.S_ISDIR(s.st_mode)
 states[p]=(s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_mode)
for relative,e in expected.items():
 if e['type']!='file':continue
 p=os.path.join(root,relative);s=os.lstat(p);assert (s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_mode)==states[p],p;os.unlink(p)
for relative,e in sorted(expected.items(),key=lambda item:item[0].count('/'),reverse=True):
 if e['type']!='directory' or relative=='.':continue
 p=os.path.join(root,relative);s=os.lstat(p);assert (s.st_dev,s.st_ino)==states[p][:2];os.rmdir(p)
s=os.lstat(root);assert (s.st_dev,s.st_ino)==states[root][:2];os.rmdir(root)
print(json.dumps({'removed_directory':root,'files':69,'logical_bytes':sum(e['size'] for e in entries)}))
