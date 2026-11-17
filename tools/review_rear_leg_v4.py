"""Local pixel correction of the rear recovery leg. No runtime changes."""
from pathlib import Path
import runpy,json,math
from PIL import Image,ImageDraw,ImageFont,ImageChops

ROOT=Path(__file__).resolve().parents[1]
g=runpy.run_path(str(ROOT/'tools/review_run_pose.py'))
OUT=ROOT/'review/run_pose'
before=Image.open(OUT/'run_stride_v3.png').convert('RGBA')
rigid=g['rigid']
original_palette={p for p in g['source'].getdata() if p[3]}
def existing(rgb):
 return min(original_palette,key=lambda p:sum((p[i]-rgb[i])**2 for i in range(3)))
outline=existing((3,2,4));dark=existing((18,21,47));mid=existing((37,44,84))
white=existing((241,243,246));gray=existing((168,174,186));sole=existing((95,118,141))

# Keep the accepted thigh untouched. Rebuild only the calf and pointed shoe.
# Knee (23,47) -> ankle (17,43) -> toe (11,39): one continuous up-back line.
rear=Image.new('RGBA',(64,64));d=ImageDraw.Draw(rear)
d.polygon([(25,46),(24,50),(21,49),(15,45),(15,42),(18,40),(21,42)],fill=outline)
d.polygon([(23,46),(23,48),(21,47),(17,44),(17,42),(19,42)],fill=dark)
d.line([(18,42),(21,44),(23,46)],fill=mid,width=2)
# A tapered shoe, heel at the trouser cuff and toe pointing along the calf.
d.polygon([(18,42),(18,44),(16,45),(10,41),(10,39),(11,38),(13,39)],fill=outline)
d.polygon([(17,42),(16,44),(11,40),(11,39),(12,39)],fill=gray)
d.line([(11,39),(16,42)],fill=white,width=1)
d.line([(12,41),(16,44)],fill=sole,width=1)

assembled=Image.new('RGBA',(64,64))
assembled.alpha_composite(rear)
assembled.alpha_composite(rigid(g['rear_thigh'],6,(32,39)))
# All foreground parts are exactly the same raster transforms as the approved body.
foreground=Image.new('RGBA',(64,64))
for im,angle,pivot,shift in [
 (g['front_thigh'],-10,(36,39),(0,0)),
 (g['front_shin'],-40,(47,48),(1,-2)),
 (g['front_boot'],0,(0,0),(8,-3)),
 (g['upper'],19,(34,39),(0,0)),
 (g['head'],0,(0,0),(9,3)),
]:foreground.alpha_composite(rigid(im,angle,pivot,shift))
assembled.alpha_composite(foreground)

# Explicitly restrict editing to the rear leg bounding region.
after=before.copy()
for y in range(33,55):
 for x in range(5,29):after.putpixel((x,y),assembled.getpixel((x,y)))
changes=[(x,y) for y in range(64) for x in range(64) if before.getpixel((x,y))!=after.getpixel((x,y))]
assert all(5<=x<29 and 33<=y<55 for x,y in changes)
assert all(not foreground.getpixel((x,y))[3] for x,y in changes),'Protected foreground changed'
palette={p for p in g['source'].getdata() if p[3]}
assert all(p in palette for p in after.getdata() if p[3])
assert after.size==(64,64)
after.save(OUT/'run_stride_v4.png')

font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',17)
small=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',14)
board=Image.new('RGB',(1120,670),(25,29,40));bd=ImageDraw.Draw(board)
for i,(label,im) in enumerate([('BEFORE / BROKEN ANKLE LINE',before),('AFTER / POINTED RECOVERY FOOT',after)]):
 x=28+i*556
 bd.text((x,20),label,font=font,fill=(225,235,245))
 tile=Image.new('RGBA',(64,64),(39,44,57,255));tile.alpha_composite(im)
 board.paste(tile.resize((512,512),Image.Resampling.NEAREST),(x,56))
 bd.text((x,584),'64 x 64 / 8x nearest-neighbor',font=small,fill=(165,180,195))
bd.text((28,620),'Only rear leg pixels changed. Body, wraps and front foot: identical.',font=font,fill=(120,221,205))
board.save(OUT/'comparison_v4.png')

crop=Image.new('RGBA',(24,24),(39,44,57,255));crop.alpha_composite(after.crop((5,32,29,56)))
crop.resize((384,384),Image.Resampling.NEAREST).save(OUT/'rear_leg_detail_v4.png')
audit={'changed_pixel_count':len(changes),'changed_bbox':ImageChops.difference(before,after).getbbox(),
 'size':[64,64],'body_front_foot_wraps_unchanged':True,'original_palette_only':True,
 'pose':'recovery (last user instruction), not push-off',
 'knee':[23,47],'ankle':[17,43],'toe':[11,39],
 'toe_direction':'up and backward, collinear with calf','runtime_modified':False}
(OUT/'audit_v4.json').write_text(json.dumps(audit,indent=2))
print(json.dumps(audit,indent=2))
