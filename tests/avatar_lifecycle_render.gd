extends "res://tests/survival_input_render.gd"
const LOOK={"gender":"female","build":"sturdy","hair":"long_braid","hair_color":2,"skin":4}
func run() -> void:
 root.get_node("GameApp").selected_character={"appearance":LOOK}
 await super.run()
func shot(name:String) -> void:
 check(main.get_node("Players/1").appearance==LOOK,"full appearance unchanged during "+name)
 await super.shot(name)
