from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import subprocess,hashlib,json
p=Path(__file__).parent
im=Image.new('RGBA',(1920,960),(0,0,0,0));d=ImageDraw.Draw(im)
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',28);small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',22)
for x,y,label in [(0,0,'FRONT'),(640,0,'BACK'),(1280,0,'ABOVE'),(0,480,'BELOW'),(640,480,'HIPS AND FEET')]:
 d.rectangle((x,y,x+235,y+38),fill=(0,0,0,175));d.text((x+12,y+5),label,font=font,fill='white')
d.rectangle((1280,480,1920,960),fill=(20,24,27,255))
for y,text in [(510,'30-SECOND HOLD: FINAL 6s'),(570,'Reconstructed branch start'),(610,'Fixed wing and hip targets'),(650,'Not a trained recovery controller'),(710,'Time shown: 24 to 30 seconds'),(760,'Feather shape is an estimate'),(800,'No autonomous landing shown')]:
 d.text((1300,y),text,font=font if y==510 else small,fill='white')
im.save(p/'labels.png')
video=p/'crow-lowered-wing-hold-five-angles.mp4'
cmd=['ffmpeg','-hide_banner','-loglevel','error','-y']
for x in ('front','back','above','below','feet'):cmd+=['-i',str(p/(x+'.mp4'))]
cmd+=['-loop','1','-framerate','50','-i',str(p/'labels.png'),'-filter_complex','[0:v][1:v][2:v]hstack=inputs=3[top];[3:v][4:v]hstack=inputs=2[bottomleft];color=c=black:s=640x480:r=50[empty];[bottomleft][empty]hstack=inputs=2[bottom];[top][bottom]vstack=inputs=2[grid];[grid][5:v]overlay=shortest=1:format=auto,format=yuv420p[out]','-map','[out]','-an','-frames:v','300','-c:v','libx264','-preset','veryfast','-crf','21','-movflags','+faststart',str(video)]
subprocess.run(cmd,check=True)
(p/'video-sha256.json').write_text(json.dumps({x.name:hashlib.sha256(x.read_bytes()).hexdigest() for x in sorted(p.glob('*.mp4'))},indent=2)+'\n')
print(video)
