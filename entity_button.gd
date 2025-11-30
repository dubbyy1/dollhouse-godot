extends TextureButton

var entity = ""

signal float_entity

func set_entity(file_name:String):
	entity = file_name
	$sprite.texture = load("res://sprites/entities/" + file_name.replace(".tscn", ".png"))

func _on_pressed():
	emit_signal("float_entity", entity)
