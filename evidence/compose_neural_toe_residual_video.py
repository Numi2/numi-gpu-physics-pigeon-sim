from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import subprocess,sys
p=Path(sys.argv[1]).resolve();original=Path(sys.argv[2]).resolve();p.mkdir(exist_ok=True,parents=True)
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',23);small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',18)
def labels(name,lines):
 im=Image.new('RGBA',(1920,960),(0,0,0,0));d=ImageDraw.Draw(im)
 for label,x,y in [('FRONT',0,0),('BACK',640,0),('ABOVE',0,480),('BELOW (GROUND HIDDEN)',640,480),('HIP / FEET CLOSE-UP',1280,0)]:
  d.rectangle((x,y,x+639,y+60),fill=(10,15,21,255));d.text((x+12,y+4),label,font=font,fill='white')
 d.rectangle((1280,480,1919,959),fill=(16,22,29,255))
 for i,line in enumerate(lines):d.text((1300,500+i*29),line,font=small,fill=(255,190,110) if i in (0,3,4,5,8,10,12) else (235,240,245))
 path=p/(name+'-labels.png');im.save(path);return path
labels('failure',['DIRECT TOE POLICY: FALL','Direct contact residual; development seed 20370113','Tilt termination at 5.26 seconds.','','Longest strict support/grip: 2.78 seconds.','Branch moved; terminal phase forced.','Scripted carrier, learned contact residual.','','Partially reconstructed state; no reset shown.','Not a continuous autonomous landing.','','Original 48-second flight: collisions disabled.','Five synchronized views; ground hidden below.'])
labels('hold',['RECONSTRUCTED PERCH: 20-SECOND TRIAL','Direct contact residual; development seed 20370127','No termination within the shown trial.','','Longest strict support/grip: 19.24 seconds.','Branch moved; terminal phase forced.','Scripted carrier, learned contact residual.','','Partially reconstructed state; no reset shown.','Not a continuous autonomous landing.','','Original 48-second flight: collisions disabled.','Five synchronized views; ground hidden below.'])
cmd=['ffmpeg','-v','error','-y','-i',str(original)]
for group in ('failure','hold'):
 for name in ('front','back','above','below','feet'):cmd+=['-i',str(p/group/(name+'.mp4'))]
cmd+=['-loop','1','-framerate','50','-i',str(p/'failure-labels.png'),'-loop','1','-framerate','50','-i',str(p/'hold-labels.png')]
graph=('[1:v][2:v][3:v][4:v][5:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g1];[g1][11:v]overlay=shortest=1,setpts=PTS-STARTPTS[a];[6:v][7:v][8:v][9:v][10:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g2];[g2][12:v]overlay=shortest=1,setpts=PTS-STARTPTS[b];[0:v]trim=duration=48,setpts=PTS-STARTPTS[o];[o][a][b]concat=n=3:v=1:a=0,format=yuv420p[v]')
cmd+=['-filter_complex',graph,'-map','[v]','-an','-c:v','libx264','-preset','veryfast','-crf','21','-movflags','+faststart',str(p/'crow-direct-toe-residual-five-angles.mp4')];subprocess.run(cmd,check=True)
