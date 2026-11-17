"""Pack generated art into pixel-aligned 64px game cells; no drawn poses are synthesized."""
from pathlib import Path
from statistics import median
from collections import deque
import json, shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r'C:\Users\LSU\.codex\generated_images\01a1e21d-be39-7bf1-a266-d7f2382f2a08')
OUT = ROOT / 'assets/player_hd'
FILES = {
 'run': 'exec-1b293872-9eac-4222-80ca-aa90c7e73a89.png',
 'idle': 'exec-5e3f0473-4615-4b8a-8549-4fc0726cbee7.png',
 'jump': 'exec-3e0553e8-0194-450c-8490-bb30e0e3c22b.png',
 'double_jump': 'exec-ed19b836-81f4-4f10-ab3c-ad2c24a88e84.png',
 'punch': 'exec-fd41d3b1-bd2c-42a7-acb9-472edb23a8b5.png',
 'jab': 'exec-fdcc0367-1038-4962-aa89-e6afd981caab.png',
 'kick': 'exec-842ecc51-56b2-4c23-98e4-9a8c16319615.png',
 'uppercut': 'exec-681a6c61-4b22-4604-ae1f-9c2398409224.png',
 'backstep': 'exec-920adbff-655a-43bd-9414-56a345107c09.png',
 'air_combo': 'exec-08dd759c-b7df-4f89-8f01-829d7d5825eb.png',
}

def clean(cell):
    # Remove semitransparent generation haze and isolated sheet marks.
    pixels = cell.load()
    w,h=cell.size
    mask={(x,y) for y in range(h) for x in range(w) if pixels[x,y][3]>=210}
    groups=[]
    while mask:
        seed=mask.pop(); q=deque([seed]); group=[seed]
        while q:
            x,y=q.popleft()
            for n in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if n in mask:
                    mask.remove(n); q.append(n); group.append(n)
        groups.append(group)
    groups.sort(key=len, reverse=True)
    result=Image.new('RGBA',cell.size)
    dst=result.load()
    # Character is the dominant connected component; disconnected boots/scarf kept nearby.
    biggest=len(groups[0])
    for group in groups:
        if len(group) < biggest*.008:
            continue
        for x,y in group:
            r,g,b,a=pixels[x,y]; dst[x,y]=(r,g,b,255)
    return result

def visor_bbox(cell):
    p=cell.load()
    points=[(x,y) for y in range(cell.height) for x in range(cell.width)
            if p[x,y][3] and p[x,y][1]>100 and p[x,y][2]>110
            and p[x,y][0] < p[x,y][1]*.65 and p[x,y][0]<p[x,y][2]*.65]
    return (min(x for x,y in points),min(y for x,y in points),max(x for x,y in points)+1,max(y for x,y in points)+1)

def main():
    OUT.mkdir(exist_ok=True)
    (OUT/'source').mkdir(exist_ok=True)
    (OUT/'source/.gdignore').write_text('')
    report={}; previews=[]
    for name,filename in FILES.items():
        shutil.copy2(SOURCE/filename,OUT/'source'/f'{name}.png')
        source=Image.open(SOURCE/filename).convert('RGBA')
        cells=[clean(source.crop((round(i*source.width/8),0,round((i+1)*source.width/8),source.height))) for i in range(8)]
        visors=[visor_bbox(c) for c in cells]
        # Fixed scale per strip from visor size, preserving pose proportions.
        diameter=median(max(v[2]-v[0],v[3]-v[1]) for v in visors)
        scale=9.0/diameter
        # Leave room for the longest kick or widest sprint without changing frame scales.
        max_span=max((c.getbbox()[2]-c.getbbox()[0])*scale for c in cells)
        if max_span>60: scale*=60/max_span
        sheet=Image.new('RGBA',(512,64)); packed=[]
        for i,(cell,v) in enumerate(zip(cells,visors)):
            bbox=cell.getbbox(); crop=cell.crop(bbox)
            nw,nh=round(crop.width*scale),round(crop.height*scale)
            small=crop.resize((nw,nh),Image.Resampling.NEAREST)
            vx=((v[0]+v[2])/2-bbox[0])*scale
            vy=((v[1]+v[3])/2-bbox[1])*scale
            if name=='double_jump':
                x=round(32-nw/2); y=round(34-nh/2)
            elif name in ('jump','air_combo'):
                x=round(35-vx); y=round(23-vy)
            else:
                x=round((38 if name=='run' else 35)-vx)
                # Preserve per-frame hop/lift, using strip-wide baseline rather than each crop.
                baseline=max(c.getbbox()[3] for c in cells)
                y=round(63-(baseline-bbox[1])*scale)
            # Guarantee the entire drawing remains inside its atlas cell.
            x=max(1,min(63-nw,x)); y=max(0,min(64-nh,y))
            frame=Image.new('RGBA',(64,64));frame.alpha_composite(small,(x,y))
            sheet.alpha_composite(frame,(i*64,0));packed.append(frame)
        sheet.save(OUT/f'{name}.png')
        report[name]={'cell':[64,64],'frames':8,'visor_width':round(diameter*scale,2),'scale':round(scale,4)}
        previews.append((name,packed))
    (OUT/'packing.json').write_text(json.dumps(report,indent=2))
    board=Image.new('RGB',(512*2+140, len(previews)*144),(28,30,44));d=ImageDraw.Draw(board)
    for row,(name,frames) in enumerate(previews):
        d.text((8,row*144+54),name,fill=(220,230,240))
        for i,f in enumerate(frames):
            bg=Image.new('RGBA',(64,64),(43,47,64,255));bg.alpha_composite(f)
            board.paste(bg.resize((128,128),Image.Resampling.NEAREST),(140+i*128,row*144))
    board.save(ROOT/'assets/ninja_animation_review.png')
    gifs=[]
    for frame in dict(previews)['run']:
        bg=Image.new('RGBA',(64,64),(28,30,44,255));bg.alpha_composite(frame)
        gifs.append(bg.resize((256,256),Image.Resampling.NEAREST).convert('RGB'))
    gifs[0].save(ROOT/'assets/ninja_run_preview.gif',save_all=True,append_images=gifs[1:],duration=65,loop=0)
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
