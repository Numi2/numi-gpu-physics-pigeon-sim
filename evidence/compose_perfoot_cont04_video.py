from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import hashlib,json,subprocess,tarfile
archive=Path('/private/tmp/crow-balance-evidence-20261115/evidence/crow-toe-perfoot-cont04-renderer-bundle-20370113.tar.gz')
manifest=json.loads(archive.with_suffix(archive.suffix+'.manifest.json').read_text())
assert hashlib.sha256(archive.read_bytes()).hexdigest()==manifest['archive_sha256']
p=Path('/Users/home/Documents/Codex/2026-11-07/c/crow-48s-landing-checkpoint-20261114/neural-perfoot-cont04-video');p.mkdir(exist_ok=True)
names=('front','back','above','below','feet')
with tarfile.open(archive,'r:gz') as tar:
 for name in names:
  matches=[m for m in tar.getmembers() if m.name.endswith('/'+name+'.mp4')];assert len(matches)==1
  (p/(name+'.mp4')).write_bytes(tar.extractfile(matches[0]).read())
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',23);small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',18)
im=Image.new('RGBA',(1920,960),(0,0,0,0));d=ImageDraw.Draw(im)
for label,x,y in [('FRONT',0,0),('BACK',640,0),('ABOVE',0,480),('BELOW (GROUND HIDDEN)',640,480),('HIP / FEET CLOSE-UP',1280,0)]:
 d.rectangle((x,y,x+639,y+60),fill=(10,15,21,255));d.text((x+12,y+4),label,font=font,fill='white')
d.rectangle((1280,480,1919,959),fill=(16,22,29,255))
lines=['LATEST RETRAINING TRIAL: FALL','Development seed 20370113','First fall: 5.10 seconds.','','Longest strict grip: 2.62 seconds.','Reconstructed perch; branch relocated.','Terminal phase forced; carrier scripted.','','Five-angle replay; no reset shown.','Not an uninterrupted autonomous landing.','','Below view hides ground visually only.']
for i,line in enumerate(lines):d.text((1300,500+i*29),line,font=small,fill=(255,190,110) if i in (0,2,4,5,6,9) else (235,240,245))
labels=p/'labels.png';im.save(labels)
cmd=['ffmpeg','-v','error','-y']
for name in names:cmd+=['-i',str(p/(name+'.mp4'))]
cmd+=['-loop','1','-framerate','50','-i',str(labels),'-filter_complex','[0:v][1:v][2:v][3:v][4:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g];[g][5:v]overlay=shortest=1,format=yuv420p[v]','-map','[v]','-an','-c:v','libx264','-preset','veryfast','-crf','21','-movflags','+faststart',str(p/'latest-five-angles.mp4')]
subprocess.run(cmd,check=True)
original=Path('/Users/home/Documents/Codex/2026-11-07/c/crow-48s-landing-checkpoint-20261114/neural-direct-toe-residual-video/crow-direct-toe-residual-five-angles.mp4')
cmd=['ffmpeg','-v','error','-y','-i',str(original),'-i',str(p/'latest-five-angles.mp4'),'-filter_complex','[0:v]trim=duration=48,setpts=PTS-STARTPTS[a];[1:v]setpts=PTS-STARTPTS[b];[a][b]concat=n=2:v=1:a=0,format=yuv420p[v]','-map','[v]','-an','-c:v','libx264','-preset','veryfast','-crf','21','-movflags','+faststart',str(p/'crow-original-48s-and-latest-failure-five-angles.mp4')]
subprocess.run(cmd,check=True)
print(p/'crow-original-48s-and-latest-failure-five-angles.mp4')
