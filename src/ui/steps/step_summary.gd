extends VBoxContainer

## Step 5 - Character Sheet (Finishing Touches).
##
## Shows the finished character and writes the export. R-S1-10.
##
## The report mirrors the Python reference (mw-depo/mw-script/chargen.py):
## priorities, attributes, saving throws, characteristics, advantages,
## skills, skill targets, and a service-eligibility note.

var draft: RefCounted
var wizard: Control

const Draft := preload("res://ui/character_draft.gd")
const Rules := preload("res://rules/mw_rules.gd")

var _sheet: RichTextLabel
var _saved_panel: PanelContainer
var _saved_label: RichTextLabel
var _save_dialog: FileDialog
var _save_report_btn: Button
var _panel: VBoxContainer


func build(_body: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "SheetScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	
	_panel = VBoxContainer.new()
	_panel.name = "SheetPanel"
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_theme_constant_override("separation", 8)
	scroll.add_child(_panel)
	
	# The confirmation that the character was written. This has to be
	# obvious: the character is saved, the wizard stays open, and a thin
	# line of text is easy to miss.
	#
	# It goes ABOVE the sheet. The sheet is long, so a confirmation
	# underneath it would sit below the fold -- exactly where a player
	# who has just pressed Finish would not see it.
	_saved_panel = PanelContainer.new()
	_saved_panel.name = "SavedPanel"
	_saved_panel.visible = false
	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	style.border_color = Color(0.55, 0.85, 0.55)
	style.bg_color = Color(0.12, 0.20, 0.14)
	style.set_content_margin_all(10)
	_saved_panel.add_theme_stylebox_override("panel", style)
	_panel.add_child(_saved_panel)
	
	_saved_label = RichTextLabel.new()
	_saved_label.name = "SavedLabel"
	_saved_label.focus_mode = Control.FOCUS_NONE
	_saved_label.bbcode_enabled = true
	_saved_label.fit_content = true
	_saved_panel.add_child(_saved_label)
	
	# Button to save the report as a text file in a user-chosen location.
	_save_report_btn = Button.new()
	_save_report_btn.name = "SaveReportButton"
	_save_report_btn.text = "Save Report"
	_save_report_btn.custom_minimum_size = Vector2(120, 36)
	_save_report_btn.add_theme_font_size_override("font_size", 14)
	_save_report_btn.pressed.connect(_on_save_report_btn_pressed)
	_panel.add_child(_save_report_btn)
	
	_sheet = RichTextLabel.new()
	_sheet.name = "Sheet"
	_sheet.focus_mode = Control.FOCUS_NONE
	_sheet.bbcode_enabled = true
	_sheet.fit_content = true
	_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(_sheet)
	
	_refresh()


func _refresh() -> void:
	if _sheet == null:
		return
	var lines: Array[String] = []
	
	# Header
	lines.append("[b]FINAL REPORT[/b]")
	lines.append("")
	
	# Character Priorities
	lines.append("[b]Character Priorities:[/b]")
	var resolved: Dictionary = Rules.resolve_priorities(draft.priorities)
	for category in draft.priorities:
		var level: int = int(draft.priorities[category])
		var value: Variant = Rules.PRIORITY_VALUES.get(category, {}).get(level, "?")
		lines.append("  %s: Priority %d (%s)" % [category, level, str(value)])
	lines.append("")
	
	# Attributes
	lines.append("[b]Attributes:[/b]")
	for attribute in draft.final_attributes:
		lines.append("  %s: %d" % [attribute, int(draft.final_attributes[attribute])])
	lines.append("")
	
	# Saving Throws
	lines.append("[b]Saving Throws:[/b]")
	for attribute in draft.saving_throws:
		lines.append("  %s: %d" % [attribute, int(draft.saving_throws[attribute])])
	lines.append("")
	
	# Characteristics
	lines.append("[b]Characteristics:[/b]")
	for characteristic in draft.characteristics:
		lines.append("  %s: %d" % [characteristic, int(draft.characteristics[characteristic])])
	lines.append("")
	
	# Advantages
	lines.append("[b]Advantages:[/b]")
	if draft.purchased_advantages.is_empty():
		lines.append("  None")
	else:
		for advantage in draft.purchased_advantages:
			var cost: int = int(draft.purchased_advantages[advantage])
			if cost == 0:
				lines.append("  %s (included free - Elemental racial trait)" % advantage)
			else:
				lines.append("  %s (%d points)" % [advantage, cost])
	lines.append("")
	
	# Skills
	lines.append("[b]Skills:[/b]")
	if not draft.selected_package.is_empty():
		lines.append("  Selected Skill Package: %s" % draft.selected_package)
	if draft.purchased_skills.is_empty():
		lines.append("  None")
	else:
		for skill in draft.purchased_skills:
			var level: int = int(draft.purchased_skills[skill])
			if level > 0:
				lines.append("  %s: Level %d" % [skill, level])
	lines.append("")
	
	# Skill Targets
	var targets := _compute_skill_targets()
	lines.append("[b]Skill Targets:[/b]")
	if targets.is_empty():
		lines.append("  None")
	else:
		for skill in targets:
			lines.append("  %s: %d" % [skill, int(targets[skill])])
	lines.append("")
	
	# Assets
	lines.append("[b]Assets:[/b]  %d C-Bills" % draft.asset_credits())
	lines.append("")
	
	# Service Eligibility Note
	if not draft.service_notes.is_empty():
		lines.append("[color=#f0c878][i]" + " | ".join(draft.service_notes) + "[/i][/color]")
	
	_sheet.text = "\n".join(lines)


## Compute the skill targets for each purchased skill.
## Target = characteristic base - skill level.
func _compute_skill_targets() -> Dictionary:
	var targets: Dictionary = {}
	for skill in draft.purchased_skills:
		var level: int = int(draft.purchased_skills[skill])
		if level <= 0:
			continue
		var char_name := _skill_characteristic(skill)
		if char_name.is_empty():
			continue
		var char_value: int = int(draft.characteristics.get(char_name, 0))
		targets[skill] = char_value - level
	return targets


## The characteristic a skill rolls against.
func _skill_characteristic(skill: String) -> String:
	match skill:
		"Acrobatics", "Archery", "Blade", "Climbing", "Jump Pack", "Running", "Swimming", "Unarmed Combat":
			return "Athletic"
		"Administration", "Alternate Identity", "Appraisal", "Computer", "Cryptography", "Demolitions", \
		 "Engineering", "Forgery", "Gambling", "Medtech", "Navigation", "Perception", "Security Systems", \
		 "Special Interests", "Strategy", "Survival", "Tactics", "Technician/Aerospace", "Technician/BattleMech", \
		 "Technician/Battlesuit", "Technician/Electronics", "Technician/Mechanic", "Technician/Spacecraft", \
		 "Technician/Weapons", "Tinker", "Tracking", "Communications/Conventional", "Communications/Hyperpulse Generator":
			return "Mental"
		"Drive/Ground", "Drive/Naval", "Escape Artist", "Gunnery/Aerospace", "Gunnery/Artillery", \
		 "Gunnery/BattleMech", "Gunnery/Battlesuit", "Gunnery/Conventional", "Gunnery/Spacecraft", \
		 "Piloting/Aerospace", "Piloting/BattleMech", "Piloting/Spacecraft", "Piloting/VTOL", \
		 "Quickdraw", "Small Arms", "Stealth", "Support Weapons", "Throwing Weapons", "Zero-G Operations":
			return "Physical"
		"Bureaucracy", "Impersonation", "Interrogation", "Leadership", "Negotiation", "Protocol", \
		 "Scrounge", "Seduction", "Streetwise", "Training", "Career Skills":
			return "Social"
	return ""


## Open the file dialog so the player can choose where to save the report.
## Uses ACCESS_FILESYSTEM so the dialog is not sandboxed to res:// or user://.
func _on_save_report_btn_pressed() -> void:
	if _save_dialog == null:
		_save_dialog = FileDialog.new()
		_save_dialog.name = "ReportFileDialog"
		_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_save_dialog.file_selected.connect(_on_file_selected)
		_save_dialog.canceled.connect(_on_dialog_canceled)
		_panel.add_child(_save_dialog)
	
	# Start in the user's home directory.
	_save_dialog.access_path = OS.get_environment("HOME")
	_save_dialog.current_file = "character_report.txt"
	
	_save_dialog.popup_centered_ratio()


## Write the report text to the chosen file and show a confirmation.
func _on_file_selected(file_path: String) -> void:
	push_warning("File selected: %s" % file_path)
	_save_dialog.hide()
	
	# Convert BBCode to plain text for the saved file.
	var plain_text: String = _bbcode_to_plain(_sheet.text)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(plain_text)
		file.close()
		push_warning("File written successfully")
		_saved_label.text = "[b][color=#8ce08c]Report saved[/color][/b]\n  written to [code]%s[/code]" % file_path
	else:
		push_warning("File write failed")
		_saved_label.text = "[b][color=#f28f78]Failed to write report[/color][/b]\n  unable to write to [code]%s[/code]" % file_path


## Convert BBCode markup to plain text.
func _bbcode_to_plain(bbcode: String) -> String:
	var result: String = bbcode
	# Remove common BBCode tags and replace with plain text.
	result = result.replace("[b]", "").replace("[/b]", "")
	result = result.replace("[i]", "").replace("[/i]", "")
	result = result.replace("[u]", "").replace("[/u]", "")
	result = result.replace("[color=#", "").replace("]", "")
	result = result.replace("[/color]", "")
	result = result.replace("[code]", "\\n[code]").replace("[/code]", "[/code]")
	result = result.replace("[url=]", "").replace("[/url]", "")
	return result


func _on_dialog_canceled() -> void:
	_save_dialog.hide()


## Write the character and show the confirmation. R-S1-10.
## Returns whether the character was written.
func finish() -> bool:
	var ok: bool = false
	if wizard and wizard.has_method("save_character"):
		ok = bool(wizard.save_character())
	if _saved_label and _saved_panel:
		if ok:
			_saved_label.text = "[b][color=#8ce08c]Character saved[/color][/b]\n  written to [code]%s[/code]\n  use \"New Character\" to build another one" % Draft.SAVE_PATH
		else:
			_saved_label.text = "[b][color=#f28f78]Could not write the character[/color][/b]\n  %s could not be written" % Draft.SAVE_PATH
		_saved_panel.visible = true
	_refresh()
	return ok


func is_complete() -> bool:
	return true
