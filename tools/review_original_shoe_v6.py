"""Use the actual original shoe, mirrored for the rear leg and tilted 15 degrees."""
from pathlib import Path
import runpy,json
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
g=runpy.run_path(str(ROOT/'tools/review_run_pose.py'))
OUT=ROOT/'review/run_pose';rigid=g['rigid']
before=Image.open(OUT/'run_stride_v2.png').convert('RGBA')
# This is the original FRONT shoe, not a new silhouette or painted replacement.
shoe=g['front_boot'].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
tilted=rigid(shoe,-15,(18,57),(-5,-11))
result=Image.new('RGBA',(64,64))
result.alpha_composite(rigid(g['rear_thigh'],6,(32,39)))
result.alpha_composite(rigid(g['rear_shin'],65,(24,48),(-1,-1)))
result.alpha_composite(tilted)
foreground=Image.new('RGBA',(64,64))
for im,angle,pivot,shift in [
 (g['front_thigh'],-10,(36,39),(0,0)),(g['front_shin'],-40,(47,48),(1,-2)),
 (g['front_boot'],0,(0,0),(8,-3)),(g['upper'],19,(34,39),(0,0)),
 (g['head'],0,(0,0),(9,3))]:
 foreground.alpha_composite(rigid(im,angle,pivot,shift))
result.alpha_composite(foreground)
# Limit the replacement to the shoe area; all other pixels stay exactly as in v2.
after=before.copy()
for y in range(40,56):
 for x in range(0,22):after.putpixel((x,y),result.getpixel((x,y)))
changed=[(x,y) for y in range(64) for x in range(64) if before.getpixel((x,y))!=after.getpixel((x,y))]
assert all(not foreground.getpixel((x,y))[3] for x,y in changed)
assert all(0<=x<22 and 40<=y<56 for x,y in changed)
after.save(OUT/'run_stride_v6.png')
font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',17)
board=Image.new('RGB',(1120,650),(25,29,40));d=ImageDraw.Draw(board)
for i,(title,im) in enumerate([('BEFORE / ORIGINAL HORIZONTAL FOOT',before),('AFTER / ORIGINAL SHOE, SLIGHT TILT',after)]):
 x=28+556*i;d.text((x,20),title,font=font,fill=(225,235,245))
 tile=Image.new('RGBA',(64,64),(39,44,57,255));tile.alpha_composite(im)
 board.paste(tile.resize((512,512),Image.Resampling.NEAREST),(x,56))
d.text((28,604),'Actual original shoe / mirrored / 15-degree downward toe tilt / no redraw',font=font,fill=(120,221,205))
board.save(OUT/'comparison_v6.png')
detail=Image.new('RGBA',(24,24),(39,44,57,255));detail.alpha_composite(after.crop((0,34,24,58)))
detail.resize((384,384),Image.Resampling.NEAREST).save(OUT/'rear_foot_detail_v6.png')
(OUT/'audit_v6.json').write_text(json.dumps({'source':'original front shoe pixels',
 'mirror':True,'rotation_degrees':-15,'scale':1,'redrawn':False,
 'body_front_foot_wraps_unchanged':True,'size':[64,64],'runtime_modified':False},indent=2))
