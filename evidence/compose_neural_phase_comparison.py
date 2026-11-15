from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import subprocess
root=Path(__file__).resolve().parent;p=root/'neural-phase-comparison-video';p.mkdir(exist_ok=True)
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',23);small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',18)
def make_labels(name,lines):
 im=Image.new('RGBA',(1920,960),(0,0,0,0));d=ImageDraw.Draw(im)
 for label,x,y in [('FRONT',0,0),('BACK',640,0),('ABOVE',0,480),('BELOW (GROUND HIDDEN)',640,480),('HIP / FEET CLOSE-UP',1280,0)]:
  d.rectangle((x,y,x+639,y+60),fill=(10,15,21,255));d.text((x+12,y+4),label,font=font,fill='white')
 d.rectangle((1280,480,1919,959),fill=(16,22,29,255))
 for i,line in enumerate(lines):d.text((1300,500+i*29),line,font=small,fill=(255,190,110) if i in (0,3,4,5,7,9,11,12) else (235,240,245))
 path=p/(name+'-labels.png');im.save(path);return path
for name,lines in [('failure',['RECONSTRUCTED PERCH: FALL','Five synchronized views; seed 20310111','9.00 seconds to tilt termination.','','Branch was relocated; landing phase forced.','Scripted carrier plus learned leg residual.','State and action history partly reconstructed.','','No post-failure reset is shown.','This is not a continuous landing.','','The original flight had collisions disabled.','Below view hides ground visually only.']),('hold',['RECONSTRUCTED PERCH: 10-SECOND HOLD','Five synchronized views; seed 20310129','Both toe grip and support gates held.','','Branch was relocated; landing phase forced.','Scripted carrier plus learned leg residual.','State and action history partly reconstructed.','','This is one used development start.','This is not a continuous landing.','','The original flight had collisions disabled.','Below view hides ground visually only.'])]:make_labels(name,lines)
original=root.parent/'crow-latest-multiview-20261114/crow-latest-48s-multiview.mp4';cmd=['ffmpeg','-v','error','-y','-i',str(original)]
for group in ('failure','hold'):
 for name in ('front','back','above','below','feet'):cmd+=['-i',str(p/group/(name+'.mp4'))]
cmd+=['-loop','1','-framerate','50','-i',str(p/'failure-labels.png'),'-loop','1','-framerate','50','-i',str(p/'hold-labels.png')]
graph=('[1:v][2:v][3:v][4:v][5:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g1];'
 '[g1][11:v]overlay=shortest=1,setpts=PTS-STARTPTS[a];'
 '[6:v][7:v][8:v][9:v][10:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g2];'
 '[g2][12:v]overlay=shortest=1,setpts=PTS-STARTPTS[b];'
 '[0:v]setpts=PTS-STARTPTS[o];[o][a][b]concat=n=3:v=1:a=0,format=yuv420p[v]')
cmd+=['-filter_complex',graph,'-map','[v]','-an','-c:v','libx264','-preset','veryfast','-crf','21','-movflags','+faststart',str(p/'crow-phase-balance-comparison-five-angles.mp4')];subprocess.run(cmd,check=True)
