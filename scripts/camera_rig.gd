extends Node3D
## Third-person camera rig. Yaw/pitch come from touch drag (add_look) and are independent
## of the movement joystick. A SpringArm3D keeps the camera from going through walls.

@export var sensitivity := 0.0035  # radians per dragged pixel
@export var follow_speed := 14.0
@export var arm_length := 4.2
@export var height_offset := 1.5
@export var min_pitch := deg_to_rad(-55.0)  # camera high, looking down
@export var max_pitch := deg_to_rad(25.0)  # camera low, looking up

var target: Node3D
var yaw := 0.0
var pitch := deg_to_rad(-12.0)

var _pivot: Node3D
var _arm: SpringArm3D
var _camera: Camera3D


func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)

	_arm = SpringArm3D.new()
	_arm.name = "SpringArm"
	_arm.spring_length = arm_length
	_arm.collision_mask = 1
	_arm.margin = 0.2
	_pivot.add_child(_arm)

	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = 70.0
	_camera.near = 0.1
	_camera.far = 400.0
	_arm.add_child(_camera)
	_camera.make_current()

	rotation.y = yaw
	_pivot.rotation.x = pitch


func set_target(new_target: Node3D) -> void:
	target = new_target
	if target:
		global_position = target.global_position + Vector3(0.0, height_offset, 0.0)


func add_look(delta: Vector2) -> void:
	yaw -= delta.x * sensitivity
	pitch = clampf(pitch - delta.y * sensitivity, min_pitch, max_pitch)


func _process(delta: float) -> void:
	if target:
		var goal := target.global_position + Vector3(0.0, height_offset, 0.0)
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
	rotation.y = yaw
	_pivot.rotation.x = pitch
