#!/usr/bin/env python3
"""Independent law-of-cosines audit of the two planar reach branches."""
from pathlib import Path
import csv,math
p=Path(__file__).resolve().parent;root=p/'baliga-crow-source/02_Range-of-Motion/MiroM120_digitization';src=root/'2017-11-09_Cor_bra_17-1L/Cor_bra_17-1L_ROM-pooled/2017-11-09_Cor_bra_17-1L_6BarDors__xyzpts.csv';derived={int(r['source_frame_1based']):r for r in csv.DictReader((p/'planar-reach-frame-errors.csv').open())};errs=[]
def dist(a,b):return math.sqrt(sum((x-y)**2 for x,y in zip(a,b)))
def angle(a,b,c):
 ab=dist(a,b);bc=dist(b,c);ac=dist(a,c);return math.acos(max(-1,min(1,(ab*ab+bc*bc-ac*ac)/(2*ab*bc))))
with src.open(newline='') as f:
 for i,row in enumerate(csv.DictReader(f),1):
  if i not in derived:continue
  pts=[[float(row[f'pt{k}_{axis}']) for axis in 'XYZ'] for k in range(1,5)];l=[dist(pts[j],pts[j+1]) for j in range(3)];e=angle(*pts[:3]);w=angle(*pts[1:]);base=sum(x*x for x in l)-2*l[0]*l[1]*math.cos(e)-2*l[1]*l[2]*math.cos(w);a=math.sqrt(max(0,base+2*l[0]*l[2]*math.cos(e+w)));b=math.sqrt(max(0,base+2*l[0]*l[2]*math.cos(e-w)));d=derived[i];errs.append(min(max(abs(a-float(d['planar_reach_branch_a'])),abs(b-float(d['planar_reach_branch_b']))),max(abs(b-float(d['planar_reach_branch_a'])),abs(a-float(d['planar_reach_branch_b'])))))
assert len(errs)==406 and max(errs)<1e-9
print('frames',len(errs),'maximum independent planar reach error',max(errs))
