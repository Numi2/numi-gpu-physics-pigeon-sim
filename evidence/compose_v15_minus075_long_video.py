from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib, json, subprocess
out=Path('/Users/home/Documents/Codex/2026-11-07/c/crow-48s-landing-checkpoint-20261114/latest-long-failure-five-angles')
views=('front','back','above','below','feet')
expected={Path(line.split('  ',1)[1]).name:line.split('  ',1)[0] for line in (out/'video-sha256.txt').read_text().splitlines()}
for view in views:
 p=out/(view+'.mp4'); assert hashlib.sha256(p.read_bytes()).hexdigest()==expected[p.name]
start,end=map(int,(out/'window.txt').read_text().split()); assert (start,end)==(125,625)
im=Image.new('RGBA',(1920,960),(0,0,0,0));d=ImageDraw.Draw(im);font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',20);small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',17)
for xy,title in [((8,8),'FRONT'),((648,8),'BACK'),((8,488),'ABOVE'),((648,488),'BELOW'),((1288,8),'HIPS AND FEET')]:
 d.rectangle((xy[0]-4,xy[1]-4,xy[0]+160,xy[1]+25),fill=(10,15,20,190));d.text(xy,title,font=font,fill=(255,255,255,255))
d.rectangle((1280,480,1919,959),fill=(16,22,29,255))
lines=['LATEST BRANCH TEST: BALANCE FAILURE','Development seed 20370113','Shown: 2.50 to 12.50 s after checkpoint','Balance termination at 12.50 s.','','Fixed hip bias; not a trained solution.','Forced perch, reconstructed branch.','Scripted carrier; no autonomous landing.','','Both feet contact the branch; the','opposed-toe proxy fails before termination.','','Five synchronized simulator views.','Below view hides ground visually only.']
for i,line in enumerate(lines):d.text((1296,498+i*27),line,font=small,fill=(255,183,84,255) if i in (0,2,3,5,6,7,10) else (235,238,243,255))
label=out/'labels.png';im.save(label)
cmd=['ffmpeg','-v','error','-y']
for view in views:cmd+=['-i',str(out/(view+'.mp4'))]
cmd+=['-loop','1','-framerate','50','-i',str(label),'-filter_complex','[0:v][1:v][2:v][3:v][4:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g];[g][5:v]overlay=shortest=1,format=yuv420p[v]','-map','[v]','-an','-c:v','libx264','-preset','veryfast','-crf','21','-movflags','+faststart',str(out/'crow-latest-branch-fall-five-angles.mp4')]
subprocess.run(cmd,check=True)
result=out/'crow-latest-branch-fall-five-angles.mp4'; print(json.dumps({'path':str(result),'sha256':hashlib.sha256(result.read_bytes()).hexdigest(),'start_interval':start,'end_interval':end},indent=2))
