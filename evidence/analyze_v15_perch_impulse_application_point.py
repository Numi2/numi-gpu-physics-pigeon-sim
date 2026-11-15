from pathlib import Path
import json,sys
a=Path('/Users/n/Developer/numi-crow-rl-20261107/artifacts/crow-v15-recorded-restart-20261114'); cases={'unperturbed':a/'v15-coupled-wing-hip-followup-20261115/20370113-hip_minus090-1500','pulse':a/'v15-coupled-wing-hip-disturbance-eval-20261115/20370113-hip_pulse_pos-1000','pulse_wings_lowered':a/'v15-wing-release-ablation-eval-20261115/20370113-release_hold_pos-1000'};wanted=(500,550,560,570,580,600,620,650,680);out={}
for label,stem in cases.items():
 frames=json.loads(stem.with_suffix('.json').read_text())['payload']['frames'];end=next((i+1 for i,f in enumerate(frames) if f['done']),len(frames));sums={}
 with stem.with_suffix('.stderr').open() as f:
  for line in f:
   x=line.split()
   if not x or x[0]!='CROW_SCENE_CONTACT':continue
   t=int(x[1]);A=int(x[4]);B=int(x[5])
   if t not in wanted or t>end or not ((A<35 and B==40) or (B<35 and A==40)):continue
   bird=A if B==40 else B
   if not (bird in (11,15) or 19<=bird<=34):continue
   sign=-1 if B==40 else 1;n,j1,j2=map(float,x[6:9]);px,py,pz=map(float,x[9:12]);nx,ny,nz,tx,ty,tz=map(float,x[13:19]);otherz=nx*ty-ny*tx;up=sign*(nz*n+tz*j1+otherz*j2);z=sums.setdefault(t,[0.,0.,0.,0.]);z[0]+=up;z[1]+=up*px;z[2]+=up*py;z[3]+=up*pz
 samples=[]
 for t in wanted:
  if t>end or t not in sums or sums[t][0]<=1e-7:continue
  f=frames[t-1];s=sums[t];center=[s[i]/s[0] for i in (1,2,3)];samples.append({'step':t,'tilt':f['tilt'],'root_position':f['q'][:3],'vertical_impulse_application_point':center,'root_minus_impulse_point_x':f['q'][0]-center[0],'total_vertical_impulse':s[0]})
 out[label]={'first_done':end if frames[end-1]['done'] else None,'samples':samples}
out['method']='Sum 16 substeps of foot and toe contacts with body 40. The x/y/z point is weighted by each contact impulse vertical component, including signed components, divided by summed vertical impulse. This is not the body center of mass, a full wrench center, a validated grasp, or by itself evidence of slipping. Positions use world axes.'
dest=a/'v15-wing-release-ablation-eval-20261115/impulse-center-comparison.json';dest.write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
