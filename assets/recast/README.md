# Emberdepths raster art — sources and integration

Original pixel artwork, authored for Emberdepths. No Risk of Rain Returns or other
game images/sprites/animation frames were copied. Artwork and source generators:
**CC0-1.0**, https://creativecommons.org/publicdomain/zero/1.0/ .
**Exception:** DejaVuSansMono.ttf is the unmodified DejaVu font, distributed under
the separate notices in FONT_LICENSE.txt (Bitstream Vera/DejaVu), not CC0.

Offline generators (Pillow only; no Python game dependency):

- tools/build_recast_art.py:40 hero sheets (2 genders ×2 hair ×5 skins ×coat/bare),
  each1536×1024,24 columns of64×64,16 actions. Three matching armor overlay sheets;
  21 unique item icons,12px world pickups, native held-item sprites and UI skin.
- tools/build_recast_characters.py: Andrew1536×2048,12 columns128×128,16 states
  including hurt/death; Julia/Cameron8 idle/blink poses40×48.
- tools/build_recast_world.py:6 creatures768×512,12 columns64×64, rows
  idle8/movement12/preparation8/contact6/recovery8/hurt4/death8/stagger6;
  native16px terrain/ore/planks/roots, bark/crowns, doors6/chests6/torches8,
  three distant landscapes, clouds, sun/moon, menu matte.

Rig JSON files are editable offline metadata. Matching *_rig.gd files contain the
same immutable data as Godot resources so gameplay does not depend on packaging
raw JSON. Renderer paths: hero_sprite.gd, actor_atlas.gd, andrew_sprite.gd,
residents.gd, tree_art.gd, sky.gd, data/blocks.gd and data/items.gd. Real game scenes
use these resources; old assets remain in the repository for history and checks.

The artwork uses authored pixel clusters and reusable raster rigs. Frames have
not received commercial production-level individual artist cleanup. Galleries
show actual renderers, with simulation stopped for inspection, not measured FPS.
Body/action timing comes from existing gameplay; presentation never creates hits.
