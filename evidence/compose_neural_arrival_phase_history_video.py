from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib, json, subprocess, tarfile

repo = Path('/private/tmp/crow-balance-evidence-20261115/evidence')
root = Path('/Users/home/Documents/Codex/2026-11-07/c/crow-48s-landing-checkpoint-20261114')
out = root/'neural-arrival-phase-history-video'
out.mkdir(exist_ok=True)
views = ('front', 'back', 'above', 'below', 'feet')
for group, variant, seed in [('failure', 'update01', '20370113'), ('hold', 'cont04', '20370127')]:
    archive = repo/f'crow-arrival-phase-history-{variant}-renderer-bundle-{seed}.tar.gz'
    manifest = json.loads(archive.with_suffix(archive.suffix+'.manifest.json').read_text())
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == manifest['archive_sha256']
    directory = out/group; directory.mkdir(exist_ok=True)
    with tarfile.open(archive, 'r:gz') as tar:
        for view in views:
            matches = [m for m in tar.getmembers() if m.name.endswith('/'+view+'.mp4')]
            assert len(matches) == 1
            (directory/(view+'.mp4')).write_bytes(tar.extractfile(matches[0]).read())

font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 23)
small = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 18)
def labels(group, lines):
    im = Image.new('RGBA', (1920,960), (0,0,0,0)); d = ImageDraw.Draw(im)
    for label,x,y in [('FRONT',0,0),('BACK',640,0),('ABOVE',0,480),('BELOW (GROUND HIDDEN)',640,480),('HIP / FEET CLOSE-UP',1280,0)]:
        d.rectangle((x,y,x+639,y+60),fill=(10,15,21,255)); d.text((x+12,y+4),label,font=font,fill='white')
    d.rectangle((1280,480,1919,959),fill=(16,22,29,255))
    for i,line in enumerate(lines): d.text((1300,500+i*29),line,font=small,fill=(255,190,110) if i in (0,2,4,5,6,8,10) else (235,240,245))
    path=out/(group+'-labels.png'); im.save(path); return path
failure = labels('failure', ['NEURAL UPDATE 01: FALL','Development seed 20370113','First fall: 5.14 seconds.','','Reconstructed branch; phase forced.','Later action history; scripted carrier.','Not a continuous autonomous landing.','','No reset shown after the fall.','Five synchronized views.','Original flight had collisions disabled.','Below view hides ground visually only.'])
hold = labels('hold', ['CONTINUATION 04: 20-SECOND HOLD','Development seed 20370127','Strict two-foot grip: 19.18 seconds.','','Reconstructed branch; phase forced.','Later action history; scripted carrier.','Not a continuous autonomous landing.','','One previously used development start.','Five synchronized views.','The harder start still failed.','Below view hides ground visually only.'])
original = root/'neural-direct-toe-residual-video/crow-direct-toe-residual-five-angles.mp4'
cmd=['ffmpeg','-v','error','-y','-i',str(original)]
for group in ('failure','hold'):
    for view in views: cmd += ['-i',str(out/group/(view+'.mp4'))]
cmd += ['-loop','1','-framerate','50','-i',str(failure),'-loop','1','-framerate','50','-i',str(hold)]
graph=('[1:v][2:v][3:v][4:v][5:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g1];'
       '[g1][11:v]overlay=shortest=1,setpts=PTS-STARTPTS[a];'
       '[6:v][7:v][8:v][9:v][10:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g2];'
       '[g2][12:v]overlay=shortest=1,setpts=PTS-STARTPTS[b];'
       '[0:v]trim=duration=48,setpts=PTS-STARTPTS[o];[o][a][b]concat=n=3:v=1:a=0,format=yuv420p[v]')
path=out/'crow-48s-then-fall-and-hold-five-angles.mp4'
cmd += ['-filter_complex',graph,'-map','[v]','-an','-c:v','libx264','-preset','veryfast','-crf','21','-movflags','+faststart',str(path)]
subprocess.run(cmd,check=True)
print(path)
