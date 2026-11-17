"""Prepare reaction sprites, human opponent and dojo background from generated sources."""
from pathlib import Path
from statistics import median
from collections import deque
import json,shutil
from PIL import Image,ImageDraw,ImageFont
from build_approved_assets import ROOT,SRC,REVIEW,visor,components,gif
FILES={
 'guard':('exec-31e049cc-e709-4a57-ab1a-6f915f25a5e7.png',4),
 'hurt':('exec-9ddaf61e-e050-43ce-b69c-69bd6d0b1331.png',6),
 'death':('exec-e3dac360-7afb-4cf0-b335-ee37831546fc.png',6),
 'knockdown':('exec-be93da02-3697-46d1-9d8c-575074913c8e.png',8),
 'enemy_idle':('exec-051ac5c5-cfd8-4919-ba4e-09784ad9f21c.png',4),
 'enemy_attack':('exec-21f7a3bf-039f-4809-963a-57057cc6cac9.png',8),
 'enemy_hurt':('exec-ee74639d-72d8-425c-bc8e-f01bf42107b4.png',8),
 'enemy_knockdown':('exec-6e8cc5bf-fded-4353-a3d2-57fd9eb2ac48.png',8),
 'enemy_death':('exec-cc3ab178-92d2-4a70-98a9-4f78c544f2d2.png',6),
}
OUT=ROOT/'review/combat_expansion';OUT.mkdir(parents=True,exist_ok=True)
(OUT/'source').mkdir(exist_ok=True)
def read(file,n):
 im=Image.open(SRC/file).convert('RGBA');frames=[]
 if file in ('exec-6e8cc5bf-fded-4353-a3d2-57fd9eb2ac48.png','exec-cc3ab178-92d2-4a70-98a9-4f78c544f2d2.png'):
  p=im.load()
  groups=components((x,y) for y in range(im.height) for x in range(im.width)
   if not(p[x,y][1]>30 and p[x,y][1]>p[x,y][0]*1.2 and p[x,y][1]>p[x,y][2]*1.2))
  groups=[g for g in groups if len(g)>1000]
  groups.sort(key=lambda g:sum(x for x,y in g)/len(g))
  assert len(groups)==n,(file,len(groups))
  for group in groups:
   left=min(x for x,y in group);right=max(x for x,y in group)+1
   c=Image.new('RGBA',(right-left+8,im.height));cp=c.load()
   for x,y in group:cp[x-left+4,y]=(*p[x,y][:3],255)
   frames.append(c)
  return frames
 for i in range(n):
  c=im.crop((round(i*im.width/n)+4,4,round((i+1)*im.width/n)-4,im.height-4))
  p=c.load()
  for y in range(c.height):
   for x in range(c.width):
    r,g,b,a=p[x,y]
    p[x,y]=(0,0,0,0) if g>30 and g>r*1.2 and g>b*1.2 else (r,g,b,255)
  frames.append(c)
 return frames
def face(c):
 p=c.load()
 groups=components((x,y) for y in range(c.height) for x in range(c.width)
  if p[x,y][3] and p[x,y][0]>120 and p[x,y][0]>p[x,y][1]*1.12 and p[x,y][1]>p[x,y][2]*1.12)
 g=groups[0];return (min(x for x,y in g),min(y for x,y in g),max(x for x,y in g)+1,max(y for x,y in g)+1)
data={};hero_target=json.loads((REVIEW/'packing.json').read_text())['idle']['visor_major_axis']
for name,(file,n) in FILES.items():
 shutil.copy2(SRC/file,OUT/'source'/f'{name}.png')
 cells=read(file,n);v=[face(c) if name.startswith('enemy_') else visor(c) for c in cells]
 diameter=median(max(b[2]-b[0],b[3]-b[1]) for b in v)
 data[name]=(cells,v,diameter)
idle_cells,idle_faces,idle_diameter=data['enemy_idle']
enemy_target=idle_diameter*53/max(c.getbbox()[3]-c.getbbox()[1] for c in idle_cells)
# One enemy face scale for every reaction, including horizontal falls.
enemy_ratio=max(max(max(c.getbbox()[2]-c.getbbox()[0],c.getbbox()[3]-c.getbbox()[1]) for c in cells)/diameter
 for name,(cells,v,diameter) in data.items() if name.startswith('enemy_'))
enemy_target=min(enemy_target,60/enemy_ratio)
audit={};packed={}
for name,(cells,vs,diameter) in data.items():
 enemy=name.startswith('enemy_');target=enemy_target if enemy else hero_target
 scale=target/diameter;baseline=max(c.getbbox()[3] for c in cells)
 frames=[]
 for i,(c,v) in enumerate(zip(cells,vs)):
  b=c.getbbox();crop=c.crop(b);w=round(crop.width*scale);h=round(crop.height*scale)
  assert max(w,h)<=64,(name,w,h)
  f=Image.new('RGBA',(64,64));s=crop.resize((w,h),Image.Resampling.NEAREST)
  x=round((64-w)/2) if 'death' in name or 'knockdown' in name else round(36-((v[0]+v[2])/2-b[0])*scale)
  y=round(63-(baseline-b[1])*scale)
  x=max(0,min(64-w,x));y=max(0,min(64-h,y));f.alpha_composite(s,(x,y));frames.append(f)
 folder=ROOT/'assets'/('enemy' if enemy else 'ninja');folder.mkdir(exist_ok=True)
 atlas=Image.new('RGBA',(64*len(frames),64))
 for i,f in enumerate(frames):atlas.alpha_composite(f,(64*i,0))
 atlas.save(folder/f'{name.removeprefix("enemy_")}.png');gif(frames,OUT/f'{name}.gif',90)
 packed[name]=frames;audit[name]={'frames':len(frames),'cell':[64,64],'scale':scale}
font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',16)
board=Image.new('RGB',(1180,len(packed)*140),(27,30,44));draw=ImageDraw.Draw(board)
for row,(name,frames) in enumerate(packed.items()):
 draw.text((6,row*140+52),name,font=font,fill=(215,230,240))
 for i,f in enumerate(frames):
  bg=Image.new('RGBA',(64,64),(39,44,57,255));bg.alpha_composite(f)
  board.paste(bg.resize((128,128),Image.Resampling.NEAREST),(150+i*128,row*140))
board.save(OUT/'reactions_board.png');(OUT/'packing.json').write_text(json.dumps(audit,indent=2))
bgfile='exec-722c1406-506e-4fcf-99b6-0ecf1eb56485.png'
shutil.copy2(SRC/bgfile,OUT/'source/dojo_background.png')
(ROOT/'assets/background').mkdir(exist_ok=True)
Image.open(SRC/bgfile).convert('RGB').resize((480,270),Image.Resampling.NEAREST).save(ROOT/'assets/background/dojo_night.png')
(ROOT/'assets/fx').mkdir(exist_ok=True)
shutil.copy2(REVIEW/'effects/uppercut_sheet.png',ROOT/'assets/fx/uppercut.png')
print('Prepared reaction sets, human sparring opponent, dojo background and uppercut FX.')
