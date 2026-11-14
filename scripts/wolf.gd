extends Node3D
## A night-time enemy. Chases the player and bites. Can be fought with the USE button.
## Uses the same small API as animal.gd (hit / display_name / hp) so USE treats both alike.

var world  # set by world.gd
var hp := 4

var _player: Node3D
var _body: Node3D
var _mats: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _flash := 0.0
var _cooldown := 0.0
var _bob := 0.0

const SPEED := 5.4
const BITE_RANGE := 1.9
const BITE_DAMAGE := 10.0
const NOTICE_RANGE := 40.0


func setup(game_world) -> void:
	world = game_world
	add_to_group("animal")
	add_to_group("wolf")


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	_build()


func display_name() -> String:
	return "Wolf"


## Returns true when the wolf dies from this hit.
func hit(damage: int) -> bool:
	hp -= damage
	_flash = 0.15
	for m in _mats:
		m.albedo_color = Color(0.95, 0.2, 0.2)
	if hp > 0:
		# knocked back a little
		var away := global_position - _player.global_position if _player else Vector3.BACK
		away.y = 0.0
		if away.length() > 0.01:
			global_position += away.normalized() * 0.9
		return false
	world._spawn_chips(global_position + Vector3(0.0, 0.7, 0.0), Color(0.75, 0.1, 0.1))
	world._add_pickup(global_position, "raw_meat", 2, Color(0.80, 0.35, 0.35))
	queue_free()
	return true


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			for i in _mats.size():
				_mats[i].albedo_color = _base_colors[i]
	_cooldown = maxf(0.0, _cooldown - delta)

	if _player == null:
		var parent: Node = null
		if world != null:
			parent = world.get_parent()
		if parent:
			_player = parent.get_node_or_null("Player") as Node3D
		if _player == null:
			return

	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist < NOTICE_RANGE and dist > 0.01:
		var dir := to_player / dist
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-10.0 * delta))
		if dist > BITE_RANGE:
			var step := dir * SPEED * delta
			var target := global_position + step
			if world.height_at(target.x, target.z) > world.WATER_LEVEL + 0.3:
				global_position.x = target.x
				global_position.z = target.z
			_bob += delta * SPEED * 2.0
			_body.position.y = absf(sin(_bob)) * 0.07
		elif _cooldown <= 0.0:
			_cooldown = 1.3
			_player.health -= BITE_DAMAGE
			_player.notified.emit("The wolf bites you!  (USE to fight back)")
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


func _build() -> void:
	var fur := Color(0.30, 0.30, 0.33)
	var dark := Color(0.18, 0.18, 0.20)
	_part(Vector3(0.45, 0.5, 1.1), Vector3(0.0, 0.75, 0.0), fur)
	_part(Vector3(0.32, 0.32, 0.4), Vector3(0.0, 0.95, -0.7), fur)
	_part(Vector3(0.18, 0.15, 0.3), Vector3(0.0, 0.88, -1.0), dark)
	_part(Vector3(0.08, 0.14, 0.06), Vector3(-0.11, 1.18, -0.65), dark)
	_part(Vector3(0.08, 0.14, 0.06), Vector3(0.11, 1.18, -0.65), dark)
	_part(Vector3(0.12, 0.12, 0.55), Vector3(0.0, 0.85, 0.75), dark)
	for x in [-0.15, 0.15]:
		for z in [-0.4, 0.4]:
			_part(Vector3(0.11, 0.55, 0.11), Vector3(x, 0.28, z), dark)
	# glowing eyes so it can be seen at night
	for x in [-0.09, 0.09]:
		var eye := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.06, 0.05, 0.03)
		var emat := StandardMaterial3D.new()
		emat.albedo_color = Color(1.0, 0.8, 0.1)
		emat.emission_enabled = true
		emat.emission = Color(1.0, 0.7, 0.1)
		em.material = emat
		eye.mesh = em
		eye.position = Vector3(x, 1.0, -0.91)
		_body.add_child(eye)
