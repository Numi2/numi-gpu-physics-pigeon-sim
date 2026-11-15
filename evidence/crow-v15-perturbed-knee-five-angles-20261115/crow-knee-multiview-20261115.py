from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import hashlib,json,subprocess

p=Path('/Users/home/Documents/Codex/2026-11-07/c/crow-48s-landing-checkpoint-20261114/latest-perturbed-knee-five-angles')
views=('front','back','above','below','feet')
expected={Path(line.split('  ',1)[1]).name:line.split('  ',1)[0] for line in (p/'video-sha256.txt').read_text().splitlines()}
assert all(hashlib.sha256((p/(v+'.mp4')).read_bytes()).hexdigest()==expected[v+'.mp4'] for v in views)
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',28);small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',22)
im=Image.new('RGBA',(1920,960),(0,0,0,0));d=ImageDraw.Draw(im)
for x,y,label in [(0,0,'FRONT'),(640,0,'BACK'),(1280,0,'ABOVE'),(0,480,'BELOW'),(640,480,'HIPS AND FEET')]:
    # Mask the replay's inherited waypoint HUD: this fixture force-sets its
    # phase and is not a completed autonomous mission.
    d.rectangle((x,y,x+300,y+78),fill=(0,0,0,255));d.text((x+12,y+5),label,font=font,fill='white')
d.rectangle((1280,480,1920,960),fill=(20,24,27,255))
for y,text in [(510,'KNEE CORRECTION: FAILED'),(560,'Fixed +0.04 rad per knee'),(610,'Reconstructed branch fixture'),(650,'Starts after internal hip disturbance'),(690,'Terminated after 2.12 seconds'),(740,'Half-speed playback'),(780,'Feather shape is estimated'),(820,'No autonomous landing shown')]:
    d.text((1300,y),text,font=font if y==510 else small,fill='white')
im.save(p/'labels.png')
cmd=['ffmpeg','-hide_banner','-loglevel','error','-y']
for view in views:cmd+=['-i',str(p/(view+'.mp4'))]
cmd+=['-loop','1','-framerate','50','-i',str(p/'labels.png'),'-filter_complex','[0:v][1:v][2:v]hstack=inputs=3[top];[3:v][4:v]hstack=inputs=2[bottomleft];color=c=black:s=640x480:r=50[empty];[bottomleft][empty]hstack=inputs=2[bottom];[top][bottom]vstack=inputs=2[grid];[grid][5:v]overlay=shortest=1:format=auto,setpts=2*PTS,fps=50,format=yuv420p[out]','-map','[out]','-an','-frames:v','212','-c:v','libx264','-preset','veryfast','-crf','21','-movflags','+faststart',str(p/'crow-knee-failure-five-angles.mp4')]
subprocess.run(cmd,check=True)
(p/'composite-sha256.json').write_text(json.dumps({'output_sha256':hashlib.sha256((p/'crow-knee-failure-five-angles.mp4').read_bytes()).hexdigest(),'source_sha256':expected,'playback_speed':0.5,'source_control_intervals':106,'fps':50,'argv':cmd},indent=2)+'\n')
print(p/'crow-knee-failure-five-angles.mp4')
