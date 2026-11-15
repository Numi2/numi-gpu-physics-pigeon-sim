from pathlib import Path
import hashlib,json,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';s=(a/'restart-round-neural-balance-masked.metal').read_text();needle='''            targetCandidate+=0.08f*clamp(actionStream[actionBase+neuralSlot],-1.0f,1.0f);
''';assert s.count(needle)==1
build=json.loads((a/'shader-build.json').read_text());manifest={}
for name,gain in [('positive','0.02f'),('negative','-0.02f')]:
 snippet=needle+'''            // Diagnostic privileged accepted-pitch feedback; not actor output.
            if (state.episode.x>=2450u && (action==7u || action==10u))
                targetCandidate+=clamp(GAIN*(state.threatGeometry.z-0.13f),-0.004f,0.004f);
'''.replace('GAIN',gain)
 src=a/f'restart-round-neural-pitch-{name}.metal';src.write_text(s.replace(needle,snippet));air=b/f'restart-round-neural-pitch-{name}.air';lib=b/f'restart-round-neural-pitch-{name}.metallib';cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True)
 link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True)
 manifest[name]={'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (src,air,lib)}}
(a/'neural-pitch-sensitivity-build.json').write_text(json.dumps(manifest,indent=2)+'\n')
