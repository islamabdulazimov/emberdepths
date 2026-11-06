# Реально используемая графика перед переработкой

База: ccb4a21. Изображений референсов не приложено; ориентир задан текстом.

| Группа | Объекты | Действующий путь до изменения |
| --- | --- | --- |
| Игрок | 2 пола × 2 волос × 5 оттенков, одетый/раздетый | player.gd._draw: линии/полигоны, procedural Pose/Action |
| Обычные существа | ashling, spirit, seamling, hollowbeak, ashweaver, void_collector | enemy.gd → actor_atlas.gd → assets/actors/*.png;7 строк |
| Босс | Andrew,14 боевых фаз, ранение/гибель | andrew.gd → andrew_art.gd/andrew_rig.gd; геометрия |
| NPC | Julia, Cameron | residents.gd → assets/actors/*.png;4 idle кадра |
| Предметы | dirt,stone,turf,emberstone,stone_pick,stone_axe,wood,wood_block,spark_balm,stone_blade,torch,dirt_wall,stone_wall,wood_wall,wood_door,wood_chest | data/items.gd → SVG; drops используют эти же иконки |
| Блоки | дёрн,земля,камень,искоруда,доски,древние корни | Blocks.TEXTURES → terrain.svg и3 SVG; TileMapLayer |
| Фоновые стены | земля,камень,дерево,корни | те же источники, затенённый слой TileMapLayer |
| Деревья |3 формы,высота5–8,пни/падение | tree_art.gd + canopy.png; forest.gd |
| Объекты | факел,дверь открыта/закрыта,сундук открыт/закрыт,сундук смерти | torch.gd,door.gd,storage_chest.gd,death_chest.gd: draw_* |
| Сооружения |3 дома,root_shelter,well_archive,полки/мосты/ступени | существующие блоки/стены/сундуки; отдельных новых типов нет |
| UI | хотбар10,сумка30,сундук30,11рецептов,3ресурса,боссHP/стойкость,меню/диалоги | inventory_ui.gd + art_direction.gd,default font |

Брони и щитов в базе нет; новые ровно5предметов деревянного комплекта. Генераторы и противники не расширяются. Переработка подключается по этим точкам, прежние картинки не выдаются за заменённые. Образец: сцена art/recast/sample, реальный Player/Enemy/Items/UI, до/после в одинаковом масштабе. Окончательный статус групп и ограничения фиксируются в HANDOFF.
