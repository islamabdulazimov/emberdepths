"""Julia and Cameron: original four-frame idle pixel sprites, CC0-1.0."""
from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1]/'assets/actors'
for kind in ['julia','cameron']:
 atlas=Image.new('RGBA',(128,40))
 for frame in range(4):
  im=Image.new('RGBA',(32,40));d=ImageDraw.Draw(im);nod=-1 if frame==1 else 0
  ink='#202932';skin='#d6af92' if kind=='julia' else '#be927b'
  d.polygon([(11,36),(11,27),(15,26),(16,35),(15,38),(10,38)],fill=ink)
  d.polygon([(17,36),(17,27),(21,27),(22,36),(23,38),(17,38)],fill=ink)
  d.rectangle((12,28,14,35),fill='#3d4b55');d.rectangle((18,28,20,35),fill='#45545c')
  d.polygon([(10,22),(13,19),(20,19),(23,23),(22,30),(12,30)],fill=ink)
  d.polygon([(12,22),(20,21),(21,29),(13,29)],fill='#647a79' if kind=='cameron' else '#69718b')
  d.line([(11,23),(9,28),(11,31)],fill=ink,width=4);d.line([(22,23),(24,28),(22,31)],fill=ink,width=4)
  d.line([(10,24),(9,28)],fill='#536b6c',width=2);d.line([(23,24),(24,28)],fill='#536b6c',width=2)
  d.rectangle((9,29,11,31),fill=skin);d.rectangle((22,29,24,31),fill=skin)
  d.polygon([(11,10+nod),(15,7+nod),(22,10+nod),(23,19+nod),(20,22+nod),(12,20+nod)],fill=ink)
  d.rectangle((13,11+nod,21,19+nod),fill=skin)
  if kind=='julia':
   d.polygon([(10,12+nod),(11,9+nod),(16,7+nod),(22,9+nod),(24,14+nod),(24,27+nod),(21,24+nod),(21,11+nod),(14,11+nod),(12,24+nod),(9,26+nod)],fill='#332e38')
   d.line([(10,13+nod),(12,8+nod),(21,8+nod),(24,13+nod)],fill='#ae815b',width=2)
   d.rectangle((9,13+nod,11,18+nod),fill='#b88a61');d.rectangle((23,13+nod,25,18+nod),fill='#b88a61')
   d.rectangle((13,13+nod,16,16+nod),outline='#e0d8b8');d.rectangle((18,13+nod,21,16+nod),outline='#e0d8b8');d.line((16,14+nod,18,14+nod),fill='#e0d8b8')
  else:
   d.polygon([(11,13+nod),(11,9+nod),(15,7+nod),(22,9+nod),(23,13+nod),(19,11+nod),(16,12+nod),(14,11+nod)],fill='#443739')
   d.line([(12,21),(16,24),(21,21)],fill='#253e44',width=2)
   d.rectangle((15,25,21,28),fill='#c3c1a8');d.line((16,26,18,26),fill=ink);d.line((17,25,17,27),fill=ink);d.point((20,26),fill='#b87855')
  if frame!=3:
   d.point((15,14+nod),fill=ink);d.point((20,14+nod),fill=ink)
  d.line((16,18+nod,19,18+nod),fill='#8a6559')
  atlas.alpha_composite(im,(frame*32,0))
 atlas.save(root/(kind+'.png'))
