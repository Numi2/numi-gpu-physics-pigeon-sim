#!/usr/bin/env python3
"""Summarize digitized corvid wing landmarks; no imputed frames or model fitting."""
from pathlib import Path
import csv,hashlib,json,math,statistics
root=Path(__file__).resolve().parent;base=root/'baliga-crow-source/02_Range-of-Motion/MiroM120_digitization'
cases=[('crow_17_1L_linkage','2017-11-09_Cor_bra_17-1L/Cor_bra_17-1L_ROM-pooled/2017-11-09_Cor_bra_17-1L_6BarDors__xyzpts.csv'),('crow_17_1L_rom','2017-11-09_Cor_bra_17-1L/Cor_bra_17-1L_ROM-pooled/2017-11-09_Cor_bra_17-1L_DorsRom1__xyzpts.csv'),('crow_18_2_rom','2018-06-14_CH-VB_LLT_partII/2018-06-14_Cor_cau_18-2_Sweep/2018-06-14_Cor_cau_18-2_VentSweepSprinkler1__xyzpts.csv')]
def sub(a,b):return [x-y for x,y in zip(a,b)]
def norm(a):return math.sqrt(sum(x*x for x in a))
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def quant(x,p):
 x=sorted(x);t=(len(x)-1)*p;i=int(t);return x[i]+(x[min(i+1,len(x)-1)]-x[i])*(t-i)
def describe(x):return {'count':len(x),'p05':quant(x,.05),'median':statistics.median(x),'p95':quant(x,.95)}
out=[]
for label,rel in cases:
 src=base/rel;lengths=[[],[],[]];ratios=[[],[]];deviations=[];valid=invalid=degenerate=0
 with src.open(newline='') as f:
  for row in csv.DictReader(f):
   try:
    p=[[float(row[f'pt{k}_{axis}']) for axis in 'XYZ'] for k in range(1,5)]
    if not all(math.isfinite(x) for point in p for x in point):raise ValueError()
    v=[sub(p[i+1],p[i]) for i in range(3)];ll=[norm(x) for x in v]
    if min(ll)<=0:raise ValueError()
    n1=cross(v[0],v[1]);n2=cross(v[1],v[2]);n=norm(n1)*norm(n2)
    for x,l in zip(lengths,ll):x.append(l)
    ratios[0].append(ll[1]/ll[0]);ratios[1].append(ll[2]/ll[0]);valid+=1
    if norm(n1)/(ll[0]*ll[1])<0.1 or norm(n2)/(ll[1]*ll[2])<0.1:degenerate+=1;continue
    cos=max(-1,min(1,sum(a*b for a,b in zip(n1,n2))/n));a=math.degrees(math.acos(cos));deviations.append(min(a,180-a))
   except (ValueError,TypeError,KeyError):invalid+=1
 out.append({'case':label,'input_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'valid_frames':valid,'invalid_frames':invalid,'degenerate_planes':degenerate,'segment_lengths_coordinate_units':[describe(x) for x in lengths],'segment_length_ratios_to_proximal':[describe(x) for x in ratios],'absolute_deviation_from_coplanarity_degrees':describe(deviations)})
(root/'geometry-analysis.json').write_text(json.dumps({'method':'Euclidean distances between the four author-defined landmarks, within-frame ratios, and the smaller angular deviation between the two segment-plane normals, excluding frames whose adjacent segment angle has |sin| < 0.1. Quantiles describe hand-manipulated sampled frames, not natural frequencies or independent joint ranges.','datasets':out},indent=2)+'\n');print(json.dumps(out,indent=2))
