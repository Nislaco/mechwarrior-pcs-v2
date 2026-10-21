extends VBoxContainer

## Step 6 - Character sheet.
##
## Shows the finished character and writes the export. R-S1-10.

var draft: RefCounted
var wizard: Control

const Draft := preload("res://ui/character_draft.gd")

var _sheet: RichTextLabel
var _saved_panel: PanelContainer
var _saved_label: RichTextLabel


func build(_body: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "SheetScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	
	var panel := VBoxContainer.new()
	panel.name = "SheetPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	scroll.add_child(panel)
	
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
	panel.add_child(_saved_panel)
	
	_saved_label = RichTextLabel.new()
	_saved_label.name = "SavedLabel"
	_saved_label.focus_mode = Control.FOCUS_NONE
	_saved_label.bbcode_enabled = true
	_saved_label.fit_content = true
	_saved_panel.add_child(_saved_label)
	
	_sheet = RichTextLabel.new()
	_sheet.name = "Sheet"
	_sheet.focus_mode = Control.FOCUS_NONE
	_sheet.bbcode_enabled = true
	_sheet.fit_content = true
	_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(_sheet)
	
	_refresh()


func _refresh() -> void:
	if _sheet == null:
		return
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % (draft.name if not draft.name.is_empty() else "Unnamed character"))
	lines.append("Race: [b]%s[/b]    Vehicle Class: %s" % [draft.race, draft.vehicle_class])
	lines.append("")
	
	lines.append("[b]Priorities[/b]")
	for category in draft.priorities:
		lines.append("  %s: %d" % [category, int(draft.priorities[category])])
	lines.append("")
	
	lines.append("[b]Attributes[/b]  (base points -> final value)")
	for attribute in draft.attribute_spent:
		lines.append("  %-10s %2d points -> %d" % [
			attribute, int(draft.attribute_spent[attribute]),
			int(draft.final_attributes.get(attribute, 0))])
	lines.append("")
	
	lines.append("[b]Saving throws[/b]")
	for attribute in draft.saving_throws:
		lines.append("  %-10s %d" % [attribute, int(draft.saving_throws[attribute])])
	lines.append("")
	
	lines.append("[b]Characteristics[/b]")
	for characteristic in draft.characteristics:
		lines.append("  %-10s %d" % [characteristic, int(draft.characteristics[characteristic])])
	lines.append("")
	
	lines.append("[b]Advantages[/b]")
	if draft.purchased_advantages.is_empty():
		lines.append("  (none)")
	for advantage in draft.purchased_advantages:
		lines.append("  %s  (%d points)" % [advantage, int(draft.purchased_advantages[advantage])])
	lines.append("")
	
	lines.append("[b]Skills[/b]  (remaining points: %d)" % draft.remaining_skill_points())
	for skill in draft.purchased_skills:
		lines.append("  %-28s %d" % [skill, int(draft.purchased_skills[skill])])
	lines.append("")
	
	lines.append("[b]Equipment[/b]")
	for item in draft.equipment:
		lines.append("  %-28s %d credits" % [str(item.get("name", "?")), int(item.get("cost", 0))])
	lines.append("")
	
	# The character's credit pool, and the balance left after the
	# equipment. The balance does not have to be zero: a character may
	# finish creation without spending all of its credits.
	lines.append("[b]Credits[/b]  %d total  -  %d spent on equipment  -  %d remaining" % [
		draft.credits, draft.equipment_cost(), draft.remaining_credits()])
	lines.append("")
	
	if not draft.service_notes.is_empty():
		lines.append("[color=#f0c878][i]" + " | ".join(draft.service_notes) + "[/i][/color]")
	
	_sheet.text = "\n".join(lines)


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
