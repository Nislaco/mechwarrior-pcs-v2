extends Control

## Step-by-step character-creation wizard.
##
## The flow mirrors the Python reference (mw-depo/mw-script/chargen.py):
##   1. Priorities      2. Advantages     3. Attributes
##   4. Skills          5. Character sheet
##
## The wizard is a thin shell: every rule decision is delegated to the
## verified engine in src/rules/, and every step is a Control that
## builds its own body. Navigation is gated on the current step
## reporting itself complete.
##
## Layout is built in code rather than in a .tscn, so there is no
## hand-authored scene file to get subtly wrong, and the whole tree is
## inspectable live through the Godot MCP bridge.

const Draft := preload("res://ui/character_draft.gd")

const STEPS: Array[String] = [
	"res://ui/steps/step_priorities.gd",
	"res://ui/steps/step_advantages.gd",
	"res://ui/steps/step_attributes.gd",
	"res://ui/steps/step_skills.gd",
	"res://ui/steps/step_summary.gd",
]

const STEP_TITLES: Array[String] = [
	"Priorities",
	"Advantages",
	"Attributes",
	"Skills",
	"Character Sheet",
]

var draft: RefCounted
var step_index: int = 0
var step: Control = null

# Layout nodes
var header: VBoxContainer
var title_label: Label
var progress_label: Label
var body: VBoxContainer
var footer: HBoxContainer
var back_button: Button
var next_button: Button
var new_character_button: Button
var message_label: Label

## Where a finished character is written. R-S1-10.
const SAVE_PATH: String = Draft.SAVE_PATH

const COL_BG: Color = Color(0.10, 0.10, 0.15)
const COL_PANEL: Color = Color(0.15, 0.15, 0.22)
const COL_ACCENT: Color = Color(0.95, 0.78, 0.25)
const COL_TEXT: Color = Color(0.88, 0.88, 0.92)
const COL_MUTED: Color = Color(0.62, 0.62, 0.70)
const COL_ERROR: Color = Color(0.95, 0.55, 0.45)
const COL_OK: Color = Color(0.55, 0.85, 0.55)


func _ready() -> void:
	draft = Draft.new()
	_build_shell()
	_show_step(0)


# --- Shell -----------------------------------------------------------------

func _build_shell() -> void:
	# Root background.
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = COL_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	var root := VBoxContainer.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	
	# Header
	header = VBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 2)
	root.add_child(header)
	
	title_label = Label.new()
	title_label.name = "Title"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", COL_ACCENT)
	header.add_child(title_label)
	
	progress_label = Label.new()
	progress_label.name = "Progress"
	progress_label.add_theme_font_size_override("font_size", 13)
	progress_label.add_theme_color_override("font_color", COL_MUTED)
	header.add_child(progress_label)
	
	# Body - each step fills this.
	body = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)
	
	# Message line (validation feedback from the current step).
	message_label = Label.new()
	message_label.name = "Message"
	message_label.add_theme_font_size_override("font_size", 14)
	message_label.add_theme_color_override("font_color", COL_ERROR)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(message_label)
	
	# Footer
	footer = HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)
	
	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(140, 40)
	back_button.pressed.connect(_on_back)
	footer.add_child(back_button)
	
	# Appears once a character has been saved, so a second one can be
	# built without restarting the application.
	new_character_button = Button.new()
	new_character_button.name = "NewCharacterButton"
	new_character_button.text = "New Character"
	new_character_button.custom_minimum_size = Vector2(180, 40)
	new_character_button.visible = false
	new_character_button.pressed.connect(_on_new_character)
	footer.add_child(new_character_button)
	
	next_button = Button.new()
	next_button.name = "NextButton"
	next_button.text = "Next"
	next_button.custom_minimum_size = Vector2(180, 40)
	next_button.pressed.connect(_on_next)
	footer.add_child(next_button)


# --- Navigation ------------------------------------------------------------

func _show_step(index: int) -> void:
	step_index = clampi(index, 0, STEPS.size() - 1)
	
	for child in body.get_children():
		# remove_child first: queue_free() is deferred, so the outgoing
		# step would still be in the body (and still the first child) until
		# the end of the frame.
		body.remove_child(child)
		child.queue_free()
	message_label.text = ""
	
	var step_script := load(STEPS[step_index])
	step = step_script.new()
	step.name = "Step_%d" % step_index
	step.draft = draft
	step.wizard = self
	# The step must fill the body. A step is a VBoxContainer, so it lays
	# out its own children; without the expand flags the body would give
	# it only its minimum size and the whole step would collapse to zero
	# height, taking every control in it out of the visible and clickable
	# area.
	step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(step)
	if step.has_method("build"):
		step.build(body)
	
	title_label.text = STEP_TITLES[step_index]
	progress_label.text = "Step %d of %d  -  %s" % [step_index + 1, STEPS.size(), STEP_TITLES[step_index]]
	
	back_button.disabled = step_index == 0
	next_button.disabled = false
	next_button.text = "Next" if step_index < STEPS.size() - 1 else "Finish"
	
	_update_footer()
	_focus_first_control()


## Give the keyboard a starting point.
##
## Without this the viewport has no focus owner at all, so Enter and Space
## go nowhere: the player has to click a control before the keyboard can
## reach it.
##
## The first *value* control (a dropdown, a spin box, a text field) takes
## focus, not the first focusable control. On the priorities step that
## would be the "Flexible Priorities" checkbox, and a player pressing
## Enter to open the first dropdown would instead silently switch the
## priority mode.
func _focus_first_control() -> void:
	var target: Control = _find_value_control(body)
	if target == null:
		target = _find_focusable(body)
	if target == null:
		target = next_button
	if target == null:
		return
	# A SpinBox cannot take focus itself -- its focus_mode is NONE and
	# the player types into the line edit inside it. Focusing the SpinBox
	# warns and does nothing, so focus the line edit.
	if target is SpinBox:
		var edit: LineEdit = target.get_line_edit()
		if edit != null:
			edit.grab_focus()
			return
	target.grab_focus()


## The first control a player types a value into.
func _find_value_control(node: Node) -> Control:
	for child in node.get_children():
		if child is Control:
			var control: Control = child
			if control is OptionButton or control is SpinBox or control is LineEdit:
				return control
			var found: Control = _find_value_control(control)
			if found != null:
				return found
	return null


## The first focusable control at or below `node`, depth first.
func _find_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is Control:
			var control: Control = child
			if control.focus_mode != Control.FOCUS_NONE and not control.disabled:
				return control
			var found: Control = _find_focusable(control)
			if found != null:
				return found
	return null


func _on_next() -> void:
	if step and step.has_method("is_complete") and not step.is_complete():
		_show_message("Finish this step before continuing.")
		return
	if step_index >= STEPS.size() - 1:
		_finish()
		return
	_show_step(step_index + 1)


func _on_back() -> void:
	if step_index <= 0:
		return
	_show_step(step_index - 1)


func _finish() -> void:
	# The final step is the character sheet; finishing writes the export.
	var saved: bool = false
	if step and step.has_method("finish"):
		saved = bool(step.finish())
	if not saved:
		_show_message("Could not save the character to %s." % SAVE_PATH)
		return
	# Make the finished state unmistakable. A thin line of text in the
	# same colour as an error message is easy to miss, and pressing
	# "Finish" again would otherwise just re-save with no visible change.
	next_button.text = "Saved"
	next_button.disabled = true
	new_character_button.visible = true
	_show_message("Character saved to %s.  %d skills, %d advantages." % [
		SAVE_PATH,
		draft.purchased_skills.size(),
		draft.purchased_advantages.size(),
	], true)


## Start a fresh character. The wizard stays open, so this is how a
## second character is built.
func _on_new_character() -> void:
	draft = Draft.new()
	new_character_button.visible = false
	_show_step(0)
	_show_message("")


func _show_message(text: String, ok: bool = false) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", COL_OK if ok else COL_ERROR)


func _update_footer() -> void:
	# The Next button is disabled when the step is not complete, except on
	# the last step where "Finish" always works.
	if step_index == STEPS.size() - 1:
		next_button.disabled = false
		return
	next_button.disabled = step == null or not step.has_method("is_complete") or not step.is_complete()


## Called by a step when its state changed, so the footer stays accurate.
func refresh() -> void:
	_update_footer()


## Save the finished character to user://. R-S1-10.
func save_character(path: String = SAVE_PATH) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(draft.to_export(), "", 2))
	file.close()
	return true
