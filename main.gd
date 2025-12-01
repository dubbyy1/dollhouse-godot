extends Node2D

@onready var EntityButton = preload("res://entity_button.tscn")

var floating_entity = ""
var selected_entity = 0
var next_id = 1
var running = false

var entities = {
	0: self
}

var id = 0
var game_name = "World"
var scenario = ""

var game_out = []
var game_process = {}
var game_states = []
var current_frame = 0

var state = Globals.EDITING

func _ready():
	load_entity_list()
	open_scene_editor()

func move_entity(entity_id):
	entities[entity_id].reparent($floater)
	floating_entity = entity_id
func destroy_entity(entity_id):
	entities.erase(entity_id)
	for entity in entities.values().slice(1):
		if entity.parent == entity_id:
			entity.parent = 0
	select_entity(0)
func duplicate_entity(entity_id):
	var Entity:PackedScene = load(entities[entity_id].scene_file_path)
	var entity = Entity.instantiate()
	
	var og_entity = entities[entity_id]
	entity.game_name = og_entity.game_name
	entity.parent = og_entity.parent
	entity.description = og_entity.description
	entity.status = og_entity.status
	entity.personality = og_entity.personality
	entity.note = og_entity.note
	entity.conceal = og_entity.conceal
	entity.game_hidden = og_entity.game_hidden
	
	entity.set_state(Globals.FLOATING)
	if $floater.get_child_count() > 0:
		$floater.get_child(0).queue_free()
	$floater.add_child(entity, true)
	floating_entity = str(entities[entity_id].scene_file_path.split("/")[-1])

func float_entity(entity_filename):
	var Entity:PackedScene = load("res://entities/" + entity_filename)
	var entity = Entity.instantiate()
	entity.set_state(Globals.FLOATING)
	if $floater.get_child_count() > 0:
		$floater.get_child(0).queue_free()
	$floater.add_child(entity, true)
	floating_entity = entity_filename
func place_entity():
	if typeof(floating_entity) == TYPE_STRING:
		var entity = $floater.get_child(0)
		entity.id = next_id
		entities[entity.id] = entity
		next_id += 1
		
		entity.set_state(Globals.EDITING)
		entity.reparent($world)
		entity.select_entity.connect(select_entity)
		entity.destroy_entity.connect(destroy_entity)
		entity.move_entity.connect(move_entity)
		entity.duplicate_entity.connect(duplicate_entity)
		
		select_entity(entity.id)
		floating_entity = ""
	elif typeof(floating_entity) == TYPE_INT:
		var entity = $floater.get_child(0)
		entity.set_state(Globals.EDITING)
		entity.reparent($world)
		
		select_entity(entity.id)
		floating_entity = ""

func select_entity(entity_id):
	if entity_id == selected_entity:
		return
	save_entity_settings()
	
	if entity_id != 0:
		entities[entity_id].select()
	if selected_entity != 0 and selected_entity in entities.keys():
		entities[selected_entity].deselect()
	
	selected_entity = entity_id
	populate_parent_options(entity_id)
	load_entity_settings(entity_id)
	
	$UI/right_pane/entity_settings.visible = false
	$UI/right_pane/humanlike_settings.visible = false
	$UI/right_pane/world_settings.visible = false
	
	if entity_id == 0:
		$UI/right_pane/world_settings.visible = true
	elif entities[entity_id].entity_type == "Entity":
		$UI/right_pane/entity_settings.visible = true
	elif entities[entity_id].entity_type == "HumanLike" or entities[entity_id].entity_type == "RobotLike":
		$UI/right_pane/entity_settings.visible = true
		$UI/right_pane/humanlike_settings.visible = true

func save_entity_settings(_arg=null):
	if selected_entity == 0:
		scenario = $UI/right_pane/world_settings/scenario/input.text
		game_name = $UI/right_pane/world_settings/name/input.text
	elif selected_entity in entities.keys():
		var entity = entities[selected_entity]
		entity.game_name = $UI/right_pane/entity_settings/name/input.text
		entity.parent = $UI/right_pane/entity_settings/parent/input.get_selected_id()
		entity.description = $UI/right_pane/entity_settings/description/input.text
		entity.status = $UI/right_pane/entity_settings/status/input.text
		entity.note = $UI/right_pane/entity_settings/note/input.text
		entity.conceal = str($UI/right_pane/entity_settings/conceal/input.button_pressed).capitalize()
		entity.game_hidden = str($UI/right_pane/entity_settings/hidden/input.button_pressed).capitalize()
		
		entity.personality = $UI/right_pane/humanlike_settings/personality/input.text
func load_entity_settings(entity_id):
	if entity_id == 0:
		$UI/right_pane/world_settings/scenario/input.text = scenario
		$UI/right_pane/world_settings/name/input.text = game_name
	else:
		var entity = entities[selected_entity]
		$UI/right_pane/entity_settings/name/input.text = entity.game_name
		$UI/right_pane/entity_settings/parent/input.select($UI/right_pane/entity_settings/parent/input.get_item_index(entity.parent))
		$UI/right_pane/entity_settings/description/input.text = entity.description
		$UI/right_pane/entity_settings/status/input.text = entity.status
		$UI/right_pane/entity_settings/note/input.text = entity.note
		$UI/right_pane/entity_settings/conceal/input.button_pressed = (entity.conceal == "True")
		$UI/right_pane/entity_settings/hidden/input.button_pressed = (entity.game_hidden == "True")
		
		$UI/right_pane/humanlike_settings/personality/input.text = entity.personality

func populate_parent_options(entity_id):
	var button = $UI/right_pane/entity_settings/parent/input
	button.clear()
	
	for entity in entities.values():
		if entity.id != entity_id:
			button.add_item(entity.game_name + " - ({0})".format([entity.id]), entity.id)
	pass

func _process(_delta):
	$floater.global_position = Vector2i(Vector2i(get_global_mouse_position()) / Vector2i(16, 16)) * Vector2i(16, 16)
	#uncomment for no grid: $floater.global_position = get_global_mouse_position()
	
	if running:
		run()
		if Engine.get_frames_drawn() % 300 == 0:
			if len(game_states) >= current_frame + 1:
				tick(current_frame)
				current_frame += 1

func tick(frame_id):
	if not OS.is_process_running(game_process["pid"]):
		print(game_process["stderr"].get_as_text())
	
	var frame = JSON.parse_string(game_states[frame_id])
	for entity_id in frame:
		var data = frame[entity_id]
		entities[int(entity_id)].update(data)

func update(data):
	pass

func run():
	#if not OS.is_process_running(game_process["pid"]):
		#print(game_process["stderr"].get_as_text())
	#else:
		#print(len(game_states))
	for frame in game_process["stdio"].get_as_text().split("\n"):
		if frame != "":
			game_states.append(frame)
	
	if len(game_states) > 20:
		OS.kill(game_process["pid"])

func _input(event):
	match state:
		Globals.EDITING:
			var is_mouse_on_world = Rect2(Vector2(), $UI/world.size).has_point($UI/world.get_local_mouse_position())
			
			if floating_entity and event.is_action("click") and event.is_pressed() and is_mouse_on_world:
				place_entity()
			elif event.is_action("click") and event.is_pressed() and is_mouse_on_world:
				if selected_entity:
					var focus_owner = entities[selected_entity].get_node("button")
					var button_has_focus = Rect2(Vector2(), focus_owner.size).has_point(focus_owner.get_local_mouse_position())
					var controls_have_focus = Rect2(Vector2(), focus_owner.get_child(0).size).has_point(focus_owner.get_child(0).get_local_mouse_position())
					if not button_has_focus and not controls_have_focus:
						select_entity(0)
	
	if event.is_action("zoom in") and event.is_pressed():
		$camera.zoom.x = clamp($camera.zoom.x + 0.05, 0.2, 5.0)
		$camera.zoom.y = clamp($camera.zoom.y + 0.05, 0.2, 5.0)
	if event.is_action("zoom out") and event.is_pressed():
		$camera.zoom.x = clamp($camera.zoom.x - 0.05, 0.2, 5.0)
		$camera.zoom.y = clamp($camera.zoom.y - 0.05, 0.2, 5.0)
	if event is InputEventMouseMotion and Input.is_action_pressed("pan"):
		$camera.global_position -= (event.relative / $camera.zoom.x)

func load_entity_list():
	var list = DirAccess.get_files_at("res://entities/")
	
	for file_name in list:
		var entity_button = EntityButton.instantiate()
		entity_button.float_entity.connect(Callable(self, "float_entity"))
		entity_button.set_entity(file_name)
		$UI/left_pane/entities/grid.add_child(entity_button)

func open_scene_editor():
	# scene
	$UI/top_panel/startstop.visible = true
	$UI/left_pane/entities.visible = true
	
	# runtime
	$UI/top_panel/time_controls.visible = false

func open_runtime_ui():
	# scene
	$UI/top_panel/startstop.visible = false
	$UI/left_pane/entities.visible = false
	
	# runtime
	$UI/top_panel/time_controls.visible = true

func compile():
	var code = "from dollhouse import Game\n\n"
	code += "game = Game(scenario='{0}')\n\n".format([scenario])
	
	var compiled_entities = [0]
	
	for entity in entities.values().slice(1):
		var ancestry = [entity.id]
		while entities[ancestry[-1]].parent != 0:
			ancestry.append(entities[ancestry[-1]].parent)
		ancestry.reverse()
		for ancestor_id in ancestry:
			if ancestor_id not in compiled_entities:
				compiled_entities.append(ancestor_id)
				code += entities[ancestor_id].get_code()
	
	code += "game.start()\n\nwhile True:\n\tgame.tick()\n\tprint(game.get_game_state())\n\tgame.fill_schedule()\n"
	
	return code

func _on_startstop_pressed():
	running = !running
	$UI/right_pane.visible = !running
	$UI/left_pane.visible = !running
	$UI/top_panel/time_controls.visible = running
	state = Globals.EDITING
	var button = ["start", "stop"][int(running)]
	$UI/top_panel/startstop.texture_normal = load("res://sprites/frame/" + button + "_normal.png")
	$UI/top_panel/startstop.texture_pressed = load("res://sprites/frame/" + button + "_pressed.png")
	$UI/top_panel/startstop.texture_hover = load("res://sprites/frame/" + button + "_hover.png")
	if running:
		state = Globals.RUNNING
		for entity in entities.values().slice(1):
			entity.set_state(Globals.RUNNING)
		start()
	else:
		state = Globals.EDITING
		for entity in entities.values().slice(1):
			entity.set_state(Globals.EDITING)

func start():
	var code = compile()
	var file = FileAccess.open("user://TECS/main.py", FileAccess.WRITE)
	file.store_string(code)
	file.close()
	
	current_frame = 0
	
	game_out = []
	game_states = []
	game_process = OS.execute_with_pipe(OS.get_user_data_dir() + "/TECS/.venv/bin/python3.14", [OS.get_user_data_dir() + "/TECS/main.py"], false)
	print(game_process["pid"])
	print(game_process["stdio"].get_path())
