from pathlib import Path
import hashlib,json,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114'
s=(a/'restart-round-neural-balance-v2.metal').read_text();needle='''    if (!reset && state.schedule.y == 0u &&
        program.dynamics.x > 0.0f) {''';assert s.count(needle)==1
inject='''    // V4 training curriculum: bounded external root-velocity disturbances, not support.
    if (!reset && state.episode.z==10u && state.navigation.z>=5.0f &&
        (state.episode.x==2500u || state.episode.x==2700u)) {
        const uint lane=environment%4u;
        float push=lane==0u ? 0.0f : lane==1u ? 0.04f : lane==2u ? -0.04f :
            0.04f*randomSigned(dispatch,environment,state.episode.y,state.episode.x,79u);
        sourceV[vBase + program.root.w + 0u] += push;
    }
'''
src=a/'restart-round-neural-balance-v4-training.metal';src.write_text(s.replace(needle,inject+needle));air=b/'restart-round-neural-balance-v4-training.air';lib=b/'restart-round-neural-balance-v4-training.metallib';build=json.loads((a/'shader-build.json').read_text());cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True);link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True)
(a/'neural-v4-training-build.json').write_text(json.dumps({'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (src,air,lib)}},indent=2)+'\n')
