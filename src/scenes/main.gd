extends Control

## MechWarrior PCS - boot scene.
##
## Hosts the character-creation wizard. The wizard builds its own UI in
## code (src/ui/wizard.gd), so there is no hand-authored scene file to
## get subtly wrong and the whole tree is inspectable live through the
## Godot MCP bridge.

const Wizard := preload("res://ui/wizard.gd")

var wizard: Control


func _ready() -> void:
	wizard = Wizard.new()
	wizard.name = "Wizard"
	wizard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wizard)
