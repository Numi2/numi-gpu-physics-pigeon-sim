from pathlib import Path
import gzip,hashlib,json,subprocess
r=Path('/Users/n/Developer/numi-crow-rl-20261107');a=r/'artifacts/crow-v15-recorded-restart-20261114';b=r/'build/crow-v15-recorded-restart-20261114';log=a/'neural-history-probe-source/stderr.gz'
with gzip.open(log,'rt') as f:
 rows=[line.split() for line in f if line.startswith('CROW_ACTION_HISTORY 201 ')]
assert len(rows)==1 and int(rows[0][2])==72 and len(rows[0])==75
values=[float(x) for x in rows[0][3:57]]; assert len(values)==54
def fl(v):
 s=format(v,'.10g');return (s if '.' in s or 'e' in s else s+'.0')+'f'
s=(a/'neural-settled-reset-exact-qv.metal').read_text();needle='''            resetScene[sceneBase+5u].orientation=float4(0.0f,0.0f,0.0998334166f,0.9950041653f);
''';assert s.count(needle)==1
snippet='''            // Diagnostic: source-recorded action history only; this is not a full checkpoint.
            if (program.counts0.x==18u && program.layout.w==3u) {
                const float recordedActionHistory[54]={'''+', '.join(map(fl,values))+'''};
                for (uint i=0u;i<54u;++i) actionHistory[delayBase+i]=recordedActionHistory[i];
            }
'''
src=a/'neural-settled-reset-action-history-corrected.metal';src.write_text(s.replace(needle,needle+snippet));air=b/'neural-settled-reset-action-history-corrected.air';lib=b/'neural-settled-reset-action-history-corrected.metallib';build=json.loads((a/'shader-build.json').read_text());cc=build['compile'].copy();cc[cc.index('-c')+1]=str(src);cc[cc.index('-o')+1]=str(air);subprocess.run(cc,check=True);link=build['link'].copy();link[link.index(str(b/'restart.air'))]=str(air);link[link.index('-o')+1]=str(lib);subprocess.run(link,check=True);(a/'neural-action-history-corrected-build.json').write_text(json.dumps({'source_observer_log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'host_step':201,'action_history':values,'compile':cc,'link':link,'sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (src,air,lib)}},indent=2)+'\n')
