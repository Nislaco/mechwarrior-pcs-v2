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

# Flexible package selection sub-panel.
var _pkg_select_panel: PanelContainer
var _pkg_select_title: Label
var _pkg_select_body: VBoxContainer
var _pkg_select_scroll: ScrollContainer
var _slot_summary: Label
var _confirm_btn: Button
var _cancel_btn: Button
var _pkg_select_dropdowns: Dictionary = {}   # skill name -> OptionButton
var _pending_pkg_name: String = ""
var _pending_pkg_spec: Dictionary = {}


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
	
	# Flexible package selection sub-panel (hidden until a flexible package is picked).
	_build_package_select_panel(panel)
	
	# Individual skills.
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


func _build_package_select_panel(parent: Control) -> void:
	_pkg_select_panel = PanelContainer.new()
	_pkg_select_panel.name = "PackageSelectPanel"
	_pkg_select_panel.visible = false
	_pkg_select_panel.add_theme_color_override("panel", Color(0.12, 0.14, 0.18, 1.0))
	_pkg_select_panel.add_theme_color_override("border_color", Color(0.3, 0.45, 0.3, 1.0))
	
	var outer := VBoxContainer.new()
	outer.name = "VBox"
	outer.add_theme_constant_override("separation", 6)
	_pkg_select_panel.add_child(outer)
	
	_pkg_select_title = Label.new()
	_pkg_select_title.add_theme_font_size_override("font_size", 14)
	_pkg_select_title.add_theme_color_override("font_color", Color(0.65, 0.85, 0.65))
	outer.add_child(_pkg_select_title)
	
	_pkg_select_scroll = ScrollContainer.new()
	_pkg_select_scroll.name = "Scroll"
	_pkg_select_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pkg_select_scroll.custom_minimum_size = Vector2(0, 200)
	_pkg_select_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_pkg_select_scroll)
	
	_pkg_select_body = VBoxContainer.new()
	_pkg_select_body.name = "Body"
	_pkg_select_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pkg_select_body.add_theme_constant_override("separation", 4)
	_pkg_select_scroll.add_child(_pkg_select_body)
	
	_slot_summary = Label.new()
	_slot_summary.add_theme_font_size_override("font_size", 12)
	_slot_summary.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	_slot_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_slot_summary)
	
	var btn_row := HBoxContainer.new()
	btn_row.name = "ButtonRow"
	btn_row.add_theme_constant_override("separation", 8)
	outer.add_child(btn_row)
	
	_confirm_btn = Button.new()
	_confirm_btn.name = "ConfirmPurchase"
	_confirm_btn.text = "Confirm purchase"
	_confirm_btn.custom_minimum_size = Vector2(160, 36)
	_confirm_btn.pressed.connect(_on_package_select_confirm)
	btn_row.add_child(_confirm_btn)
	
	_cancel_btn = Button.new()
	_cancel_btn.name = "Cancel"
	_cancel_btn.text = "Cancel"
	_cancel_btn.custom_minimum_size = Vector2(100, 36)
	_cancel_btn.pressed.connect(_on_package_select_cancel)
	btn_row.add_child(_cancel_btn)
	
	parent.add_child(_pkg_select_panel)


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
		return
	
	var learn: int = int(draft.final_attributes.get("LEARN", 0))
	var eligible: Dictionary = SkillRules.eligible_packages(draft.race, remaining, learn)
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
		label.text = "%s  (%d pts)" % [package_name, int(spec.get("cost", 0))]
		label.custom_minimum_size = Vector2(220, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		
		var summary := Label.new()
		summary.name = "Summary"
		summary.add_theme_color_override("font_color", Color(0.62, 0.62, 0.70))
		summary.text = _package_summary(spec)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.custom_minimum_size = Vector2(0, 36)
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary.clip_text = true
		row.add_child(summary)
		
		var button := Button.new()
		button.name = "Buy"
		button.text = "Select"
		button.custom_minimum_size = Vector2(80, 36)
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.pressed.connect(_on_select_package.bind(package_name, spec))
		row.add_child(button)
		
		_package_list.add_child(row)


func _package_summary(spec: Dictionary) -> String:
	if "skills" in spec:
		var parts: Array[String] = []
		for skill in spec["skills"]:
			parts.append("%s %d" % [str(skill), int(spec["skills"][skill])])
		return ", ".join(parts)
	# Flexible package: show slot summary.
	var slot_parts: Array[String] = []
	for level in spec.get("skills_at_level", {}):
		var l: int = int(level)
		if l > 0 and int(spec["skills_at_level"][level]) > 0:
			slot_parts.append("%d at level %d" % [int(spec["skills_at_level"][level]), l])
	var req: Array = spec.get("required_skills", [])
	return "%s  (required: %s)" % [", ".join(slot_parts), ", ".join(req.map(func(s): return str(s)))]


func _on_select_package(package_name: String, spec: Dictionary) -> void:
	# Fixed package: apply immediately (no selection needed).
	if "skills" in spec:
		var applied: Dictionary = draft.purchased_skills.duplicate(true)
		applied = SkillRules.apply_fixed_package(spec, applied)
		var pkg_base: Dictionary = {}
		for skill in spec["skills"]:
			pkg_base[skill] = int(spec["skills"][skill])
		draft.purchased_skills = applied
		draft.selected_package = package_name
		draft.package_base_skills = pkg_base
		draft.package_flat_cost = int(spec.get("cost", 0))
		_pkg_select_panel.visible = false
		_refresh()
		wizard.refresh()
		return
	
	# Flexible package: open the selection sub-panel.
	_pending_pkg_name = package_name
	_pending_pkg_spec = spec
	_populate_package_select_panel(spec)
	_pkg_select_panel.visible = true


func _populate_package_select_panel(spec: Dictionary) -> void:
	# Clear the body.
	for child in _pkg_select_body.get_children():
		child.queue_free()
	_pkg_select_dropdowns.clear()
	
	var pkg_name: String = str(_pending_pkg_name)
	var slots: Dictionary = SkillRules.package_slots(spec)
	var required: Array = spec.get("required_skills", [])
	var all_electives: Array = spec.get("elective_skills", [])
	# Electives minus required (same as Python reference).
	var electives: Array = []
	for s in all_electives:
		if not required.has(s):
			electives.append(s)
	
	# Build list of available levels (count > 0) from high to low.
	var available_levels: Array = []
	for level in slots:
		var l: int = int(level)
		if l > 0 and int(slots[level]) > 0:
			available_levels.append(l)
	available_levels.sort_custom(func(a, b): return a > b)
	
	_pkg_select_title.text = "Configure package: %s" % pkg_name
	
	# Slot summary line (initial).
	_update_slot_summary(slots, {})
	
	# --- Required skills section ---
	var req_header := Label.new()
	req_header.text = "Required skills (each takes one slot)"
	req_header.add_theme_font_size_override("font_size", 13)
	req_header.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5))
	_pkg_select_body.add_child(req_header)
	
	for skill in required:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		
		var lbl := Label.new()
		lbl.text = str(skill)
		lbl.custom_minimum_size = Vector2(220, 0)
		row.add_child(lbl)
		
		var opt := OptionButton.new()
		opt.custom_minimum_size = Vector2(120, 0)
		# Options: each available level.
		for l in available_levels:
			opt.add_item("Level %d" % l, l)
		# Default: first available level.
		if available_levels.size() > 0:
			opt.select(0)
		opt.item_selected.connect(_on_pkg_skill_level.bind(str(skill), slots))
		row.add_child(opt)
		opt.set_meta("skill", str(skill))
		_pkg_select_dropdowns[str(skill)] = opt
		
		_pkg_select_body.add_child(row)
	
	# --- Elective skills section ---
	var el_header := Label.new()
	el_header.text = "Elective skills (select level, or 0 to skip)"
	el_header.add_theme_font_size_override("font_size", 13)
	el_header.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
	_pkg_select_body.add_child(el_header)
	
	for skill in electives:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		
		var lbl := Label.new()
		lbl.text = str(skill)
		lbl.custom_minimum_size = Vector2(220, 0)
		row.add_child(lbl)
		
		var opt := OptionButton.new()
		opt.custom_minimum_size = Vector2(120, 0)
		# Options: 0 (skip) first, then each available level.
		opt.add_item("Skip", 0)
		for l in available_levels:
			opt.add_item("Level %d" % l, l)
		opt.select(0)  # default: skip
		opt.item_selected.connect(_on_pkg_skill_level.bind(str(skill), slots))
		row.add_child(opt)
		opt.set_meta("skill", str(skill))
		_pkg_select_dropdowns[str(skill)] = opt
		
		_pkg_select_body.add_child(row)


func _on_pkg_skill_level(_index: int, skill: String, slots: Dictionary) -> void:
	# Re-read the current selection from all dropdowns and update the slot summary.
	var choices: Dictionary = {}
	for key in _pkg_select_dropdowns:
		var opt: OptionButton = _pkg_select_dropdowns[key]
		choices[key] = int(opt.get_item_id(opt.selected))
	_update_slot_summary(slots, choices)
	_update_confirm_state(slots, choices)


func _update_slot_summary(slots: Dictionary, choices: Dictionary) -> void:
	var used: Dictionary = {}
	for key in choices:
		var lvl: int = int(choices[key])
		if lvl <= 0:
			continue
		if not used.has(lvl):
			used[lvl] = 0
		used[lvl] = int(used[lvl]) + 1
	
	var parts: Array[String] = []
	for level in slots:
		var l: int = int(level)
		var total: int = int(slots[level])
		if total <= 0:
			continue
		var u: int = int(used.get(l, 0))
		var rem: int = total - u
		parts.append("%d/%d left at level %d" % [u, total, l])
	_slot_summary.text = "Slots used:  " + "  |  ".join(parts)


func _update_confirm_state(slots: Dictionary, choices: Dictionary) -> void:
	var used: Dictionary = {}
	for key in choices:
		var lvl: int = int(choices[key])
		if lvl <= 0:
			continue
		if not used.has(lvl):
			used[lvl] = 0
		used[lvl] = int(used[lvl]) + 1
	var ok := true
	for level in slots:
		var l: int = int(level)
		var total: int = int(slots[level])
		if total <= 0:
			continue
		if int(used.get(l, 0)) > total:
			ok = false
			break
	_confirm_btn.disabled = not ok


func _on_package_select_confirm() -> void:
	var spec: Dictionary = _pending_pkg_spec
	var slots: Dictionary = SkillRules.package_slots(spec)
	var choices: Dictionary = {}
	for key in _pkg_select_dropdowns:
		var opt: OptionButton = _pkg_select_dropdowns[key]
		choices[key] = int(opt.get_item_id(opt.selected))
	
	var applied: Dictionary = draft.purchased_skills.duplicate(true)
	applied = SkillRules.apply_flexible_package(spec, choices, applied)
	
	# Record package base skills.
	var pkg_base: Dictionary = {}
	for key in choices:
		var lvl: int = int(choices[key])
		if lvl > 0:
			pkg_base[key] = lvl
	
	draft.purchased_skills = applied
	draft.selected_package = str(_pending_pkg_name)
	draft.package_base_skills = pkg_base
	draft.package_flat_cost = int(spec.get("cost", 0))
	
	_pkg_select_panel.visible = false
	_pending_pkg_name = ""
	_pending_pkg_spec = {}
	_refresh()
	wizard.refresh()


func _on_package_select_cancel() -> void:
	_pkg_select_panel.visible = false
	_pending_pkg_name = ""
	_pending_pkg_spec = {}


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
		# Clamp: a package may grant a level above LEARN; the dropdown only
		# has options 0..max_level, so select(mini(owned, max_level)) avoids
		# the out-of-bounds 'Invalid index' crash in OptionButton.select().
		option.select(mini(owned, max_level))
		option.item_selected.connect(_on_skill_level.bind(skill))
		row.add_child(option)
		
		var cost = Label.new()
		cost.name = "Cost"
		cost.custom_minimum_size = Vector2(120, 0)
		cost.add_theme_color_override("font_color", Color(0.62, 0.62, 0.70))
		cost.text = "%d point%s" % [owned * (owned + 1) / 2, "" if owned == 1 else "s"]
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
	# R-S1-8.  The cost to reach level L is triangular: L*(L+1)/2 points.
	# Raising from `previous` to `level` costs triangular(level) - triangular(previous).
	# Lowering is always free.
	var marginal: int = level * (level + 1) / 2 - previous * (previous + 1) / 2
	if marginal > 0 and marginal > draft.remaining_skill_points():
		return
	draft.purchased_skills[skill] = level
	draft.recompute_attributes()
	_refresh()
	wizard.refresh()

func is_complete() -> bool:
	# Skills are optional, but the pool must not be overspend.
	return draft.remaining_skill_points() >= 0
