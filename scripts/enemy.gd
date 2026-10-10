extends CharacterBody3D
## Simple blocky training dummy. Wanders, takes damage, flashes, tips over and dies.
## Plain state machine — no AI magic, just enough to be fun to hit.

@export var max_hp := 40.0
@export var speed := 2.6
@export var wander_radius := 16.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _hp: float
var _target := Vector3.ZERO
var _wait := 0.0
var _dead := false

@onready var _mesh_root: Node3D = $MeshRoot
@onready var _anim: AnimationPlayer = _find_anim()

func _ready() -> void:
	_hp = max_hp
	_pick_target()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	if _wait > 0.0:
		_wait -= delta
		velocity.x = lerpf(velocity.x, 0.0, clampf(8.0 * delta, 0.0, 1.0))
		velocity.z = lerpf(velocity.z, 0.0, clampf(8.0 * delta, 0.0, 1.0))
	else:
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 1.2:
			_wait = randf_range(1.0, 3.0)
			_pick_target()
		else:
			var dir := to.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			_mesh_root.rotation.y = lerp_angle(_mesh_root.rotation.y, atan2(dir.x, dir.z), clampf(8.0 * delta, 0.0, 1.0))
	move_and_slide()
	_animate()

func take_damage(amount: float, from_pos: Vector3) -> void:
	if _dead:
		return
	_hp -= amount
	var kb := global_position - from_pos
	kb.y = 0.0
	if kb.length() > 0.01:
		velocity += kb.normalized() * 7.0
	VFX.burst(global_position + Vector3(0, 1.2, 0), Color(1, 1, 1), 16, 7.0)
	_punch()
	if _hp <= 0.0:
		_die()

func _punch() -> void:
	_mesh_root.scale = Vector3.ONE * 0.18 * 1.18
	var tw := create_tween()
	tw.tween_property(_mesh_root, "scale", Vector3.ONE * 0.18, 0.18)

func _die() -> void:
	_dead = true
	collision_layer = 0
	collision_mask = 0
	VFX.burst(global_position + Vector3(0, 1.0, 0), Color(1, 0.3, 0.3), 45, 11.0)
	VFX.shake(0.3)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_mesh_root, "rotation:x", -1.45, 0.45).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_mesh_root, "position:y", -1.6, 0.9).set_delay(0.35)
	tw.chain().tween_callback(queue_free)

func _pick_target() -> void:
	var a := randf() * TAU
	var r := randf_range(4.0, wander_radius)
	_target = Vector3(cos(a) * r, 0, sin(a) * r)

func _find_anim() -> AnimationPlayer:
	return find_child("AnimationPlayer", true, false) as AnimationPlayer

func _animate() -> void:
	if _anim == null:
		return
	var moving := Vector2(velocity.x, velocity.z).length() > 0.6
	var want := &"walk" if moving else &"idle"
	if _anim.has_animation(want) and _anim.current_animation != want:
		_anim.play(want)
