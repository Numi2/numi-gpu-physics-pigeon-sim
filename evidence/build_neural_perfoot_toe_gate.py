from pathlib import Path
import hashlib, json, subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107')
a=r/'artifacts/crow-v15-recorded-restart-20261114'
b=r/'build/crow-v15-recorded-restart-20261114'
old='''                        // Gate neural residual by bilateral accepted support and established toe-contact ramps.
                        const bool bothLoaded=(state.status.w & ((1u<<20)|(1u<<21)))==((1u<<20)|(1u<<21));
                        const bool gripEstablished=(state.status.w & 63u)>=24u && ((state.status.w>>6u)&63u)>=24u;
                        const float toeResidual=(bothLoaded && gripEstablished ? 0.25f : 0.0f)*clamp(actionStream[actionBase+toeSlot],-1.0f,1.0f);'''
new='''                        // Development experiment: contact-gated authority per foot, with existing position limits retained.
                        const bool footLoaded=(state.status.w & (1u << (20u+side)))!=0u;
                        const float toeResidual=(footLoaded && ramp>0u ? 0.25f : 0.0f)*clamp(actionStream[actionBase+toeSlot],-1.0f,1.0f);'''
build=json.loads((a/'shader-build.json').read_text())
records={}
for name in ('eval','training'):
    base=a/('neural-toe-contact-gated-eval.metal' if name=='eval' else 'neural-arrival-training.metal')
    src=a/f'neural-toe-perfoot-{name}.metal'; air=b/f'neural-toe-perfoot-{name}.air'; lib=b/f'neural-toe-perfoot-{name}.metallib'
    assert not src.exists() and not lib.exists()
    s=base.read_text(); assert s.count(old)==1
    src.write_text(s.replace(old,new))
    cc=build['compile'].copy(); cc[cc.index('-c')+1]=str(src); cc[cc.index('-o')+1]=str(air); subprocess.run(cc,check=True)
    link=build['link'].copy(); link[link.index(str(b/'restart.air'))]=str(air); link[link.index('-o')+1]=str(lib); subprocess.run(link,check=True)
    records[name]={'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (base,src,air,lib)}}
(a/'neural-toe-perfoot-build.json').write_text(json.dumps(records,indent=2)+'\n')
print(json.dumps({k:v['sha256'] for k,v in records.items()},indent=2))
