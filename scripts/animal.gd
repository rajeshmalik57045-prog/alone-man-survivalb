extends Node3D
## A simple huntable animal (deer or rabbit). Wanders, runs away from the player,
## and drops raw meat when killed. Built from boxes so no model files are needed.

var kind := "deer"
var world  # set by world.gd
var hp := 3

var _player: Node3D
var _dir := Vector3.ZERO
var _timer := 0.0
var _fleeing := false
var _bob := 0.0
var _body: Node3D
var _mats: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _flash := 0.0

const BOUND := 105.0


func setup(animal_kind: String, game_world) -> void:
	kind = animal_kind
	world = game_world
	hp = 3 if kind == "deer" else 1
	add_to_group("animal")


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	if kind == "deer":
		_build_deer()
	else:
		_build_rabbit()
	rotation.y = randf() * TAU
	_timer = randf() * 3.0


func display_name() -> String:
	return "Deer" if kind == "deer" else "Rabbit"


## Returns true when the animal dies from this hit.
func hit(damage: int) -> bool:
	hp -= damage
	_flash = 0.15
	for m in _mats:
		m.albedo_color = Color(0.9, 0.15, 0.15)
	_fleeing = true
	if hp > 0:
		return false
	var meat := 3 if kind == "deer" else 1
	world._spawn_chips(global_position + Vector3(0.0, 0.6, 0.0), Color(0.75, 0.1, 0.1))
	world._add_pickup(global_position, "raw_meat", meat, Color(0.80, 0.35, 0.35))
	queue_free()
	return true


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			for i in _mats.size():
				_mats[i].albedo_color = _base_colors[i]

	if _player == null:
		var parent := world.get_parent() if world else null
		if parent:
			_player = parent.get_node_or_null("Player") as Node3D
	var speed := 0.0
	var scare := 11.0 if kind == "deer" else 8.0
	var away := Vector3.ZERO
	if _player:
		away = global_position - _player.global_position
		away.y = 0.0
		_fleeing = away.length() < scare
	if _fleeing and away.length() > 0.01:
		_dir = away.normalized()
		speed = 6.2 if kind == "deer" else 5.0
	else:
		_timer -= delta
		if _timer <= 0.0:
			_timer = randf_range(2.0, 5.0)
			if randf() < 0.4:
				_dir = Vector3.ZERO
			else:
				var a := randf() * TAU
				_dir = Vector3(cos(a), 0.0, sin(a))
		speed = 1.3

	if _dir != Vector3.ZERO and speed > 0.0:
		var step := _dir * speed * delta
		var target := global_position + step
		if absf(target.x) < BOUND and absf(target.z) < BOUND \
				and world.height_at(target.x, target.z) > world.WATER_LEVEL + 0.4:
			global_position.x = target.x
			global_position.z = target.z
		else:
			_dir = -_dir  # turn back from water / the edge
		rotation.y = lerp_angle(rotation.y, atan2(-_dir.x, -_dir.z), 1.0 - exp(-8.0 * delta))
		_bob += delta * speed * 2.0
		_body.position.y = absf(sin(_bob)) * 0.08
	else:
		_body.position.y = 0.0
	global_position.y = world.height_at(global_position.x, global_position.z)


func _part(size: Vector3, pos: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	bm.material = mat
	m.mesh = bm
	m.position = pos
	_body.add_child(m)
	_mats.append(mat)
	_base_colors.append(color)


func _build_deer() -> void:
	var brown := Color(0.55, 0.36, 0.2)
	var light := Color(0.75, 0.58, 0.38)
	_part(Vector3(0.5, 0.55, 1.2), Vector3(0.0, 1.0, 0.0), brown)
	_part(Vector3(0.22, 0.55, 0.25), Vector3(0.0, 1.35, -0.62), brown)
	_part(Vector3(0.25, 0.25, 0.4), Vector3(0.0, 1.62, -0.78), light)
	_part(Vector3(0.05, 0.4, 0.05), Vector3(-0.1, 1.9, -0.7), Color(0.85, 0.8, 0.7))
	_part(Vector3(0.05, 0.4, 0.05), Vector3(0.1, 1.9, -0.7), Color(0.85, 0.8, 0.7))
	for x in [-0.17, 0.17]:
		for z in [-0.45, 0.45]:
			_part(Vector3(0.12, 0.7, 0.12), Vector3(x, 0.35, z), brown)


func _build_rabbit() -> void:
	var grey := Color(0.72, 0.5, 0.28)  # tan, so it stands out on green grass
	_body.scale = Vector3(1.7, 1.7, 1.7)
	_part(Vector3(0.3, 0.3, 0.5), Vector3(0.0, 0.25, 0.0), grey)
	_part(Vector3(0.2, 0.2, 0.2), Vector3(0.0, 0.38, -0.3), grey)
	_part(Vector3(0.05, 0.22, 0.05), Vector3(-0.06, 0.62, -0.3), grey)
	_part(Vector3(0.05, 0.22, 0.05), Vector3(0.06, 0.62, -0.3), grey)
	_part(Vector3(0.12, 0.12, 0.12), Vector3(0.0, 0.3, 0.3), Color(0.95, 0.95, 0.95))
