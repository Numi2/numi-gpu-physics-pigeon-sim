from pathlib import Path
import subprocess,hashlib,json,shutil
root=Path('/Users/home/Documents/Codex/2026-11-07/c/crow-48s-landing-checkpoint-20261114'); out=root/'latest-first-episode-five-angles';old=root/'neural-direct-toe-residual-video/crow-direct-toe-residual-five-angles.mp4';hold=root/'neural-arrival-phase-history-video/hold';views=('front','back','above','below','feet')
failure=out/'latest-failure-labels.png';held=out/'earlier-hold-labels.png'
shutil.copy2(root/'latest-resetfixed-five-angles/earlier-hold-labels.png',held)
subprocess.run(['ffmpeg','-v','error','-y','-i',str(root/'latest-resetfixed-five-angles/latest-failure-labels.png'),'-vf',"drawbox=x=1298:y=555:w=600:h=29:color=0x10161d@1:t=fill",'-frames:v','1','-update','1',str(failure)],check=True)
cmd=['ffmpeg','-v','error','-y','-i',str(old)]
for directory in (out,hold):
 for view in views:cmd+=['-i',str(directory/(view+'.mp4'))]
cmd+=['-loop','1','-framerate','50','-i',str(failure),'-loop','1','-framerate','50','-i',str(held)]
graph=('[1:v][2:v][3:v][4:v][5:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g1];[g1][11:v]overlay=shortest=1,setpts=PTS-STARTPTS[a];[6:v][7:v][8:v][9:v][10:v]xstack=inputs=5:layout=0_0|640_0|0_480|640_480|1280_0:fill=0x10161d:shortest=1[g2];[g2][12:v]overlay=shortest=1,setpts=PTS-STARTPTS[b];[0:v]trim=duration=48,setpts=PTS-STARTPTS[o];[o][a][b]concat=n=3:v=1:a=0,format=yuv420p[v]')
path=out/'crow-first-episode-fall-and-earlier-hold-five-angles.mp4';cmd+=['-filter_complex',graph,'-map','[v]','-an','-c:v','libx264','-preset','veryfast','-crf','21','-movflags','+faststart',str(path)];subprocess.run(cmd,check=True)
print(json.dumps({'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()},indent=2))
