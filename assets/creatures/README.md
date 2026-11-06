# Original creature sprites

`seamling.svg`, `hollowbeak.svg`, `ashweaver.svg`, `void_collector.svg` are original
Emberdepths pixel sprite atlases. Each contains four 64×48 poses: movement,
preparation, strike, recovery. Shapes/palettes were authored for this project;
no source imagery, third-party characters or borrowed assets were used.

The assets and their source generator `tools/build_creature_sprites.py` are
provided under **CC0-1.0**:
https://creativecommons.org/publicdomain/zero/1.0/ .
Regenerate with `python3 tools/build_creature_sprites.py` (Python stdlib only).
Animation timing, collision size and balance are in `data/creatures.gd`.
