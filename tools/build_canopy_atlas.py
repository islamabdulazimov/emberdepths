"""Original Emberdepths foliage, generated offline; no third-party assets. CC0-1.0."""
from pathlib import Path
from random import Random
from PIL import Image, ImageDraw

PALETTES = [('#243c41', '#365651', '#4e7261', '#83a181'),
            ('#283e43', '#3e5e54', '#628474', '#a3ad88'),
            ('#203940', '#314e4c', '#4c6c58', '#829573')]

def build():
    atlas = Image.new('RGBA', (256, 156))
    outline = [(0,18),(4,18),(4,10),(12,10),(12,5),(22,5),(22,1),
               (40,1),(40,5),(50,5),(50,10),(58,10),(58,18),(63,18),
               (63,33),(58,33),(58,40),(48,40),(48,47),(17,47),
               (17,43),(7,43),(7,37),(0,37)]
    for row, palette in enumerate(PALETTES):
        for variant in range(4):
            rng = Random(4919 + variant*137 + row*29)
            crown = Image.new('RGBA', (64,52))
            mask = Image.new('L', crown.size)
            ImageDraw.Draw(mask).polygon(outline, fill=255)
            draw = ImageDraw.Draw(crown)
            draw.polygon(outline, fill=palette[0])
            # Layered leaf masses: shaded underside, broad broken planes above.
            for y in range(4,44,5):
                for x in range(-2,64,8):
                    xx, yy = x+rng.randrange(-3,4), y+rng.randrange(-2,3)
                    shade = palette[1 if y>27 else 2]
                    if rng.random()<0.23: shade = palette[3 if y<26 else 2]
                    draw.rectangle((xx,yy,xx+rng.randrange(5,12),yy+rng.randrange(2,5)),fill=shade)
                    if y<25 and rng.random()<0.25:
                        draw.line((xx+1,yy,xx+4,yy),fill=palette[3],width=1)
            crown.putalpha(mask)
            atlas.alpha_composite(crown,(variant*64,row*52))
    atlas.save(Path(__file__).resolve().parents[1]/'assets/canopy.png')

if __name__ == '__main__': build()
