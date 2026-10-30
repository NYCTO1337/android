extends CanvasLayer
class_name PauseMenu
## Shown in the PAUSED state. Runs while the tree is paused.


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	UIKit.full_rect(root)
	root.theme = UIKit.get_theme()
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	UIKit.full_rect(dim)          # mouse_filter STOP by default: taps never reach the game
	root.add_child(dim)

	var center := CenterContainer.new()
	UIKit.full_rect(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := UIKit.title("პაუზა", 46)
	title.custom_minimum_size = Vector2(0, 90)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UIKit.button("გაგრძელება", func() -> void: GameState.change_state(GameState.State.PLAYING)))
	box.add_child(UIKit.button("ბოლო საკონტროლო წერტილი", func() -> void: GameState.send("restart_checkpoint")))
	box.add_child(UIKit.button("პარამეტრები", func() -> void: GameState.open_settings()))
	box.add_child(UIKit.button("მთავარი მენიუ", func() -> void: GameState.send("main_menu")))

	GameState.state_changed.connect(_on_state)
	_on_state(GameState.state, GameState.state)


func _on_state(new_state: int, _old: int) -> void:
	visible = new_state == GameState.State.PAUSED
