from pathlib import Path
import hashlib,json,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';base=a/'restart-round-neural-balance-long.metal';s=base.read_text();old='targetCandidate+=0.08f*clamp(actionStream[actionBase+neuralSlot],-1.0f,1.0f);';assert s.count(old)==1
build=json.loads((a/'shader-build.json').read_text());out={}
for name,scale in [('zero','0.00f'),('double','0.16f')]:
 src=a/f'neural-authority-{name}.metal';src.write_text(s.replace(old,f'targetCandidate+={scale}*clamp(actionStream[actionBase+neuralSlot],-1.0f,1.0f);'));air=b/f'neural-authority-{name}.air';lib=b/f'neural-authority-{name}.metallib';cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True);link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True);out[name]={'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (src,air,lib)}}
(a/'neural-authority-build.json').write_text(json.dumps({'base_sha256':hashlib.sha256(base.read_bytes()).hexdigest(),'variants':out},indent=2)+'\n')
