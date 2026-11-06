"""Original Emberdepths creature pixel sprites. CC0-1.0, no source imagery."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]/'assets/creatures'
ROOT.mkdir(exist_ok=True)

def polygon(points,color): return f'<polygon points="{points}" fill="{color}"/>'
def path(d,color): return f'<path d="{d}" fill="{color}"/>'
def make(kind):
 frames=[]
 for frame in range(4):
  art=''
  if kind=='seamling':
   art+=polygon('-10,0 -9,-13 -6,-14 -4,-5 -5,0','#302d35')+polygon('3,0 5,-16 8,-15 8,-3 10,-1','#463f3c')
   art+=polygon('-9,-14 -11,-23 -5,-28 2,-30 8,-24 7,-12 1,-8','#302d35')
   art+=polygon('-8,-18 -7,-25 -4,-26 -3,-16','#8c6a50')+polygon('0,-28 4,-27 6,-20 3,-13 0,-15','#715b4c')
   art+=path('M-5 -25h2v8h-2zM-2 -16h7v2h-7zM2 -24h2v3H2z','#c7d4a0')
   art+=polygon('-8,-22 -15,-16 -13,-13 -5,-18','#665442')
  elif kind=='hollowbeak':
   art+=path('M-11 -5h3v5h-5v-2h2zM0 -4h3v4h-5v-2h2zM9 -5h3v5H7v-2h2z','#6c807e')
   art+=polygon('-13,-5 -12,-15 -7,-21 2,-25 11,-24 16,-17 13,-8 5,-4','#25313c')
   art+=polygon('-10,-9 -10,-15 -5,-20 3,-23 10,-22 13,-17 10,-10 4,-7','#708383')
   art+=polygon('1,-20 9,-21 12,-17 9,-12 3,-11 -1,-15','#1b2832')
   art+=path('M-7 -17h4v2h-4zM2 -23h6v2H2zM3 -11h6v1H3z','#b1beb0')
  elif kind=='ashweaver':
   spread=15 if frame in [0,3] else (5 if frame==1 else 10)
   art+=polygon(f'-{spread},-11 -6,-17 0,-12 6,-17 {spread},-11 11,-3 3,-6 0,-1 -3,-6 -11,-3','#23313e')
   art+=polygon(f'-{spread-2},-10 -6,-14 -1,-9 -4,-5 -10,-5','#7c8e98')
   art+=polygon(f'{spread-2},-10 6,-14 1,-9 4,-5 10,-5','#506978')
   art+=polygon('-3,-11 0,-14 3,-11 2,-3 0,-1 -2,-4','#c6c7af')
   art+=path('M-1 -11h3v2h-3z','#bd8058')
  else:
   art+=path('M-14 -4h4v4h-6v-2h2zM-3 -4h4v4h-6v-2h2zM8 -4h4v4H6v-2h2z','#696361')
   art+=polygon('-18,-5 -16,-18 -11,-23 5,-25 13,-18 18,-12 16,-3 6,-2 -6,-3','#292c35')
   art+=polygon('-16,-8 -13,-18 -7,-20 4,-19 11,-13 10,-5 0,-4','#6b655d')
   art+=polygon('-13,-17 -12,-27 -3,-30 1,-25 -3,-17','#c9c8ac')
   art+=polygon('-1,-20 1,-29 9,-27 13,-21 7,-16','#8c9e9e')
   art+=polygon('-9,-24 -6,-25 -4,-18 -8,-17','#686356')
   art+=polygon('9,-21 17,-17 20,-10 17,-2 11,-3 10,-10','#b7875d')
   art+=path('M12 -17h3v9h-3zM-14 -10h4v2h-4z','#ded3ad')
  sx,sy,dx=(1,1,0)
  if frame==1: sx,sy=.88,.86
  if frame==2: sx,sy,dx=1.10,1.02,2
  frames.append(f'<g transform="translate({frame*64+32+dx} 46) scale({sx} {sy})">{art}</g>')
 return '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="48" shape-rendering="crispEdges">'+''.join(frames)+'</svg>'
for kind in ['seamling','hollowbeak','ashweaver','void_collector']:
 (ROOT/(kind+'.svg')).write_text(make(kind))
