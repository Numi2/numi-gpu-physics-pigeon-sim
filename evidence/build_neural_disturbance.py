from pathlib import Path
import hashlib,json,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';base=(a/'restart-round-neural-balance-long.metal').read_text()
needle='''    if (!reset && state.schedule.y == 0u &&
        program.dynamics.x > 0.0f) {''';assert base.count(needle)==1
act='''            targetCandidate+=0.08f*clamp(actionStream[actionBase+neuralSlot],-1.0f,1.0f);''';assert base.count(act)==1
build=json.loads((a/'shader-build.json').read_text());manifest={}
for direction,velocity in [('plus','0.04f'),('minus','-0.04f')]:
 for mode in ('live','frozen'):
  inject='''    // One documented external generalized-velocity disturbance, never support.
    if (!reset && state.episode.z==10u && state.navigation.z>=5.0f && state.episode.x==2600u)
        sourceV[vBase + program.root.w + 0u] += VELOCITY;
'''.replace('VELOCITY',velocity)
  s=base.replace(needle,inject+needle)
  if mode=='frozen':
   replacement='''            const float fixedResidual[4]={-0.0247f,-0.0237f,0.0235f,0.0181f};
            targetCandidate+=0.08f*(state.episode.x>=2600u ? fixedResidual[neuralSlot] : clamp(actionStream[actionBase+neuralSlot],-1.0f,1.0f));'''
   s=s.replace(act,replacement)
  name=f'neural-disturbance-{direction}-{mode}';src=a/(name+'.metal');src.write_text(s);air=b/(name+'.air');lib=b/(name+'.metallib');cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True);link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True);manifest[name]={'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (src,air,lib)}}
(a/'neural-disturbance-build.json').write_text(json.dumps(manifest,indent=2)+'\n')
