extends VBoxContainer

## Step 5 - Equipment.
##
## Buy an archetype loadout, or pick individual items. Purchases deduct
## from the character's credits. R-S1-9.

const SkillRules := preload("res://rules/mw_rules_skills.gd")

var draft: RefCounted
var wizard: Control

var _credits_label: Label
var _list: VBoxContainer


func build(_body: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "EquipmentScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	
	var panel := VBoxContainer.new()
	panel.name = "EquipmentPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	scroll.add_child(panel)
	
	_credits_label = Label.new()
	_credits_label.name = "CreditsLabel"
	_credits_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_credits_label)
	
	_list = VBoxContainer.new()
	_list.name = "EquipmentList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	panel.add_child(_list)
	
	_refresh()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	
	var remaining: int = draft.remaining_credits()
	_credits_label.text = "Credits remaining: %d of %d  -  you do not have to spend them all" % [remaining, draft.credits]
	
	# What is already bought.
	for item in draft.equipment:
		_list.add_child(_make_bought_row(item))
	
	# Archetype offers.
	var title := Label.new()
	title.name = "ArchetypeTitle"
	title.text = "Archetype packages"
	title.add_theme_font_size_override("font_size", 15)
	_list.add_child(title)
	
	for variant in ["Standard", "Light"]:
		var kit: Array = SkillRules.archetype_equipment(draft.race, variant)
		if kit.is_empty():
			continue
		var row := HBoxContainer.new()
		row.name = "Archetype_%s" % variant
		row.add_theme_constant_override("separation", 8)
		
		var label := Label.new()
		label.name = "Name"
		label.text = "%s  (%d credits, %d items)" % [variant, SkillRules.equipment_total_cost(kit), kit.size()]
		label.custom_minimum_size = Vector2(340, 0)
		row.add_child(label)
		
		var button := Button.new()
		button.name = "Buy"
		button.text = "Buy"
		button.custom_minimum_size = Vector2(90, 0)
		button.disabled = not SkillRules.equipment_affordable(kit, remaining)
		button.pressed.connect(_on_buy_archetype.bind(variant))
		row.add_child(button)
		
		_list.add_child(row)
	
	# Individual items from the equipment tables.
	var items_title := Label.new()
	items_title.name = "ItemsTitle"
	items_title.text = "Individual items"
	items_title.add_theme_font_size_override("font_size", 15)
	_list.add_child(items_title)
	
	for entry in _catalog():
		var item_row := HBoxContainer.new()
		item_row.name = "Item_%s" % str(entry.get("name", "item"))
		item_row.add_theme_constant_override("separation", 8)
		
		var item_label := Label.new()
		item_label.name = "Name"
		item_label.text = "%s  (%d credits)" % [str(entry.get("name", "?")), int(entry.get("cost", 0))]
		item_label.custom_minimum_size = Vector2(340, 0)
		item_row.add_child(item_label)
		
		var buy := Button.new()
		buy.name = "Buy"
		buy.text = "Buy"
		buy.custom_minimum_size = Vector2(90, 0)
		buy.disabled = not SkillRules.equipment_affordable([entry], remaining)
		buy.pressed.connect(_on_buy_item.bind(entry))
		item_row.add_child(buy)
		
		_list.add_child(item_row)


func _make_bought_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "Bought_%s" % str(item.get("name", "item"))
	row.add_theme_constant_override("separation", 8)
	
	var label := Label.new()
	label.name = "Name"
	label.text = "%s  (%d credits)" % [str(item.get("name", "?")), int(item.get("cost", 0))]
	label.custom_minimum_size = Vector2(340, 0)
	label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
	row.add_child(label)
	
	var remove := Button.new()
	remove.name = "Remove"
	remove.text = "Remove"
	remove.custom_minimum_size = Vector2(100, 0)
	remove.pressed.connect(_on_remove.bind(str(item.get("name", ""))))
	row.add_child(remove)
	
	return row


func _catalog() -> Array:
	# Flatten the equipment tables into a single list of purchasable items.
	var items: Array = []
	for file in ["weapons.json", "armor.json", "electronics.json", "medical.json", "gear.json"]:
		var path: String = "res://data/%s" % file
		if not FileAccess.file_exists(path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed == null:
			continue
		items.append_array(_flatten(parsed))
	return items


func _flatten(node, out: Array = []) -> Array:
	if node is Dictionary:
		for key in node:
			var value = node[key]
			if value is Dictionary and value.has("name"):
				out.append(value)
			else:
				_flatten(value, out)
	elif node is Array:
		for entry in node:
			if entry is Dictionary and entry.has("name"):
				out.append(entry)
			else:
				_flatten(entry, out)
	return out


func _on_buy_archetype(variant: String) -> void:
	var kit: Array = SkillRules.archetype_equipment(draft.race, variant)
	if not SkillRules.equipment_affordable(kit, draft.remaining_credits()):
		return
	draft.equipment.append_array(kit)
	_refresh()
	wizard.refresh()


func _on_buy_item(entry: Dictionary) -> void:
	if not SkillRules.equipment_affordable([entry], draft.remaining_credits()):
		return
	draft.equipment.append(entry.duplicate(true))
	_refresh()
	wizard.refresh()


func _on_remove(item_name: String) -> void:
	for i in range(draft.equipment.size() - 1, -1, -1):
		if str(draft.equipment[i].get("name", "")) == item_name:
			draft.equipment.remove_at(i)
	_refresh()
	wizard.refresh()


func is_complete() -> bool:
	# Equipment is optional, but the character must not be over budget.
	return draft.remaining_credits() >= 0
