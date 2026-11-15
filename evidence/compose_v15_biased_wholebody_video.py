from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib,json,subprocess
out=Path('/Users/home/Documents/Codex/2026-11-07/c/crow-48s-landing-checkpoint-20261114/latest-trained-five-angles'); views=('front','back','above','below','feet');font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',20);small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',17)
for trial,intervals in (('hard',(0,500)),('easy',(0,400))):
 dpath=out/trial; expected={Path(line.split('  ',1)[1]).name:line.split('  ',1)[0] for line in (dpath/'video-sha256.txt').read_text().splitlines()}
 for view in views:
  p=dpath/(view+'.mp4');assert hashlib.sha256(p.read_bytes()).hexdigest()==expected[p.name]
 assert tuple(map(int,(dpath/'window.txt').read_text().split()))==intervals
 im=Image.new('RGBA',(1920,960),(0,0,0,0));d=ImageDraw.Draw(im)
 for xy,title in [((8,8),'FRONT'),((648,8),'BACK'),((8,488),'ABOVE'),((648,488),'BELOW'),((1288,8),'HIPS AND FEET')]:
  d.rectangle((xy[0]-4,xy[1]-4,xy[0]+160,xy[1]+25),fill=(10,15,20,190));d.text(xy,title,font=font,fill=(255,255,255,255))
 d.rectangle((1280,480,1919,959),fill=(16,22,29,255))
 if trial=='hard': lines=['WHOLE-BODY NETWORK: HARD START','Development seed 20370113','10 s after physical checkpoint.','No termination in shown interval.','Maximum tilt 0.249 rad.','','This is a short development hold.','A different fixed-posture run lost','balance after 12.5 seconds.']
 else: lines=['WHOLE-BODY NETWORK: EASY START','Development seed 20370127','8 s after physical checkpoint.','No termination in shown interval.','Tilt exceeded the 0.15 rad test limit.','','First-250 peak: 0.157 rad.','The candidate failed the matched test.']
 lines+=['','Forced perch; reconstructed branch.','Scripted carrier; no autonomous landing.','Below view hides ground visually.']
 for i,line in enumerate(lines):d.text((1296,498+i*27),line,font=small,fill=(255,183,84,255) if i in (0,2,4,6) else (235,238,243,255))
 im.save(dpath/'labels.png')
cmd=['ffmpeg','-v','error','-y']
for trial in ('hard','easy'):
 for view in views:cmd+=['-i',str(out/trial/(view+'.mp4'))]
for trial in ('hard','easy'):cmd+=['-loop','1','-framerate','50','-i',str(out/trial/'labels.png')]
graph=('[0:v][1:v][2:v][3:v][4:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g1];[g1][10:v]overlay=shortest=1,setpts=PTS-STARTPTS[a];[5:v][6:v][7:v][8:v][9:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g2];[g2][11:v]overlay=shortest=1,setpts=PTS-STARTPTS[b];[a][b]concat=n=2:v=1:a=0,format=yuv420p[v]')
path=out/'crow-trained-balance-two-starts-five-angles.mp4';cmd+=['-filter_complex',graph,'-map','[v]','-an','-c:v','libx264','-preset','veryfast','-crf','21','-movflags','+faststart',str(path)];subprocess.run(cmd,check=True);print(json.dumps({'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}))
