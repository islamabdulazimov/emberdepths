"""Original CC0 Emberdepths ability icon. Offline Pillow; no game dependency."""
from pathlib import Path
from PIL import Image, ImageDraw
root=Path(__file__).resolve().parents[1]/'assets/recast'
im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
# Knotted copper cord with a hanging carved wooden loop, unlike armor silhouettes.
d.line([(5,4),(7,3),(16,3),(18,5),(17,10)],fill='#111e27',width=4)
d.line([(5,4),(7,3),(16,3),(18,5),(17,10)],fill='#b58a57',width=2)
d.polygon([(10,7),(15,8),(19,14),(16,21),(8,21),(5,15)],fill='#111e27')
d.polygon([(10,9),(14,9),(17,14),(15,19),(9,19),(7,15)],fill='#715437')
d.line([(10,10),(13,10),(15,14),(13,17),(10,17),(9,14),(10,10)],fill='#d3ad6c',width=2)
d.rectangle((11,12,13,15),fill='#243842')
d.line([(8,9),(16,9)],fill='#799da0',width=2)
d.point((8,8),fill='#b5c7b0');d.point((17,14),fill='#ead6a1')
im.save(root/'item_traveler_knot.png')
im.resize((12,12),Image.Resampling.NEAREST).save(root/'drop_traveler_knot.png')
