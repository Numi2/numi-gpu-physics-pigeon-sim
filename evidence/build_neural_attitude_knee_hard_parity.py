from pathlib import Path
import hashlib, json, subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107'); a=r/'artifacts/crow-v15-recorded-restart-20261114'; b=r/'build/crow-v15-recorded-restart-20261114'
base=a/'neural-toe-contact-gated-eval.metal'; src=a/'neural-attitude-knee-hard-parity.metal'; air=b/'neural-attitude-knee-hard-parity.air'; lib=b/'neural-attitude-knee-hard-parity.metallib'
assert not src.exists() and not lib.exists()
s=base.read_text()
needle='''            targetCandidate+=0.08f*clamp(actionStream[actionBase+neuralSlot],-1.0f,1.0f);
        }
        const float target = clamp(
'''
assert s.count(needle)==1
replacement='''            targetCandidate+=0.08f*clamp(actionStream[actionBase+neuralSlot],-1.0f,1.0f);
        }
        // Diagnostic only: knee action condition is outside hip/ankle branch.
        if (fixedFlightController && state.navigation.z>=5.0f && state.episode.x>=2450u &&
            (action==8u || action==11u) && environment>0u && environment<16u) {
            const float pitchGain[3]={-0.06f,-0.12f,-0.18f};
            const float rateGain[5]={-0.12f,-0.06f,0.0f,0.06f,0.12f};
            const uint k=environment-1u;
            targetCandidate+=clamp(pitchGain[k/5u]*(state.threatGeometry.z-0.13f)+rateGain[k%5u]*state.threatGeometry.w,-0.04f,0.04f);
        }
        const float target = clamp(
'''
s=s.replace(needle,replacement)
for key in ('4991u','4992u','4993u'):
    old=f'randomUnit(dispatch,environment,episode,0u,{key})'
    new=f'randomUnit(dispatch,0u,episode,0u,{key})'
    assert s.count(old)==1
    s=s.replace(old,new)
src.write_text(s)
build=json.loads((a/'shader-build.json').read_text()); cc=build['compile'].copy(); cc[cc.index('-c')+1]=str(src); cc[cc.index('-o')+1]=str(air); subprocess.run(cc,check=True)
link=build['link'].copy(); link[link.index(str(b/'restart.air'))]=str(air); link[link.index('-o')+1]=str(lib); subprocess.run(link,check=True)
record={'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (base,src,air,lib)},'scope':'corrected bounded privileged knee feedback diagnostic, not neural control'}
(a/'neural-attitude-knee-hard-parity-build.json').write_text(json.dumps(record,indent=2)+'\n'); print('hard start shared lane knee parity built')
