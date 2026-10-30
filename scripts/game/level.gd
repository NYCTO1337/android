extends Node2D
class_name Level
## The one level. Gameplay objects (physics) are built from the data tables
## below; their art is plain textures from assets/art/. Nothing here draws
## placeholder shapes. Coordinates are world pixels, y grows downwards.

signal player_died
signal completed

# [x_from, x_to, top_y]  (ground fills down to y = top + 800)
const GROUND := [
	[0, 1500, 600], [1900, 2700, 600], [2700, 4200, 472],
	[4700, 5400, 472], [5400, 7900, 600], [6600, 6820, 472],
]
# crumbling planks over the pits: [x, top_y], width 124
const CRUMBLE := [[1516, 600], [1676, 600], [4216, 472], [4376, 472], [4536, 472]]
# one-way stepping planks: [x, top_y, width]
const ONE_WAY := [[5776, 520, 128], [5936, 520, 128]]
# thorns: [x, ground_top_y, tiles of 64 px]
const THORNS := [[860, 600, 2], [3200, 472, 2], [5760, 600, 5]]
# pushable crates: [x_center, ground_top_y]
const CRATES := [[2300, 600], [6380, 600]]
# levers: [x, top_y, door_index]
const LEVERS := [[3000, 472, 0], [6710, 472, 1]]
# doors: [x, base_y]
const DOORS := [[3800, 472], [7050, 600]]
# checkpoint lanterns (checkpoint index = position in this list + 1): [x, top_y]
const LANTERNS := [[1360, 600], [2000, 600], [4800, 472], [6200, 600]]
const START := Vector2(220, 577)
const GATE := Vector2(7560, 600)
const WORLD_RIGHT := 7900
const KILL_Y := 1050.0

var player: Player
var camera: Camera2D
var checkpoint := 0

var _tex: Dictionary = {}
var _crates: Array = []
var _levers: Array = []
var _doors: Array = []
var _planks: Array = []
var _lanterns: Array = []
var _modulate: CanvasModulate
var _done := false


# ---------------------------------------------------------------- inner types

class Art extends Node2D:
	var level: Level

	func _draw() -> void:
		level.draw_ground(self)


class Crate extends RigidBody2D:
	var home := Vector2.ZERO
	var tex: Texture2D

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 1 | 2 | 4
		lock_rotation = true
		can_sleep = false
		mass = 5.0
		continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
		var pm := PhysicsMaterial.new()
		pm.friction = 1.0
		pm.bounce = 0.0
		physics_material_override = pm
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(60, 62)
		cs.shape = r
		add_child(cs)

	func _draw() -> void:
		draw_texture(tex, Vector2(-32, -32))

	func reset_pos() -> void:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, home))


class Door extends StaticBody2D:
	var home := Vector2.ZERO
	var tex: Texture2D
	var _tw: Tween

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(52, 192)
		cs.shape = r
		cs.position = Vector2(0, -96)
		add_child(cs)

	func _draw() -> void:
		draw_texture(tex, Vector2(-32, -192))

	func set_open(open: bool, instant: bool = false) -> void:
		if _tw != null:
			_tw.kill()
		var target := home + (Vector2(0, -215) if open else Vector2.ZERO)
		if instant:
			position = target
			return
		_tw = create_tween()
		_tw.tween_property(self, "position", target, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


class Lever extends Node2D:
	var on := false
	var door: Door
	var tex_off: Texture2D
	var tex_on: Texture2D

	func _draw() -> void:
		draw_texture(tex_on if on else tex_off, Vector2(-32, -70))

	func toggle() -> void:
		on = not on
		queue_redraw()
		if door != null:
			door.set_open(on)

	func reset() -> void:
		on = false
		queue_redraw()
		if door != null:
			door.set_open(false, true)


class CrumblePlank extends StaticBody2D:
	var home := Vector2.ZERO
	var width := 124.0
	var tex: Texture2D
	var state := 0   # 0 solid, 1 shaking, 2 fallen
	var _shape: CollisionShape2D
	var _tw: Tween

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		_shape = CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(width, 12)
		_shape.shape = r
		_shape.position = Vector2(width * 0.5, 6)
		_shape.one_way_collision = true
		add_child(_shape)

	func _draw() -> void:
		var x := 0.0
		while x < width:
			var w := minf(64.0, width - x)
			draw_texture_rect_region(tex, Rect2(x, -4, w, 24), Rect2(0, 0, w, 24))
			x += 64.0

	func trigger() -> void:
		if state != 0:
			return
		state = 1
		_tw = create_tween()
		_tw.tween_method(_shake, 0.0, 1.0, 0.55)
		_tw.tween_callback(_drop)

	func _shake(t: float) -> void:
		position.x = home.x + sin(t * 70.0) * 2.5 * t
		position.y = home.y + t * 2.0

	func _drop() -> void:
		state = 2
		_shape.set_deferred("disabled", true)
		_tw = create_tween()
		_tw.set_parallel(true)
		_tw.tween_property(self, "position:y", home.y + 700.0, 0.9).set_ease(Tween.EASE_IN)
		_tw.tween_property(self, "modulate:a", 0.0, 0.9)
		_tw.chain().tween_interval(2.4)
		_tw.chain().tween_callback(reset)

	func reset() -> void:
		if _tw != null:
			_tw.kill()
		state = 0
		position = home
		modulate.a = 1.0
		_shape.set_deferred("disabled", false)


class Lantern extends Node2D:
	var lit := false
	var tex: Texture2D
	var light: PointLight2D
	var _t := 0.0

	func _ready() -> void:
		light = PointLight2D.new()
		light.texture = load("res://assets/art/light.png")
		light.texture_scale = 2.4
		light.color = Color(1.0, 0.78, 0.45)
		light.energy = 0.0
		light.position = Vector2(12, -77)   # the flame
		add_child(light)

	func set_lit(v: bool) -> void:
		lit = v
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		if lit:
			light.energy = 0.95 + 0.12 * sin(_t * 7.0) + 0.06 * sin(_t * 13.1)
		else:
			light.energy = 0.0

	func _draw() -> void:
		draw_texture(tex, Vector2(-24, -112))
		if not lit:   # unlit lantern: cover the flame
			draw_rect(Rect2(7, -85, 10, 17), Color(0.035, 0.04, 0.045))


# ------------------------------------------------------------------- building

func _ready() -> void:
	for n in ["ground_top", "ground_fill", "plank", "crate", "lever_off", "lever_on",
			"door", "thorns", "lantern", "gate", "glow", "light"]:
		_tex[n] = load("res://assets/art/%s.png" % n)

	_modulate = CanvasModulate.new()
	_modulate.color = Color(0.6, 0.62, 0.68)
	add_child(_modulate)

	var art := Art.new()
	art.level = self
	art.z_index = -2
	add_child(art)

	_build_collision()
	_build_props()
	_build_player()
	PerfGovernor.quality_changed.connect(_apply_quality)
	_apply_quality(PerfGovernor.quality)


func draw_ground(ci: CanvasItem) -> void:
	var top_tex: Texture2D = _tex["ground_top"]
	var fill_tex: Texture2D = _tex["ground_fill"]
	var plank_tex: Texture2D = _tex["plank"]
	var thorn_tex: Texture2D = _tex["thorns"]
	for g in GROUND:
		var x0: float = g[0]
		var x1: float = g[1]
		var top: float = g[2]
		ci.draw_texture_rect(fill_tex, Rect2(x0, top + 56.0, x1 - x0, 720.0), true)
		var x := x0
		while x < x1:
			var w := minf(128.0, x1 - x)
			ci.draw_texture_rect_region(top_tex, Rect2(x, top - 40.0, w, 96.0), Rect2(0, 0, w, 96))
			x += 128.0
	for p in ONE_WAY:
		var px: float = p[0]
		var py: float = p[1]
		var pw: float = p[2]
		var x := 0.0
		while x < pw:
			ci.draw_texture_rect_region(plank_tex, Rect2(px + x, py - 4.0, minf(64.0, pw - x), 24), Rect2(0, 0, minf(64.0, pw - x), 24))
			x += 64.0
	for t in THORNS:
		var tx: float = t[0]
		var ty: float = t[1]
		for i in range(int(t[2])):
			ci.draw_texture(thorn_tex, Vector2(tx + i * 64.0, ty - 44.0))


func _box(rect: Rect2, one_way: bool = false) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	cs.shape = r
	cs.position = rect.position + rect.size * 0.5
	cs.one_way_collision = one_way
	b.add_child(cs)
	add_child(b)


func _area(rect: Rect2, cb: Callable) -> void:
	var a := Area2D.new()
	a.collision_layer = 8
	a.collision_mask = 2
	a.monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	cs.shape = r
	cs.position = rect.position + rect.size * 0.5
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(cb)


func _build_collision() -> void:
	for g in GROUND:
		var x0: float = g[0]
		var x1: float = g[1]
		var top: float = g[2]
		_box(Rect2(x0, top, x1 - x0, 800.0))
	for p in ONE_WAY:
		_box(Rect2(float(p[0]), float(p[1]), float(p[2]), 10.0), true)
	_box(Rect2(-60, -600, 60, 2600))               # left wall
	_box(Rect2(WORLD_RIGHT, -600, 60, 2600))       # right wall

	for t in THORNS:
		var tx: float = t[0]
		var ty: float = t[1]
		var tw: float = float(t[2]) * 64.0
		_area(Rect2(tx + 8.0, ty - 28.0, tw - 16.0, 28.0), _on_kill_body)

	_area(Rect2(GATE.x - 50.0, GATE.y - 220.0, 100.0, 220.0), _on_gate_body)


func _build_props() -> void:
	for d in DOORS:
		var door := Door.new()
		door.tex = _tex["door"]
		door.home = Vector2(float(d[0]), float(d[1]))
		door.position = door.home
		door.z_index = -1
		add_child(door)
		_doors.append(door)
	for l in LEVERS:
		var lever := Lever.new()
		lever.tex_off = _tex["lever_off"]
		lever.tex_on = _tex["lever_on"]
		lever.position = Vector2(float(l[0]), float(l[1]))
		lever.door = _doors[int(l[2])]
		lever.z_index = -1
		add_child(lever)
		_levers.append(lever)
	for c in CRATES:
		var crate := Crate.new()
		crate.tex = _tex["crate"]
		crate.home = Vector2(float(c[0]), float(c[1]) - 32.0)
		crate.position = crate.home
		crate.z_index = 0
		add_child(crate)
		_crates.append(crate)
	for c in CRUMBLE:
		var plank := CrumblePlank.new()
		plank.tex = _tex["plank"]
		plank.home = Vector2(float(c[0]), float(c[1]))
		plank.position = plank.home
		add_child(plank)
		_planks.append(plank)
	var index := 1
	for l in LANTERNS:
		var lan := Lantern.new()
		lan.tex = _tex["lantern"]
		lan.position = Vector2(float(l[0]), float(l[1]))
		lan.z_index = -1
		add_child(lan)
		_lanterns.append(lan)
		_area(Rect2(float(l[0]) - 70.0, float(l[1]) - 170.0, 140.0, 170.0), _on_lantern_body.bind(index))
		index += 1

	# the exit: an arch against a pale glow
	var glow := Sprite2D.new()
	glow.texture = _tex["glow"]
	glow.position = Vector2(GATE.x, GATE.y - 150.0)
	glow.scale = Vector2(2.4, 2.4)
	glow.modulate = Color(0.9, 0.95, 1.0, 0.85)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.z_index = -3
	add_child(glow)
	var gate := Sprite2D.new()
	gate.texture = _tex["gate"]
	gate.centered = false
	gate.position = Vector2(GATE.x - 96.0, GATE.y - 288.0)
	gate.z_index = -1
	add_child(gate)
	var gl := PointLight2D.new()
	gl.texture = _tex["light"]
	gl.texture_scale = 3.2
	gl.color = Color(0.85, 0.92, 1.0)
	gl.energy = 1.1
	gl.position = Vector2(GATE.x, GATE.y - 150.0)
	gl.name = "GateLight"
	add_child(gl)


func _build_player() -> void:
	player = Player.new()
	player.position = START
	player.z_index = 1
	add_child(player)
	camera = Camera2D.new()
	camera.offset = Vector2(0, -110)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 4.5
	camera.limit_left = 0
	camera.limit_right = WORLD_RIGHT
	camera.limit_top = -300
	camera.limit_bottom = 950
	player.add_child(camera)
	player.camera = camera
	player.died.connect(func() -> void: player_died.emit())
	player.jumped.connect(func() -> void: AudioManager.play("jump"))
	player.landed.connect(func() -> void: AudioManager.play("land"))
	player.stepped.connect(func() -> void: AudioManager.play("step"))


func _apply_quality(q: int) -> void:
	for l in _lanterns:
		l.light.visible = q < 2
	var gl := get_node_or_null("GateLight") as PointLight2D
	if gl != null:
		gl.visible = q < 2
	_modulate.color = Color(0.6, 0.62, 0.68) if q < 2 else Color(0.8, 0.82, 0.88)


# ----------------------------------------------------------------- gameplay

func spawn_pos(index: int) -> Vector2:
	if index <= 0 or index > LANTERNS.size():
		return START
	var l: Array = LANTERNS[index - 1]
	return Vector2(float(l[0]) + 46.0, float(l[1]) - 23.0)


## Puts the hero at a checkpoint (used when a run starts or is continued).
func start_at(index: int) -> void:
	checkpoint = index
	for i in range(_lanterns.size()):
		_lanterns[i].set_lit(i + 1 <= index)
	player.revive(spawn_pos(index))
	_snap_camera()
	_reset_objects(player.position.x)


## Brings the hero back to the last checkpoint (after death / restart).
func respawn() -> void:
	player.revive(spawn_pos(checkpoint))
	_snap_camera()
	_reset_objects(player.position.x)


func _snap_camera() -> void:
	camera.offset.x = 0.0
	camera.force_update_scroll()
	camera.reset_smoothing()


func _reset_objects(cx: float) -> void:
	for p in _planks:
		p.reset()
	for c in _crates:
		if c.home.x > cx - 200.0:
			c.reset_pos()
	for l in _levers:
		if l.position.x > cx - 200.0:
			l.reset()


func _physics_process(delta: float) -> void:
	var playing: bool = GameState.state == GameState.State.PLAYING
	if playing:
		GameState.run_time += delta
	if player == null or _done:
		return

	var pp := player.global_position
	if not player.frozen and pp.y > KILL_Y:
		player.kill()

	for c in _crates:
		if c.position.y > 1150.0:
			c.reset_pos()

	if player.is_on_floor() and not player.frozen:
		var feet := pp.y + Player.HALF_HEIGHT
		for p in _planks:
			if p.state == 0 and pp.x > p.home.x - 6.0 and pp.x < p.home.x + p.width + 6.0 \
					and absf(feet - p.home.y) < 8.0:
				p.trigger()

	var near: Lever = null
	for l in _levers:
		if absf(pp.x - l.position.x) < 70.0 and absf(pp.y - (l.position.y - 22.0)) < 90.0:
			near = l
	GameState.set_interact(near != null and playing and not player.frozen)
	if near != null and playing and not player.frozen and Input.is_action_just_pressed("interact"):
		near.toggle()
		AudioManager.play("lever")
		AudioManager.play("door")


func _on_kill_body(body: Node2D) -> void:
	if body == player:
		player.kill()


func _on_lantern_body(body: Node2D, index: int) -> void:
	if body != player or index <= checkpoint:
		return
	checkpoint = index
	_lanterns[index - 1].set_lit(true)
	AudioManager.play("checkpoint")
	GameState.save_checkpoint(index)


func _on_gate_body(body: Node2D) -> void:
	if body != player or _done:
		return
	_done = true
	player.freeze_idle()
	GameState.set_interact(false)
	completed.emit()
