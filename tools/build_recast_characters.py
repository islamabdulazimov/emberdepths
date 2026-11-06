"""Original Andrew and resident pixel animation artwork. CC0-1.0."""
from build_recast_art import Ink,OUT,INK,GOLD,mix,shade
from PIL import Image
import math,json
PHASES=['intro','chase','uppercut_windup','uppercut_active','uppercut_recovery','spin_windup','spin_active','spin_recovery','backflip','super_windup','super_flight','super_impact','super_recovery','stunned','hurt','death']
def boss_pose(phase,t):
 ease=t*t*(3-2*t);p={'lh':(-25,-22),'le':(-30,-35),'rh':(27,-22),'re':(31,-35),'lf':(-11,0),'rf':(11,0),'dy':0,'dx':0,'turn':1.0,'tuck':0,'rotation':0}
 if phase=='intro':
  u=math.sin(t*math.pi);p.update(lh=mix((-25,-22),(-28,-67),u),le=mix((-30,-35),(-39,-48),u),rh=mix((27,-22),(28,-67),u),re=mix((31,-35),(39,-48),u))
 elif phase=='chase':
  def step(t,side):
   u=(t+(.5 if side<0 else 0))%1
   if u<.6:return(side*11+8-16*u/.6,0)
   u=(u-.6)/.4;return(side*11-8+16*(3*u*u-2*u*u*u),-math.sin(u*math.pi)**2*5)
  p['lf']=step(t,-1);p['rf']=step(t,1);p['rh']=(27-math.sin(t*math.tau)*5,-22);p['lh']=(-25+math.sin(t*math.tau)*5,-22)
 elif phase=='uppercut_windup':p.update(rh=mix((27,-22),(6,-30),ease),re=mix((31,-35),(17,-23),ease),lh=(-19,-43),dy=4*ease,dx=-3*ease)
 elif phase=='uppercut_active':
  u=.9+.1*(1-(1-t)**3);p.update(rh=mix((6,-30),(30,-80),u),re=mix((17,-23),(35,-51),u),lh=(-19,-43),dy=4-7*u,dx=-3+7*u)
 elif phase=='uppercut_recovery':p.update(rh=mix((30,-80),(27,-22),ease),re=mix((35,-51),(31,-35),ease),dy=-3*(1-ease),dx=4*(1-ease))
 elif phase=='spin_windup':p.update(rh=mix((27,-22),(-8,-47),ease),re=(20,-40),lh=mix((-25,-22),(-36,-44),ease))
 elif phase=='spin_active':p.update(rh=(53,-43),re=(36,-43),lh=(-53,-43),le=(-36,-43),turn=.2+.8*abs(math.cos(t*math.tau)),back=math.cos(t*math.tau)<0)
 elif phase=='spin_recovery':p.update(rh=mix((53,-43),(27,-22),ease),re=mix((36,-43),(31,-35),ease),lh=mix((-53,-43),(-25,-22),ease),le=mix((-36,-43),(-30,-35),ease))
 elif phase=='backflip':
  tuck=math.sin(t*math.pi);p.update(rh=mix((27,-22),(13,-35),tuck),lh=mix((-25,-22),(-13,-35),tuck),lf=(-8,-16*tuck),rf=(9,-15*tuck),rotation=-360*t,tuck=tuck)
 elif phase=='super_windup':p.update(rh=(22,-56),re=(31,-38),lh=(-22,-56),le=(-31,-38),dy=6*ease,lf=(-14,0),rf=(14,0))
 elif phase=='super_flight':p.update(rh=mix((17,-74),(29,-35),ease),re=(26,-52),lh=mix((-17,-74),(-29,-35),ease),le=(-26,-52),lf=(-10,-12*(1-ease)),rf=(10,-12*(1-ease)))
 elif phase=='super_impact':p.update(rh=(30,-5),re=(31,-24),lh=(-30,-5),le=(-31,-24),dy=8*(1-t*.25),lf=(-18,0),rf=(18,0))
 elif phase=='super_recovery':p.update(rh=mix((30,-5),(27,-22),ease),re=mix((31,-24),(31,-35),ease),lh=mix((-30,-5),(-25,-22),ease),le=mix((-31,-24),(-30,-35),ease),dy=6*(1-ease))
 elif phase in ['stunned','hurt']:p.update(rh=(30,-11),re=(30,-28),lh=(-28,-12),le=(-29,-29),dy=3,dx=math.sin(t*math.pi*2)*2*(1-t))
 elif phase=='death':p.update(rh=(32,-5),re=(31,-20),lh=(-29,-5),le=(-30,-23),lf=(-22,0),rf=(24,0),dy=15*ease)
 return p
RIG=[]
def boss_frame(phase,t,p):
 im=Image.new('RGBA',(128,128));a=Ink(im,(64,112));dx=p['dx'];dy=p['dy'];skin='#d9b08b';shade1='#a77965';shade2='#76564f';hi='#f1cfa3'
 def arm(side,joint,hand):
  shoulder=(side*18+dx,-46+dy);joint=(joint[0]+dx,joint[1]+dy);hand=(hand[0]+dx,hand[1]+dy)
  a.limb(shoulder,joint,hand,(skin if side>0 else shade1,hi if side>0 else skin,shade2),9)
  # Deltoid/biceps volume has a deliberate lit plane, wrist wraps and knuckles.
  mid=mix(shoulder,joint,.45);a.oval((mid[0]-4,mid[1]-4,mid[0]+3,mid[1]+3),skin if side>0 else shade1);a.line([(mid[0]-2,mid[1]-2),(mid[0]+1,mid[1]-3)],hi if side>0 else skin,2)
  wrist=mix(hand,joint,.2);a.line([(wrist[0]-3,wrist[1]),(wrist[0]+3,wrist[1])],'#735242',3);a.line([(wrist[0]-2,wrist[1]-1),(wrist[0]+2,wrist[1]-1)],GOLD)
  a.oval((hand[0]-5,hand[1]-4,hand[0]+4,hand[1]+4),INK);a.oval((hand[0]-4,hand[1]-3,hand[0]+3,hand[1]+3),skin if side>0 else shade1);a.line([(hand[0]-2,hand[1]-2),(hand[0]+1,hand[1]-2)],hi if side>0 else skin)
 # Long hair behind trapezius, then rear arm/legs, then torso and front arm.
 a.poly([(-13+dx,-69+dy),(-8+dx,-77+dy),(7+dx,-77+dy),(13+dx,-69+dy),(15+dx,-39+dy),(8+dx,-43+dy),(2+dx,-38+dy),(-8+dx,-42+dy),(-15+dx,-40+dy)],INK)
 arm(-1,p['le'],p['lh'])
 for side,foot in [(-1,p['lf']),(1,p['rf'])]:
  hip=(side*10+dx,-14+dy);knee=mix(hip,foot,.5);knee=(knee[0]+side*2,knee[1]-1)
  a.limb(hip,knee,(foot[0],foot[1]-3),(shade1 if side<0 else skin,skin if side<0 else hi,shade2),7)
  a.poly([(foot[0]-6,foot[1]-6),(foot[0]+4,foot[1]-6),(foot[0]+8,foot[1]-2),(foot[0]+7,foot[1]),(foot[0]-6,foot[1])],INK);a.rect((foot[0]-4,foot[1]-4,foot[0]+4,foot[1]-2),'#40515c');a.line([(foot[0]-3,foot[1]-5),(foot[0]+2,foot[1]-5)],GOLD)
 a.poly([(-19+dx,-48+dy),(-11+dx,-55+dy),(9+dx,-55+dy),(21+dx,-47+dy),(23+dx,-38+dy),(26+dx,-26+dy),(24+dx,-17+dy),(16+dx,-11+dy),(-14+dx,-11+dy),(-25+dx,-17+dy),(-27+dx,-25+dy),(-24+dx,-36+dy),(-25+dx,-43+dy)],INK)
 a.poly([(-18+dx,-46+dy),(-10+dx,-52+dy),(9+dx,-52+dy),(19+dx,-45+dy),(20+dx,-36+dy),(23+dx,-26+dy),(20+dx,-18+dy),(12+dx,-14+dy),(-12+dx,-14+dy),(-22+dx,-19+dy),(-24+dx,-27+dy),(-21+dx,-36+dy),(-22+dx,-43+dy)],skin)
 a.poly([(-20+dx,-44+dy),(-15+dx,-48+dy),(-17+dx,-37+dy),(-14+dx,-29+dy),(-16+dx,-19+dy),(-22+dx,-23+dy),(-23+dx,-30+dy)],shade1)
 # Separate pectoral planes and a heavy belly, not a stack of armour boxes.
 for side in [-1,1]:
  a.oval((side*8-8+dx,-49+dy,side*8+8+dx,-36+dy),shade1)
  a.oval((side*8-7+dx,-49+dy,side*8+7+dx,-39+dy),skin)
  a.line([(side*8-5+dx,-47+dy),(side*8+2+dx,-48+dy)],hi,2)
  a.line([(side*8-4+dx,-37+dy),(side*8+3+dx,-38+dy)],shade2)
 a.oval((-20+dx,-36+dy,23+dx,-13+dy),shade1);a.oval((-18+dx,-36+dy,21+dx,-16+dy),skin);a.oval((-13+dx,-35+dy,15+dx,-22+dy),hi);a.line([(-3+dx,-19+dy),(0+dx,-20+dy),(2+dx,-19+dy)],shade2)
 a.line([(-3+dx,-43+dy),(0+dx,-45+dy),(3+dx,-43+dy)],shade1)
 a.poly([(-19+dx,-15+dy),(-9+dx,-12+dy),(11+dx,-12+dy),(20+dx,-16+dy),(18+dx,-10+dy),(10+dx,-7+dy),(-10+dx,-7+dy),(-18+dx,-10+dy)],'#29313a');a.line([(-17+dx,-13+dy),(17+dx,-13+dy)],'#9c7853',3);a.rect((-3+dx,-15+dy,3+dx,-10+dy),GOLD);a.rect((-1+dx,-14+dy,1+dx,-12+dy),INK)
 a.poly([(-10+dx,-8+dy),(10+dx,-8+dy),(10+dx,-1+dy),(5+dx,-3+dy),(0+dx,0+dy),(-7+dx,-2+dy)],'#4a454a');a.line([(-7+dx,-7+dy),(-5+dx,-2+dy)],'#786153');a.line([(5+dx,-7+dy),(6+dx,-3+dy)],'#786153')
 # Strong neck, long dark locks, square jaw and brows.
 a.rect((-6+dx,-60+dy,6+dx,-49+dy),shade1);a.poly([(-11+dx,-69+dy),(-7+dx,-74+dy),(7+dx,-74+dy),(12+dx,-68+dy),(11+dx,-58+dy),(7+dx,-53+dy),(-7+dx,-53+dy),(-12+dx,-58+dy)],INK)
 a.poly([(-8+dx,-67+dy),(-5+dx,-71+dy),(6+dx,-71+dy),(9+dx,-66+dy),(9+dx,-58+dy),(5+dx,-55+dy),(-5+dx,-55+dy),(-9+dx,-59+dy)],skin);a.line([(-7+dx,-65+dy),(-7+dx,-59+dy),(-3+dx,-56+dy)],shade1,2);a.line([(-3+dx,-70+dy),(5+dx,-70+dy)],hi)
 a.poly([(-12+dx,-65+dy),(-11+dx,-71+dy),(-6+dx,-77+dy),(6+dx,-76+dy),(12+dx,-70+dy),(10+dx,-65+dy),(5+dx,-69+dy),(-1+dx,-69+dy),(-5+dx,-65+dy),(-6+dx,-45+dy),(-12+dx,-42+dy)],'#392f35');a.line([(-8+dx,-67+dy),(-9+dx,-48+dy)],'#6e5050',2);a.line([(-7+dx,-73+dy),(-2+dx,-75+dy),(5+dx,-73+dy)],'#74564f')
 a.line([(10+dx,-65+dy),(12+dx,-46+dy)],'#4b3940',3);a.line([(-3+dx,-64+dy),(1+dx,-65+dy)],shade2,2);a.line([(4+dx,-65+dy),(8+dx,-64+dy)],shade2,2);a.rect((-1+dx,-63+dy,0+dx,-62+dy),INK);a.rect((6+dx,-63+dy,7+dx,-62+dy),INK);a.line([(3+dx,-62+dy),(4+dx,-59+dy)],hi,2);a.line([(0+dx,-57+dy),(7+dx,-57+dy)],shade2);a.line([(-2+dx,-55+dy),(6+dx,-55+dy)],hi)
 if p.get('back',False):
  a.poly([(-10+dx,-71+dy),(8+dx,-72+dy),(12+dx,-64+dy),(13+dx,-44+dy),(6+dx,-47+dy),(2+dx,-41+dy),(-8+dx,-46+dy),(-12+dx,-59+dy)],'#392f35')
  a.line([(-7+dx,-65+dy),(-8+dx,-49+dy)],'#6e5050',2);a.line([(6+dx,-66+dy),(8+dx,-48+dy)],'#6e5050')
 arm(1,p['re'],p['rh'])
 if p['turn']!=1:
  width=max(1,round(128*p['turn']));im2=Image.new('RGBA',(128,128));im2.alpha_composite(im.resize((width,128),Image.Resampling.NEAREST),((128-width)//2,0));im=im2
 if p['rotation']!=0:im=im.rotate(p['rotation'],resample=Image.Resampling.NEAREST,center=(64,75))
 if phase=='death':
  pix=im.load()
  for y in range(128):
   for x in range(128):
    if ((x*17+y*11)%37)/37<t*.95:pix[x,y]=(0,0,0,0)
 return im

def andrew():
 atlas=Image.new('RGBA',(1536,len(PHASES)*128));rig=[]
 for ri,phase in enumerate(PHASES):
  frames=[]
  for f in range(12):
   t=f/11;p=boss_pose(phase,t);frames.append(p);atlas.alpha_composite(boss_frame(phase,t,p),(f*128,ri*128))
  rig.append(frames)
 atlas.save(OUT/'andrew.png');data={'phases':PHASES,'poses':rig};(OUT/'andrew_rig.json').write_text(json.dumps(data));(OUT/'andrew_rig.gd').write_text('extends RefCounted\nconst DATA := '+json.dumps(data)+'\n')
def residents():
 for kind in ['julia','cameron']:
  atlas=Image.new('RGBA',(40*8,48))
  for f in range(8):
   im=Image.new('RGBA',(40,48));a=Ink(im,(20,44));nod=-1 if f in [1,2] else 0;skin='#caa587' if kind=='julia' else '#b88e74';hy=-29+nod
   for side in [-1,1]:
    a.limb((side*3,-13),(side*4,-7),(side*4,-2),('#34434f','#69767a','#24303e'),3);a.poly([(side*4-3,-4),(side*4+2,-4),(side*4+4,-1),(side*4+3,0),(side*4-3,0)],INK);a.line([(side*4-1,-3),(side*4+2,-2)],'#aa9271')
   if kind=='julia':
    a.poly([(-6,hy-5),(-4,hy-9),(3,hy-8),(7,hy-4),(8,hy+12),(5,hy+10),(2,hy+14),(-4,hy+10),(-8,hy+12)],'#252733');a.line([(-5,hy-2),(-6,hy+9)],'#45444f',2);a.line([(5,hy),(6,hy+9)],'#55505b')
   a.poly([(-7,-23),(0,-25),(6,-23),(8,-17),(6,-10),(-5,-10),(-7,-16)],INK);a.poly([(-5,-22),(0,-23),(4,-22),(6,-17),(4,-12),(-4,-12),(-5,-17)],'#617987' if kind=='julia' else '#496a70');a.line([(-4,-21),(-4,-14)],'#a0a9a3' if kind=='julia' else '#7d9b99',2)
   for side in [-1,1]:a.limb((side*6,-21),(side*8,-15),(side*7,-11),('#516570','#80918f','#2c3c49'),2);a.rect((side*7-1,-13,side*7+1,-11),skin)
   a.poly([(-5,hy-5),(-3,hy-7),(4,hy-6),(6,hy-2),(5,hy+4),(2,hy+6),(-4,hy+4),(-6,hy)],INK);a.poly([(-4,hy-4),(-2,hy-5),(3,hy-5),(4,hy-1),(4,hy+3),(1,hy+4),(-3,hy+3)],skin);a.line([(-3,hy-3),(1,hy-4)],'#e6c4a1');a.line([(-4,hy),(-3,hy+2)],'#926b5b')
   if kind=='julia':
    a.poly([(-6,hy-3),(-5,hy-6),(-1,hy-9),(4,hy-8),(6,hy-4),(2,hy-6),(-1,hy-5),(-3,hy-1),(-6,hy+2)],'#2b2935');a.line([(-4,hy-5),(-1,hy-7),(3,hy-6)],'#57505c')
    a.line([(-7,hy-2),(-6,hy-7),(-1,hy-10),(5,hy-8),(7,hy-2)],'#927353',2);a.rect((-8,hy-2,-6,hy+3),'#314857');a.rect((-8,hy-1,-7,hy+2),'#b99c70');a.rect((6,hy-2,8,hy+3),'#314857');a.rect((7,hy-1,8,hy+2),'#b99c70')
    a.rect((-4,hy-1,-1,hy+2),'#b5c4b7');a.rect((1,hy-1,4,hy+2),'#b5c4b7');a.line([(-1,hy),(1,hy)],'#b5c4b7');a.rect((-3,hy,-2,hy+1),skin);a.rect((2,hy,3,hy+1),skin)
   else:
    a.poly([(-6,hy-2),(-5,hy-6),(-2,hy-9),(4,hy-7),(6,hy-3),(2,hy-5),(0,hy-4),(-2,hy-5),(-4,hy-1)],'#34313b');a.line([(-4,hy-5),(-1,hy-7),(3,hy-6)],'#5f4c4c')
    a.line([(-5,-23),(-2,-20),(3,-22)],'#2d434e',2);a.line([(-2,-21),(-2,-17)],'#c4c4a5');a.line([(2,-21),(2,-17)],'#c4c4a5');a.line([(-3,-14),(3,-14)],'#2b4550');a.rect((0,-18,5,-15),'#acb8ab');a.rect((1,-17,3,-16),'#344652');a.rect((2,-18,2,-15),'#344652');a.rect((4,-17,5,-17),GOLD)
   if f!=6:a.rect((-3,hy,-2,hy+1),INK);a.rect((2,hy,3,hy+1),INK)
   a.line([(-1,hy+3),(2,hy+3)],'#805e54');atlas.alpha_composite(im,(f*40,0))
  atlas.save(OUT/f'npc_{kind}.png')
if __name__=='__main__':andrew();residents()
