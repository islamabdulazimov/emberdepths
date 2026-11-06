"""Original 1px tile/prop/creature artwork, CC0-1.0; no external imagery."""
from build_recast_art import Ink,OUT,INK,DARK,GOLD,shade
from PIL import Image,ImageDraw
import math,random
KINDS=['seamling','hollowbeak','ashweaver','void_collector','ashling','spirit']
COUNTS=[8,12,8,6,8,4,8,6]
def creatures(kinds=KINDS):
 for kind in kinds:
  atlas=Image.new('RGBA',(768,512))
  for row,n in enumerate(COUNTS):
   for frame in range(12):
    t=min(frame,n-1)/max(1,n-1);ph=frame/n*math.tau
    im=Image.new('RGBA',(64,64));a=Ink(im,(32,54))
    prep=t*t if row==2 else 0;hit=1-t*.65 if row==3 else (.35*(1-t) if row==4 else 0);recoil=math.sin(t*math.pi) if row in [5,7] else 0
    breath=math.sin(ph) if row==0 else 0;walk=math.sin(ph) if row==1 else 0;dead=t if row==6 else 0
    if kind=='seamling':
     x=-prep*3+hit*4-recoil*2;y=-15+prep*3+breath+dead*8
     # Bark-mantis: hooked limbs, hollow ribcage, pale moss fans, paired eyes.
     for side in [-1,1]:
      ft=(frame/n+(0.5 if side<0 else 0))%1
      step=(4-8*ft/.58 if ft<.58 else -4+8*(ft-.58)/.42) if row==1 else 0
      lift=-math.sin((ft-.58)/.42*math.pi)**2*4 if row==1 and ft>.58 else 0
      a.limb((x+side*3,y+6),(side*7,-5),(side*6+step,lift),('#665346','#a78660','#3e3738'),3)
      a.line([(side*6+step,lift),(side*6+step+3,lift)],'#bbab7c')
     a.poly([(x-8,y+4),(x-9,y-5),(x-6,y-11),(x-2,y-14),(x+6,y-10),(x+9,y-3),(x+6,y+7),(x,y+9)],INK)
     a.poly([(x-6,y+3),(x-6,y-5),(x-3,y-11),(x,y-9),(x-1,y+5)],'#8b704e')
     a.poly([(x+2,y-9),(x+6,y-6),(x+6,y+2),(x+2,y+6)],'#4d5046')
     for i in range(4):a.line([(x-5,y-5+i*3),(x-2,y-6+i*3),(x+2,y-3+i*3)],'#b59c6c' if i%2 else '#736646')
     a.poly([(x-6,y-9),(x-10,y-15),(x-6,y-13),(x-4,y-18),(x-1,y-13)],'#677d61');a.line([(x-6,y-12),(x-4,y-15)],'#b6be89')
     a.rect((x+1,y-9,x+2,y-7),'#d6dba1');a.rect((x+5,y-8,x+6,y-6),'#d6dba1');a.line([(x,y-3),(x+4,y-2)],'#242f34',2)
     for side in [-1,1]:
      hand=(x+side*(10+hit*8-prep*4),y+4-hit*8)
      a.limb((x+side*6,y-7),(x+side*11,y-3),hand,('#7b6148','#bc9d6c','#443e37'),3)
      a.line([hand,(hand[0]+side*3,hand[1]+4),(hand[0]+side*1,hand[1]+6)],'#d0c297',2)
    elif kind=='hollowbeak':
     x=hit*3-recoil*2;y=-8+prep*2+breath*.6+dead*6
     for i in range(3):
      xx=-8+i*7;lift=max(0,math.sin(ph+i*math.pi))*2 if row==1 else 0
      a.limb((xx,y+3),(xx-3,-4-lift),(xx+2,-lift),('#50605e','#a0aaa0','#2f4148'),2)
     a.poly([(x-13,y+2),(x-14,y-4),(x-10,y-11),(x-3,y-14),(x+6,y-12),(x+12,y-7),(x+17,y-5),(x+16,y-1),(x+10,y),(x+5,y+7),(x-7,y+6)],INK)
     a.poly([(x-11,y),(x-11,y-5),(x-6,y-11),(x+2,y-11),(x+8,y-7),(x+10,y-3),(x+5,y+4),(x-6,y+4)],'#7d8f8a')
     a.poly([(x-10,y-5),(x-6,y-9),(x+1,y-10),(x-2,y-5)],'#bfccb6');a.poly([(x-9,y+1),(x-3,y-1),(x+2,y+4),(x-5,y+4)],'#4c666d')
     a.oval((x-1,y-8,x+9,y+1),INK);a.oval((x+1,y-7,x+7,y-1),'#263d49');a.line([(x+1,y-5),(x+5,y-6)],'#bac49c')
     a.poly([(x+7,y-6),(x+14+hit*2,y-5),(x+17+hit*2,y-2),(x+9,y-1)],'#a0a792');a.line([(x+9,y-4),(x+14,y-3)],'#e1d9b4')
     for dx,dy in [(-7,-3),(-4,2),(-4,-7)]:a.line([(x+dx,y+dy),(x+dx+2,y+dy+1)],'#4a5b60')
    elif kind=='ashweaver':
     fold=prep if row==2 else(.3*(1-t) if row==4 else (.65-t*.4 if row==3 else 0));spread=17-fold*10;y=-9+breath-recoil*3+dead*5;flap=walk*3 if row==1 else math.sin(ph)*2 if row==0 else -fold*4
     for side in [-1,1]:
      a.poly([(0,y-5),(side*6,y-10),(side*spread,y-5+flap),(side*14,y+2),(side*9,y+1),(side*8,y+6),(side*3,y+1)],INK)
      a.poly([(side*3,y-5),(side*6,y-8),(side*(spread-2),y-5+flap),(side*11,y),(side*7,y-1)],'#6a8b95' if side<0 else '#496876')
      a.line([(side*5,y-6),(side*10,y-3),(side*(spread-3),y-4+flap)],'#a8c0b8')
      a.line([(side*6,y-5),(side*9,y),(side*8,y+3)],'#344f60')
     a.poly([(-3,y-6),(0,y-10),(3,y-6),(2,y+5),(0,y+8),(-2,y+4)],INK);a.line([(0,y-8),(0,y+3)],'#c1c9ad',3);a.line([(-1,y-5),(1,y-5)],'#e7b66d',2);a.line([(-2,y+4),(-4,y+7)],'#8d9d9f')
    elif kind=='void_collector':
     x=-prep*2+hit*4-recoil;y=-10+breath*.5+dead*7
     for xx in [-11,-5,5,11]:
      a.limb((xx,y+5),(xx+walk*2,-3),(xx+walk*2,0),('#665b51','#afa282','#393f42'),3)
     a.poly([(x-17,y+5),(x-18,y-5),(x-13,y-11),(x-6,y-14),(x+7,y-13),(x+17,y-7-prep*4),(x+20,y+1),(x+16,y+9),(x+3,y+11),(x-11,y+8)],INK)
     for i in range(4):
      xx=x-15+i*8;a.poly([(xx,y-4),(xx+3,y-10),(xx+8,y-8),(xx+7,y+5),(xx+3,y+8),(xx,y+4)],['#6d675c','#93876b','#697e7c','#a28b64'][i]);a.line([(xx+1,y-3),(xx+3,y-8),(xx+5,y-7)],'#c5bd96')
     a.poly([(x-13,y-7),(x-13,y-16),(x-8,y-21),(x-5,y-16),(x-6,y-7)],'#bcb895');a.line([(x-12,y-12),(x-8,y-18)],'#e3dcb3')
     a.poly([(x+2,y-10),(x+5,y-19),(x+9,y-17),(x+12,y-9)],'#96aba1');a.line([(x+5,y-14),(x+6,y-17)],'#ccd2af')
     a.poly([(x+12,y-6-prep*5),(x+19,y-2-prep*5),(x+23,y+5),(x+18,y+10),(x+12,y+8)],'#987047');a.line([(x+15,y-2-prep*4),(x+19,y+4),(x+17,y+7)],'#d5b37a',2)
     a.rect((x+8,y-5,x+10,y-3),'#e7bd76')
    elif kind=='ashling':
     x=hit*4-recoil*2;y=-6+breath*.6+prep*2+dead*4
     for side in [-1,1]:a.limb((side*4,y+2),(side*7,-2),(side*6+walk*side*2,0),('#354b57','#6e8b91','#20303d'),2)
     a.poly([(x-10,y+4),(x-11,y-1),(x-8,y-7),(x-3,y-11),(x+4,y-10),(x+9,y-4),(x+12,y+2),(x+8,y+6)],INK)
     a.poly([(x-8,y+1),(x-7,y-5),(x-3,y-8),(x+2,y-8),(x+6,y-3),(x+8,y+2),(x+3,y+4)],'#506e7b');a.poly([(x-7,y-4),(x-3,y-7),(x,y-5),(x-2,y-1)],'#8d9d9e')
     a.poly([(x+1,y-7),(x+5,y-4),(x+4,y),(x+6,y+3),(x+1,y+2),(x-2,y-1)],'#273c49');a.line([(x+2,y-4),(x+7,y-3)],'#e0ab63',2)
     a.line([(x-5,y+2),(x-1,y+3)],'#a78266');a.line([(x-4,y-5),(x-2,y-3)],'#bf9363')
    else:
     y=-10+math.sin(ph)*2+dead*8;recoil*=2
     for i in range(3):a.poly([(-5+i*4,y),(i*4-5,y+12+math.sin(ph+i)*3),(i*4-2,y+7),(3+i,y-3)],'#405c70')
     a.poly([(-8-recoil,y-3),(-6,y-12),(0,y-18),(6,y-13),(8,y-4),(5,y+4),(0,y+2),(-5,y+5)],INK)
     a.poly([(-5,y-4),(-4,y-11),(0,y-15),(4,y-11),(5,y-4),(2,y+1),(-2,y+1)],'#718e93');a.poly([(-3,y-6),(-2,y-11),(1,y-13),(3,y-9),(2,y-6)],'#b3c8bc')
     a.rect((-3,y-8,-1,y-7),'#203440');a.rect((2,y-8,4,y-7),'#203440');a.line([(-1,y-2),(2,y-2)],'#d2d9b6')
    if row==6:
     pix=im.load()
     for yy in range(64):
      for xx in range(64):
       if ((xx*11+yy*7)%23)/23<dead*.95:pix[xx,yy]=(0,0,0,0)
    atlas.alpha_composite(im,(frame*64,row*64))
  atlas.save(OUT/f'mob_{kind}.png')
def terrain():
 rng=random.Random(4167)
 atlas=Image.new('RGBA',(48,16))
 for kind in ['turf','dirt','stone','ore','planks','roots']:
  im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im)
  base={'turf':'#68574d','dirt':'#68574d','stone':'#4b626e','ore':'#4b626e','planks':'#6e4e3c','roots':'#42493e'}[kind];d.rectangle((0,0,15,15),fill=base)
  if kind in ['turf','dirt']:
   for x,y,w in [(1,3,4),(8,1,5),(12,8,3),(2,10,5),(7,6,4),(8,13,5)]:
    d.polygon([(x,y),(x+w,y-1),(min(15,x+w+2),y+2),(x+1,y+3)],fill='#7d6856');d.line([(x+1,y),(x+w,y)],fill='#92765e');d.line([(x+2,y+4),(min(15,x+w),y+4)],fill='#504b47')
   if kind=='turf':
    d.polygon([(0,0),(15,0),(15,3),(12,2),(10,5),(8,3),(5,4),(3,2),(0,4)],fill='#455f50');d.line([(0,0),(4,1),(8,0),(12,1),(15,0)],fill='#a0aa73',width=2);d.line([(0,2),(4,2),(6,3),(9,1),(13,3),(15,2)],fill='#778f62');d.line([(5,4),(5,7),(7,8)],fill='#9b8059')
  elif kind in ['stone','ore']:
   for pts in [[(0,1),(6,0),(8,4),(5,8),(0,7)],[(9,0),(15,1),(15,6),(11,7),(8,4)],[(1,9),(5,9),(9,13),(7,15),(1,15)],[(9,8),(14,8),(15,14),(11,15),(8,12)]]:
    d.polygon(pts,fill=['#5e7680','#536e7b','#516873','#6b8087'][rng.randrange(4)]);d.line(pts[:3],fill='#829194');d.line(pts[-2:]+pts[:1],fill='#334854')
   if kind=='ore':
    d.line([(2,13),(5,9),(7,10),(10,5),(13,4)],fill='#815b42',width=4);d.line([(3,12),(5,9),(7,10),(10,5),(13,4)],fill='#c28d51',width=2);d.line([(4,11),(5,9),(7,10)],fill='#e0bc78');d.point((11,6),fill='#f6db96')
  elif kind=='planks':
   for y in [0,5,11]:
    d.rectangle((0,y,15,min(y+3,15)),fill=['#8a6346','#6c503d','#98744e'][[0,5,11].index(y)]);d.line((0,y,15,y),fill='#ba9564');d.line((0,y+4,15,y+4),fill='#3e3833');d.line((3,y+2,9,y+1),fill='#a58254');d.point((1,y+2),fill='#3d5056');d.point((14,y+2),fill='#3d5056')
  else:
   for i in [-3,3,9,15]:d.line([(i,0),(i+3,6),(i+1,11),(i+4,15)],fill='#263a3d',width=4);d.line([(i+1,0),(i+4,6),(i+2,11),(i+5,15)],fill='#8b7f58',width=2);d.line([(i+2,1),(i+4,5)],fill='#b0a279')
  if kind in ['turf','dirt','stone']:atlas.alpha_composite(im,({'turf':0,'dirt':16,'stone':32}[kind],0))
  else:im.save(OUT/f'tile_{kind}.png')
 atlas.save(OUT/'terrain.png')
def props():
 # Full-sized doors and six moving lids, preserving original gameplay bounds.
 door=Image.new('RGBA',(16*6,48))
 for f in range(6):
  im=Image.new('RGBA',(16,48));a=Ink(im,(0,0));a.rect((0,0,1,47),INK);a.rect((14,0,15,47),INK);a.line([(1,1),(14,1)],'#b18b59',2)
  width=max(1,11-f*2)
  a.rect((2,3,2+width,46),'#856444')
  for x in range(3,3+width,4):a.line([(x,4),(x,44)],'#b5915d');a.line([(x+2,4),(x+2,44)],'#574431')
  for y in [11,36]:a.line([(2,y),(2+width,y)],'#36535e',3);a.line([(3,y-1),(2+width,y-1)],'#77979a')
  a.rect((1+width,24,3+width,27),GOLD);door.alpha_composite(im,(f*16,0))
 door.save(OUT/'door.png')
 chest=Image.new('RGBA',(32*6,32))
 for f in range(6):
  im=Image.new('RGBA',(32,32));a=Ink(im,(0,0));a.poly([(0,17),(31,17),(31,29),(28,31),(2,31),(0,29)],INK);a.rect((2,18,29,28),'#8d6545')
  for y in [19,24,28]:a.line([(3,y),(28,y)],'#bc9462');a.line([(3,y+1),(28,y+1)],'#5d4937')
  a.rect((3,18,28,19),'#171e29');lift=f*2
  a.poly([(0,15-lift),(3,11-lift),(27,11-lift),(31,15-lift),(31,19-lift),(0,19-lift)],INK);a.poly([(2,15-lift),(5,13-lift),(26,13-lift),(29,15-lift),(29,17-lift),(2,17-lift)],'#b58a56');a.line([(4,13-lift),(26,13-lift)],'#dec18a')
  for x in [6,24]:a.rect((x,14-lift,x+2,18-lift),'#56747c');a.rect((x,20,x+2,28),'#526d76');a.rect((x,21,x,26),'#9fb0a3')
  a.rect((14,17-lift,18,22-lift),GOLD);a.rect((15,18-lift,16,20-lift),'#f0d5a0');chest.alpha_composite(im,(f*32,0))
 chest.save(OUT/'chest.png')
 # Torch pixels share the item palette but have independently moving flame poses.
 atlas=Image.new('RGBA',(16*8,24))
 for f in range(8):
  im=Image.new('RGBA',(16,24));a=Ink(im,(0,0));a.line([(7,22),(8,12)],INK,5);a.line([(7,22),(8,12)],'#9b7650',2);a.line([(5,14),(11,14)],'#719299',2)
  bend=round(math.sin(f*math.pi/4));a.poly([(5,13),(4,8),(6+bend,3),(8,6),(11+bend,2),(12,8),(10,13)],'#aa6546');a.poly([(6,12),(6+bend,7),(8,8),(10,5),(10,11),(8,14)],'#edb967');a.line([(8,11),(8,8)],'#f7df9c',2);atlas.alpha_composite(im,(f*16,0))
 atlas.save(OUT/'torch.png')
 # Twelve irregular tree crowns at a consistent native pixel density.
 atlas=Image.new('RGBA',(256,156))
 palettes=[['#172c34','#29483f','#42684e','#688557','#a0aa73'],['#243139','#3b5349','#59785b','#859568','#b8ba87'],['#162e36','#294b4c','#426959','#638568','#97a77c']]
 for row,palette in enumerate(palettes):
  for col in range(4):
   rng=random.Random(871+row*67+col*113);im=Image.new('RGBA',(64,52));d=ImageDraw.Draw(im)
   centers=[(rng.randrange(9,55),rng.randrange(10,41),rng.randrange(6,12)) for _ in range(30)]
   for x,y,r in sorted(centers,key=lambda p:p[1]):
    pts=[(round(x+math.cos(a*math.tau/10)*r),round(y+math.sin(a*math.tau/10)*r*.7))for a in range(10)];d.polygon(pts,fill=palette[0]);d.polygon([(xx,yy-2)for xx,yy in pts[1:]],fill=palette[1])
    for i in range(6):
     lx=x+rng.randrange(-r+2,r-1);ly=y+rng.randrange(-r//2,r//3);d.line([(lx,ly),(lx+3,ly-1),(lx+4,ly)],fill=palette[2 if ly>y-2 else 3],width=2)
    d.line([(x-r//2,y-r//2),(x,y-r//2-2),(x+3,y-r//2)],fill=palette[4])
   atlas.alpha_composite(im,(col*64,row*52))
 atlas.save(OUT/'canopy.png')
 # Repeating bark segments and flared roots are textured, never stretched.
 im=Image.new('RGBA',(48,16));a=Ink(im,(0,0))
 for i in range(4):
  x=i*12;a.poly([(x+2,0),(x+9,0),(x+11,15),(x,15)],INK);a.poly([(x+3,0),(x+7,0),(x+9,15),(x+2,15)],'#8e7354');a.line([(x+4,0),(x+4,5),(x+6,8),(x+5,15)],'#c1a16e');a.line([(x+7,2),(x+6,6),(x+8,10),(x+7,14)],'#4d4a40',2);a.line([(x+2,4),(x+3,7)],'#67705a')
 im.save(OUT/'bark.png')
 im=Image.new('RGBA',(32,16));a=Ink(im,(16,15));a.poly([(-15,0),(-9,-3),(-5,-7),(-4,-15),(3,-15),(5,-6),(11,-2),(15,0)],INK);a.poly([(-10,-1),(-4,-6),(-2,-15),(1,-15),(3,-5),(10,-1)],'#8e7354');a.line([(-3,-4),(-1,-10),(-1,-14)],'#c1a16e');a.line([(1,-5),(3,-3),(7,-2)],'#b39462');im.save(OUT/'roots.png')
if __name__=='__main__':creatures();terrain();props()

def backgrounds():
 from PIL import ImageDraw
 # One authored pixel density for all three atmospheric silhouettes.
 for layer in range(3):
  rng=random.Random(581+layer*177);im=Image.new('RGBA',(960,540));d=ImageDraw.Draw(im)
  palette=[['#7e9697','#94a79f','#677f89'],['#617d82','#789191','#496874'],['#3d5c69','#5e7b7f','#2f495d']][layer]
  base=345+layer*49;ridge=[(0,540)];ys=[]
  for x in range(0,961,3):
   height=28+math.sin(x*.017+layer)*17+math.sin(x*.047+layer*4)*8
   ys.append(round(base-height));ridge.append((x,round(base-height)))
  ridge.extend([(960,540)]);d.polygon(ridge,fill=palette[0])
  for i in range(18):
   x=rng.randrange(-20,960);w=rng.randrange(9,25);h=rng.randrange(17,70);y=base-rng.randrange(8,25)
   points=[(x,y+25),(x+1,y-h+5),(x+w//3,y-h),(x+w//2,y-h+6),(x+w-3,y-h+3),(x+w,y+24)]
   d.polygon(points,fill=palette[0]);d.line(points[1:4],fill=palette[1]);d.polygon([(x+w//2,y-h+9),(x+w-3,y-h+6),(x+w-1,y+19),(x+w//2,y+8)],fill=palette[2])
   for k in range(2):
    yy=y-h+15+k*12;d.line([(x+2,yy),(x+w//2,yy+2)],fill=palette[2])
  im.save(OUT/f'background_{layer}.png')
 clouds=Image.new('RGBA',(256,24))
 for f in range(4):
  im=Image.new('RGBA',(64,24));d=ImageDraw.Draw(im);rng=random.Random(f+889)
  for i in range(8):
   x=7+i*7;y=12+rng.randrange(-3,3);r=rng.randrange(4,9)
   d.polygon([(x-r,y+2),(x-r+2,y-2),(x,y-r//2),(x+r-2,y-2),(x+r,y+3),(x+2,y+5)],fill='#b4c0af');d.line([(x-r+3,y-2),(x,y-r//2),(x+3,y-2)],fill='#d7dac1')
  clouds.alpha_composite(im,(f*64,0))
 clouds.save(OUT/'clouds.png')
 for kind in ['sun','moon']:
  im=Image.new('RGBA',(40,40));d=ImageDraw.Draw(im);c=(20,20)
  d.ellipse((2,2,38,38),fill=(219,195,133,12) if kind=='sun' else(139,180,206,12));d.ellipse((6,6,34,34),fill=(242,211,151,30) if kind=='sun' else(151,186,202,25))
  if kind=='sun':
   d.polygon([(12,12),(17,9),(24,9),(29,14),(31,20),(28,27),(22,31),(15,29),(10,23),(9,17)],fill='#d8a568');d.polygon([(13,13),(18,10),(24,11),(28,16),(28,22),(24,27),(17,26),(12,21)],fill='#f0d298');d.line([(14,14),(18,12),(23,12)],fill='#f4e6bb',width=2)
  else:
   d.ellipse((10,10,30,30),fill='#b8cbbb');d.ellipse((17,8,34,27),fill='#5a7386');d.line([(14,17),(16,15),(18,16)],fill='#7b98a2',width=2);d.line([(14,23),(17,24),(19,23)],fill='#839ea0');d.point((12,20),fill='#dfdfbd')
  im.save(OUT/f'{kind}.png')
 # New menu matte: carved roots frame a quiet basalt horizon, center stays clear.
 im=Image.new('RGBA',(960,540));d=ImageDraw.Draw(im)
 for y in range(540):
  t=y/539;d.line((0,y,959,y),fill=(round(15+t*8),round(27+t*11),round(38+t*9),255))
 for layer in range(3):im.alpha_composite(Image.open(OUT/f'background_{layer}.png'))
 d=ImageDraw.Draw(im)
 for side in [-1,1]:
  for i in range(5):
   x=55+i*26 if side<0 else 905-i*26
   pts=[(x,540),(x+side*12,430),(x+side*8,300),(x-side*12,200),(x-side*36,111),(x-side*82,42),(x-side*122,5)]
   d.line(pts,fill='#10202b',width=35-i*3);d.line([(xx-side*7,yy)for xx,yy in pts],fill='#2a4247',width=3)
   for j in range(2,6):
    xx,yy=pts[j];d.line([(xx,yy),(xx-side*33,yy-9),(xx-side*55,yy-32)],fill='#142933',width=7);d.line([(xx,yy-2),(xx-side*32,yy-12)],fill='#3c5350',width=1)
 for i in range(54):
  x=(i*173+29)%960;y=(i*113+17)%540
  if x<220 or x>740:d.rectangle((x,y,x+1,y+1),fill='#a17d54' if i%3 else '#607e7c')
 im.save(OUT/'menu.png')
if __name__=='__main__':backgrounds()
