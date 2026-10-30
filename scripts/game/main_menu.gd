extends CanvasLayer
class_name MainMenu
## Title screen: a lonely silhouette next to a lit lantern, and the menu.

var _stage: Control
var _hero: AnimatedSprite2D
var _continue_btn: Button
var _confirm: Control
var _menu: Control


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	UIKit.full_rect(root)
	root.theme = UIKit.get_theme()
	add_child(root)

	_stage = Control.new()
	UIKit.full_rect(_stage)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage)
	_stage.resized.connect(_stage.queue_redraw)
	root.add_child(_stage)

	_hero = AnimatedSprite2D.new()
	_hero.sprite_frames = Player.make_frames()
	_hero.scale = Vector2(0.8, 0.8)
	_stage.add_child(_hero)
	_hero.play("idle")

	var center := CenterContainer.new()
	UIKit.full_rect(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	_menu = box

	var title := UIKit.title("NYCTO'S ADVENTURE", 58)
	title.custom_minimum_size = Vector2(0, 120)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(title)

	_continue_btn = UIKit.button("გაგრძელება", func() -> void: GameState.send("continue"))
	box.add_child(_continue_btn)
	box.add_child(UIKit.button("ახალი თამაში", _on_new_game))
	box.add_child(UIKit.button("პარამეტრები", func() -> void: GameState.open_settings()))
	if PlatformService.platform_name() != "iOS":
		box.add_child(UIKit.button("გასვლა", func() -> void: GameState.send("quit")))

	_build_confirm(root)

	GameState.state_changed.connect(_on_state)
	get_viewport().size_changed.connect(_stage.queue_redraw)
	_on_state(GameState.state, GameState.state)


func _build_confirm(root: Control) -> void:
	var holder := CenterContainer.new()
	UIKit.full_rect(holder)
	holder.visible = false
	root.add_child(holder)
	_confirm = holder
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	UIKit.full_rect(dim)
	holder.add_child(dim)
	var panel := PanelContainer.new()
	holder.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var msg := UIKit.label("ახალი თამაში წაშლის შენახულ პროგრესს.\nგაგრძელება?", 24, UIKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(msg)
	vb.add_child(UIKit.button("დიახ, ახალი თამაში", func() -> void:
		_confirm.visible = false
		GameState.send("new_game")))
	vb.add_child(UIKit.button("გაუქმება", func() -> void: _confirm.visible = false))


func _on_new_game() -> void:
	if GameState.has_continue():
		_confirm.visible = true
	else:
		GameState.send("new_game")


func _on_state(new_state: int, _old: int) -> void:
	visible = new_state == GameState.State.MAIN_MENU
	if visible:
		_continue_btn.visible = GameState.has_continue()
		_confirm.visible = false
		_stage.queue_redraw()


func _draw_stage() -> void:
	var vp := _stage.size
	var gy := floorf(vp.y - 118.0)
	var top_tex: Texture2D = load("res://assets/art/ground_top.png")
	var fill_tex: Texture2D = load("res://assets/art/ground_fill.png")
	_stage.draw_texture_rect(fill_tex, Rect2(0, gy + 56.0, vp.x, vp.y - gy), true)
	var x := 0.0
	while x < vp.x:
		var w := minf(128.0, vp.x - x)
		_stage.draw_texture_rect_region(top_tex, Rect2(x, gy - 40.0, w, 96.0), Rect2(0, 0, w, 96))
		x += 128.0
	var lx := vp.x * 0.64
	_stage.draw_texture(load("res://assets/art/lantern.png"), Vector2(lx - 24.0, gy - 112.0))
	var glow: Texture2D = load("res://assets/art/glow.png")
	_stage.draw_texture_rect(glow, Rect2(lx + 12.0 - 140.0, gy - 77.0 - 140.0, 280.0, 280.0), false, Color(1.0, 0.75, 0.4, 0.42))
	_hero.position = Vector2(lx - 96.0, gy - 42.0 * 0.8 + 0.0)
