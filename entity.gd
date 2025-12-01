extends Node2D

# locations for available squares
# positions for occupied squares
var sibling_locations:PackedVector2Array = []
var sibling_positions:PackedVector2Array = []
var child_locations:PackedVector2Array = []
var child_positions:PackedVector2Array = []

@export_enum("Entity", "HumanLike", "RobotLike") var entity_type = "Entity"

@export var id:int

@export var game_name:String
var path:String = "/" + game_name
@export var parent:int
@export var description:String
@export var status:String
@export var personality:String
@export var note:String
@export var conceal:String
@export var game_hidden:String

var game_position:int = -1

var state:int = Globals.FLOATING
var moving:bool = false

var hovered = false
enum {
	IDLE,
	SELECTED
}
var edit_state:int = IDLE

var sprite_start_y = 0
var sprite_overlap_y = 0

signal select_entity
signal destroy_entity
signal move_entity
signal duplicate_entity

func _ready():
	sprite_start_y = $sprite.position.y
	for c in $sibling_locations.get_children():
		c.body_entered.connect(update_positions)
	for c in $child_locations.get_children():
		c.body_entered.connect(update_positions)

func update_positions(body):
	if edit_state == SELECTED:
		match state:
			Globals.FLOATING, Globals.EDITING:
				set_sibling_locations()
				for c in $sibling_locations.get_children():
					if not Vector2(Vector2i(c.global_position / Vector2(16, 16))) in sibling_positions:
						c.visible = true
					else:
						c.visible = false
				set_child_locations()
				for c in $child_locations.get_children():
					if not Vector2(Vector2i(c.global_position / Vector2(16, 16))) in child_positions:
						c.visible = true
					else:
						c.visible = false

func _process(delta):
	if moving:
		global_position = global_position.move_toward($navigator.get_next_path_position(), 2)
		set_child_locations()
		set_sibling_locations()
		if $navigator.is_navigation_finished():
			moving = false

func _input(event):
	if event is InputEventMouseMotion:
		update_positions(null)

func update(data):
	if data["path"] != path:
		path = data["path"]
	if data["status"] != status:
		status = data["status"]
	
	if data["parent"] != int(parent):
		parent = data["parent"]
		if data["position"] == -1 or data["position"] == parent:
			game_position = data["position"]
			var available_locations = get_node("/root/main").entities[parent].get_free_child_locations()
			if len(get_node("/root/main").entities[parent].child_positions) >= len(get_node("/root/main").entities[parent].child_locations):
				sprite_overlap_y = (len(get_node("/root/main").entities[parent].child_positions) - len(get_node("/root/main").entities[parent].child_locations) + 1) * 2
			move(available_locations)
		else:
			game_position = data["position"]
			var available_locations = get_node("/root/main").entities[game_position].get_free_sibling_locations()
			if len(get_node("/root/main").entities[game_position].sibling_positions) >= len(get_node("/root/main").entities[game_position].sibling_locations):
				sprite_overlap_y = (len(get_node("/root/main").entities[game_position].sibling_positions) - len(get_node("/root/main").entities[game_position].sibling_locations) + 1) * 2
			move(available_locations)
		#reparent(get_node("/root/main").entities[parent])
	elif data["position"] != game_position:
		game_position = data["position"]
		var available_locations = get_node("/root/main").entities[game_position].get_free_sibling_locations()
		if len(get_node("/root/main").entities[game_position].sibling_positions) >= len(get_node("/root/main").entities[game_position].sibling_locations):
			sprite_overlap_y = (len(get_node("/root/main").entities[game_position].sibling_positions) - len(get_node("/root/main").entities[game_position].sibling_locations) + 1) * 2
		move(available_locations)
	print(str(id) + ": " + str(data))

func sort_locations(a, b):
	$navigator.target_position = a * Vector2(16, 16)
	var a_distance = $navigator.distance_to_target()
	$navigator.target_position = b * Vector2(16, 16)
	var b_distance = $navigator.distance_to_target()
	return a < b

func move(available_locations:Array):
	available_locations.sort_custom(sort_locations)
	if entity_type == "Entity" or entity_type == "RobotLike":
		global_position = available_locations[0] * Vector2(16, 16)
		
		$sprite.position.y = sprite_start_y - ((path.count("/") - 1) * 4)
		set_child_locations()
		set_sibling_locations()
	elif entity_type == "HumanLike":
		var reachable_squares = []
		for square in available_locations:
			$navigator.target_position = square * Vector2(16, 16)
			if $navigator.is_target_reachable():
				reachable_squares.append(square)
		if reachable_squares:
			$navigator.target_position = reachable_squares[0] * Vector2(16, 16)
			moving = true
			set_child_locations()
			set_sibling_locations()
		else:
			global_position = available_locations[0] * Vector2(16, 16)
			set_child_locations()
			set_sibling_locations()

func set_state(new_state):
	match new_state:
		Globals.FLOATING:
			modulate.a = 0.5
			$sibling_locations.visible = true
			$child_locations.visible = true
		Globals.EDITING:
			modulate.a = 1
			if edit_state == SELECTED:
				$sibling_locations.visible = true
				$child_locations.visible = true
		Globals.RUNNING:
			set_sibling_locations()
			set_child_locations()
			$sibling_locations.visible = false
			$child_locations.visible = false
	state = new_state

func set_sibling_locations():
	var grid_locations:PackedVector2Array = []
	sibling_positions = []
	for c in $sibling_locations.get_children():
		var grid_pos = Vector2i(c.global_position) / Vector2i(16, 16)
		if c.has_overlapping_bodies():
			sibling_positions.append(grid_pos)
		grid_locations.append(grid_pos)
	
	sibling_locations = grid_locations
func get_free_sibling_locations():
	var res = []
	for square in sibling_locations:
		if not square in sibling_positions:
			res.append(square)
	if res:
		return res
	else:
		return sibling_locations

func set_child_locations():
	var grid_locations:PackedVector2Array = []
	child_positions = []
	for c in $child_locations.get_children():
		var grid_pos = Vector2i(c.global_position) / Vector2i(16, 16)
		if c.get_overlapping_bodies() != [$collision] and c.get_overlapping_bodies() != []:
			child_positions.append(grid_pos)
		grid_locations.append(grid_pos)
	
	child_locations = grid_locations
func get_free_child_locations():
	var res = []
	for square in child_locations:
		if not square in child_positions:
			res.append(square)
	if res:
		return res
	else:
		return child_locations

func fill_child_location(square:Vector2i):
	child_positions.append(square)
func clear_child_location(square:Vector2i):
	child_positions.remove_at(child_positions.find(Vector2(square)))
func fill_sibling_location(square:Vector2i):
	sibling_positions.append(square)
func clear_sibling_location(square:Vector2i):
	sibling_positions.remove_at(sibling_positions.find(Vector2(square)))

func _on_button_pressed():
	match state:
		Globals.EDITING:
			select_entity.emit(id)
func select():
	$button/edit_controls.visible = true
	$sprite/selected.visible = true
	$sibling_locations.visible = true
	$child_locations.visible = true
	edit_state = SELECTED
func deselect():
	$button.release_focus()
	$button/edit_controls.visible = false
	$sprite/selected.visible = false
	$sibling_locations.visible = false
	$child_locations.visible = false
	edit_state = IDLE

func _on_delete_pressed():
	destroy_entity.emit(id)
	queue_free()

func _on_move_pressed():
	global_position = get_global_mouse_position()# - Vector2(16, 16)# - $button/edit_controls.position - Vector2(6.5, 6.5)
	move_entity.emit(id)
	set_state(Globals.FLOATING)

func _on_duplicate_pressed():
	duplicate_entity.emit(id)

func get_code():
	var code = "entity_{0}, entity_{0}_id = ".format([str(id)])
	
	if entity_type == "Entity":
		code += "game.create_entity({"
	elif entity_type == "HumanLike":
		code += "game.create_humanlike({"
	elif entity_type == "RobotLike":
		code += "game.create_robotlike({"
	
	code += "\n\t'name': '{0}',".format([game_name])
	if parent == 0:
		code += "\n\t'parent': 0,"
	else:
		code += "\n\t'parent': {0},".format(["entity_" + str(parent) + "_id"])
	code += "\n\t'id': {0},".format([id])
	code += "\n\t'description': '''{0}''',".format([description])
	code += "\n\t'status': '''{0}''',".format([status])
	code += "\n\t'personality': '''{0}''',".format([personality])
	code += "\n\t'master_note': '''{0}''',".format([note])
	code += "\n\t'conceal': {0},".format([conceal])
	code += "\n\t'hidden': {0},".format([game_hidden])
	
	if entity_type == "Entity":
		code += "\n\t'duration': 0, 'command': 'create_entity'\n}, 0)\n\n"
	elif entity_type == "HumanLike":
		code += "\n\t'duration': 0, 'command': 'create_humanlike'\n}, 0)\n\n"
	elif entity_type == "RobotLike":
		code += "\n\t'duration': 0, 'command': 'create_robotlike'\n}, 0)\n\n"
	
	return code
