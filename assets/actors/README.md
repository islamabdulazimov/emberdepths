# Emberdepths original character artwork

All PNG atlases here are original artwork, authored for this project, licensed
**CC0-1.0** (https://creativecommons.org/publicdomain/zero/1.0/).
No external imagery or game assets were used.

`tools/build_actor_atlases.py` generates six 512×336 atlases. Each cell is 64×48;
rows: idle (4), movement (8), preparation (6), contact (4), recovery (6),
hurt (3), death (6). Unused end columns repeat the final frame.
`tools/build_resident_sprites.py` generates Julia/Cameron four-frame 32×40 idle
sprites. The generators use Pillow as an **offline art tool**, not a game dependency.

Nearest filtering is inherited from project.godot. Animation selection follows
actual combat state/timers; artwork never calculates hits or changes damage.
The earlier SVG atlases in assets/creatures remain for historical compatibility.
