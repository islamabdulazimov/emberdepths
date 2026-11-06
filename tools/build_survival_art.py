"""Original CC0 downed poses, recovery binding and coins. Offline Pillow only."""
from pathlib import Path
from PIL import Image,ImageDraw
import math
out=Path(__file__).resolve().parents[1]/'assets/recast'
skins=['e2c3a5','ca9e7e','ac795c','77503f','45302b']
for gender in ['male','female']:
 for hair in ['short','long']:
  for si,skin in enumerate(skins):
   for bare in [False,True]:
    sheet=Image.new('RGBA',(768,64))
    for frame in range(12):
     im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im);b=1 if frame in [3,4,5,6] else 0
     ink='#131c27';cloth='#3d6868';light='#80a7a0'
     # Bent legs and resting shoulders, not a rotated standing frame.
     d.line([(36,47),(43,44),(50,49)],fill=ink,width=5);d.line([(36,46),(43,43),(50,48)],fill='#37434b',width=3)
     d.rectangle((48,48,53,51),fill=ink);d.line([(34,48),(41,49),(49,50)],fill='#24313e',width=4)
     d.polygon([(25,43-b),(34,42-b),(40,46),(37,50),(27,50),(23,47)],fill=ink)
     d.polygon([(25,44-b),(33,43-b),(38,46),(36,48),(27,48)],fill='#'+skin if bare else cloth)
     d.line([(27,43-b),(33,43-b)],fill='#'+skin if bare else light,width=1)
     d.rectangle((15,40,24,48),fill=ink);d.rectangle((17,41,24,47),fill='#'+skin)
     d.line([(16,40),(22,39),(25,41)],fill='#222430',width=3)
     if hair=='long':d.rectangle((13,42,17,50),fill='#222430');d.line([(13,44),(13,49)],fill='#49393b',width=1)
     if gender=='female':d.point((23,44),fill='#bf9260')
     d.line([(19,43),(21,43)],fill=ink);d.point((24,45),fill='#f0d9bb')
     d.line([(30,45-b),(27,49),(22,49)],fill=ink,width=4);d.line([(29,45-b),(26,48),(22,48)],fill='#'+skin,width=2)
     if not bare:d.line([(30,45-b),(28,47)],fill=cloth,width=3);d.line([(35,45),(36,48)],fill='#bf9260',width=2)
     sheet.paste(im,(frame*64,0))
    sheet.save(out/f'downed_{gender}_{hair}_{si}_{"bare" if bare else "coat"}.png')
for part in ['head','body','legs']:
 sheet=Image.new('RGBA',(768,64))
 for frame in range(12):
  im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im);b=1 if frame in [3,4,5,6] else 0
  if part=='head':d.polygon([(14,40),(19,38),(24,40),(24,42),(15,43)],fill='#503b2b');d.line([(15,40),(20,39),(23,40)],fill='#d3b374',width=2)
  if part=='body':d.polygon([(27,43-b),(33,42-b),(39,46),(36,49),(28,48)],fill='#73543a');d.line([(28,43-b),(34,43-b),(37,46)],fill='#b58a57',width=2);d.point((35,47),fill='#dcc28d')
  if part=='legs':d.line([(40,44),(43,44),(47,47)],fill='#b58a57',width=3);d.line([(40,49),(44,50)],fill='#967046',width=3)
  sheet.paste(im,(frame*64,0))
 sheet.save(out/f'downed_armor_{part}.png')
im=Image.new('RGBA',(12,12));d=ImageDraw.Draw(im)
d.ellipse((1,2,10,10),fill='#17232c');d.ellipse((2,2,9,9),fill='#996533');d.ellipse((3,2,8,8),fill='#d5b366');d.line([(5,4),(7,4),(5,6),(7,6)],fill='#f1d99a',width=1);d.point((3,8),fill='#725132');im.save(out/'coin.png')
im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
d.polygon([(6,5),(16,4),(20,9),(17,19),(7,20),(3,15)],fill='#15232b');d.polygon([(7,6),(15,5),(18,10),(16,18),(8,18),(5,14)],fill='#729c94')
d.line([(7,7),(17,14),(8,17),(15,8)],fill='#c6d2af',width=3);d.rectangle((9,9,13,13),fill='#bb8149');d.rectangle((10,10,12,12),fill='#efd598');im.save(out/'item_spark_binding.png');im.resize((12,12),Image.Resampling.NEAREST).save(out/'drop_spark_binding.png')
