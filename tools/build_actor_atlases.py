"""Original pixel animation atlases, CC0-1.0. Pillow is an offline art tool only."""
from pathlib import Path
from PIL import Image, ImageDraw
import math,sys
ROOT=Path(__file__).resolve().parents[1]/'assets/actors'
ROOT.mkdir(exist_ok=True)
COUNTS=[4,8,6,4,6,3,6]
INK='#202932'; BARK='#83644d'; MOSS='#b0c393'; IVORY='#d6d5b6'
def make(kind):
 atlas=Image.new('RGBA',(512,336))
 for row,count in enumerate(COUNTS):
  for frame in range(8):
   t=min(frame,count-1)/max(1,count-1)
   phase=frame/max(1,count)*math.tau
   im=Image.new('RGBA',(64,48));d=ImageDraw.Draw(im)
   def p(points,color):d.polygon([(round(x+32),round(y+46)) for x,y in points],fill=color)
   def line(points,color,w=1):d.line([(round(x+32),round(y+46)) for x,y in points],fill=color,width=w)
   def limb(a,b,c,color,w=3):
    line([a,b,c],INK,w+2)
    for x,y in [a,b,c]:d.ellipse((round(x+32-w/2-1),round(y+46-w/2-1),round(x+32+w/2+1),round(y+46+w/2+1)),fill=INK)
    line([a,b,c],color,w)
   prep=t if row==2 else 0
   strike=(1-t*.65) if row==3 else (.35*(1-t) if row==4 else 0)
   hurt=math.sin(t*math.pi) if row==5 else 0
   death=t if row==6 else 0
   step=math.sin(phase) if row==1 else 0
   breath=math.sin(phase) if row==0 else 0
   if kind=='seamling':
    cy=-17+breath+prep*3+hurt*2+death*10; cx=-prep*2+strike*4-hurt*2
    # Two unequal legs remain anchored to the torso. Support foot stays at y0.
    for side in [-1,1]:
     ft=(frame/count+(0.5 if side<0 else 0))%1
     if ft<.6:xx=4-8*ft/.6;yy=0
     else:xx=-4+8*(ft-.6)/.4;yy=-math.sin((ft-.6)/.4*math.pi)**2*3
     foot=(side*6+(xx if row==1 else 0),yy if row==1 else 0)
     limb((cx+side*3,cy+7),(side*7,cy+12),foot,'#685348',3 if side<0 else 4)
    p([(cx-7,cy+7),(cx-9,cy-4),(cx-5,cy-11+prep*2),(cx+3,cy-13+prep*3),(cx+8,cy-5),(cx+6,cy+6),(cx,cy+10)],INK)
    p([(cx-6,cy+4),(cx-6,cy-5),(cx-3,cy-10),(cx-1,cy+4)],BARK)
    p([(cx+1,cy-10),(cx+5,cy-6),(cx+5,cy+4),(cx+2,cy+7)],'#a0835b')
    line([(cx-3,cy-9),(cx-2,cy-1),(cx+4,cy+2)],MOSS,2)
    line([(cx+2,cy-8),(cx+3,cy-5)],IVORY,1)
    limb((cx-5,cy-5),(cx-10-prep*2,cy+1),(cx-8+strike*3,cy+7),'#6c5746',2)
    limb((cx+5,cy-5),(cx+10-prep*4,cy-2),(cx+9+strike*10-prep*5,cy+5-strike*5),BARK,3)
   elif kind=='hollowbeak':
    cy=-10+breath+prep*2+death*8;cx=strike*2-hurt*2
    for i in range(3):
     x=-9+i*8;lift=max(0,math.sin(phase+i*math.pi))*2 if row==1 else 0
     limb((x,cy+3),(x-2,-3-lift),(x+2,-lift),'#7c8c80',2)
    p([(cx-12,cy+3),(cx-13,cy-6),(cx-7,cy-13),(cx+3,cy-16),(cx+12,cy-13),(cx+16,cy-6),(cx+11,cy+2),(cx+2,cy+6)],INK)
    p([(cx-10,cy),(cx-9,cy-6),(cx-4,cy-11),(cx+4,cy-13),(cx+10,cy-11),(cx+12,cy-6),(cx+8,cy),(cx,cy+3)],'#84928b')
    p([(cx+1,cy-10),(cx+8,cy-10),(cx+11+strike*3,cy-6),(cx+7,cy-2),(cx+1,cy-1),(cx-2,cy-5)],'#24323b')
    line([(cx-8,cy-7),(cx-3,cy-11),(cx+3,cy-12)],'#b9c2a6',2)
    line([(cx+2,cy),(cx+7,cy-1)],'#b4aa8b',1)
   elif kind=='ashweaver':
    fold=prep if row==2 else (.2*(1-t) if row==4 else (.6-.4*t if row==3 else 0))
    spread=(16-11*fold)*(1-death*.65);cy=-9+breath+death*6+hurt*3
    flap=math.sin(phase)*4 if row in [0,1] else -prep*3
    p([(-spread,cy-4+flap),(-5,cy-9),(0,cy-5),(5,cy-9),(spread,cy-4-flap),(11,cy+4),(3,cy+1),(0,cy+7),(-4,cy+1),(-12,cy+4)],INK)
    p([(-spread+2,cy-3+flap),(-6,cy-7),(-2,cy-3),(-5,cy+1),(-11,cy+2)],'#8a9a9b')
    p([(spread-2,cy-3-flap),(6,cy-7),(2,cy-3),(5,cy+1),(11,cy+2)],'#506c77')
    p([(-3,cy-5),(0,cy-8),(3,cy-5),(2,cy+4),(0,cy+6),(-2,cy+2)],IVORY)
    line([(-1,cy-5),(2,cy-4)],'#bd8058',2)
   elif kind=='void_collector':
    lift=prep*5;cx=-prep*2+strike*4-hurt;cy=-12+breath+death*9
    for side in [-1,1]:
     for off in [-8,6]:limb((off,cy+6),(off+side*3,-4),(off+side*4+step*side*2,0),'#70665b',3)
    old_p,old_line=p,line
    def p(points,color):old_p([(x+cx,y) for x,y in points],color)
    def line(points,color,w=1):old_line([(x+cx,y) for x,y in points],color,w)
    p([(-18,cy+6),(-17,cy-6),(-11,cy-12),(4,cy-13),(13,cy-8-lift),(19,cy+1-lift),(16,cy+10),(4,cy+11),(-9,cy+8)],INK)
    p([(-15,cy+4),(-13,cy-4),(-7,cy-9),(4,cy-9),(12,cy-5-lift),(15,cy+3-lift),(10,cy+7),(-4,cy+7)],'#796c57')
    p([(-14,cy-4),(-12,cy-15),(-3,cy-18),(1,cy-13),(-4,cy-4)],'#d2ceb0')
    p([(-1,cy-7),(2,cy-17),(9,cy-15),(13,cy-8),(6,cy-4)],'#8a9b98')
    p([(10,cy-7-lift),(17,cy-3-lift),(21,cy+3-lift),(18,cy+11-lift),(12,cy+10-lift)],'#b98659')
    line([(13,cy-4-lift),(16,cy+4-lift)],'#e2cd9e',2)
   elif kind=='ashling':
    cy=-7+breath+prep*2+death*5;cx=strike*3-hurt
    for side in [-1,1]:limb((side*4,cy+3),(side*7,-2),(side*6+step*side*2,0),'#344752',2)
    p([(cx-9,cy+6),(cx-10,cy),(cx-6,cy-7),(cx-2,cy-10),(cx+5,cy-8),(cx+10,cy),(cx+8,cy+6)],INK)
    p([(cx-7,cy+3),(cx-7,cy-2),(cx-3,cy-7),(cx+3,cy-6),(cx+7,cy),(cx+5,cy+4)],'#596d74')
    line([(cx,cy-7),(cx+2,cy-2),(cx,cy+2)],'#24313d',2)
    line([(cx+2,cy-4),(cx+6,cy-4)],'#e4a567',2)
   else:
    cy=-10+math.sin(phase)*2+death*6+hurt*2
    for i in range(3):
     p([(-5+i*3,cy+2),(i*3-4,cy+13+math.sin(phase+i)*3),(i*3,cy+8), (3+i,cy)],'#526e74')
    p([(-7,cy),(-5,cy-9),(0,cy-15),(5,cy-11),(7,cy-3),(4,cy+4),(0,cy+1),(-4,cy+5)],'#273b48')
    p([(-4,cy-3),(-2,cy-11),(3,cy-10),(5,cy-4),(1,cy)],'#a2b3aa')
    line([(0,cy-8),(3,cy-8)],'#29313b',2)
   if row==6:
    # Dissolving silhouette is a proper short sequence, not a rotating rectangle.
    pix=im.load()
    for y in range(48):
     for x in range(64):
      if ((x*13+y*7)%19)/19 < death*.9:pix[x,y]=(0,0,0,0)
   atlas.alpha_composite(im,(frame*64,row*48))
 atlas.save(ROOT/(kind+'.png'))
if __name__=='__main__':
 for kind in (sys.argv[1:] or ['seamling','hollowbeak','ashweaver','void_collector','ashling','spirit']):make(kind)
