"""Check the actual new source images used by HeroSprite, not legacy atlases."""
from pathlib import Path
from PIL import Image
import json,math
root=Path(__file__).resolve().parents[1]/'assets/avatar'
frames=0
for path in root.glob('*.png'):
 im=Image.open(path)
 cols=12 if path.name.startswith('downed') else 24
 rows=1 if cols==12 else 16
 cell_x,cell_y=(36,40) if path.name.startswith('arm_') else (64,64)
 assert im.size==(cols*cell_x,rows*cell_y),(path.name,im.size)
 for row in range(rows):
  for f in range(cols):
   box=im.crop((f*cell_x,row*cell_y,(f+1)*cell_x,(row+1)*cell_y)).getbbox()
   if not box:
    assert 'hair_short' in path.name and path.name.endswith('_rear.png'),(path.name,row,f,'unexpected blank')
   else:assert box[0]>0 and box[1]>0 and box[2]<cell_x and box[3]<cell_y,(path.name,row,f,'clipping',box)
   frames+=1
print('AVATAR_FRAMES_WITHIN_CELLS',frames)
for build in ['slim','normal','sturdy']:
 male=Image.open(root/f'armor_male_{build}_body.png').crop((0,0,64,64)).getchannel('A')
 female=Image.open(root/f'armor_female_{build}_body.png').crop((0,0,64,64)).getchannel('A')
 def bounds(im,y):return im.crop((0,y,64,y+1)).getbbox()
 def width(im,y):
  b=bounds(im,y);return b[2]-b[0]
 assert width(male,27)>width(female,27),(build,'shoulders')
 assert width(female,39)>width(male,39),(build,'hips')
 assert bounds(female,32)[2]>bounds(female,35)[2],(build,'clothed chest to waist contour')
 assert width(female,39)>width(female,35),(build,'waist to hip contour')
 print('FITTED_SILHOUETTES',build,'shoulders',width(male,27),width(female,27),'hips',width(male,39),width(female,39))
rig=json.loads((root/'rig.json').read_text())
# During stance, world movement cancels local foot movement. No doubled run cycle.
first=rig['poses'][1][0]['rf'][0];last=rig['poses'][1][8]['rf'][0]
assert abs((last-first)+(8/24)*(20/.42))<1e-5
print('RUN_SUPPORT_MATCHES_WORLD_TRAVEL')
# Downed breathing must change the actual connected clothed body, for all six fits.
for gender in ['male','female']:
 for build in ['slim','normal','sturdy']:
  im=Image.open(root/f'downed_{gender}_{build}_1_coat.png')
  assert im.crop((0,0,64,64)).tobytes()!=im.crop((3*64,0,4*64,64)).tobytes()
print('SIX_DOWNED_BREATHING_VARIANTS_OK')
# Skin/color layers share geometry: check all actions for every actual body fit.
from collections import deque
connected=0
for gender in ['male','female']:
 for build in ['slim','normal','sturdy']:
  base=Image.open(root/f'body_{gender}_{build}_1_coat.png').convert('RGBA')
  arms=Image.open(root/f'arm_{gender}_{build}_1_coat.png').convert('RGBA')
  for r in range(16):
   for f in range(24):base.alpha_composite(arms.crop((f*36,r*40,(f+1)*36,(r+1)*40)),(f*64+16,r*64+16))
  im=base.getchannel('A')
  for row in range(16):
   for f in range(24):
    frame=im.crop((f*64,row*64,(f+1)*64,(row+1)*64))
    points={(i%64,i//64)for i,v in enumerate(frame.getdata())if v}
    seen={next(iter(points))};todo=deque(seen)
    while todo:
     x,y=todo.popleft()
     for dx,dy in [(1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)]:
      p=(x+dx,y+dy)
      if p in points and p not in seen:seen.add(p);todo.append(p)
    assert seen==points,(gender,build,row,f,'detached pixels',len(points)-len(seen))
    connected+=1
print('SIX_BODY_FITS_CONNECTED_FRAMES',connected)
