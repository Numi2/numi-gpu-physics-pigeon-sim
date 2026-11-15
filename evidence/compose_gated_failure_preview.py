from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import subprocess,sys
p=Path(sys.argv[1]);p.mkdir(parents=True,exist_ok=True)
im=Image.new('RGBA',(1920,960),(0,0,0,0));d=ImageDraw.Draw(im);font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',23);small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',18)
for label,x,y in [('FRONT',0,0),('BACK',640,0),('ABOVE',0,480),('BELOW (GROUND HIDDEN)',640,480),('HIP / FEET CLOSE-UP',1280,0)]:
 d.rectangle((x,y,x+639,y+60),fill=(10,15,21,255));d.text((x+12,y+4),label,font=font,fill='white')
d.rectangle((1280,480,1919,959),fill=(16,22,29,255))
lines=['RESERVED ARRIVAL: FALL AT 3.54 S','Contact-gated neural legs and toes','Seed 20360117; strict grip 1.22 s','','Branch relocated; terminal phase forced.','Partially reconstructed state.','Scripted toe carrier also active.','','Not a continuous autonomous landing.','Five synchronized simulated views.']
for i,line in enumerate(lines):d.text((1300,500+i*29),line,font=small,fill=(255,190,110) if i in (0,4,5,6,8) else (235,240,245))
label=p/'preview-labels.png';im.save(label)
cmd=['ffmpeg','-v','error','-y']
for n in ('front','back','above','below','feet'):cmd+=['-i',str(p/'failure'/(n+'.mp4'))]
cmd+=['-loop','1','-framerate','50','-i',str(label),'-filter_complex','[0:v][1:v][2:v][3:v][4:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g];[g][5:v]overlay=shortest=1,format=yuv420p[v]','-map','[v]','-an','-c:v','libx264','-preset','veryfast','-crf','21','-movflags','+faststart',str(p/'crow-reserved-arrival-failure-five-angles.mp4')];subprocess.run(cmd,check=True)
