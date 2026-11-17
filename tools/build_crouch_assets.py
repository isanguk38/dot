"""Pack crouch actions using the approved standing set's fixed head scale."""
from pathlib import Path
from statistics import median
import json,shutil
from PIL import Image
from build_approved_assets import SRC,ROOT,REVIEW,OUT,read_cells,visor,gif
FILES={
 'crouch_idle':('exec-7c858495-8909-450a-b895-e7c72d67e826.png',4),
 'crouch_walk':('exec-b626015e-deb4-4ece-920d-6fc711fbc2fa.png',8),
 'crouch_combo':('exec-4b69828f-4730-4187-b250-bdffdc5e3712.png',8),
}
audit=json.loads((REVIEW/'packing.json').read_text())
target=audit['idle']['visor_major_axis']
for name,(file,n) in FILES.items():
 shutil.copy2(SRC/file,REVIEW/'source'/f'{name}.png')
 cells=read_cells(SRC/file,n);vs=[visor(c) for c in cells]
 diameter=median(v[2]-v[0] for v in vs);scale=target/diameter
 baseline=max(c.getbbox()[3] for c in cells);frames=[]
 for c,v in zip(cells,vs):
  b=c.getbbox();crop=c.crop(b);w=round(crop.width*scale);h=round(crop.height*scale)
  assert max(w,h)<63
  s=crop.resize((w,h),Image.Resampling.NEAREST)
  x=round(36-((v[0]+v[2])/2-b[0])*scale)
  y=round(63-(baseline-b[1])*scale)
  f=Image.new('RGBA',(64,64));f.alpha_composite(s,(max(1,min(63-w,x)),y));frames.append(f)
 atlas=Image.new('RGBA',(64*n,64))
 for i,f in enumerate(frames):atlas.alpha_composite(f,(64*i,0))
 atlas.save(OUT/f'{name}.png');gif(frames,REVIEW/f'{name}.gif',100 if name=='crouch_idle' else 75)
 audit[name]={'frames':n,'cell':[64,64],'visor_major_axis':target,'fixed_strip_scale':round(scale,5)}
(REVIEW/'packing.json').write_text(json.dumps(audit,indent=2))
print('Packed crouch idle, walk, jab and low kick with existing visor scale',target)
