from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import subprocess
root=Path(__file__).resolve().parent;p=root/'neural-v3-long-video';p.mkdir(exist_ok=True)
im=Image.new('RGBA',(1920,960),(0,0,0,0));d=ImageDraw.Draw(im);font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',23);small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',19)
for label,x,y in [('FRONT',0,0),('BACK',640,0),('ABOVE',0,480),('BELOW (GROUND HIDDEN)',640,480),('HIP / FEET CLOSE-UP',1280,0)]:
 d.rectangle((x,y,x+639,y+60),fill=(10,15,21,255));d.text((x+12,y+4),label,font=font,fill='white')
d.rectangle((1280,480,1919,959),fill=(16,22,29,255))
lines=['NEURAL V3: 20-SECOND DEVELOPMENT HOLD','Five synchronized views of recorded physics','Reconstructed 48-second checkpoint; no reset','','Branch moved near the crow; landing phase forced.','A scripted carrier plus neural hip/ankle residuals','controls this development fixture.','','Used seed: 19.26 s continuous qualifying grip','within a 20-second run. No external push tested.','','This is not an autonomous original-course landing.','Original flight had course collisions disabled.','Below view hides ground visually; physics unchanged.']
for i,line in enumerate(lines):d.text((1300,501+i*31),line,font=small,fill=(255,190,110) if i in (0,4,5,6,8,9,11,12) else (235,240,245))
labels=p/'neural-v3-labels.png';im.save(labels);original=root.parent/'crow-latest-multiview-20261114/crow-latest-48s-multiview.mp4'
cmd=['ffmpeg','-v','error','-y','-i',str(original)]
for name in ('front','back','above','below','feet'):cmd+=['-i',str(p/(name+'.mp4'))]
cmd+=['-loop','1','-framerate','50','-i',str(labels)]
graph=('[1:v][2:v][3:v][4:v][5:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[grid];[grid][6:v]overlay=shortest=1[labeled];[0:v]setpts=PTS-STARTPTS[original];[labeled]setpts=PTS-STARTPTS[resumed];[original][resumed]concat=n=2:v=1:a=0,format=yuv420p[v]')
cmd+=['-filter_complex',graph,'-map','[v]','-an','-c:v','libx264','-preset','veryfast','-crf','21','-movflags','+faststart',str(p/'crow-v3-20s-branch-multiview.mp4')];subprocess.run(cmd,check=True)
