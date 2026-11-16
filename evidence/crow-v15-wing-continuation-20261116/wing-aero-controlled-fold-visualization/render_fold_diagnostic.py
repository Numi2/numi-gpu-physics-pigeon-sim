"""Render exported FK as an explicitly schematic, body-centered diagnostic."""
import json
import math
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

base=Path(__file__).resolve().parent
lanes=[json.loads((base/f'kinematics-{i}.json').read_text()) for i in range(3)]
assert all(len(lane['frames'])==480 for lane in lanes)
W,H=1440,900
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',22)
small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',17)
out=base/'crow-articulated-fold-diagnostic-failed.mp4'
command=['/opt/homebrew/bin/ffmpeg','-y','-hide_banner','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r','30','-i','-','-c:v','libx264','-pix_fmt','yuv420p','-crf','19','-movflags','+faststart',str(out)]
proc=subprocess.Popen(command,stdin=subprocess.PIPE)

def rotate(q,v):
    a=np.asarray(q[:3]); w=q[3]; v=np.asarray(v)
    return v+2*np.cross(a,np.cross(a,v)+w*v)

def panel(draw,frame,x0,y0,label,view):
    x1,y1=x0+460,y0+345
    draw.rounded_rectangle((x0,y0,x1,y1),14,fill='#202a35',outline='#536273',width=2)
    draw.text((x0+14,y0+10),label+'  |  '+view,font=font,fill='#eef4f8')
    root=np.asarray(frame[0][:3]); center=np.array([x0+230,y0+198]); scale=540
    def proj(p):
        v=np.asarray(p)-root
        p2=np.array([v[1],-v[0]]) if view=='above' else np.array([v[1],-v[2]])
        return tuple(center+scale*p2)
    def line(a,b,color,width):draw.line([proj(a),proj(b)],fill=color,width=width)
    # Torso and head are schematic markers, not a surface or feather rendering.
    line(frame[7][:3],frame[0][:3],'#778798',11)
    line(frame[0][:3],frame[17][:3],'#a1afbb',12)
    for side,idxs,sign in [('left',(5,35,37),1),('right',(6,38,40),-1)]:
        for idx,length,color in zip(idxs,(.08355912,.09530571,.09089033),('#69d2d0','#57b8e8','#f0c674')):
            body=frame[idx]; p=np.asarray(body[:3]); d=rotate(body[3:],(0,sign*length/2,0))
            line(p-d,p+d,color,9)
            for point in (p-d,p+d):
                a,b=proj(point);draw.ellipse((a-4,b-4,a+4,b+4),fill='#edf4fa')
    a,b=proj(root);draw.ellipse((a-10,b-10,a+10,b+10),fill='#d6e2ec')

try:
    for f in range(90):
        step=479 if f>=59 else f*8
        im=Image.new('RGB',(W,H),'#101720');d=ImageDraw.Draw(im)
        d.text((25,13),'EXPERIMENTAL FOLD — TRACKING FAILED',font=font,fill='#ffd18e')
        d.text((25,45),f'Native recorded states  |  {step/240:.2f} s / 2.00 s  |  moving root centered in each view',font=small,fill='#c6d4df')
        for lane in range(3):
            for row,view in enumerate(('above','front')):
                panel(d,lanes[lane]['frames'][step],20+lane*470,90+row*355,f'{(0,5,10)[lane]} m/s wind',view)
        d.text((25,810),'Lines: upper arm / forearm / hand. Dots mark segment endpoints. No feathers or swept collision geometry shown.',font=small,fill='#dbe6ef')
        d.text((25,840),'Diagnostic only: no flight, landing, balance, or biological realism qualification.',font=small,fill='#ffbf9b')
        proc.stdin.write(im.tobytes())
finally:
    proc.stdin.close()
    status=proc.wait()
    if status:raise SystemExit(status)
