extends CanvasLayer
class_name EndScreen
## The ending: the light of the gate, then black, then the result.

var _black: ColorRect
var _content: Control
var _stats: Label
var _tw: Tween


func _ready() -> void:
	layer = 33
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	UIKit.full_rect(root)
	root.theme = UIKit.get_theme()
	add_child(root)

	_black = ColorRect.new()
	_black.color = Color(0.005, 0.006, 0.008, 0.0)
	UIKit.full_rect(_black)
	root.add_child(_black)

	_content = CenterContainer.new()
	UIKit.full_rect(_content)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.modulate.a = 0.0
	root.add_child(_content)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_content.add_child(box)
	var title := UIKit.title("დასასრული", 56)
	title.custom_minimum_size = Vector2(0, 110)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(title)
	_stats = UIKit.label("", 24, UIKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_stats.custom_minimum_size = Vector2(0, 110)
	box.add_child(_stats)
	box.add_child(UIKit.button("თავიდან", func() -> void: GameState.send("new_game")))
	box.add_child(UIKit.button("მთავარი მენიუ", func() -> void: GameState.send("main_menu")))

	GameState.state_changed.connect(_on_state)
	_on_state(GameState.state, GameState.state)


func _on_state(new_state: int, _old: int) -> void:
	visible = new_state == GameState.State.LEVEL_COMPLETE
	if _tw != null:
		_tw.kill()
	if not visible:
		return
	var best := float(GameState.progress["best_time"])
	_stats.text = "დრო  %s\nდაღუპვა  %d\nსაუკეთესო დრო  %s" % [
		GameState.format_time(GameState.run_time), GameState.deaths,
		GameState.format_time(best) if best >= 0.0 else "—"]
	_black.color.a = 0.0
	_content.modulate.a = 0.0
	_tw = create_tween()
	_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tw.tween_property(_black, "color:a", 1.0, 2.6)
	_tw.tween_property(_content, "modulate:a", 1.0, 1.2)
