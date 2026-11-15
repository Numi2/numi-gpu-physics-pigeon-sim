from pathlib import Path
import hashlib,json,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114'
base=a/'neural-toe-contact-gated-eval.metal'; original=base.read_text();build=json.loads((a/'shader-build.json').read_text())
needle='''            targetCandidate+=0.08f*clamp(actionStream[actionBase+neuralSlot],-1.0f,1.0f);
        }
        const float target = clamp(
'''
assert original.count(needle)==1
records=[]
for idx,(p,d) in enumerate((p,d) for p in (-.18,-.12,-.06,.0,.06) for d in (-.06,.0,.06)):
    stem=f'neural-knee-sequential-screen-{idx:02d}';src=a/(stem+'.metal');air=b/(stem+'.air');lib=b/(stem+'.metallib')
    assert not src.exists() and not lib.exists()
    def f(x): return f'{x:.3f}f'
    replacement='''            targetCandidate+=0.08f*clamp(actionStream[actionBase+neuralSlot],-1.0f,1.0f);
        }
        // Exploratory privileged feedback, outside the actor's hip/ankle branch.
        if (fixedFlightController && state.navigation.z>=5.0f && state.episode.x>=2450u && (action==8u || action==11u))
            targetCandidate+=clamp('''+f(p)+'''*(state.threatGeometry.z-0.13f)+'''+f(d)+'''*state.threatGeometry.w,-0.04f,0.04f);
        const float target = clamp(
'''
    src.write_text(original.replace(needle,replacement));cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True)
    records.append({'index':idx,'pitch_gain':p,'rate_gain':d,'sha256':{str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in (src,air,lib)},'compile':cc,'link':link})
(a/'neural-knee-sequential-screen-build.json').write_text(json.dumps({'base_sha256':hashlib.sha256(base.read_bytes()).hexdigest(),'variants':records,'scope':'development-only privileged knee feedback; original flight path untouched'},indent=2)+'\n')
print('built',len(records),'bounded knee variants')
