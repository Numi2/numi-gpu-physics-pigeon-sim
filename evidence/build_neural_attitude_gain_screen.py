from pathlib import Path
import hashlib,json,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114'
base=a/'neural-toe-contact-gated-eval.metal';src=a/'neural-attitude-gain-screen.metal';air=b/'neural-attitude-gain-screen.air';lib=b/'neural-attitude-gain-screen.metallib';assert not src.exists() and not lib.exists()
s=base.read_text();needle='''            targetCandidate+=0.08f*clamp(actionStream[actionBase+neuralSlot],-1.0f,1.0f);
''';assert s.count(needle)==1
snippet=needle+'''            // Exploratory only: lane 0 is the unmodified control; 15 lanes screen a bounded hip feedback grid.
            if (state.episode.x>=2450u && (action==7u || action==10u) && environment>0u && environment<16u) {
                const float pitchGain[3]={-0.06f,-0.12f,-0.18f};
                const float rateGain[5]={-0.12f,-0.06f,0.0f,0.06f,0.12f};
                const uint k=environment-1u;
                targetCandidate+=clamp(pitchGain[k/5u]*(state.threatGeometry.z-0.13f)+rateGain[k%5u]*state.threatGeometry.w,-0.04f,0.04f);
            }
'''
src.write_text(s.replace(needle,snippet));build=json.loads((a/'shader-build.json').read_text());cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True);link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True);record={'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (base,src,air,lib)},'grid':{'control_lane':0,'pitch':[-.06,-.12,-.18],'rate':[-.12,-.06,0,.06,.12],'bound_rad':.04},'scope':'different randomized starts across lanes; discovery only, not matched comparisons or neural policy'};(a/'neural-attitude-gain-screen-build.json').write_text(json.dumps(record,indent=2)+'\n');print('attitude gain screen built')
