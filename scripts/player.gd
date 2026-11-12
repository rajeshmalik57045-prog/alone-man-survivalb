extends CharacterBody3D
## Player controller (Phase 1): camera-relative movement, sprint, jump, crouch, USE action.
##
## VISUAL: if res://assets/characters/survivor.glb exists it is used (with an AnimationPlayer
## if the file has one). Otherwise a clearly-marked PLACEHOLDER capsule is shown.
## The placeholder is NOT the final character - see assets/characters/README.md.

signal notified(text: String)

const MODEL_PATH := "res://assets/characters/survivor.glb"
const GRAVITY := 18.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.2
const USE_RANGE := 2.6

@export var run_speed := 5.0
@export var sprint_speed := 7.5
@export var crouch_speed := 1.8
@export var jump_velocity := 6.0
@export var acceleration := 28.0

var cam_rig  # camera rig node; provides `yaw`

var health := 100.0
var hunger := 100.0
var thirst := 100.0
var stamina := 100.0

var touch_move := Vector2.ZERO
var touch_sprint := false
var crouching := false

var _jump_requested := false
var _visual: Node3D
var _is_placeholder := true
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _anim: AnimationPlayer


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1

	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.35
	_capsule.height = STAND_HEIGHT
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	_shape.position.y = STAND_HEIGHT * 0.5
	add_child(_shape)

	_visual = _build_visual()
	add_child(_visual)


# ---------- input from controls ----------

func on_move_changed(vector: Vector2, sprint: bool) -> void:
	touch_move = vector
	touch_sprint = sprint


func request_jump() -> void:
	_jump_requested = true


func set_crouch(on: bool) -> void:
	crouching = on
	var h := CROUCH_HEIGHT if on else STAND_HEIGHT
	_capsule.height = h
	_shape.position.y = h * 0.5
	if _is_placeholder:
		_visual.scale.y = h / STAND_HEIGHT


func use_action() -> void:
	var best: Node3D = null
	var best_dist := USE_RANGE
	for n in get_tree().get_nodes_in_group("interactable"):
		var node := n as Node3D
		if node == null:
			continue
		var d := global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	if best:
		var item := str(best.get_meta("item", "Item"))
		best.remove_from_group("interactable")
		best.queue_free()
		notified.emit("%s collected" % item)
	else:
		notified.emit("Nothing to use here")


# ---------- physics ----------

func _physics_process(delta: float) -> void:
	var move := touch_move
	var sprint_wanted := touch_sprint
	if move.length() < 0.05:
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		sprint_wanted = Input.is_action_pressed("sprint")

	var yaw := 0.0
	if cam_rig:
		yaw = cam_rig.yaw
	var dir := Basis(Vector3.UP, yaw) * Vector3(move.x, 0.0, move.y)

	var moving := move.length() > 0.1
	var sprinting := sprint_wanted and moving and not crouching and stamina > 5.0 and is_on_floor()

	var speed := run_speed
	if crouching:
		speed = crouch_speed
	elif sprinting:
		speed = sprint_speed

	var target_h := dir * speed
	velocity.x = move_toward(velocity.x, target_h.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_h.z, acceleration * delta)

	if is_on_floor():
		if _jump_requested and not crouching:
			velocity.y = jump_velocity
	else:
		velocity.y -= GRAVITY * delta
	_jump_requested = false

	if sprinting:
		stamina = maxf(0.0, stamina - 18.0 * delta)
	else:
		stamina = minf(100.0, stamina + 12.0 * delta)

	if moving:
		var target_yaw := atan2(-dir.x, -dir.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))

	move_and_slide()
	_update_animation(moving, sprinting)


func _update_animation(moving: bool, sprinting: bool) -> void:
	if _anim == null:
		return
	var anim_name := "idle"
	if not is_on_floor():
		anim_name = "jump"
	elif sprinting:
		anim_name = "sprint"
	elif moving:
		anim_name = "crouch_walk" if crouching else "walk"
	elif crouching:
		anim_name = "crouch_idle"
	if _anim.has_animation(anim_name) and _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.2)


# ---------- visuals ----------

func _build_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"

	if ResourceLoader.exists(MODEL_PATH):
		var scene := load(MODEL_PATH) as PackedScene
		if scene:
			root.add_child(scene.instantiate())
			var found := root.find_children("*", "AnimationPlayer", true, false)
			if not found.is_empty():
				_anim = found[0] as AnimationPlayer
			_is_placeholder = false
			return root

	# PLACEHOLDER (orange capsule with a "nose" box so the facing direction is visible).
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = STAND_HEIGHT
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.85, 0.45, 0.15)
	capsule.material = body_mat
	body.mesh = capsule
	body.position.y = STAND_HEIGHT * 0.5
	root.add_child(body)

	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 0.2, 0.3)
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.95, 0.9, 0.8)
	box.material = nose_mat
	nose.mesh = box
	nose.position = Vector3(0.0, 1.5, -0.38)
	root.add_child(nose)

	return root
