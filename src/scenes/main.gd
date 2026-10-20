extends Control

## MechWarrior PCS — character creation companion.
## Boot scene. The real UI is built by the wizard (see src/ui/).
## This script exists so the project always has a valid entry point and so
## the Godot MCP bridge can inspect the live scene tree.

func _ready() -> void:
	# Placeholder root so the scene is never empty. Replaced by the
	# character-creation wizard once the UI system lands.
	var label := Label.new()
	label.text = "MechWarrior PCS — character creation"
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
