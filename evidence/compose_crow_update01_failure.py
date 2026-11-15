from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import subprocess
p=Path('/Users/home/Documents/Codex/2026-11-07/c/crow-48s-landing-checkpoint-20261114/neural-update01-video');font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',23);small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',18)
im=Image.new('RGBA',(1920,960),(0,0,0,0));d=ImageDraw.Draw(im)
for label,x,y in [('FRONT',0,0),('BACK',640,0),('ABOVE',0,480),('BELOW (GROUND HIDDEN)',640,480),('HIP / FEET CLOSE-UP',1280,0)]:
 d.rectangle((x,y,x+639,y+60),fill=(10,15,21,255));d.text((x+12,y+4),label,font=font,fill='white')
d.rectangle((1280,480,1919,959),fill=(16,22,29,255))
for i,line in enumerate(['RECONSTRUCTED PERCH: FALL','Network update 01; development seed 20310201','Tilt termination at 19.72 seconds.','','Longest strict support/grip: 17.38 seconds.','Branch moved; terminal phase forced.','Scripted carrier, neural hip/ankle residual.','','Partially reconstructed state; no reset shown.','Not a continuous autonomous landing.','','Below view hides ground visually only.']):d.text((1300,500+i*29),line,font=small,fill=(255,190,110) if i in (0,3,4,5,8,10) else (235,240,245))
labels=p/'failure-preview-labels.png';im.save(labels)
cmd=['ffmpeg','-v','error','-y']
for name in ('front','back','above','below','feet'):cmd+=['-i',str(p/'failure'/f'{name}.mp4')]
cmd+=['-loop','1','-framerate','50','-i',str(labels),'-filter_complex','[0:v][1:v][2:v][3:v][4:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g];[g][5:v]overlay=shortest=1,format=yuv420p[v]','-map','[v]','-an','-c:v','libx264','-preset','veryfast','-crf','21','-movflags','+faststart',str(p/'crow-update01-fall-five-angles.mp4')]
subprocess.run(cmd,check=True)
