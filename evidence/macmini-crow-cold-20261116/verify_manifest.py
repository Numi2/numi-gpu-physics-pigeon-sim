#!/usr/bin/env python3
import sys,json
expected=json.load(open(sys.argv[1]));actual=json.load(open(sys.argv[2]));a={x['path']:x for x in expected['entries']};b={x['path']:x for x in actual['entries']};errors=[];extra_provenance=0
for key in sorted(a.keys()|b.keys()):
 if key not in a or key not in b:errors.append([key,'presence']);continue
 x,y=a[key],b[key]
 for field in ('type','mode','mtime_ns','size','sha256','target'):
  if x.get(field)!=y.get(field):errors.append([key,field,x.get(field),y.get(field)])
 for attr in sorted(x['xattrs'].keys()|y['xattrs'].keys()):
  if attr=='com.apple.provenance' and attr not in x['xattrs']:
   extra_provenance+=1;continue
  if x['xattrs'].get(attr)!=y['xattrs'].get(attr):errors.append([key,'xattr',attr])
print(json.dumps({'pass':not errors,'expected_entries':len(a),'actual_entries':len(b),'extra_receiver_provenance_attributes':extra_provenance,'errors':errors},indent=2));sys.exit(bool(errors))
