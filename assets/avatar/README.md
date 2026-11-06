# Emberdepths adult avatar layers

Original clothed pixel artwork and generator: **CC0-1.0**,
https://creativecommons.org/publicdomain/zero/1.0/ . No external sprites,
characters, animation frames or reference images were copied.

`tools/build_avatar_art.py --normal` builds the ordinary male/female sample;
`python tools/build_avatar_art.py` builds the full set. Offline Pillow only.
The generator reuses this project's CC0 pixel-line helpers and action rig.

- Six body fits: male/female × slim/normal/sturdy. Each has five skin tones and
  coat/plain clothing: 60 body sheets, 1536×1024, 24 frames ×16 actions.
- Sixty foreground-arm sheets, 864×640, 24×16 packed 36×40 cells. They draw
  after hair/armor so a raised hand stays visible; crop offset (16,16) keeps the
  original 64×64 action anchors. Body/arm pixels are checked together.
- Eighteen matching armor sheets: head/body/legs for each fit. Breastplates cover
  the full torso; their contour and leg roots follow the underlying body.
- Six shared hairstyles, separate rear/front sheets, tinted from a six-color
  palette by the renderer. No separate texture bake for every color.
- Sixty downed-body sheets, eighteen fitted armor overlays and twelve hair layers:
  12 breathing frames per sheet. Plain clothing still includes shirt and trousers;
  the legacy `unclothed` flag never renders nudity in this set.
- `rig.gd` is the runtime constant resource; `rig.json` is matching offline metadata.
  Rendering does not depend on exporting raw JSON. Hands, weapons and shields use
  the same shared anchors and combat timings. One run cycle contains one support
  cycle, matching world speed, rather than doubled leg cycles.

Live integration: `scripts/visuals/hero_sprite.gd`, `hero_death.gd`, Player,
`ui/portrait.gd` and the character creator. Old recast hero assets remain for
history/regression comparison; current Player renders this folder.

Data: `data/appearance.gd`. Appearance keys are gender, build, hair, hair_color,
skin. Old short/long hairstyles retain their IDs; missing build/color normalize
into normal/dark. Cosmetics do not change collision, health, speed or reach.

This is original prototype artwork built on reusable raster rigs. It has not
received individual commercial production cleanup on every frame. Native
screenshots and staged motion reviews are in `docs/avatar`; automated pixel
checks verify geometry, not artistic quality or measured game performance.
