from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import subprocess,hashlib,json
root=Path('/Users/home/Documents/Codex/2026-11-07/c/crow-48s-landing-checkpoint-20261114'); out=root/'latest-resetfixed-five-angles';old=root/'neural-direct-toe-residual-video/crow-direct-toe-residual-five-angles.mp4';hold=root/'neural-arrival-phase-history-video/hold'; views=('front','back','above','below','feet')
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',23);small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',18)
def labels(name,lines):
 im=Image.new('RGBA',(1920,960),(0,0,0,0));d=ImageDraw.Draw(im)
 for label,x,y in [('FRONT',0,0),('BACK',640,0),('ABOVE',0,480),('BELOW (GROUND HIDDEN)',640,480),('HIP / FEET CLOSE-UP',1280,0)]:
  d.rectangle((x,y,x+639,y+60),fill=(10,15,21,255));d.text((x+12,y+4),label,font=font,fill='white')
 d.rectangle((1280,480,1919,959),fill=(16,22,29,255))
 for i,line in enumerate(lines):d.text((1300,500+i*29),line,font=small,fill=(255,190,110) if i in (0,2,4,5,6,8,10) else (235,240,245))
 path=out/(name+'-labels.png');im.save(path);return path
failure=labels('latest-failure',['LATEST NETWORK: FALL','Development seed 20370113','First fall: 5.14 seconds.','','Reconstructed branch; phase forced.','Policy fork at checkpoint: 0.98 s.','Scripted carrier; no autonomous landing.','','Five synchronized simulator views.','First 48s is a separate old replay.','Old flight had collisions disabled.','Below view hides ground visually only.'])
held=labels('earlier-hold',['EARLIER NETWORK: 20-SECOND HOLD','Development seed 20370127','Strict two-foot grip: 19.18 seconds.','','Reconstructed branch; phase forced.','Later action history; scripted carrier.','Not a continuous autonomous landing.','','Development start; not held-out.','Five synchronized simulator views.','The other start still failed.','Below view hides ground visually only.'])
cmd=['ffmpeg','-v','error','-y','-i',str(old)]
for directory in (out,hold):
 for view in views:cmd+=['-i',str(directory/(view+'.mp4'))]
cmd+=['-loop','1','-framerate','50','-i',str(failure),'-loop','1','-framerate','50','-i',str(held)]
graph=('[1:v][2:v][3:v][4:v][5:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g1];[g1][11:v]overlay=shortest=1,setpts=PTS-STARTPTS[a];[6:v][7:v][8:v][9:v][10:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g2];[g2][12:v]overlay=shortest=1,setpts=PTS-STARTPTS[b];[0:v]trim=duration=48,setpts=PTS-STARTPTS[o];[o][a][b]concat=n=3:v=1:a=0,format=yuv420p[v]')
path=out/'crow-latest-fall-and-earlier-hold-five-angles.mp4';cmd+=['-filter_complex',graph,'-map','[v]','-an','-c:v','libx264','-preset','veryfast','-crf','21','-movflags','+faststart',str(path)];subprocess.run(cmd,check=True)
print(json.dumps({'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()},indent=2))
