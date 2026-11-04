extends Control
# Generic binding: no reference to Andrew, its scene, attack states or rules.
var state: RefCounted
var main: Node2D
var title: Label
var health_bar: ProgressBar
var poise_bar: ProgressBar

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 position = Vector2(230, 380)
 title = Label.new()
 title.size = Vector2(500, 20)
 title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 title.mouse_filter = Control.MOUSE_FILTER_IGNORE
 title.add_theme_font_size_override("font_size", 15)
 add_child(title)
 health_bar = _bar(23, 16, Color("b85461"))
 poise_bar = _bar(42, 7, Color("d6b975"))
 hide()

func _bar(y: float, height: float, color: Color) -> ProgressBar:
 var bar := ProgressBar.new()
 bar.position.y = y
 bar.size = Vector2(500, height)
 bar.show_percentage = false
 bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var background := StyleBoxFlat.new()
 background.bg_color = Color("202b36")
 bar.add_theme_stylebox_override("background", background)
 var fill := StyleBoxFlat.new()
 fill.bg_color = color
 bar.add_theme_stylebox_override("fill", fill)
 add_child(bar)
 return bar

func bind_boss(value: RefCounted) -> void:
 state = value
 refresh()

func unbind_boss() -> void:
 state = null
 hide()

func _process(_delta: float) -> void:
 refresh()

func refresh() -> void:
 visible = state != null and state.active
 if is_instance_valid(main) and is_instance_valid(main.inventory_ui) and (main.inventory_ui.opened or (is_instance_valid(main.player) and main.player.dead)):
  visible = false
 if not visible: return
 title.text = "%s · %d / %d ОЗ" % [state.boss_name, state.health, state.max_health]
 health_bar.max_value = state.max_health
 health_bar.value = state.health
 poise_bar.visible = state.show_poise
 poise_bar.max_value = maxi(1, state.max_poise)
 poise_bar.value = state.poise
 poise_bar.tooltip_text = "Стойкость %d / %d" % [state.poise, state.max_poise]
