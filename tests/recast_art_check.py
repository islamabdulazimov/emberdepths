"""Offline checks of the actual authored atlases (Pillow, not a runtime dependency)."""
from pathlib import Path
from PIL import Image
import json,math,collections
root=Path(__file__).resolve().parents[1]/'assets/recast'
rig=json.loads((root/'andrew_rig.json').read_text());atlas=Image.open(root/'andrew.png');pairs=0
for row,phase in enumerate(rig['phases']):
 if phase=='death':continue # Deliberate dissolve creates holes after gameplay ends.
 for f,p in enumerate(rig['poses'][row]):
  im=atlas.crop((f*128,row*128,(f+1)*128,(row+1)*128));alpha=im.getchannel('A')
  def point(x,y):
   x+=p['dx'];y+=p['dy'];x+=64;y+=112
   x=(x-64)*p['turn']+64
   angle=-p['rotation']*math.pi/180;xx=x-64;yy=y-75
   return(round(64+xx*math.cos(angle)-yy*math.sin(angle)),round(75+xx*math.sin(angle)+yy*math.cos(angle)))
  def near(pos):
   for radius in range(4):
    for y in range(pos[1]-radius,pos[1]+radius+1):
     for x in range(pos[0]-radius,pos[0]+radius+1):
      if 0<=x<128 and 0<=y<128 and alpha.getpixel((x,y)):return x,y
   raise AssertionError((phase,f,'missing joint',pos))
  def connected(a,b):
   todo=collections.deque([a]);seen={a}
   while todo:
    x,y=todo.popleft()
    if (x,y)==b:return True
    for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
     if 0<=xx<128 and 0<=yy<128 and (xx,yy) not in seen and alpha.getpixel((xx,yy)):seen.add((xx,yy));todo.append((xx,yy))
   return False
  for side,e,h in [(-1,'le','lh'),(1,'re','rh')]:
   shoulder=near(point(side*18,-46));elbow=near(point(*p[e]));hand=near(point(*p[h]))
   assert connected(shoulder,elbow),(phase,f,side,'shoulder-elbow')
   assert connected(elbow,hand),(phase,f,side,'elbow-fist')
   pairs+=2
print('BOSS_ATLAS_CONNECTED_PAIRS',pairs)
frames=0
for path in root.glob('hero_*.png'):
 im=Image.open(path);assert im.size==(1536,1024)
 for row in range(16):
  for f in range(24):
   box=im.crop((f*64,row*64,(f+1)*64,(row+1)*64)).getbbox()
   assert box and box[0]>0 and box[1]>0 and box[2]<64 and box[3]<64,(path.name,row,f,'clipped silhouette',box)
   frames+=1
print('HERO_UNCLIPPED_FRAMES',frames)
icons=[p.read_bytes() for p in root.glob('item_*.png')];assert len(icons)==22 and len(set(icons))==22
print('DISTINCT_ITEM_ICONS',len(icons))
# An open door must actually be transparent through the passage.
im=Image.open(root/'door.png');assert im.getpixel((5*16+10,24))[3]==0
print('OPEN_DOOR_PASSAGE_TRANSPARENT_OK')
