"""Original CC0 clothed adult avatars. Pixel anatomy, fitted armor, shared action rig.
Only the ordinary male/female sample is built with --normal; inspect it first.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import ast,json,math,sys
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/avatar';OUT.mkdir(exist_ok=True)
ns={'Image':Image,'ImageDraw':ImageDraw,'math':math,'INK':'#131c27'}
tree=ast.parse((ROOT/'tools/build_recast_art.py').read_text())
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,(ast.FunctionDef,ast.ClassDef)) and n.name in ['Ink','mix','foot','rgb','shade']],type_ignores=[]),'shared_pixel_helpers','exec'),ns)
Ink=ns['Ink'];mix=ns['mix'];foot=ns['foot'];shade=ns['shade']
INK='#131c27';SKINS=['e2c3a5','ca9e7e','ac795c','77503f','45302b']
STYLES=['short','short_swept','short_curls','long','long_braid','long_tail']
rig=json.loads((ROOT/'assets/recast/hero_rig.json').read_text())
# One complete support/recovery cycle per 24 frames; hands/hit timing unchanged.
for f,p in enumerate(rig['poses'][1]):p['lf']=foot(f/24,-1);p['rf']=foot(f/24,1)
for row,poses in enumerate(rig['poses']):
 for f,p in enumerate(poses):p['hair_sway']=math.sin(f/24*math.tau+row*.4)*.8
def transform(im,p):
 if 'rotation' in p:
  im=im.rotate(p['rotation']*180/math.pi,resample=Image.Resampling.NEAREST,center=(32,42))
  shifted=Image.new('RGBA',(64,64));shifted.alpha_composite(im,(0,p.get('roll_shift',0)));return shifted
 return im

def torso(p,gender,build):
 x,y=p['hip'];w={'slim':-1,'normal':0,'sturdy':1}[build]
 if gender=='male':pts=[(-6-w,-12),(3+w,-13),(6+w,-11),(7+w,-7),(4+w,-3),(4+w,2),(-4-w,2),(-5-w,-4)]
 else:pts=[(-4-w,-12),(2+w,-13),(4+w,-11),(6+w,-9),(7+w,-7),(5+w,-5),(3+w,-3),(5+w,0),(5+w,2),(-5-w,2),(-7-w,0),(-6-w,-3),(-3-w,-5)]
 return [(x+a,y+b)for a,b in pts]
def frame(p,skin,gender,build,plain=False,part=None):
 im=Image.new('RGBA',(64,64));a=Ink(im);x,y=p['hip'];hx,hy=p['head'];w={'slim':-1,'normal':0,'sturdy':1}[build]
 limb=3+(build=='sturdy');shoulder=5+w if gender=='male' else 3+w;hip=2+w*.4 if gender=='male' else 3+w*.4
 cloth='#3f696d' if not plain else '#687976';clight='#81a5a2' if not plain else '#a9b7a6';pants='#3d4c58'
 skin='#'+skin;sh=tuple(int(v*.65) for v in bytes.fromhex(skin[1:]));hi=tuple(min(255,int(v*1.12))for v in bytes.fromhex(skin[1:]))
 if part is None:
  a.limb((x-shoulder,y-10),mix((x-shoulder,y-10),p['left'],.55),p['left'],(sh,skin,sh),limb)
  for side,end in [(-1,p['lf']),(1,p['rf'])]:
   start=(x+side*hip,y);knee=mix(start,end,.5);knee=(knee[0]+side*2,knee[1]-1)
   a.limb(start,knee,(end[0],end[1]-2),(pants,'#6a7778','#24333e'),limb)
   a.poly([(end[0]-2,end[1]-4),(end[0]+2,end[1]-4),(end[0]+4,end[1]-1),(end[0]+3,end[1]),(end[0]-3,end[1])],INK);a.line([(end[0]-1,end[1]-3),(end[0]+2,end[1]-2)],'#b28b59')
  points=torso(p,gender,build);a.poly(points,INK)
  # Inset clothed contour follows chest, waist and hips, not isolated bumps.
  inner=[(x+(xx-x)*.76,y+(yy-y)*.93)for xx,yy in points];a.poly(inner,cloth)
  a.line([(x-2,y-11),(x-2,y-6),(x,y-4)],clight,2)
  if gender=='male':a.line([(x,y-10),(x+4+w,y-9),(x+4+w,y-7)],clight,1)
  else:a.line([(x+2,y-10),(x+4+w,y-8),(x+3,y-6)],clight,1);a.line([(x-4-w,y-1),(x-2,y+1)],'#718588',1)
  a.line([(x-2,y-2),(x+3,y-2)],'#a17b52',2);a.rect((x,y-3,x+1,y-1),'#d4b178')
  a.line([(x,y-13),(hx,hy+4)],skin,3)
  a.poly([(hx-4,hy-5),(hx+3,hy-5),(hx+5,hy-2),(hx+5,hy+3),(hx+2,hy+5),(hx-3,hy+4),(hx-5,hy)],INK)
  a.poly([(hx-3,hy-4),(hx+2,hy-4),(hx+4,hy-1),(hx+4,hy+3),(hx+1,hy+4),(hx-2,hy+3)],skin)
  a.line([(hx-2,hy-3),(hx+1,hy-3)],hi,2);a.line([(hx-3,hy),(hx-2,hy+3)],sh,2);a.rect((hx+2,hy-1,hx+3,hy),INK);a.rect((hx+4,hy+1,hx+5,hy+2),skin);a.line([(hx,hy+3),(hx+2,hy+3)],sh)
 if part=='arm':
  a.limb((x+shoulder,y-10),mix((x+shoulder,y-10),p['right'],.55),p['right'],(skin,hi,sh),limb)
  a.line([(x+shoulder,y-10),mix((x+shoulder,y-10),p['right'],.3)],cloth,limb+1)
 if part=='body':
  pts=torso(p,gender,build);a.poly(pts,INK);a.poly([(x+(xx-x)*.84,y+(yy-y)*.96)for xx,yy in pts],'#8e6949')
  for xx in [-2,1,3]:a.line([(x+xx,y-10),(x+xx+(1 if gender=='female' and xx>0 else 0),y-7),(x+xx*.7,y-3)],'#c4a06c',1)
  a.line([(x-3,y-7),(x+4+w,y-5)],'#395760',2);a.rect((x,y-6,x+1,y-4),'#d8b67b')
 if part=='head':
  a.poly([(hx-6,hy-3),(hx-5,hy-7),(hx,hy-10),(hx+5,hy-8),(hx+6,hy-3),(hx+3,hy-2),(hx+1,hy-5),(hx-2,hy-4),(hx-3,hy+2),(hx-5,hy+3)],INK)
  a.poly([(hx-4,hy-4),(hx-4,hy-6),(hx,hy-8),(hx+3,hy-7),(hx+4,hy-4),(hx,hy-5)],'#9b744b');a.line([(hx-3,hy-5),(hx,hy-7),(hx+3,hy-6)],'#d0ac6e');a.rect((hx-5,hy-2,hx-3,hy),'#7c5b41')
 if part=='legs':
  for side,end in [(-1,p['lf']),(1,p['rf'])]:
   knee=mix((x+side*hip,y),end,.5);a.limb((x+side*hip,y),knee,(end[0],end[1]-3),('#7b593f','#c09a63','#4a3d31'),limb)
 return transform(im,p)
def hair_frame(p,style,layer):
 im=Image.new('RGBA',(64,64));a=Ink(im);hx,hy=p['head'];sway=round(math.sin(float(p['weapon'])*1.8)+p.get('hair_sway',0))
 if layer=='rear' and style.startswith('long'):
  if style=='long':a.poly([(hx-5,hy-3),(hx-2,hy),(hx-2+sway,hy+13),(hx-5+sway,hy+16),(hx-8+sway,hy+11),(hx-7,hy+1)],'#555555');a.line([(hx-5,hy+2),(hx-5+sway,hy+12)],'#bcbcbc',1)
  if style=='long_braid':
   a.line([(hx-5,hy),(hx-7,hy+7),(hx-5+sway,hy+15)],'#383838',4)
   for y in range(3,15,3):a.line([(hx-7+(y%2),hy+y),(hx-4,hy+y+1)],'#eeeeee',2)
  if style=='long_tail':a.poly([(hx-5,hy-4),(hx-9,hy-1),(hx-10+sway,hy+8),(hx-7+sway,hy+13),(hx-6+sway,hy+8),(hx-7,hy+2)],'#777777');a.line([(hx-8,hy),(hx-8+sway,hy+8)],'#dddddd',1)
 if layer=='front':
  a.poly([(hx-5,hy-1),(hx-5,hy-5),(hx-2,hy-8),(hx+3,hy-7),(hx+5,hy-4),(hx+1,hy-4),(hx-1,hy-2),(hx-2,hy+2),(hx-5,hy+2)],'#333333')
  a.poly([(hx-4,hy-4),(hx-1,hy-7),(hx+2,hy-6),(hx+3,hy-4),(hx-1,hy-3),(hx-3,hy)],'#cccccc')
  a.line([(hx-2,hy-6),(hx+1,hy-5)],'#ffffff',1)
  if style=='short_swept':a.poly([(hx-4,hy-4),(hx-2,hy-9),(hx+4,hy-8),(hx+6,hy-5),(hx,hy-5)],'#aaaaaa');a.line([(hx-1,hy-8),(hx+3,hy-7)],'#ffffff')
  if style=='short_curls':
   for xx,yy in [(-4,-5),(-2,-7),(1,-7),(4,-5),(-5,-2)]:a.oval((hx+xx-1,hy+yy-1,hx+xx+2,hy+yy+2),'#cccccc');a.rect((hx+xx,hy+yy,hx+xx+1,hy+yy+1),'#555555')
  if style.startswith('long'):a.line([(hx-4,hy),(hx-4,hy+5)],'#aaaaaa',2)
 return transform(im,p)
def atlas(call,poses=rig['poses']):
 im=Image.new('RGBA',(len(poses[0])*64,len(poses)*64))
 for row,ps in enumerate(poses):
  for f,p in enumerate(ps):im.alpha_composite(call(p),(f*64,row*64))
 return im
def downed_shape(gender,build,b):
 w={'slim':-1,'normal':0,'sturdy':1}[build]
 if gender=='male':return [(24,43-w-b),(29,41-w-b),(34,42-w-b),(40,45),(38,49),(27,49),(24,47)]
 return [(24,44-b),(27,42-w-b),(30,41-w-b),(33,44-b),(35,45),(38,42-w-b),(41,45),(39,49),(27,49),(24,47)]
def downed_frame(f,skin,gender,build,plain=False,part=None):
 im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im);b=1 if f in [3,4,5,6] else 0;w={'slim':-1,'normal':0,'sturdy':1}[build]
 pts=downed_shape(gender,build,b)
 if part is None:
  d.line([(36,47),(43,44),(50,49)],fill=INK,width=5+w);d.line([(36,46),(43,43),(50,48)],fill='#596b74',width=3+w)
  d.rectangle((48,48,53,51),fill=INK);d.line([(34,48),(41,49),(49,50)],fill='#24313e',width=4+w)
  d.polygon(pts,fill=INK);d.polygon([(30+(x-30)*.84,46+(y-46)*.8)for x,y in pts],fill='#3f696d' if not plain else '#687976')
  d.line([(27,43-b),(31,43-b)],fill='#81a5a2',width=1)
  d.rectangle((22,43,26,46),fill='#'+skin)
  d.polygon([(15,41),(22,40),(25,42),(25,47),(19,49),(15,46)],fill=INK);d.polygon([(17,42),(22,41),(24,43),(24,46),(20,48),(17,46)],fill='#'+skin)
  d.line([(21,44),(23,44)],fill=INK);d.point((25,46),fill='#'+skin)
  d.line([(30,45-b),(27,49),(22,49)],fill=INK,width=4);d.line([(29,45-b),(26,48),(22,48)],fill='#'+skin,width=2)
  d.line([(30,45-b),(28,47)],fill='#3f696d' if not plain else '#687976',width=3)
 if part=='head':d.polygon([(14,41),(16,38),(22,38),(25,41),(24,43),(15,44)],fill='#503b2b');d.line([(16,40),(21,39),(24,41)],fill='#d3b374',width=2)
 if part=='body':
  d.polygon(pts,fill=INK);d.polygon([(30+(x-30)*.86,46+(y-46)*.85)for x,y in pts],fill='#8e6949');d.line([(27,43-b),(31,43-b),(36,46)],fill='#c4a06c',width=2);d.line([(29,47),(37,47)],fill='#395760',width=1)
 if part=='legs':d.line([(39,45),(43,44),(47,47)],fill='#b58a57',width=3+w);d.line([(39,49),(44,50)],fill='#967046',width=3+w)
 return im
def downed_hair(f,style,layer):
 im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im)
 if layer=='rear' and style.startswith('long'):
  if style=='long':d.polygon([(15,41),(17,44),(17,50),(10,51),(11,45)],fill='#777777');d.line([(13,45),(12,50)],fill='#dddddd')
  if style=='long_braid':
   d.line([(14,42),(12,46),(9,50),(15,51)],fill='#555555',width=3)
   for x,y in [(12,45),(10,48),(13,50)]:d.line([(x-1,y),(x+1,y+1)],fill='#dddddd',width=1)
  if style=='long_tail':d.polygon([(14,41),(10,42),(7,47),(8,51),(12,49),(11,46),(16,44)],fill='#aaaaaa');d.line([(10,44),(9,48)],fill='#ffffff')
 if layer=='front':
  d.polygon([(14,44),(14,40),(18,38),(23,39),(26,42),(22,42),(19,41),(17,44),(16,47)],fill='#333333')
  d.line([(15,41),(18,39),(22,40),(24,41)],fill='#cccccc',width=2);d.point((19,39),fill='#ffffff')
  if style=='short_swept':d.polygon([(15,40),(18,36),(23,37),(26,40),(20,39)],fill='#bbbbbb');d.line([(18,37),(22,38)],fill='#ffffff')
  if style=='short_curls':
   for x,y in [(15,40),(18,38),(21,39),(24,40)]:d.ellipse((x-1,y-1,x+1,y+1),fill='#dddddd');d.point((x,y),fill='#666666')
 return im
def downed_atlas(call):
 im=Image.new('RGBA',(768,64))
 for f in range(12):im.alpha_composite(call(f),(f*64,0))
 return im

def arm_atlas(call):
 # Forearm layer has a smaller shared cell, preserving two pixels of padding.
 im=Image.new('RGBA',(24*36,16*40))
 for row,poses in enumerate(rig['poses']):
  for f,p in enumerate(poses):
   source=call(p);box=source.getbbox()
   assert box and box[0]>=18 and box[1]>=18 and box[2]<=50 and box[3]<=54,box
   im.alpha_composite(source.crop((16,16,52,56)),(f*36,row*40))
 return im

builds=['normal'] if '--normal' in sys.argv else ['slim','normal','sturdy']
for gender in ['male','female']:
 for build in builds:
  for si,skin in enumerate(SKINS):
   for plain in [False,True]:
    atlas(lambda p:frame(p,skin,gender,build,plain)).save(OUT/f'body_{gender}_{build}_{si}_{"plain" if plain else "coat"}.png')
    arm_atlas(lambda p:frame(p,skin,gender,build,plain,part='arm')).save(OUT/f'arm_{gender}_{build}_{si}_{"plain" if plain else "coat"}.png')
  for part in ['head','body','legs']:atlas(lambda p:frame(p,SKINS[1],gender,build,part=part)).save(OUT/f'armor_{gender}_{build}_{part}.png')
  for si,skin in enumerate(SKINS):
   for plain in [False,True]:downed_atlas(lambda f:downed_frame(f,skin,gender,build,plain)).save(OUT/f'downed_{gender}_{build}_{si}_{"plain" if plain else "coat"}.png')
  for part in ['head','body','legs']:downed_atlas(lambda f:downed_frame(f,SKINS[1],gender,build,part=part)).save(OUT/f'downed_armor_{gender}_{build}_{part}.png')
for style in STYLES:
 for layer in ['rear','front']:
  atlas(lambda p:hair_frame(p,style,layer)).save(OUT/f'hair_{style}_{layer}.png')
  downed_atlas(lambda f:downed_hair(f,style,layer)).save(OUT/f'downed_hair_{style}_{layer}.png')
(OUT/'rig.gd').write_text('extends RefCounted\nconst DATA := '+json.dumps(rig)+'\n');(OUT/'rig.json').write_text(json.dumps(rig))
print('AVATAR_ART_BUILT',builds)
