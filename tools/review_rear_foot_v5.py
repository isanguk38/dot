"""Refine the visible shoe silhouette only, preserving the v4 leg and body."""
from pathlib import Path
import runpy,json
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1]
g=runpy.run_path(str(ROOT/'tools/review_rear_leg_v4.py'))
OUT=ROOT/'review/run_pose'
before=g['after'];after=before.copy();d=ImageDraw.Draw(after)
black=g['outline'];white=g['white'];gray=g['gray'];sole=g['sole']
# Give the shoe its own toe box, instep, heel and sole rather than a pale calf tip.
d.polygon([(18,41),(19,42),(19,44),(17,46),(15,45),(10,42),(8,40),(8,38),(10,36),(12,36),(14,38)],fill=black)
d.polygon([(10,37),(12,37),(14,39),(17,40),(18,42),(17,44),(15,43),(11,41),(9,39)],fill=white)
# The upper has visible volume; sole remains a distinct one-pixel stepped strip.
d.line([(9,40),(11,42),(13,43),(15,44),(17,45)],fill=sole,width=1)
d.line([(10,40),(12,41),(14,42),(16,43),(17,43)],fill=gray,width=1)
# Recessed cuff marks where dark trousers enter the back of the shoe.
d.line([(17,40),(18,41),(18,42)],fill=black,width=1)
changes=[(x,y) for y in range(64) for x in range(64) if before.getpixel((x,y))!=after.getpixel((x,y))]
assert all(8<=x<=19 and 36<=y<=46 for x,y in changes)
assert all(not g['foreground'].getpixel((x,y))[3] for x,y in changes)
assert all(p in g['palette'] for p in after.getdata() if p[3])
after.save(OUT/'run_stride_v5.png')

font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',17)
board=Image.new('RGB',(1120,650),(25,29,40));bd=ImageDraw.Draw(board)
for col,(title,im) in enumerate([('BEFORE / SHOE TOO THIN',before),('AFTER / VISIBLE TOE, INSTEP AND HEEL',after)]):
 x=28+556*col
 bd.text((x,20),title,font=font,fill=(225,235,245))
 bg=Image.new('RGBA',(64,64),(39,44,57,255));bg.alpha_composite(im)
 board.paste(bg.resize((512,512),Image.Resampling.NEAREST),(x,56))
bd.text((28,604),'Rear shoe only. Remaining pixels are identical to the previous pose.',font=font,fill=(120,221,205))
board.save(OUT/'comparison_v5.png')
detail=Image.new('RGBA',(24,24),(39,44,57,255));detail.alpha_composite(after.crop((4,32,28,56)))
detail.resize((384,384),Image.Resampling.NEAREST).save(OUT/'rear_foot_detail_v5.png')
(OUT/'audit_v5.json').write_text(json.dumps({'changed_pixels':len(changes),'edit_bounds':[8,36,20,47],
 'body_front_foot_wraps_unchanged':True,'original_palette_only':True,'size':[64,64],
 'runtime_modified':False},indent=2))
