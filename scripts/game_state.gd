extends Node
## Inventory, crafting recipes, item use, and the hunger / thirst / health clock (Phase 3).

signal inventory_changed
signal message(text: String)

const MAX_WEIGHT := 60.0

# Survival numbers (per second). Full -> empty: hunger ~17 min, thirst ~10 min.
const HUNGER_DECAY := 0.10
const THIRST_DECAY := 0.16
const STARVE_DAMAGE := 0.8
const HEALTH_REGEN := 0.35

const ITEMS := {
	"wood": {"name": "Wood", "weight": 1.0},
	"stone": {"name": "Stone", "weight": 1.5},
	"berries": {"name": "Berries", "weight": 0.2, "food": 12.0},
	"raw_meat": {"name": "Raw Meat", "weight": 0.8, "food": 6.0, "sick": 6.0},
	"cooked_meat": {"name": "Cooked Meat", "weight": 0.7, "food": 35.0},
	"stone_axe": {"name": "Stone Axe", "weight": 2.0},
	"torch": {"name": "Torch", "weight": 0.5},
	"campfire": {"name": "Campfire", "weight": 4.0, "place": "campfire"},
	"shelter": {"name": "Shelter", "weight": 8.0, "place": "shelter"},
}

# limit: 0 = can craft as many as you like, 1 = only one at a time
const RECIPES := [
	{"id": "stone_axe", "cost": {"wood": 3, "stone": 2}, "limit": 1, "note": "Chops trees faster"},
	{"id": "torch", "cost": {"wood": 2, "stone": 1}, "limit": 1, "note": "Light for the night (later phase)"},
	{"id": "campfire", "cost": {"wood": 4, "stone": 2}, "limit": 0, "note": "Light, and cooks raw meat"},
	{"id": "shelter", "cost": {"wood": 8, "stone": 4}, "limit": 0, "note": "A roof over your head"},
]

var player  # set by main.gd
var world  # set by main.gd

var items := {}  # item id -> count

var _warned := {"hunger": false, "thirst": false, "health": false}


# ---------- inventory ----------

func item_name(id: String) -> String:
	if ITEMS.has(id):
		return str(ITEMS[id]["name"])
	return id


func count(id: String) -> int:
	return int(items.get(id, 0))


func weight() -> float:
	var w := 0.0
	for id in items:
		w += float(ITEMS[id]["weight"]) * float(items[id])
	return w


func can_add(id: String, n: int) -> bool:
	return weight() + float(ITEMS[id]["weight"]) * float(n) <= MAX_WEIGHT


func add(id: String, n: int) -> bool:
	if not can_add(id, n):
		return false
	items[id] = count(id) + n
	inventory_changed.emit()
	return true


func remove(id: String, n: int) -> bool:
	if count(id) < n:
		return false
	items[id] = count(id) - n
	if int(items[id]) <= 0:
		items.erase(id)
	inventory_changed.emit()
	return true


func drop(id: String) -> void:
	if remove(id, 1):
		message.emit("Dropped %s" % item_name(id))


# ---------- crafting ----------

func can_craft(recipe: Dictionary) -> bool:
	var limit := int(recipe.get("limit", 0))
	if limit > 0 and count(str(recipe["id"])) >= limit:
		return false
	var cost: Dictionary = recipe["cost"]
	for id in cost:
		if count(str(id)) < int(cost[id]):
			return false
	return true


func craft(recipe_id: String) -> void:
	for recipe in RECIPES:
		if str(recipe["id"]) != recipe_id:
			continue
		if not can_craft(recipe):
			message.emit("Cannot craft %s now" % item_name(recipe_id))
			return
		var cost: Dictionary = recipe["cost"]
		for id in cost:
			remove(str(id), int(cost[id]))
		if add(recipe_id, 1):
			message.emit("Crafted %s" % item_name(recipe_id))
		else:
			for id in cost:
				add(str(id), int(cost[id]))
			message.emit("Too heavy to carry")
		return


# ---------- using items ----------

func use_item(id: String) -> void:
	if count(id) <= 0:
		return
	var def: Dictionary = ITEMS[id]
	if def.has("food"):
		if player.hunger >= 99.0:
			message.emit("You are not hungry")
			return
		remove(id, 1)
		player.hunger = minf(100.0, player.hunger + float(def["food"]))
		if def.has("sick"):
			player.health = maxf(1.0, player.health - float(def["sick"]))
			message.emit("Raw meat made you sick - cook it first!")
		else:
			message.emit("Ate %s" % str(def["name"]))
	elif def.has("place"):
		_place(id, str(def["place"]), str(def["name"]))
	else:
		message.emit("%s - nothing to do with it yet" % str(def["name"]))


func _place(id: String, kind: String, display_name: String) -> void:
	var fwd: Vector3 = player.get_forward()
	var pos: Vector3 = player.global_position + fwd * 2.6
	pos.y = world.height_at(pos.x, pos.z)
	var yaw := atan2(-fwd.x, -fwd.z)
	if world.place_structure(kind, pos, yaw):
		remove(id, 1)
		message.emit("%s placed" % display_name)
	else:
		message.emit("Cannot place it here (water or steep ground)")


# ---------- survival clock ----------

func _process(delta: float) -> void:
	if player == null:
		return
	player.hunger = maxf(0.0, player.hunger - HUNGER_DECAY * delta)
	player.thirst = maxf(0.0, player.thirst - THIRST_DECAY * delta)

	if player.hunger <= 0.0 or player.thirst <= 0.0:
		player.health -= STARVE_DAMAGE * delta
	elif player.hunger > 50.0 and player.thirst > 50.0:
		player.health = minf(100.0, player.health + HEALTH_REGEN * delta)

	_warn("hunger", player.hunger < 25.0, "You are getting hungry - eat something")
	_warn("thirst", player.thirst < 25.0, "You are getting thirsty - find water")
	_warn("health", player.health < 25.0, "Health is low!")

	if player.health <= 0.0:
		_die()


func _warn(key: String, active: bool, text: String) -> void:
	if active and not bool(_warned[key]):
		message.emit(text)
	_warned[key] = active


func _die() -> void:
	message.emit("You died - respawning at camp")
	player.health = 60.0
	player.hunger = 60.0
	player.thirst = 60.0
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0.0, world.height_at(0.0, 0.0) + 1.5, 0.0)
