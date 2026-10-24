extends VBoxContainer

## Step 1 - Priorities.
##
## Assign a priority level 0-4 to each of the five categories, either
## uniquely (the standard rule) or by distributing a pool of 10 Character
## Points (the optional flexible rule). R-S1-1 / R-S1-2.

const Rules := preload("res://rules/mw_rules.gd")
const LevelOption := preload("res://ui/level_option.gd")

var draft: RefCounted
var wizard: Control

var _use_flexible: CheckBox
var _levels: Dictionary = {}      # category -> OptionButton
var _summary: RichTextLabel


func build(_body: Control) -> void:
	# Every category is recorded from the start, at its default level of 0.
	#
	# A dropdown only reports a change, so a category the player leaves
	# alone would never be recorded at all -- and "Priority 0" could never
	# be chosen, because that is what the dropdown already shows. Since
	# the assignment needs all five categories, a single untouched row
	# would leave the whole character unresolved.
	for category in Rules.CATEGORIES:
		if not draft.priorities.has(category):
			draft.priorities[category] = 0
	draft.apply_priorities()
	
	var scroll := ScrollContainer.new()
	scroll.name = "PrioritiesScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	
	var panel := VBoxContainer.new()
	panel.name = "PrioritiesPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	scroll.add_child(panel)
	
	# Rule choice.
	# A highlighted panel so the rule toggle stands out on the dark theme.
	var mode_row := PanelContainer.new()
	mode_row.name = "ModeRow"
	mode_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mode_style := StyleBoxFlat.new()
	mode_style.bg_color = Color(0.13, 0.18, 0.32)
	mode_style.border_color = Color(0.95, 0.78, 0.25)
	mode_style.set_border_width_all(1)
	mode_style.set_corner_radius_all(6)
	mode_style.content_margin_left = 12
	mode_style.content_margin_right = 12
	mode_style.content_margin_top = 8
	mode_style.content_margin_bottom = 8
	mode_row.add_theme_stylebox_override("panel", mode_style)
	panel.add_child(mode_row)
	
	var mode_inner := HBoxContainer.new()
	mode_inner.name = "ModeInner"
	mode_inner.add_theme_constant_override("separation", 10)
	mode_row.add_child(mode_inner)
	
	_use_flexible = CheckBox.new()
	_use_flexible.name = "FlexibleCheck"
	_use_flexible.text = "Flexible Priorities: distribute 10 Character Points (instead of assigning 0-4 once each)"
	_use_flexible.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_use_flexible.add_theme_color_override("font_color", Color(0.85, 0.85, 0.92))
	_use_flexible.add_theme_color_override("font_hover_color", Color(0.95, 0.78, 0.25))
	_use_flexible.add_theme_color_override("font_pressed_color", Color(0.95, 0.78, 0.25))
	_use_flexible.toggled.connect(_on_mode_toggled)
	mode_inner.add_child(_use_flexible)
	
	# One row per category.
	for category in Rules.CATEGORIES:
		panel.add_child(_make_category_row(category))
	
	# Live summary of what the priorities grant.
	_summary = RichTextLabel.new()
	_summary.name = "PrioritySummary"
	_summary.focus_mode = Control.FOCUS_NONE
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	_summary.custom_minimum_size = Vector2(0, 150)
	panel.add_child(_summary)
	
	_update_summary()


func _make_category_row(category: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "Row_%s" % category
	row.add_theme_constant_override("separation", 8)
	
	var label := Label.new()
	label.name = "Label"
	label.text = category
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)
	
	var option := LevelOption.new()
	option.name = "Option"
	option.custom_minimum_size = Vector2(300, 0)
	option.item_selected.connect(_on_level_changed.bind(category))
	_levels[category] = option
	row.add_child(option)
	
	_refresh_category_options(category)
	return row


func _refresh_category_options(category: String) -> void:
	var option: OptionButton = _levels[category]
	option.clear()
	var values: Dictionary = Rules.PRIORITY_VALUES[category]
	for level in range(5):
		option.add_item("Priority %d  ->  %s" % [level, str(values[level])])
	# Show what the draft already holds, so rebuilding the options (for
	# example when the rule mode is toggled) does not lose the choice.
	option.select(clampi(int(draft.priorities.get(category, 0)), 0, 4))


func _on_mode_toggled(_pressed: bool) -> void:
	draft.use_flexible_priorities = _use_flexible.button_pressed
	for category in Rules.CATEGORIES:
		_refresh_category_options(category)
	_update_summary()


func _on_level_changed(_index: int, category: String) -> void:
	var option: OptionButton = _levels[category]
	var level: int = option.selected
	draft.priorities[category] = level
	draft.apply_priorities()
	_update_summary()
	wizard.refresh()


func _update_summary() -> void:
	if _summary == null:
		return
	if draft.priorities.size() < 5:
		_summary.text = "[i]Assign all five categories to see what they grant.[/i]"
		return
	var lines: Array[String] = []
	lines.append("[b]What these priorities grant[/b]")
	for category in Rules.CATEGORIES:
		var value = Rules.PRIORITY_VALUES[category][int(draft.priorities.get(category, 0))]
		lines.append("  %s: Priority %d  ->  %s" % [category, int(draft.priorities.get(category, 0)), str(value)])
	var validation: Dictionary = (
		Rules.validate_flexible_priorities(draft.priorities)
		if draft.use_flexible_priorities
		else Rules.validate_standard_priorities(draft.priorities)
	)
	if validation.ok:
		lines.append("[color=#7fd67f]Valid assignment.[/color]")
	else:
		lines.append("[color=#f28f78]%s[/color]" % str(validation.error))
	_summary.text = "\n".join(lines)


func is_complete() -> bool:
	if draft.priorities.size() < 5:
		return false
	if draft.use_flexible_priorities:
		return bool(Rules.validate_flexible_priorities(draft.priorities).ok)
	return bool(Rules.validate_standard_priorities(draft.priorities).ok)
