extends VBoxContainer

## Step 2 - Advantages.
##
## Spend Advantage Points on advantages, honouring variable cost tiers,
## one tier per family, and the race restrictions. R-S1-4.

const Rules := preload("res://rules/mw_rules.gd")

var draft: RefCounted
var wizard: Control

var _points_label: Label
var _list: VBoxContainer
var _family_label: Label


func build(_body: Control) -> void:
	var panel := VBoxContainer.new()
	panel.name = "AdvantagesPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 6)
	add_child(panel)
	
	_points_label = Label.new()
	_points_label.name = "PointsLabel"
	_points_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_points_label)
	
	_family_label = Label.new()
	_family_label.name = "FamilyLabel"
	_family_label.add_theme_font_size_override("font_size", 12)
	_family_label.add_theme_color_override("font_color", Color(0.62, 0.62, 0.70))
	_family_label.text = "Variable-cost advantages: Contact, DropShip, Extra Edge and Well-Connected each have 1 / 2 / 3 point tiers."
	panel.add_child(_family_label)
	
	var scroll := ScrollContainer.new()
	scroll.name = "AdvantagesScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	
	_list = VBoxContainer.new()
	_list.name = "AdvantagesList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	
	_refresh()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	
	var remaining: int = draft.remaining_advantage_points()
	_points_label.text = "Advantage Points remaining: %d  (of %d)" % [remaining, draft.advantage_points]
	
	# Anything already bought is shown, greyed, with what it cost.
	for advantage in draft.purchased_advantages:
		_list.add_child(_make_purchased_row(advantage, int(draft.purchased_advantages[advantage])))
	
	# And what is still on offer.
	var available: Dictionary = Rules.available_advantages(
		draft.race, remaining, draft.vehicle_priority, draft.purchased_advantages)
	if available.is_empty():
		var none := Label.new()
		none.name = "NoOptions"
		none.text = "No further advantages available."
		none.add_theme_color_override("font_color", Color(0.62, 0.62, 0.70))
		_list.add_child(none)
		return
	
	for advantage in available:
		_list.add_child(_make_available_row(advantage, int(available[advantage]), remaining))


func _make_purchased_row(advantage: String, cost: int) -> Control:
	var row := HBoxContainer.new()
	row.name = "Bought_%s" % advantage
	row.add_theme_constant_override("separation", 8)
	
	var label := Label.new()
	label.name = "Name"
	label.text = "%s  (%d point%s)" % [advantage, cost, "" if cost == 1 else "s"]
	label.custom_minimum_size = Vector2(340, 0)
	label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
	row.add_child(label)
	
	return row


func _make_available_row(advantage: String, cheapest: int, remaining: int) -> Control:
	var row := HBoxContainer.new()
	row.name = "Offer_%s" % advantage
	row.add_theme_constant_override("separation", 8)
	
	var label := Label.new()
	label.name = "Name"
	label.text = advantage
	label.custom_minimum_size = Vector2(340, 0)
	row.add_child(label)
	
	var tiers: Array[int] = Rules.advantage_cost_tiers(advantage)
	if tiers.size() > 1:
		# Variable cost: offer each tier up to what the player can afford.
		for tier in tiers:
			if tier > remaining:
				continue
			row.add_child(_make_buy_button(advantage, tier))
	else:
		row.add_child(_make_buy_button(advantage, cheapest))
	
	return row


func _make_buy_button(advantage: String, cost: int) -> Button:
	var button := Button.new()
	button.name = "Buy_%s_%d" % [advantage, cost]
	button.text = "Buy (%d)" % cost
	button.custom_minimum_size = Vector2(100, 0)
	button.pressed.connect(_on_buy.bind(advantage, cost))
	return button


func _on_buy(advantage: String, cost: int) -> void:
	draft.purchased_advantages[advantage] = cost
	# The Exceptional Attribute needs a follow-up: which attribute?
	if advantage == "Exceptional Attribute":
		draft.exceptional_attribute = "BUILD"
		draft.recompute_attributes()
	_refresh()
	wizard.refresh()


func is_complete() -> bool:
	# A character is valid with 0 advantages spent, but the player must at
	# least have been offered the choice. Completing means "done looking".
	return true
