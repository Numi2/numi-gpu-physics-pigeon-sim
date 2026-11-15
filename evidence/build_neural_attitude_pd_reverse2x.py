from pathlib import Path
import hashlib,json,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114'
base=a/'neural-toe-contact-gated-eval.metal';src=a/'neural-attitude-pd-reverse2x.metal';air=b/'neural-attitude-pd-reverse2x.air';lib=b/'neural-attitude-pd-reverse2x.metallib';assert not src.exists() and not lib.exists()
s=base.read_text();needle='''            targetCandidate+=0.08f*clamp(actionStream[actionBase+neuralSlot],-1.0f,1.0f);
''';assert s.count(needle)==1
snippet=needle+'''            // Diagnostic only: bounded privileged pitch/rate feedback through physical hip drives.
            // A successful diagnostic is a teacher candidate, not an autonomous neural policy.
            if (state.episode.x>=2450u && (action==7u || action==10u))
                targetCandidate+=clamp(-0.24f*(state.threatGeometry.z-0.13f)-0.08f*state.threatGeometry.w,-0.08f,0.08f);
'''
src.write_text(s.replace(needle,snippet));build=json.loads((a/'shader-build.json').read_text());cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True);link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True);record={'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (base,src,air,lib)},'scope':'diagnostic teacher candidate, bounded privileged pitch feedback, not neural policy'};(a/'neural-attitude-pd-reverse2x-build.json').write_text(json.dumps(record,indent=2)+'\n');print('attitude PD diagnostic built')
