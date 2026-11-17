"""Pack generated animation artwork into consistent 64px atlases and review media."""
from pathlib import Path
from collections import deque
from statistics import median
import json, shutil
from PIL import Image, ImageDraw, ImageFont, ImageFilter
ROOT=Path(__file__).resolve().parents[1]
SRC=Path(r'C:\Users\LSU\.codex\generated_images\01a1e21d-be39-7bf1-a266-d7f2382f2a08')
OUT=ROOT/'assets/ninja'; REVIEW=ROOT/'review/approved'
FILES={
 'run':('exec-faa5efa1-6b2f-4e7f-8fe3-bb1ad27fd42c.png',8),
 'idle':('exec-a5168976-bc0b-4b46-9726-545b23f569e3.png',4),
 'jump':('exec-344a4295-dc81-4b03-93b2-f5a1771fb475.png',8),
 'double_jump':('exec-3a5f8adc-4a19-4782-aa8a-53c4e1685f39.png',8),
 'punch':('exec-09c920a0-a788-4876-8e76-833e46be54a4.png',8),
 'jab':('exec-bd6bfa16-57e5-43f9-9193-8ccc1b09bbea.png',8),
 'kick':('exec-26593dc5-ba87-4945-9535-6bb6b867a264.png',8),
 'uppercut':('exec-1be8f5e1-b879-455f-896e-a1ed7672fd47.png',8),
 'backstep':('exec-15bc0ef8-f6f0-4aad-81bb-cc826a7535f3.png',8),
 'air_combo':('exec-d6e1279d-e6cc-4725-99f8-a5c1781a71d8.png',8),
}
FX={'hit':('exec-8246bddf-0042-48c4-acc2-1610fc715335.png',6),
 'uppercut':('exec-d67326a5-1eff-4597-a75d-05ffd94eb1f8.png',8)}

def components(points):
 points=set(points);result=[]
 while points:
  first=points.pop();q=deque([first]);c=[first]
  while q:
   x,y=q.popleft()
   for n in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
    if n in points:points.remove(n);q.append(n);c.append(n)
  result.append(c)
 return sorted(result,key=len,reverse=True)

def clean(im):
 p=im.load();w,h=im.size
 r,g,b,a=p[0,0]
 if g>150 and g>r*1.5 and g>b*1.5:
  out=im.copy();op=out.load()
  for y in range(h):
   for x in range(w):
    r,g,b,a=p[x,y]
    op[x,y]=(0,0,0,0) if g>30 and g>r*1.2 and g>b*1.2 else (r,g,b,255)
  return out
 # Extract the connected dark/colored silhouette, close tiny outline gaps, then
 # retain enclosed original colors. This preserves white sneaker interiors even
 # when the generator supplied a white sheet instead of clean alpha.
 points={(x,y) for y in range(h) for x in range(w)
  if p[x,y][3]>=210 and not(max(p[x,y][:3])-min(p[x,y][:3])<35 and min(p[x,y][:3])>100)}
 groups=components(points)
 cyan=components((x,y) for x,y in points if p[x,y][1]>100 and p[x,y][2]>100 and p[x,y][0]<p[x,y][1]*.7)
 seed=cyan[0][0]
 main=next(c for c in groups if seed in c)
 group=list(main)
 gx0=min(x for x,y in group);gx1=max(x for x,y in group)
 gy0=min(y for x,y in group);gy1=max(y for x,y in group)
 # Some generated alpha mattes disconnected white shoes from the trouser cuff.
 # Include nearby lower-body outline islands before closing/filling their interiors.
 for extra in groups:
  if extra is main or len(extra)<12 or len(extra)>len(main)*.08:continue
  ex=sum(x for x,y in extra)/len(extra);ey=sum(y for x,y in extra)/len(extra)
  if gx0-15<=ex<=gx1+15 and gy0+(gy1-gy0)*.55<=ey<=gy1+55:
   group.extend(extra)
 mask=Image.new('L',(w,h));mp=mask.load()
 for x,y in group:mp[x,y]=255
 mask=mask.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
 flood=Image.new('L',(w+2,h+2));flood.paste(mask,(1,1))
 ImageDraw.floodfill(flood,(0,0),128,thresh=0)
 out=Image.new('RGBA',im.size);dst=out.load();fp=flood.load()
 for y in range(h):
  for x in range(w):
   restore_white_shoe=min(p[x,y][:3])>130 and y>gy0+(gy1-gy0)*.6
   if fp[x+1,y+1]!=128 and (p[x,y][3]>=210 or restore_white_shoe):
    dst[x,y]=(*p[x,y][:3],255)
 return out

def visor(im):
 p=im.load()
 groups=components((x,y) for y in range(im.height) for x in range(im.width)
  if p[x,y][3] and p[x,y][1]>100 and p[x,y][2]>100 and p[x,y][0]<p[x,y][1]*.7)
 g=groups[0];return (min(x for x,y in g),min(y for x,y in g),max(x for x,y in g)+1,max(y for x,y in g)+1)

def read_cells(path,n,cleanup=True):
 im=Image.open(path).convert('RGBA')
 if cleanup and path.name=='exec-26593dc5-ba87-4945-9535-6bb6b867a264.png':
  # Crop the generated header/footer haze, outside every character's artwork.
  im=im.crop((0,235,im.width,510))
 return [(clean(c) if cleanup else c) for c in [im.crop((round(i*im.width/n),0,round((i+1)*im.width/n),im.height)) for i in range(n)]]

def gif(frames,path,ms=75):
 rgb=[]
 for f in frames:
  bg=Image.new('RGBA',f.size,(27,30,44,255));bg.alpha_composite(f)
  rgb.append(bg.resize((f.width*4,f.height*4),Image.Resampling.NEAREST).convert('RGB'))
 rgb[0].save(path,save_all=True,append_images=rgb[1:],duration=ms,loop=0)

def main():
 OUT.mkdir(parents=True,exist_ok=True);REVIEW.mkdir(parents=True,exist_ok=True)
 sources=REVIEW/'source';sources.mkdir(exist_ok=True)
 data={};ratios=[]
 for name,(file,n) in FILES.items():
  shutil.copy2(SRC/file,sources/f'{name}.png')
  cells=read_cells(SRC/file,n);vs=[visor(c) for c in cells]
  diameter=median(max(v[2]-v[0],v[3]-v[1]) for v in vs)
  data[name]=(cells,vs,diameter)
  ratios.append(max(max(c.getbbox()[2]-c.getbbox()[0],c.getbbox()[3]-c.getbbox()[1]) for c in cells)/diameter)
 assert max(ratios)<8, 'Background contamination would shrink all character frames'
 target=min(13,60/max(ratios));packed={};audit={}
 for name,(cells,vs,diameter) in data.items():
  scale=target/diameter;frames=[]
  global_baseline=max(c.getbbox()[3] for c in cells)
  for c,v in zip(cells,vs):
   b=c.getbbox();crop=c.crop(b);w=round(crop.width*scale);h=round(crop.height*scale)
   s=crop.resize((w,h),Image.Resampling.NEAREST)
   vx=((v[0]+v[2])/2-b[0])*scale;vy=((v[1]+v[3])/2-b[1])*scale
   if name=='double_jump':x=round((64-w)/2);y=round((64-h)/2)
   elif name in ('jump','air_combo'):
    x=round(36-vx);y=round(20-vy)
   else:x=round(36-vx);y=round(63-(global_baseline-b[1])*scale)
   x=max(1,min(63-w,x));y=max(0,min(64-h,y))
   f=Image.new('RGBA',(64,64));f.alpha_composite(s,(x,y));frames.append(f)
  atlas=Image.new('RGBA',(64*len(frames),64))
  for i,f in enumerate(frames):atlas.alpha_composite(f,(64*i,0))
  atlas.save(OUT/f'{name}.png');packed[name]=frames
  gif(frames,REVIEW/f'{name}.gif',80 if name=='idle' else 65)
  audit[name]={'frames':len(frames),'cell':[64,64],'visor_major_axis':round(target,2),'fixed_strip_scale':round(scale,5)}
 (REVIEW/'packing.json').write_text(json.dumps(audit,indent=2))
 font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',17)
 board=Image.new('RGB',(1170,len(packed)*140),(27,30,44));d=ImageDraw.Draw(board)
 for row,(name,frames) in enumerate(packed.items()):
  d.text((8,row*140+50),name,font=font,fill=(215,230,240))
  for i,f in enumerate(frames):
   tile=Image.new('RGBA',(64,64),(39,44,57,255));tile.alpha_composite(f)
   board.paste(tile.resize((128,128),Image.Resampling.NEAREST),(140+128*i,row*140))
 board.save(REVIEW/'all_actions.png')
 # Effects remain strictly review-only until user approval.
 fx_dir=REVIEW/'effects';fx_dir.mkdir(exist_ok=True)
 for name,(file,n) in FX.items():
  shutil.copy2(SRC/file,sources/f'fx_{name}.png')
  cells=read_cells(SRC/file,n,False)
  for c in cells:c.putalpha(c.getchannel('A').point(lambda a:255 if a>=180 else 0))
  bounds=[c.getbbox() for c in cells];valid=[b for b in bounds if b]
  global_top=min(b[1] for b in valid);global_bottom=max(b[3] for b in valid)
  maxw=max(b[2]-b[0] for b in valid)
  scale=min((30 if name=='hit' else 48)/(global_bottom-global_top),48/maxw)
  fxframes=[]
  for c,b in zip(cells,bounds):
   f=Image.new('RGBA',(64,64))
   if b:
    crop=c.crop(b);w=max(1,round(crop.width*scale));h=max(1,round(crop.height*scale))
    s=crop.resize((w,h),Image.Resampling.NEAREST)
    y=round(32-(global_bottom-global_top)*scale/2+(b[1]-global_top)*scale) if name=='hit' else round(58-(global_bottom-b[1])*scale)
    f.alpha_composite(s,(round((64-w)/2),y))
   fxframes.append(f)
  atlas=Image.new('RGBA',(64*n,64))
  for i,f in enumerate(fxframes):atlas.alpha_composite(f,(i*64,0))
  atlas.save(fx_dir/f'{name}_sheet.png');gif(fxframes,fx_dir/f'{name}_effect.gif',55)
  # Offline compositing only; this media is not loaded by the game.
  preview=[];anim=packed['punch' if name=='hit' else 'uppercut']
  for tick in range(18):
   bg=Image.new('RGBA',(160,112),(27,30,44,255));draw=ImageDraw.Draw(bg)
   draw.line((0,95,160,95),fill=(78,167,180),width=1)
   fi=min(7,tick//2);bg.alpha_composite(anim[fi],(35,32))
   e=tick-5
   if 0<=e<len(fxframes):bg.alpha_composite(fxframes[e],(56 if name=='hit' else 69,35 if name=='hit' else 21))
   preview.append(bg)
  gif(preview,fx_dir/f'{name}_on_character.gif',65)
  preview[7 if name=='hit' else 8].resize((640,448),Image.Resampling.NEAREST).save(fx_dir/f'{name}_example.png')
 print('Packed ten actions and two review-only effects. Target visor:',round(target,2))

if __name__=='__main__':main()
