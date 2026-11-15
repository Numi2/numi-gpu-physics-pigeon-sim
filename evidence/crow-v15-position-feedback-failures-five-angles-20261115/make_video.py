from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import subprocess,hashlib,json
p=Path('/Users/home/Documents/Codex/2026-11-07/c/crow-48s-landing-checkpoint-20261114/latest-position-feedback-failures');font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',28);small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',22)
for variant,count,title,subtitle in [('pos',128,'POSITIVE CORRECTION: FAILED','Terminated at step 678'),('neg',147,'NEGATIVE CORRECTION: FAILED','Terminated at step 697')]:
 d=p/variant;im=Image.new('RGBA',(1920,960),(0,0,0,0));draw=ImageDraw.Draw(im)
 for x,y,label in [(0,0,'FRONT'),(640,0,'BACK'),(1280,0,'ABOVE'),(0,480,'BELOW'),(640,480,'HIPS AND FEET')]:
  draw.rectangle((x,y,x+235,y+38),fill=(0,0,0,175));draw.text((x+12,y+5),label,font=font,fill='white')
 draw.rectangle((1280,480,1920,960),fill=(20,24,27,255))
 for y,text in [(510,title),(560,subtitle),(610,'Reconstructed branch fixture'),(650,'Internal hip disturbance'),(690,'Fixed position-only hip feedback'),(740,'Feather shape is estimated'),(780,'No neural recovery or landing shown')]:draw.text((1300,y),text,font=font if y==510 else small,fill='white')
 im.save(d/'labels.png');cmd=['ffmpeg','-hide_banner','-loglevel','error','-y']
 for x in ('front','back','above','below','feet'):cmd+=['-i',str(d/(x+'.mp4'))]
 cmd+=['-loop','1','-framerate','50','-i',str(d/'labels.png'),'-filter_complex','[0:v][1:v][2:v]hstack=inputs=3[top];[3:v][4:v]hstack=inputs=2[bottomleft];color=c=black:s=640x480:r=50[empty];[bottomleft][empty]hstack=inputs=2[bottom];[top][bottom]vstack=inputs=2[grid];[grid][5:v]overlay=shortest=1:format=auto,format=yuv420p[out]','-map','[out]','-an','-frames:v',str(count),'-c:v','libx264','-preset','veryfast','-crf','21','-movflags','+faststart',str(d/'five-angles.mp4')];subprocess.run(cmd,check=True)
(p/'concat.txt').write_text("file 'pos/five-angles.mp4'\nfile 'neg/five-angles.mp4'\n")
output=p/'crow-position-feedback-failures-five-angles.mp4';subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-f','concat','-safe','0','-i',str(p/'concat.txt'),'-c','copy','-movflags','+faststart',str(output)],check=True)
(p/'video-sha256.json').write_text(json.dumps({str(x.relative_to(p)):hashlib.sha256(x.read_bytes()).hexdigest() for x in sorted(p.rglob('*.mp4'))},indent=2)+'\n');print(output)
