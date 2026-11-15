from pathlib import Path
import gzip, hashlib, json, subprocess

r = Path('/Users/n/Developer/numi-crow-rl-20261107')
a = r/'artifacts/crow-v15-recorded-restart-20261114'
b = r/'build/crow-v15-recorded-restart-20261114'
log = a/'neural-history-probe-source/stderr.gz'
with gzip.open(log, 'rt') as f:
    rows = [line.split() for line in f if line.startswith('CROW_ACTION_HISTORY 201 ')]
assert len(rows) == 1 and int(rows[0][2]) == 72 and len(rows[0]) == 75
values = [float(x) for x in rows[0][3:57]]
assert len(values) == 54
def fl(v):
    s = format(v, '.10g')
    return (s if '.' in s or 'e' in s else s+'.0')+'f'
snippet = '''            // Approximate diagnostic only: history from a later source frame, not the original checkpoint.
            if (program.counts0.x==18u && program.layout.w==3u) {
                const float recordedActionHistory[54]={'''+', '.join(map(fl, values))+'''};
                for (uint i=0u;i<54u;++i) actionHistory[delayBase+i]=recordedActionHistory[i];
            }
'''
build = json.loads((a/'shader-build.json').read_text())
records = {'source_observer_log_sha256': hashlib.sha256(log.read_bytes()).hexdigest(), 'source_host_step': 201, 'action_history': values, 'variants': {}}
for name in ('eval', 'training'):
    base = a/f'neural-arrival-phase-control-{name}.metal'
    src = a/f'neural-arrival-phase-history-control-{name}.metal'
    air = b/f'neural-arrival-phase-history-control-{name}.air'
    lib = b/f'neural-arrival-phase-history-control-{name}.metallib'
    assert not src.exists() and not lib.exists()
    s = base.read_text()
    needle = '            resetScene[sceneBase+5u].orientation=float4(0.0f,0.0f,0.0998334166f,0.9950041653f);\n'
    assert s.count(needle) == 1
    src.write_text(s.replace(needle, needle+snippet))
    cc = build['compile'].copy(); cc[cc.index('-c')+1] = str(src); cc[cc.index('-o')+1] = str(air)
    subprocess.run(cc, check=True)
    link = build['link'].copy(); link[link.index(str(b/'restart.air'))] = str(air); link[link.index('-o')+1] = str(lib)
    subprocess.run(link, check=True)
    records['variants'][name] = {'compile': cc, 'link': link, 'sha256': {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in (base, src, air, lib)}}
(a/'neural-arrival-phase-history-control-build.json').write_text(json.dumps(records, indent=2)+'\n')
print('arrival phase and approximate history diagnostic built')
