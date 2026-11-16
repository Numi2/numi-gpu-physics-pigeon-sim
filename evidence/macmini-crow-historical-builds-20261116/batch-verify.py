#!/usr/bin/env python3
import sys,json
x=json.load(open(sys.argv[1]))['roots'];y=json.load(open(sys.argv[2]))['roots'];errors=[];added=0;count=0
if set(x)!=set(y):errors.append(['roots',sorted(set(x)^set(y))])
for root in sorted(set(x)&set(y)):
 a={e['path']:e for e in x[root]['entries']};b={e['path']:e for e in y[root]['entries']};count+=len(a)
 for key in sorted(a.keys()|b.keys()):
  if key not in a or key not in b:errors.append([root,key,'presence']);continue
  u,v=a[key],b[key]
  for field in ('type','mode','mtime_ns','size','sha256','target'):
   if u.get(field)!=v.get(field):errors.append([root,key,field,u.get(field),v.get(field)])
  for attr in u['xattrs'].keys()|v['xattrs'].keys():
   if attr=='com.apple.provenance' and attr not in u['xattrs']:added+=1;continue
   if u['xattrs'].get(attr)!=v['xattrs'].get(attr):errors.append([root,key,'xattr',attr])
print(json.dumps({'pass':not errors,'roots':len(x),'entries':count,'extra_receiver_provenance_attributes':added,'errors':errors},indent=2));sys.exit(bool(errors))
