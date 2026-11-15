#!/usr/bin/env python3
"""Optimistic planar reach approximation for retained measured 3-D landmarks."""
from pathlib import Path
import csv,math,json,hashlib,statistics
root=Path(__file__).resolve().parent
src=root/'baliga-crow-source/02_Range-of-Motion/MiroM120_digitization/2017-11-09_Cor_bra_17-1L/Cor_bra_17-1L_ROM-pooled/2017-11-09_Cor_bra_17-1L_6BarDors__xyzpts.csv'
def sub(a,b):return [x-y for x,y in zip(a,b)]
def norm(v):return math.sqrt(sum(x*x for x in v))
def angle(a,b):return math.acos(max(-1,min(1,sum(x*y for x,y in zip(a,b))/(norm(a)*norm(b)))))
def q(v,p):
 v=sorted(v);t=(len(v)-1)*p;i=int(t);return v[i]+(v[min(i+1,len(v)-1)]-v[i])*(t-i)
rows=[];invalid=[]
with src.open(newline='') as f:
 for i,row in enumerate(csv.DictReader(f),1):
  try:
   p=[[float(row[f'pt{k}_{a}']) for a in 'XYZ'] for k in range(1,5)]
   if not all(math.isfinite(x) for point in p for x in point):raise ValueError()
   v=[sub(p[j+1],p[j]) for j in range(3)];lengths=[norm(x) for x in v]
   if min(lengths)<=0:raise ValueError()
   e=angle([-x for x in v[0]],v[1]);w=angle([-x for x in v[1]],v[2]);a2=math.pi-e;turn=math.pi-w
   reaches=[]
   for s in (-1,1):
    a3=a2+s*turn;x=lengths[0]+lengths[1]*math.cos(a2)+lengths[2]*math.cos(a3);y=lengths[1]*math.sin(a2)+lengths[2]*math.sin(a3);reaches.append(math.hypot(x,y))
   actual=norm(sub(p[3],p[0]));err=min(abs(z-actual) for z in reaches);rows.append({'source_frame_1based':i,'actual_reach':actual,'planar_reach_branch_a':reaches[0],'planar_reach_branch_b':reaches[1],'best_absolute_error':err,'normalizing_segment_sum':sum(lengths),'best_normalized_error':err/sum(lengths)})
  except (ValueError,KeyError,TypeError,ZeroDivisionError):invalid.append(i)
outfile=root/'planar-reach-frame-errors.csv'
with outfile.open('w',newline='') as f:
 writer=csv.DictWriter(f,fieldnames=rows[0].keys());writer.writeheader();writer.writerows(rows)
def summary(a):
 z=[x['best_normalized_error'] for x in a];return {'frames':len(z),'median':statistics.median(z),'p95':q(z,.95),'max':max(z),'median_percent':100*statistics.median(z)}
train=[r for r in rows if r['source_frame_1based']<=350];test=[r for r in rows if r['source_frame_1based']>=351]
out={'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'frame_errors_sha256':hashlib.sha256(outfile.read_bytes()).hexdigest(),'training_frames':summary(train),'held_out_frames':summary(test),'invalid_frame_count':len(invalid),'invalid_frame_numbers':invalid,'held_out_median_below_2_percent':statistics.median([x['best_normalized_error'] for x in test])<.02,'limitations':'Per-frame best planar branch uses measured segment lengths and 3D angles; optimistic geometry only, not physical calibration or biological motion frequency.'}
(root/'planar-reach-analysis.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({k:v for k,v in out.items() if k!='invalid_frame_numbers'},indent=2))
