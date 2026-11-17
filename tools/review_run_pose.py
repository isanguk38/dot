"""One review pose assembled from original pixels, without image generation.

Only rigid part transforms (nearest sampling), no scaling or new character palette.
This script writes review artifacts only. It never replaces runtime sprites.
"""
from pathlib import Path
import math, json, hashlib
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'review/run_pose'
OUT.mkdir(parents=True,exist_ok=True)
source=Image.open(ROOT/'assets/player/run.png').convert('RGBA').crop((0,0,64,64))

def part(points):
    mask=Image.new('L',(64,64));ImageDraw.Draw(mask).polygon(points,fill=255)
    result=source.copy()
    # Keep source alpha, including its original transparent pixels.
    result.putalpha(Image.composite(source.getchannel('A'),Image.new('L',(64,64)),mask))
    return result

def rigid(image,degrees,pivot,shift=(0,0)):
    a=math.radians(degrees);c=math.cos(a);s=math.sin(a)
    px,py=pivot;dx,dy=shift
    # PIL inverse mapping; rotation changes orientation, never body-part scale.
    return image.transform((64,64),Image.Transform.AFFINE,
        (c,s,px-c*(px+dx)-s*(py+dy),-s,c,py+s*(px+dx)-c*(py+dy)),
        resample=Image.Resampling.NEAREST)

# Far/near leg contours are separated at the original crotch.
rear_thigh=part([(29,37),(35,38),(35,42),(30,47),(28,50),(21,50),(20,47),(24,40)])
rear_shin=part([(21,47),(29,48),(27,53),(23,57),(22,58),(16,58),(17,53)])
rear_boot=part([(16,57),(23,57),(23,63),(12,63),(12,59)])
front_thigh=part([(35,37),(40,37),(42,40),(48,44),(51,48),(48,50),(43,49),(39,48),(35,44),(33,42)])
front_shin=part([(44,48),(51,48),(51,54),(49,57),(44,58),(42,56),(44,54)])
front_boot=part([(41,57),(49,57),(49,58),(55,59),(55,63),(40,63),(40,59)])
upper=part([(0,0),(64,0),(64,37),(42,37),(40,40),(29,40),(28,37),(0,37)])
# The hood/face is copied unchanged, so the visor and head silhouette cannot drift.
head=part([(27,0),(49,0),(49,16),(45,16),(45,20),(40,20),(34,18),(30,17),(27,14)])
hp=head.load();up=upper.load()
for y in range(64):
    for x in range(64):
        r,g,b,a=hp[x,y]
        if r>g*1.8 and b>g*1.5 and r>30:
            hp[x,y]=(0,0,0,0)  # Scarf belongs to torso, never to the translated hood.
        if hp[x,y][3]:up[x,y]=(0,0,0,0)

result=Image.new('RGBA',(64,64))
# Reference-guided recovery leg: knee down/back, shin folded back, foot lifted.
# Separate joint rotations replace the old straight-leg rotation that read as a kick.
result.alpha_composite(rigid(rear_thigh,6,(32,39)))
result.alpha_composite(rigid(rear_shin,65,(24,48),(-1,-1)))
result.alpha_composite(rigid(rear_boot,-90,(21,57),(-10,-11)))
result.alpha_composite(rigid(front_thigh,-10,(36,39)))
result.alpha_composite(rigid(front_shin,-40,(47,48),(1,-2)))
result.alpha_composite(rigid(front_boot,0,(0,0),(8,-3)))
result.alpha_composite(rigid(upper,19,(34,39)))
result.alpha_composite(rigid(head,0,(0,0),(9,3)))
# Remove isolated one/two-pixel contour remnants at cut boundaries.
from collections import deque
remaining={(x,y) for y in range(64) for x in range(64) if result.getpixel((x,y))[3]}
while remaining:
    component=[remaining.pop()]; queue=deque(component)
    while queue:
        x,y=queue.popleft()
        for neighbor in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if neighbor in remaining:
                remaining.remove(neighbor);queue.append(neighbor);component.append(neighbor)
    if len(component)<=2:
        for point in component:result.putpixel(point,(0,0,0,0))
result.save(OUT/'run_stride_v3.png')
source.save(OUT/'original.png')

font_path=Path('C:/Windows/Fonts/consola.ttf')
font=ImageFont.truetype(str(font_path),18)
small=ImageFont.truetype(str(font_path),14)
board=Image.new('RGB',(1120,690),(25,29,40));d=ImageDraw.Draw(board)
previous=Image.open(OUT/'run_stride_v2.png').convert('RGBA')
for col,(title,sprite) in enumerate([('BEFORE / HORIZONTAL REAR FOOT',previous),('AFTER / REAR TOES POINT DOWN',result)]):
    x=28+col*556
    d.text((x,20),title,font=font,fill=(224,233,242))
    tile=Image.new('RGBA',(64,64),(39,44,57,255));tile.alpha_composite(sprite)
    board.paste(tile.resize((512,512),Image.Resampling.NEAREST),(x,56))
    for g in range(0,65,8):
        yy=56+g*8
        d.line((x,yy,x+512,yy),fill=(57,62,74),width=1)
        xx=x+g*8
        d.line((xx,56,xx,568),fill=(57,62,74),width=1)
    d.text((x,584),'64 x 64 | 8x nearest-neighbor preview',font=small,fill=(161,178,195))
d.text((28,622),'Original palette / original wrapped forearms / no limb scaling',font=font,fill=(120,221,205))
d.text((28,650),'Single pose for review. Runtime files are unchanged.',font=small,fill=(161,178,195))
board.save(OUT/'comparison_v3.png')

def colors(im):return {p for p in im.getdata() if p[3]}
assert colors(result)<=colors(source), 'New character colors were introduced'
audit={
 'source':'assets/player/run.png, cell 0',
 'output':'review/run_pose/run_stride_v3.png',
 'source_cell_size':[64,64], 'output_cell_size':[64,64],
 'part_scaling':False,'new_opaque_colors':len(colors(result)-colors(source)),
 'head_transform':'unchanged pixels, translated +9,+3',
 'body_rotation_degrees':19,'rear_thigh_rotation':6,'rear_shin_rotation':65,
 'rear_boot_translation':[-10,-11],'rear_boot_pivot':[21,57],'rear_boot_rotation':-90,
 'front_thigh_rotation':-10,'front_shin_rotation':-40,'front_boot_rotation':0,
 'runtime_modified':False,
 'review_note':'Rigid rotations preserve part scale; pixel diagonal edges still need visual approval.',
}
(OUT/'audit_v3.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
print(json.dumps(audit,indent=2))
