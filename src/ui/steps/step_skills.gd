extends VBoxContainer

## Step 4 - Skills.
##
## Optionally buy a skill package, then spend the remaining skill points
## on individual skills. No skill level may exceed LEARN. R-S1-8.

const Rules := preload("res://rules/mw_rules.gd")
const SkillRules := preload("res://rules/mw_rules_skills.gd")
const LevelOption := preload("res://ui/level_option.gd")

var draft: RefCounted
var wizard: Control

var _points_label: Label
var _package_list: VBoxContainer
var _skill_list: VBoxContainer
var _learn_label: Label


func build(_body: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "SkillsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	
	var panel := VBoxContainer.new()
	panel.name = "SkillsPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	scroll.add_child(panel)
	
	_points_label = Label.new()
	_points_label.name = "PointsLabel"
	_points_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_points_label)
	
	_learn_label = Label.new()
	_learn_label.name = "LearnLabel"
	_learn_label.add_theme_font_size_override("font_size", 12)
	_learn_label.add_theme_color_override("font_color", Color(0.62, 0.62, 0.70))
	panel.add_child(_learn_label)
	
	# Package offers.
	var package_title := Label.new()
	package_title.name = "PackageTitle"
	package_title.text = "Skill packages"
	package_title.add_theme_font_size_override("font_size", 16)
	panel.add_child(package_title)
	
	_package_list = VBoxContainer.new()
	_package_list.name = "PackageList"
	_package_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_package_list.add_theme_constant_override("separation", 4)
	panel.add_child(_package_list)
	
	# Individual skills.
	#
	# The skill list is NOT wrapped in a second scroll container. A
	# ScrollContainer nested inside another one has a minimum height of
	# zero (it can always scroll), so the inner one collapses and takes
	# every skill row with it. The step's own scroll carries the whole
	# step instead.
	var skill_title := Label.new()
	skill_title.name = "SkillTitle"
	skill_title.text = "Individual skills"
	skill_title.add_theme_font_size_override("font_size", 16)
	panel.add_child(skill_title)
	
	_skill_list = VBoxContainer.new()
	_skill_list.name = "SkillList"
	_skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_list.add_theme_constant_override("separation", 2)
	panel.add_child(_skill_list)
	
	_refresh()


func _refresh() -> void:
	for child in _package_list.get_children():
		child.queue_free()
	for child in _skill_list.get_children():
		child.queue_free()
	
	var remaining: int = draft.remaining_skill_points()
	_points_label.text = "Skill Points remaining: %d  (of %d)" % [remaining, draft.skill_points]
	_learn_label.text = "No skill level may exceed your LEARN attribute (%d).  Package cost is deducted from the same pool." % int(draft.final_attributes.get("LEARN", 0))
	
	_refresh_packages(remaining)
	_refresh_skills(remaining)


func _refresh_packages(remaining: int) -> void:
	# The selected package is shown as bought.
	if not draft.selected_package.is_empty():
		var row := HBoxContainer.new()
		row.name = "BoughtPackage"
		var label := Label.new()
		label.text = "Purchased: %s" % draft.selected_package
		label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
		row.add_child(label)
		_package_list.add_child(row)
	
	var eligible: Dictionary = SkillRules.eligible_packages(draft.race, remaining)
	if eligible.is_empty():
		var none := Label.new()
		none.text = "No package is affordable with %d points." % remaining
		none.add_theme_color_override("font_color", Color(0.62, 0.62, 0.70))
		_package_list.add_child(none)
		return
	
	for package_name in eligible:
		var spec: Dictionary = eligible[package_name]
		var row := HBoxContainer.new()
		row.name = "Package_%s" % package_name
		row.add_theme_constant_override("separation", 8)
		
		var label := Label.new()
		label.name = "Name"
		label.text = "%s  (%d points)" % [package_name, int(spec.get("cost", 0))]
		label.custom_minimum_size = Vector2(420, 0)
		row.add_child(label)
		
		var summary := Label.new()
		summary.name = "Summary"
		summary.add_theme_color_override("font_color", Color(0.62, 0.62, 0.70))
		summary.text = _package_summary(spec)
		row.add_child(summary)
		
		var button := Button.new()
		button.name = "Buy"
		button.text = "Buy"
		button.custom_minimum_size = Vector2(90, 0)
		button.pressed.connect(_on_buy_package.bind(package_name, spec))
		row.add_child(button)
		
		_package_list.add_child(row)


func _package_summary(spec: Dictionary) -> String:
	if str(spec.get("kind", "")) == "fixed":
		var parts: Array[String] = []
		for skill in spec.get("skills", {}):
			parts.append("%s %d" % [str(skill), int(spec["skills"][skill])])
		return ", ".join(parts)
	var slot_parts: Array[String] = []
	for level in spec.get("skills_at_level", {}):
		var l: int = int(level)
		if l > 0 and int(spec["skills_at_level"][level]) > 0:
			slot_parts.append("%d at level %d" % [int(spec["skills_at_level"][level]), l])
	return "%s - required: %s" % [", ".join(slot_parts), ", ".join(spec.get("required_skills", []))]


func _on_buy_package(package_name: String, spec: Dictionary) -> void:
	# A fixed package grants its exact skill map. A flexible package is
	# applied with the skills it already grants (the prototype grants the
	# package's required skills at their slot levels and leaves electives
	# to the individual-skill list below).
	var applied: Dictionary = draft.purchased_skills.duplicate(true)
	if str(spec.get("kind", "")) == "fixed":
		applied = SkillRules.apply_fixed_package(spec, applied)
	else:
		var choices: Dictionary = {}
		for skill in spec.get("required_skills", []):
			choices[skill] = 2
		applied = SkillRules.apply_flexible_package(spec, choices, applied)
	draft.purchased_skills = applied
	draft.selected_package = package_name
	_refresh()
	wizard.refresh()


func _refresh_skills(_remaining: int) -> void:
	var learn: int = int(draft.final_attributes.get("LEARN", 0))
	var max_level: int = SkillRules.max_skill_level(learn)
	var all_skills: Array = _skill_names()
	
	for skill in all_skills:
		var row := HBoxContainer.new()
		row.name = "Skill_%s" % skill
		row.add_theme_constant_override("separation", 8)
		
		var label := Label.new()
		label.name = "Name"
		label.text = skill
		label.custom_minimum_size = Vector2(300, 0)
		row.add_child(label)
		
		var owned: int = int(draft.purchased_skills.get(skill, 0))
		var option := LevelOption.new()
		option.name = "Level"
		option.custom_minimum_size = Vector2(140, 0)
		option.add_item("0", 0)
		for level in range(1, max_level + 1):
			option.add_item(str(level), level)
		option.select(owned)
		option.item_selected.connect(_on_skill_level.bind(skill))
		row.add_child(option)
		
		var cost := Label.new()
		cost.name = "Cost"
		cost.custom_minimum_size = Vector2(120, 0)
		cost.add_theme_color_override("font_color", Color(0.62, 0.62, 0.70))
		cost.text = "%d point%s" % [owned, "" if owned == 1 else "s"]
		row.add_child(cost)
		
		_skill_list.add_child(row)


func _skill_names() -> Array:
	# The master skill list, in a stable order.
	var names: Array = []
	var path: String = "res://data/skills.json"
	if not FileAccess.file_exists(path):
		return names
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		return names
	for skill in parsed:
		names.append(str(skill))
	names.sort()
	return names


func _on_skill_level(index: int, skill: String) -> void:
	# OptionButton index maps to the level value stored as the item id.
	var level: int = index
	var previous: int = int(draft.purchased_skills.get(skill, 0))
	if level == previous:
		return
	# The pool must not be overspent. Refuse the change and put the
	# control back where it was, rather than letting the player wedge
	# themselves with an un-affordable character.
	var cost: int = level - previous
	if cost > 0 and cost > draft.remaining_skill_points():
		return
	draft.purchased_skills[skill] = level
	draft.recompute_attributes()
	_refresh()
	wizard.refresh()


func is_complete() -> bool:
	# Skills are optional, but the pool must not be overspent.
	return draft.remaining_skill_points() >= 0
