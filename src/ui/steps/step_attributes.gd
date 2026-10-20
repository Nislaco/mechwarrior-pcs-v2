extends VBoxContainer

## Step 3 - Attributes.
##
## Distribute the attribute points across the five attributes, respecting
## the racial maximums. INTUITION is special: it costs two points per
## point of value, so the UI bounds POINTS, not value. R-S1-5..R-S1-7.

const Rules := preload("res://rules/mw_rules.gd")

var draft: RefCounted
var wizard: Control

var _points_label: Label
var _rows: Dictionary = {}       # attribute -> {spin, value, cap, modifier}
var _derived: RichTextLabel
var _notes: RichTextLabel


func build(_body: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "AttributesScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	
	var panel := VBoxContainer.new()
	panel.name = "AttributesPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	scroll.add_child(panel)
	
	_points_label = Label.new()
	_points_label.name = "PointsLabel"
	_points_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_points_label)
	
	for attribute in Rules.ATTRIBUTES:
		panel.add_child(_make_attribute_row(attribute))
	
	_derived = RichTextLabel.new()
	_derived.name = "Derived"
	_derived.focus_mode = Control.FOCUS_NONE
	_derived.bbcode_enabled = true
	_derived.fit_content = true
	_derived.custom_minimum_size = Vector2(0, 130)
	panel.add_child(_derived)
	
	_notes = RichTextLabel.new()
	_notes.name = "Notes"
	_notes.focus_mode = Control.FOCUS_NONE
	_notes.bbcode_enabled = true
	_notes.fit_content = true
	_notes.add_theme_color_override("font_color", Color(0.95, 0.78, 0.45))
	panel.add_child(_notes)
	
	_refresh()


func _make_attribute_row(attribute: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "Row_%s" % attribute
	row.add_theme_constant_override("separation", 8)
	
	var label := Label.new()
	label.name = "Label"
	label.text = attribute
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	
	var spin := SpinBox.new()
	spin.name = "Spin"
	spin.min_value = 0
	spin.max_value = 0
	spin.value = 0
	spin.get_line_edit().select_all_on_focus = true
	spin.value_changed.connect(_on_points_changed.bind(attribute))
	row.add_child(spin)
	
	var points_label := Label.new()
	points_label.name = "Points"
	points_label.custom_minimum_size = Vector2(120, 0)
	points_label.add_theme_color_override("font_color", Color(0.62, 0.62, 0.70))
	row.add_child(points_label)
	
	var value_label := Label.new()
	value_label.name = "Value"
	value_label.custom_minimum_size = Vector2(220, 0)
	row.add_child(value_label)
	
	_rows[attribute] = {"spin": spin, "points": points_label, "value": value_label}
	return row


func _on_points_changed(value: float, attribute: String) -> void:
	var requested: int = int(value)
	# The spin's maximum is allowed to sit above the pool (so the value is
	# never silently clamped), so the pool is enforced here instead.
	var pool: int = draft.attribute_points
	var others: int = 0
	for other in draft.attribute_spent:
		if other != attribute:
			others += int(draft.attribute_spent[other])
	if others + requested > pool:
		requested = maxi(0, pool - others)
	draft.attribute_spent[attribute] = requested
	draft.recompute_attributes()
	_refresh()
	wizard.refresh()


func _refresh() -> void:
	if draft.race.is_empty():
		return
	var modifiers: Dictionary = Rules.race_modifiers(draft.race)
	var maximums: Dictionary = Rules.race_maximums(draft.race)
	# The Exceptional Attribute raises one attribute's maximum by 1.
	var effective_max: Dictionary = maximums.duplicate()
	if not draft.exceptional_attribute.is_empty() and effective_max.has(draft.exceptional_attribute):
		effective_max[draft.exceptional_attribute] = int(effective_max[draft.exceptional_attribute]) + 1
	
	var remaining: int = draft.remaining_attribute_points()
	_points_label.text = "Attribute Points remaining: %d  (of %d)   -   race: %s" % [remaining, draft.attribute_points, draft.race]
	
	for attribute in Rules.ATTRIBUTES:
		var row: Dictionary = _rows[attribute]
		var spin: SpinBox = row.spin
		var spent: int = int(draft.attribute_spent.get(attribute, 0))
		# The headroom is how many MORE points may go in. The spin's maximum
		# must never sit below the points already allocated, or Godot clamps
		# the value and silently destroys the player's allocation.
		var headroom: int = Rules.attribute_points_headroom(attribute, spent, effective_max, modifiers)
		var pool: int = remaining + spent
		spin.max_value = maxi(spent, mini(headroom, pool))
		spin.set_value_no_signal(spent)
		var value: int = Rules.attribute_final_value(attribute, spent, modifiers)
		row.points.text = "%d points" % spent
		if attribute == "INTUITION":
			row.value.text = "value %d  (2 points per 1)" % value
		else:
			row.value.text = "value %d" % value
	
	_update_derived()


func _update_derived() -> void:
	if _derived == null:
		return
	var lines: Array[String] = ["[b]Derived values[/b]"]
	if not draft.saving_throws.is_empty():
		lines.append("  Saving throws: " + _format_map(draft.saving_throws))
		lines.append("  Characteristics: " + _format_map(draft.characteristics))
	_derived.text = "\n".join(lines)
	
	if _notes != null:
		if draft.service_notes.is_empty():
			_notes.text = ""
		else:
			_notes.text = "[i]" + " | ".join(draft.service_notes) + "[/i]"


func _format_map(map: Dictionary) -> String:
	var parts: Array[String] = []
	for key in map:
		parts.append("%s %d" % [str(key), int(map[key])])
	return ", ".join(parts)


func is_complete() -> bool:
	# All attribute points must be spent.
	return draft.remaining_attribute_points() == 0
