extends VBoxContainer

## Step 6 - Character sheet.
##
## Shows the finished character and writes the export. R-S1-10.

var draft: RefCounted
var wizard: Control

var _sheet: RichTextLabel
var _save_label: Label


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
	
	_sheet = RichTextLabel.new()
	_sheet.name = "Sheet"
	_sheet.focus_mode = Control.FOCUS_NONE
	_sheet.bbcode_enabled = true
	_sheet.fit_content = true
	_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(_sheet)
	
	_save_label = Label.new()
	_save_label.name = "SaveLabel"
	_save_label.add_theme_font_size_override("font_size", 13)
	_save_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
	panel.add_child(_save_label)
	
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
	
	lines.append("[b]Equipment[/b]  (credits remaining: %d)" % draft.remaining_credits())
	for item in draft.equipment:
		lines.append("  %-28s %d credits" % [str(item.get("name", "?")), int(item.get("cost", 0))])
	lines.append("")
	
	if not draft.service_notes.is_empty():
		lines.append("[color=#f0c878][i]" + " | ".join(draft.service_notes) + "[/i][/color]")
	
	_sheet.text = "\n".join(lines)


func finish() -> void:
	# Write the character to user://. R-S1-10.
	if wizard and wizard.has_method("save_character"):
		var ok: bool = wizard.save_character()
		if _save_label:
			_save_label.text = "Saved to user://character.json" if ok else "Could not write user://character.json"
	_refresh()


func is_complete() -> bool:
	return true
