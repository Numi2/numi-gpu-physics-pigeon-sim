#!/usr/bin/env python3
"""Derive paired 3D marker angles using Baliga et al.'s published xyzangles convention.

Cadaver manipulation measurements, not live flight/perching kinematics. No scaling,
corvid-to-crow assumption, dynamical model or joint limits are imposed here.
"""
from pathlib import Path
import csv,hashlib,json,math
root=Path(__file__).resolve().parent;source=root/'baliga-crow-source/02_Range-of-Motion/MiroM120_digitization';
cases=[('crow_17_1L_linkage','2017-11-09_Cor_bra_17-1L/Cor_bra_17-1L_ROM-pooled/2017-11-09_Cor_bra_17-1L_6BarDors__xyzpts.csv'),('crow_17_1L_rom','2017-11-09_Cor_bra_17-1L/Cor_bra_17-1L_ROM-pooled/2017-11-09_Cor_bra_17-1L_DorsRom1__xyzpts.csv'),('crow_18_2_rom','2018-06-14_CH-VB_LLT_partII/2018-06-14_Cor_cau_18-2_Sweep/2018-06-14_Cor_cau_18-2_VentSweepSprinkler1__xyzpts.csv')]
def angle(a,b,c):
 u=[a[i]-b[i] for i in range(3)];v=[c[i]-b[i] for i in range(3)];den=math.sqrt(sum(x*x for x in u)*sum(x*x for x in v))
 if den==0:raise ValueError('zero-length marker segment')
 return math.degrees(math.acos(max(-1,min(1,sum(u[i]*v[i] for i in range(3))/den))))
result=[]
for label,rel in cases:
 file=source/rel;out=root/(label+'-angles.csv');read=valid=invalid=0;elbows=[];wrists=[]
 with file.open(newline='') as inp,out.open('w',newline='') as dst:
  rows=csv.DictReader(inp);writer=csv.writer(dst);writer.writerow(('source_frame_1based','elbow_deg','manus_deg'))
  for idx,row in enumerate(rows,1):
   read+=1
   try:
    pts=[[float(row[f'pt{k}_{axis}']) for axis in 'XYZ'] for k in range(1,5)]
    if not all(math.isfinite(x) for p in pts for x in p):raise ValueError('nonfinite marker')
    e=angle(*pts[:3]);w=angle(*pts[1:]);writer.writerow((idx,f'{e:.9f}',f'{w:.9f}'));elbows.append(e);wrists.append(w);valid+=1
   except (ValueError,TypeError,KeyError):invalid+=1
 result.append({'label':label,'source':str(file.relative_to(root)),'source_sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'derived':out.name,'derived_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'frames_total':read,'valid':valid,'invalid':invalid,'elbow_deg_range':[min(elbows),max(elbows)],'manus_deg_range':[min(wrists),max(wrists)]})
(root/'measured-angle-manifest.json').write_text(json.dumps({'method':'3D arccos of vertex-to-neighbor vectors, same as author xyzangles in 01_CommonFunctions.R; landmark labels defined by author Config-ind scripts.','limitations':'Two cadaver specimens; linkage is manually manipulated. Other trials sample range of motion, not animal-chosen movement or independent joint limits. Taxon path Corvus_caurinus; first file name Cor_bra, second Cor_cau.','datasets':result},indent=2)+'\n');print(json.dumps(result,indent=2))
