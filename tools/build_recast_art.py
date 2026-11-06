"""Emberdepths: original hand-authored pixel clusters/animation rigs, CC0-1.0.
Pillow is used only to rasterize the authored artwork offline. No borrowed images.
"""
from PIL import Image,ImageDraw
from pathlib import Path
import math,json,random
OUT=Path(__file__).resolve().parents[1]/'assets/recast';OUT.mkdir(exist_ok=True)
INK='#131c27';DARK='#24313e';CLOTH='#3d6868';LIGHT='#80a7a0';GOLD='#bf9260'
ROWS=['idle','run','jump','fall','land','windup','active','recovery','mine','place','roll','parry','hurt','death','block','guard_break']
SKINS=['e2c3a5','ca9e7e','ac795c','77503f','45302b']
def rgb(c):return tuple(bytes.fromhex(c.lstrip('#')))
def shade(c,f):return tuple(max(0,min(255,round(v*f))) for v in rgb(c))
class Ink:
 def __init__(self,im,anchor=(32,51)):self.im=im;self.d=ImageDraw.Draw(im);self.a=anchor
 def pts(self,p):return[(round(x+self.a[0]),round(y+self.a[1]))for x,y in p]
 def poly(self,p,c):self.d.polygon(self.pts(p),fill=c)
 def line(self,p,c,w=1):self.d.line(self.pts(p),fill=c,width=w)
 def rect(self,p,c):self.d.rectangle(self.pts([(p[0],p[1]),(p[2],p[3])]),fill=c)
 def oval(self,p,c):self.d.ellipse(self.pts([(p[0],p[1]),(p[2],p[3])]),fill=c)
 def limb(self,a,b,c,palette,w=4):
  for col,width in [(INK,w+2),(palette[0],w)]:
   self.line([a,b,c],col,width)
   for x,y in [a,b,c]:self.oval((x-width/2,y-width/2,x+width/2,y+width/2),col)
  self.line([(a[0]-1,a[1]),(b[0]-1,b[1])],palette[1],max(1,w//3))
  self.line([(b[0]+1,b[1]),(c[0]+1,c[1])],palette[2],1)
def mix(a,b,t):return tuple(x+(y-x)*t for x,y in zip(a,b))
def foot(t,side):
 t=(t+(0.5 if side<0 else 0))%1
 if t<.42:return(side*3+10-20*t/.42,0)
 u=(t-.42)/.58;v=-20*.58/.42
 x=(2*u*u*u-3*u*u+1)*-10+(u*u*u-2*u*u+u)*v+(-2*u*u*u+3*u*u)*10+(u*u*u-u*u)*v
 return(side*3+x,-math.sin(u*math.pi)**2*7)
def pose(row,f):
 t=f/23;phase=f/24*math.tau;b=round(math.sin(phase)) if row in ['idle','block'] else 0
 p=dict(hip=(0,-12+b),head=(0,-31+b),left=(-7,-15+b),right=(7,-15+b),lf=(-3,0),rf=(3,0),lean=0,weapon=-.3,off=(0,0))
 if row=='run':
  p['lf']=foot(f/12,-1);p['rf']=foot(f/12,1);p['hip']=(1,-12-round(math.sin(phase)**2));p['head']=(2,-31-round(math.sin(phase)**2));p['left']=(-7-math.sin(phase)*4,-16);p['right']=(7+math.sin(phase)*4,-16)
 if row in ['jump','fall','land']:
  u=t if row=='land' else 1
  p['lf']=(-5,(-4 if row=='jump' else -1)*(1-u if row=='land' else 1));p['rf']=(5,-6 if row=='jump' else -1)
  p['left']=(-8,-22);p['right']=(9,-23)
  if row=='land':p['hip']=(0,-12+(1-t)*3);p['head']=(1,-31+(1-t)*3)
 if row=='jump':p['lf']=(-5,-2-4*t);p['rf']=(5,-4-4*t);p['head']=(t,-31-t);p['right']=(8,-20-4*t)
 if row=='fall':p['lf']=(-4,-1+t*2);p['rf']=(5,-4+4*t);p['head']=(1,-31+t);p['right']=(9,-22+3*t)
 if row in ['windup','active','recovery']:
  if row=='windup':u=t*t;p['right']=mix((7,-15),(-4,-29),u);p['head']=(-2*u,-31+u);p['weapon']=-.4-u*1.9
  elif row=='active':u=.85+.15*(1-(1-t)**3);p['right']=mix((-4,-29),(13,-21),u);p['head']=(2,-31);p['hip']=(2,-12);p['weapon']=-2.3+u*2.7
  else:p['right']=mix((13,-21),(7,-15),t);p['weapon']=.4-t*.7;p['head']=(2*(1-t),-31)
  p['left']=(-5,-22);p['lf']=(-5,0);p['rf']=(6,0)
 if row=='mine':
  u=t/.4 if t<.4 else(1-(t-.4)/.6);p['right']=mix((9,-14),(-3,-30),u);p['weapon']=.6-u*2.8;p['head']=(1,-30+math.sin(t*math.pi));p['left']=(-6,-20)
 if row=='place':p['right']=mix((7,-15),(12,-21),math.sin(t*math.pi));p['weapon']=0
 if row=='parry':
  u=min(1,t*4)*(1-max(0,(t-.35)/.65));p['right']=mix((7,-15),(10,-27),u);p['left']=mix((-7,-15),(1,-23),u);p['weapon']=-1.4*u
 if row=='block':p['right']=(10,-23);p['left']=(8,-22);p['head']=(-1,-30);p['weapon']=-.7
 if row=='roll':
  fold=min(1,t/.2)*(1-max(0,(t-.75)/.25));fold=fold*fold*(3-2*fold)
  p['hip']=mix((0,-12),(0,-8),fold);p['head']=mix((0,-31),(2,-20),fold);p['right']=mix((7,-15),(7,-15),fold);p['left']=mix((-7,-15),(-5,-14),fold);p['lf']=mix((-3,0),(-5,-3),fold);p['rf']=mix((3,0),(6,-4),fold);p['weapon']=-.3-fold*.7
  p['rotation']=-math.tau*t
 if row in ['hurt','guard_break']:
  u=math.sin(t*math.pi);p['head']=(-3*u,-31+2*u);p['hip']=(-u,-12);p['right']=(10,-13);p['left']=(-10,-13)
 if row=='death':
  u=t*t*(3-2*t);p['hip']=(2,-12+8*u);p['head']=(4*u,-31+15*u);p['left']=(-8,-15+10*u);p['right']=(10,-15+10*u);p['lf']=(-6,0);p['rf']=(8,0)
 return p
POSES=[[pose(row,f) for f in range(24)] for row in ROWS]
def hero_frame(p,skin,gender,hair,bare=False,only=None):
 im=Image.new('RGBA',(64,64));a=Ink(im);skin='#'+skin;sh=shade(skin,.65);hi=shade(skin,1.15);x,y=p['hip'];hx,hy=p['head']
 if only is None:
  # Rear hair, cape and rear arm lie behind a single connected torso.
  a.poly([(hx-5,hy-3),(hx-3,hy-7),(hx+4,hy-7),(hx+6,hy-2),(hx+5,hy+9 if hair=='long' else hy+2),(hx-5,hy+8 if hair=='long' else hy+1)],'#222430')
  if not bare:
   a.poly([(x-4,y-13),(x-8,y-9),(x-9-2*math.sin(p['weapon']),y+5),(x-5,y+2),(x-3,y+6),(x-1,y-7)],INK)
   a.line([(x-5,y-10),(x-7,y+1)],'#78594e',2);a.line([(x-6,y-7),(x-6,y-1)],GOLD)
  a.limb((x-5,y-10),mix((x-5,y-10),p['left'],.55),p['left'],(sh,skin,sh),3)
  for side,end in [(-1,p['lf']),(1,p['rf'])]:
   hip=(x+side*2,y);knee=mix(hip,end,.5);knee=(knee[0]+side*2,knee[1]-1)
   a.limb(hip,knee,(end[0],end[1]-2),(sh if bare else '#354653',skin if bare else '#5c6a6f','#22313f'),3)
   a.poly([(end[0]-2,end[1]-4),(end[0]+2,end[1]-4),(end[0]+4,end[1]-1),(end[0]+3,end[1]),(end[0]-3,end[1])],INK)
   a.line([(end[0]-1,end[1]-3),(end[0]+2,end[1]-2)],GOLD)
  waist=3 if gender=='female' else 4
  a.poly([(x-6,y-12),(x+4,y-13),(x+6,y-8),(x+waist,y-2),(x+5,y+2),(x-4,y+2),(x-5,y-4)],INK)
  a.poly([(x-4,y-11),(x+2,y-12),(x+4,y-8),(x+3,y-3),(x+4,y),(x-3,y),(x-3,y-5)],skin if bare else CLOTH)
  a.line([(x-3,y-10),(x-3,y-4),(x-1,y-2)],hi if bare else LIGHT,2)
  if not bare:
   a.line([(x+2,y-10),(x+2,y-2)],'#29434c',2);a.line([(x-3,y-8),(x+3,y-5)],'#a58a68',2);a.rect((x-5,y-2,x+4,y), '#705143');a.rect((x,y-3,x+2,y),GOLD)
  a.poly([(hx-4,hy-5),(hx+3,hy-5),(hx+5,hy-2),(hx+5,hy+3),(hx+2,hy+5),(hx-3,hy+4),(hx-5,hy)],INK)
  a.poly([(hx-3,hy-4),(hx+2,hy-4),(hx+4,hy-1),(hx+4,hy+3),(hx+1,hy+4),(hx-2,hy+3)],skin)
  a.line([(hx-2,hy-3),(hx+1,hy-3)],hi,2);a.line([(hx-3,hy),(hx-2,hy+3)],sh,2);a.rect((hx+2,hy-1,hx+3,hy),INK);a.rect((hx+4,hy+1,hx+5,hy+2),skin)
  a.line([(hx,hy+3),(hx+2,hy+3)],sh)
  a.poly([(hx-5,hy-2),(hx-4,hy-6),(hx-1,hy-8),(hx+3,hy-7),(hx+5,hy-4),(hx+1,hy-5),(hx-1,hy-3),(hx-2,hy+1),(hx-5,hy+2)],'#272937')
  a.line([(hx-3,hy-5),(hx,hy-6),(hx+2,hy-5)],'#56606a',2)
  if hair=='long':a.poly([(hx-5,hy),(hx-3,hy+1),(hx-3,hy+9),(hx-5,hy+11),(hx-6,hy+7)],'#373b49');a.line([(hx-4,hy+3),(hx-4,hy+8)],'#59636c')
  a.limb((x+4,y-10),mix((x+4,y-10),p['right'],.55),p['right'],(skin,hi,sh),3)
  if not bare:a.line([(x+4,y-10),mix((x+4,y-10),p['right'],.35)],CLOTH,4)
 if only=='body':
  a.poly([(x-6,y-12),(x+4,y-13),(x+6,y-9),(x+5,y-2),(x+3,y),(x-4,y),(x-5,y-6)],INK)
  for i in range(3):
   xx=x-4+i*3;a.poly([(xx,y-10),(xx+2,y-11),(xx+3,y-2),(xx,y-1)],['#6b4936','#98704c','#b68d5e'][i]);a.line([(xx,y-9),(xx+1,y-3)],'#d1af74')
  a.line([(x-5,y-8),(x+4,y-6)],'#324d54',2);a.rect((x,y-7,x+1,y-5),GOLD)
 if only=='head':
  a.poly([(hx-6,hy-3),(hx-5,hy-7),(hx,hy-10),(hx+5,hy-8),(hx+6,hy-3),(hx+3,hy-2),(hx+1,hy-5),(hx-2,hy-4),(hx-3,hy+2),(hx-5,hy+3)],INK)
  a.poly([(hx-4,hy-4),(hx-4,hy-6),(hx,hy-8),(hx+3,hy-7),(hx+4,hy-4),(hx,hy-5)],'#9b744b');a.line([(hx-3,hy-5),(hx,hy-7),(hx+3,hy-6)],'#d0ac6e');a.rect((hx-5,hy-2,hx-3,hy), '#7c5b41')
 if only=='legs':
  for side,end in [(-1,p['lf']),(1,p['rf'])]:
   knee=mix((x+side*2,y),end,.5);a.poly([(knee[0]-2,knee[1]-2),(knee[0]+2,knee[1]-3),(end[0]+2,end[1]-3),(end[0]-2,end[1]-2)],INK);a.line([knee,(end[0],end[1]-3)],'#a27b51',3);a.line([(knee[0]-1,knee[1]-1),(end[0]-1,end[1]-4)],'#d0ad77')
 if 'rotation'in p:
  # Every roll frame has tucked knees/head/arms; not a rotating idle frame.
  im=im.rotate(p['rotation']*180/math.pi,resample=Image.Resampling.NEAREST,center=(32,42))
  if 'roll_shift' not in p and only is None:p['roll_shift']=52-im.getbbox()[3]
  shifted=Image.new('RGBA',im.size);shifted.alpha_composite(im,(0,p.get('roll_shift',0)));im=shifted
 return im

def heroes():
 for gender in ['male','female']:
  for hair in ['short','long']:
   for si,skin in enumerate(SKINS):
    for bare in [False,True]:
     atlas=Image.new('RGBA',(1536,len(ROWS)*64))
     for ri,row in enumerate(POSES):
      for f,p in enumerate(row):atlas.alpha_composite(hero_frame(p,skin,gender,hair,bare),(f*64,ri*64))
     atlas.save(OUT/f'hero_{gender}_{hair}_{si}_{"bare" if bare else "coat"}.png')
 for part in ['head','body','legs']:
  atlas=Image.new('RGBA',(1536,len(ROWS)*64))
  for ri,row in enumerate(POSES):
   for f,p in enumerate(row):atlas.alpha_composite(hero_frame(p,SKINS[1],'male','short',only=part),(f*64,ri*64))
  atlas.save(OUT/f'armor_{part}.png')
 data={'rows':ROWS,'poses':POSES}
 (OUT/'hero_rig.json').write_text(json.dumps(data))
 (OUT/'hero_rig.gd').write_text('extends RefCounted\nconst DATA := '+json.dumps(data)+'\n')

def icons():
 ids=['dirt','stone','turf','emberstone','stone_pick','stone_axe','wood','wood_block','spark_balm','stone_blade','torch','dirt_wall','stone_wall','wood_wall','wood_door','wood_chest','wood_sword','wood_shield','wood_helm','wood_armor','wood_legs']
 for name in ids:
  im=Image.new('RGBA',(32,32));a=Ink(im,(0,0))
  if name in ['wood_sword','stone_blade']:
   outline=[(2,14),(7,14),(10,12),(26,13),(30,15),(26,18),(10,18),(7,17),(2,17)] if name=='wood_sword' else [(2,14),(7,14),(10,10),(16,10),(17,8),(23,11),(27,11),(30,15),(25,21),(19,20),(16,22),(10,20),(7,17),(2,17)]
   a.poly(outline,INK)
   if name=='stone_blade':a.poly([(11,11),(16,11),(18,10),(26,13),(28,15),(24,19),(17,20),(11,18)],'#758c91');a.line([(12,12),(17,11),(25,14)],'#cbd4c3',2)
   a.poly([(10,13),(24,13),(28,15),(24,17),(10,17)],'#a88659' if name=='wood_sword' else '#768b91');a.line([(11,13),(23,13),(27,15)],'#d9bf86' if name=='wood_sword' else '#cbd4c3');a.line([(12,16),(21,16)],'#73563e' if name=='wood_sword' else '#4a6470');a.line([(8,11),(8,20)],GOLD,2);a.line([(2,15),(6,15)],'#7b5442',2)
  elif name in ['stone_pick','stone_axe']:
   a.line([(7,26),(22,7)],INK,5);a.line([(7,25),(22,8)],'#8a654c',3);a.line([(8,24),(21,8)],'#c1a06b')
   p=[(8,9),(15,4),(23,5),(28,11),(24,10),(20,8),(15,8)] if name=='stone_pick' else [(13,5),(22,5),(27,10),(27,16),(21,20),(16,16),(17,12)]
   a.poly(p,INK);a.poly([(x,y+1)for x,y in p[1:]],'#768890');a.line(p[1:3],'#c5cdb7',2)
  elif name=='wood_shield':
   a.poly([(5,4),(15,1),(26,5),(25,19),(20,26),(15,30),(8,26),(4,18)],INK);a.poly([(7,6),(15,3),(23,7),(22,18),(18,25),(15,27),(10,24),(7,18)],'#8f6948')
   for x in [10,15,20]:a.line([(x,7),(x,21)],'#bd9866',2);a.line([(x+1,7),(x+1,21)],'#654932')
   a.line([(7,10),(22,10)],'#415a60',3);a.line([(9,21),(20,21)],'#415a60',3);a.oval((12,12,18,18),GOLD);a.rect((14,13,16,16),'#e2c795')
  elif name=='wood_helm':
   a.poly([(5,13),(7,5),(13,1),(23,3),(27,10),(27,19),(23,27),(19,26),(19,17),(11,15),(10,26),(6,27)],INK)
   a.poly([(7,12),(9,6),(14,3),(21,5),(24,10),(24,15),(18,13),(12,13)],'#a47a50');a.line([(9,10),(11,6),(16,4),(21,6)],'#dec18b',2)
   a.line([(8,14),(7,24)],'#926b49',3);a.line([(24,15),(22,24)],'#926b49',3);a.line([(9,14),(23,16)],'#4c6770',2);a.rect((14,12,16,14),GOLD)
  elif name=='wood_armor':
   a.poly([(3,9),(8,4),(12,3),(14,6),(18,6),(20,3),(25,5),(29,10),(26,16),(23,14),(23,28),(9,28),(8,14),(5,16)],INK)
   a.poly([(6,9),(9,6),(12,6),(13,10),(19,10),(21,6),(24,7),(26,10),(23,13),(21,12),(21,25),(11,25),(10,12),(8,13)],'#8f6848')
   for x in [12,16,20]:a.line([(x,12),(x,22)],'#c2a06a',2);a.line([(x+1,13),(x+1,22)],'#634b39')
   a.line([(11,17),(22,17)],'#365563',2);a.line([(10,24),(22,24)],'#72543e',3);a.rect((15,23,18,26),GOLD);a.rect((16,23,17,24),'#e3c58b')
  elif name=='wood_legs':
   for dx in [0,14]:
    a.poly([(3+dx,4),(10+dx,2),(12+dx,14),(9+dx,27),(10+dx,29),(1+dx,29),(2+dx,21)],INK)
    a.poly([(5+dx,5),(8+dx,4),(10+dx,14),(7+dx,24),(4+dx,24),(5+dx,17)],'#a47a51');a.line([(6+dx,7),(7+dx,15),(5+dx,23)],'#d6b780',2);a.line([(4+dx,12),(10+dx,12)],'#3b5964',2);a.line([(3+dx,23),(8+dx,23)],'#3b5964',2)
  elif name=='spark_balm':
   a.poly([(13,3),(20,3),(21,7),(19,10),(24,16),(24,24),(20,28),(11,28),(7,24),(8,16),(13,10)],INK);a.rect((13,3,19,7),'#b18a5a');a.poly([(13,11),(18,11),(22,17),(22,23),(19,26),(12,26),(9,23),(10,17)],'#617f7c');a.poly([(10,20),(21,18),(21,23),(18,25),(12,25)],'#be8050');a.rect((11,14,12,19),'#b8c9b4');a.line([(11,22),(19,21)],'#e2b978')
  elif name=='torch':
   a.line([(13,27),(17,12)],INK,6);a.line([(13,27),(17,12)],'#94704d',3);a.poly([(12,12),(11,7),(15,2),(16,7),(20,5),(22,11),(18,17),(14,17)],'#a5573c');a.poly([(14,11),(15,6),(18,10),(19,13),(16,16)],'#f2bb63');a.rect((16,11,17,14),'#f5e1a0');a.line([(12,16),(20,16)],'#6b9292',2)
  elif name in ['wood_door','wood_chest']:
   if name=='wood_door':
    a.poly([(8,2),(24,2),(24,29),(7,29)],INK);a.rect((10,4,22,27),'#8b674b')
    for x in [12,17,21]:a.line([(x,5),(x,26)],'#b38c5c')
    a.line([(10,9),(22,9)],'#3c5962',2);a.line([(10,23),(22,23)],'#3c5962',2);a.oval((18,15,21,18),GOLD)
   else:
    a.poly([(3,12),(7,7),(25,7),(29,12),(29,26),(3,26)],INK);a.poly([(5,12),(9,9),(23,9),(27,12),(27,23),(5,23)],'#9b7650');a.line([(5,14),(27,14)],'#d1ad72',2);a.line([(5,22),(27,22)],'#604831',2)
    for x in [9,22]:a.line([(x,10),(x,23)],'#52717b',3)
    a.rect((14,14,18,19),GOLD);a.rect((15,15,16,17),'#e1c58d')
  elif name=='wood':
   for x,y in [(3,9),(10,3),(12,16)]:
    a.poly([(x,y+1),(x+11,y-2),(x+16,y+2),(x+15,y+7),(x+5,y+11),(x,y+7)],INK);a.poly([(x+2,y+2),(x+11,y),(x+14,y+3),(x+4,y+7)],'#9b7451');a.line([(x+4,y+2),(x+11,y+1)],'#d0ad77');a.oval((x+1,y+3,x+7,y+9),'#c3a06b');a.oval((x+3,y+4,x+6,y+7),'#7f593f');a.rect((x+4,y+5,x+5,y+6),'#e0c48a')
  elif name=='wood_wall':
   a.poly([(4,4),(27,4),(27,28),(4,28)],INK);a.rect((6,6,25,26),'#624c3b')
   for x in [7,12,17,22]:a.line([(x,7),(x,25)],'#a17e51',2);a.line([(x+2,7),(x+2,25)],'#443d33')
   a.line([(7,23),(24,8)],'#c3a06c',3);a.rect((6,6,25,7),'#8d7451')
  elif name=='wood_block':
   a.poly([(3,10),(21,3),(29,10),(29,24),(10,29),(3,23)],INK);a.poly([(5,11),(20,6),(26,11),(10,16)],'#c09b65');a.poly([(5,13),(9,17),(9,26),(5,22)],'#7e5d42');a.poly([(11,17),(27,12),(27,23),(11,26)],'#98714b')
   for y in [18,22]:a.line([(12,y),(26,y-4)],'#5a4938');a.line([(13,y-1),(26,y-5)],'#c2a06a')
  elif name in ['stone_wall','dirt_wall']:
   a.poly([(4,4),(27,4),(27,28),(4,28)],INK);base='#70838a' if name=='stone_wall' else '#91715b';a.rect((6,6,25,26),base)
   for y in [12,20]:a.line([(6,y),(25,y)],'#2f4550' if name=='stone_wall' else '#4f4944');a.line([(7,y-1),(24,y-1)],'#a0aaa3' if name=='stone_wall' else '#b29470')
   for x,y in [(16,6),(11,13),(20,21)]:a.line([(x,y),(x,y+6)],'#344b56' if name=='stone_wall' else '#625246')
  else:
   col={'dirt':'#765b50','turf':'#6b8466','stone':'#6d7e86','emberstone':'#796458','dirt_wall':'#665450','stone_wall':'#5a6d79'}[name]
   a.poly([(4,11),(10,5),(20,4),(28,12),(26,24),(17,28),(7,25),(3,19)],INK);a.poly([(6,12),(12,7),(20,6),(25,12),(23,22),(16,25),(8,22),(5,18)],col);a.poly([(7,12),(13,8),(20,8),(21,12),(13,14)],shade(col,1.3));a.poly([(14,16),(24,13),(22,21),(17,24)],shade(col,.7));a.line([(7,18),(12,17),(15,20)],shade(col,1.1))
   if name=='turf':a.line([(5,12),(9,7),(13,8),(18,5),(23,8)],'#a1ae77',3)
   if name=='emberstone':a.line([(10,10),(12,15),(17,17),(20,22)],'#b87348',3);a.line([(10,10),(12,15),(17,17)],'#edbb6b')
  if name=='dirt':
   im=Image.new('RGBA',(32,32));a=Ink(im,(0,0))
   for x,y,r in [(12,12,8),(21,19,7),(9,22,6)]:
    a.oval((x-r,y-r,x+r,y+r),INK);a.oval((x-r+2,y-r+1,x+r-1,y+r-2),'#84674e');a.line([(x-r+3,y-2),(x-1,y-r+3)],'#bd9970',2);a.line([(x,y+2),(x+3,y+4)],'#4f4940')
  if name=='turf':
   im=Image.new('RGBA',(32,32));a=Ink(im,(0,0));a.poly([(3,13),(14,7),(28,12),(27,22),(17,27),(6,23)],INK);a.poly([(5,14),(15,10),(26,13),(25,21),(17,24),(7,21)],'#87694e');a.poly([(3,13),(7,7),(10,10),(15,5),(19,9),(24,7),(28,12),(17,17),(7,16)],'#5d7f56');a.line([(5,12),(9,11),(15,7),(19,11),(24,10)],'#b3bc7d',2);a.line([(10,17),(11,24),(14,27)],'#bb9768');a.line([(21,16),(20,23)],'#bb9768')
  im.save(OUT/f'item_{name}.png')
  im.resize((12,12),Image.Resampling.NEAREST).save(OUT/f'drop_{name}.png')
  if name in ['wood_sword','stone_blade','stone_pick','stone_axe','torch']:im.resize((24,24),Image.Resampling.NEAREST).save(OUT/f'held_{name}.png')
  if name=='wood_shield':im.resize((14,17),Image.Resampling.NEAREST).save(OUT/'held_wood_shield.png')

if __name__=='__main__':
 import sys
 if 'icons' not in sys.argv:heroes()
 icons()

# Shared UI skin and small resource glyphs; same 1px palette as the item art.
def ui_assets():
 im=Image.new('RGBA',(24,24));a=Ink(im,(0,0));a.rect((0,0,23,23),'#111b26');a.rect((1,1,22,22),'#53656b');a.rect((2,2,21,21),'#293d49');a.rect((3,3,20,20),'#1a2a35');a.line([(3,3),(20,3)],'#75908a');a.line([(3,20),(20,20)],'#101b26')
 for x,y in [(2,2),(20,2),(2,20),(20,20)]:a.rect((x,y,x+1,y+1),'#b6925e')
 im.save(OUT/'ui_panel.png')
 for kind,palette,points in [('health',['#773b42','#b25d57','#df9980'],[(7,13),(1,7),(1,3),(4,1),(7,4),(10,1),(13,3),(13,7)]),('mana',['#2c4b69','#5282a4','#a2c4cd'],[(7,0),(11,5),(13,9),(10,13),(4,13),(1,9),(3,5)]),('stamina',['#33584b','#639273','#bad090'],[(1,11),(2,5),(6,1),(13,1),(13,7),(9,12),(3,13)])]:
  im=Image.new('RGBA',(15,15));a=Ink(im,(0,0));a.poly(points,INK);a.poly([(7+(x-7)*.75,7+(y-7)*.75)for x,y in points],palette[1]);a.line([(4,7),(5,4),(7,5)],palette[2],2);a.line([(6,11),(9,9),(10,7)],palette[0]);im.save(OUT/f'ui_{kind}.png')
 atlas=Image.new('RGBA',(24*4,24))
 for f in range(4):
  im=Image.new('RGBA',(24,24));a=Ink(im,(0,0));points=[(5-f,2+f),(13-f,6+f),(20-f,13+f),(22-f,21+f)];a.line(points,'#bda36e',2);a.line(points[1:3],'#f3dca4');a.rect((20-f,16+f,21-f,19+f),'#e4c788');atlas.alpha_composite(im,(f*24,0))
 atlas.save(OUT/'sword_trace.png')
if __name__=='__main__':ui_assets()
