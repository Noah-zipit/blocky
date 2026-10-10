extends CharacterBody3D
## Blocky third-person controller.
## Desktop: WASD / arrows to move, Space to jump, Shift to sprint, click to capture mouse look.
## Touch:   left virtual joystick to move, right button to jump, drag right half to look.
## Uses the standard Godot 4 CharacterBody3D pattern. No AI-generated magic.

@export var walk_speed := 6.0
@export var sprint_speed := 9.5
@export var jump_velocity := 7.0
@export var acceleration := 14.0
@export var mouse_sensitivity := 0.0028
@export var touch_look_sensitivity := 0.0085

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var touch_move := Vector2.ZERO

# --- combat ---
var meter := 0.0
const METER_MAX := 100.0
var _atk_cd := 0.0
var _chidori_cd := 0.0
var _domain_cd := 0.0
var _dash_t := 0.0
var _dash_dir := Vector3.ZERO
var _dash_hit: Array = []
var _anim_lock := 0.0

var _yaw := 0.0
var _pitch := -0.32

@onready var _pivot: Node3D = $CameraPivot
@onready var _mesh_root: Node3D = $MeshRoot
@onready var _anim: AnimationPlayer = _find_anim()

func _ready() -> void:
	_ensure_input_map()
	_apply_look()

# ---------------------------------------------------------------- input map --
# Actions are registered at runtime so project.godot stays hand-editable.
func _ensure_input_map() -> void:
	_key_action(&"move_forward", [KEY_W, KEY_UP])
	_key_action(&"move_back", [KEY_S, KEY_DOWN])
	_key_action(&"move_left", [KEY_A, KEY_LEFT])
	_key_action(&"move_right", [KEY_D, KEY_RIGHT])
	_key_action(&"jump", [KEY_SPACE])
	_key_action(&"sprint", [KEY_SHIFT])

func _key_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key: int in keys:
		var exists := false
		for e: InputEvent in InputMap.action_get_events(action):
			if e is InputEventKey and e.physical_keycode == key:
				exists = true
				break
		if not exists:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)

# ------------------------------------------------------------------- input --
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.25, 0.55)
		_apply_look()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT \
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
				and not DisplayServer.is_touchscreen_available():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			match k.physical_keycode:
				KEY_J:
					try_attack()
				KEY_K:
					try_chidori()
				KEY_L:
					try_domain()

## Called by the touch UI when the player drags on the right half of the screen.
func add_camera_drag(relative: Vector2) -> void:
	_yaw -= relative.x * touch_look_sensitivity
	_pitch = clampf(_pitch - relative.y * touch_look_sensitivity, -1.25, 0.55)
	_apply_look()

## Called by the touch UI jump button.
func try_touch_jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity

func _apply_look() -> void:
	rotation.y = _yaw
	_pivot.rotation.x = _pitch

# ------------------------------------------------------------------ physics --
func _physics_process(delta: float) -> void:
	_atk_cd = maxf(0.0, _atk_cd - delta)
	_chidori_cd = maxf(0.0, _chidori_cd - delta)
	_domain_cd = maxf(0.0, _domain_cd - delta)
	if _anim_lock > 0.0:
		_anim_lock -= delta

	# Chidori dash overrides normal movement.
	if _dash_t > 0.0:
		_dash_t -= delta
		velocity.x = _dash_dir.x * 24.0
		velocity.z = _dash_dir.z * 24.0
		velocity.y = -1.0
		_dash_damage()
		move_and_slide()
		if _dash_t <= 0.0:
			VFX.hitstop(0.12)
			VFX.shake(0.5)
			VFX.shockwave(global_position, Color(0.55, 0.8, 1.0), 6.0, 0.4)
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed(&"jump"):
		velocity.y = jump_velocity

	var input_dir := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	input_dir += touch_move
	input_dir = input_dir.limit_length(1.0)

	var speed := sprint_speed if Input.is_action_pressed(&"sprint") else walk_speed
	var dir := transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO

	var blend := clampf(acceleration * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, dir.x * speed, blend)
	velocity.z = lerpf(velocity.z, dir.z * speed, blend)

	move_and_slide()
	_face_movement(delta, dir)
	_animate(dir)

func _face_movement(delta: float, dir: Vector3) -> void:
	if dir.length() > 0.05:
		var target := atan2(dir.x, dir.z)
		_mesh_root.rotation.y = lerp_angle(_mesh_root.rotation.y, target, clampf(10.0 * delta, 0.0, 1.0))

# ---------------------------------------------------------------- animation --
func _find_anim() -> AnimationPlayer:
	var found := find_child("AnimationPlayer", true, false)
	return found as AnimationPlayer

func _animate(dir: Vector3) -> void:
	if _anim == null or _anim_lock > 0.0:
		return
	var want := &"idle"
	if not is_on_floor():
		want = &"idle"
	elif dir.length() > 0.1:
		want = &"sprint" if Input.is_action_pressed(&"sprint") and _anim.has_animation(&"sprint") else &"walk"
	if not _anim.has_animation(want):
		return
	if _anim.current_animation != want:
		_anim.play(want)

# ------------------------------------------------------------------ combat --
func add_meter(v: float) -> void:
	meter = minf(METER_MAX, meter + v)

func _facing() -> Vector3:
	var f: Vector3 = _mesh_root.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3(0, 0, 1)

func _play(anim_name: StringName) -> void:
	if _anim != null and _anim.has_animation(anim_name):
		_anim.play(anim_name)

func _enemies_in_range(origin: Vector3, radius: float) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node3D
		if en == null:
			continue
		if en.global_position.distance_to(origin) <= radius:
			out.append(en)
	return out

## Light melee swing — J on desktop, ATK button on touch.
func try_attack() -> void:
	if _atk_cd > 0.0 or _dash_t > 0.0 or _anim_lock > 0.0:
		return
	_atk_cd = 0.45
	_anim_lock = 0.35
	_play(&"attack-melee-right")
	await get_tree().create_timer(0.14).timeout
	var fwd := _facing()
	var hits := 0
	for e in _enemies_in_range(global_position, 3.4):
		var en := e as Node3D
		var to: Vector3 = en.global_position - global_position
		to.y = 0.0
		if fwd.angle_to(to.normalized()) < deg_to_rad(65.0):
			if en.has_method("take_damage"):
				en.take_damage(14.0, global_position)
				hits += 1
	if hits > 0:
		VFX.shockwave(global_position + fwd * 1.6 + Vector3(0, 1, 0), Color(1, 0.9, 0.4), 4.0, 0.35)
		VFX.hitstop(0.07)
		VFX.shake(0.25)
		add_meter(10.0 * hits)

## CHIDORI — lightning dash strike. K on desktop, CHI button on touch.
func try_chidori() -> void:
	if _chidori_cd > 0.0 or _dash_t > 0.0:
		return
	_chidori_cd = 4.0
	_dash_t = 0.45
	_dash_dir = _facing()
	_dash_hit.clear()
	_anim_lock = 0.6
	_play(&"sprint")
	VFX.chidori_aura(self, 0.55)
	VFX.shake(0.35)

func _dash_damage() -> void:
	for e in _enemies_in_range(global_position, 2.6):
		var id: int = e.get_instance_id()
		if _dash_hit.has(id):
			continue
		_dash_hit.append(id)
		if e.has_method("take_damage"):
			e.take_damage(26.0, global_position)
			add_meter(18.0)
			VFX.burst(e.global_position + Vector3(0, 1.2, 0), Color(0.55, 0.8, 1.0), 30, 9.0)

## DOMAIN EXPANSION — the cinematic ultimate. L on desktop, DOM button on touch.
func try_domain() -> void:
	if _domain_cd > 0.0 or meter < METER_MAX or _dash_t > 0.0:
		return
	meter = 0.0
	_domain_cd = 20.0
	_anim_lock = 1.4
	_play(&"emote-yes")
	VFX.domain_expansion(global_position, 24.0, Color(0.45, 0.03, 0.08))
	await get_tree().create_timer(1.0, true, false, true).timeout
	for e in _enemies_in_range(global_position, 24.0):
		if e.has_method("take_damage"):
			e.take_damage(70.0, global_position)
		VFX.burst(e.global_position + Vector3(0, 1.2, 0), Color(1, 0.25, 0.3), 50, 12.0)
	VFX.flash(Color(1, 0.3, 0.35), 0.5, 0.5)
	VFX.hitstop(0.25)
