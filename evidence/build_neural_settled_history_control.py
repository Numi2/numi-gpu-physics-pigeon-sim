from pathlib import Path
import json,subprocess,hashlib
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';s=(a/'neural-settled-reset-exact-qv.metal').read_text();needle='''            resetScene[sceneBase+5u].orientation=float4(0.0f,0.0f,0.0998334166f,0.9950041653f);
''';assert s.count(needle)==1
snippet='''            // Align temporal position/velocity references with the restored generalized state.
            // This copies the engine's normal physically reached stage-arrival reset convention.
            for (uint action=0u; action<program.counts0.x; ++action) {
                const uint velocityIndex=actions[action].indices.w;
                const uint positionIndex=actions[action].indices.z;
                previousJointVelocity[previousVelocityBase+action]=velocityIndex==MR_INVALID_INDEX ? 0.0f : resetV[vBase+velocityIndex];
                previousJointVelocity[previousVelocityBase+program.counts0.x+action]=positionIndex==MR_INVALID_INDEX ? 0.0f : resetQ[qBase+positionIndex];
            }
'''
src=a/'neural-settled-reset-history.metal';src.write_text(s.replace(needle,needle+snippet));air=b/'neural-settled-reset-history.air';lib=b/'neural-settled-reset-history.metallib';build=json.loads((a/'shader-build.json').read_text());cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True);link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True);(a/'neural-settled-history-build.json').write_text(json.dumps({'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (src,air,lib)}},indent=2)+'\n')
