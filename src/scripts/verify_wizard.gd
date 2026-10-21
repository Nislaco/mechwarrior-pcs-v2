extends SceneTree

## Verification harness for the character-creation wizard (UI layer).
##
## The rules are covered by verify_rules.gd; this covers the UI that
## drives them: the step flow, the validation gates, and the export.
##
## Run: godot --headless --path src -s res://scripts/verify_wizard.gd
## Exits non-zero on any failure.

const Wizard := preload("res://ui/wizard.gd")
const Rules := preload("res://rules/mw_rules.gd")

var checks: int = 0
var failures: int = 0
var wizard: Control


func _initialize() -> void:
	print("--- MechWarrior PCS Wizard Verification Start ---")
	wizard = Wizard.new()
	wizard.name = "Wizard"
	# Give the wizard a real size, the way the boot scene does. Without
	# this the wizard is 0x0, the root falls back to its minimum size and
	# the body gets zero height -- so every layout check below would be
	# measuring a wizard that was never laid out at all.
	wizard.set_anchors_preset(Control.PRESET_TOP_LEFT)
	wizard.size = Vector2(1280, 800)
	# Add to the root window so the wizard's _ready() runs and the shell
	# is built before the checks run.
	get_root().add_child(wizard)
	# _ready() is deferred until the node enters the tree and the first
	# frame is processed, so wait for it before asserting.
	await process_frame
	_run_checks()


func _run_checks() -> void:
	_test_shell()
	await _test_layout()
	await _test_priorities_gate()
	_test_advantage_purchase()
	await _test_attribute_allocation()
	_test_skill_package()
	_test_equipment()
	_test_export()
	_test_credits()
	# Before the finished-state test, which starts a fresh character.
	_test_export_against_rulebook()
	await _test_finished_state()
	
	print("--- MechWarrior PCS Wizard Verification End: %d checks, %d failures ---" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(id: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if condition:
		print("PASS ", id)
	else:
		failures += 1
		print("FAIL ", id, (" - " + detail) if detail != "" else "")


# --- Shell -----------------------------------------------------------------

func _test_shell() -> void:
	# The shell has a header, a body, a message line and a footer.
	_check("UI-AT-1 wizard has a body", wizard.body != null and wizard.body.get_child_count() == 1)
	_check("UI-AT-1 wizard shows step 1 of 6", wizard.title_label.text == "Priorities", wizard.title_label.text)
	_check("UI-AT-1 Back is disabled on the first step", wizard.back_button.disabled)
	_check("UI-AT-1 Next is disabled until the step is complete", wizard.next_button.disabled)
	_check("UI-AT-1 six steps are registered", Wizard.STEPS.size() == 6)


# --- Layout ---------------------------------------------------------------

func _test_layout() -> void:
	# The body must have real height, and so must the step inside it.
	#
	# A step is a plain Control it has a zero minimum size and does not
	# lay out its own children, so the body gave it zero height and the
	# whole step fell out of the visible and clickable area. The controls
	# were still in the tree; they were simply not on screen.
	for index in range(Wizard.STEPS.size()):
		wizard._show_step(index)
		# Container layout is deferred to the end of the frame, so the step
		# has no size until the next frame is processed.
		await process_frame
		await process_frame
		var step: Control = wizard.body.get_child(0)
		_check("UI-AT-8 step %d has a non-zero height" % index, step.size.y > 0.0,
			"height %f" % step.size.y)
		_check("UI-AT-8 step %d has a non-zero width" % index, step.size.x > 0.0,
			"width %f" % step.size.x)
		
		# Every interactive control in the step must be on screen: it must
		# have a real size, and no ancestor may be collapsed to zero.
		var controls: Array[Control] = []
		_collect_interactive(step, controls)
		var broken: Array[String] = []
		for control in controls:
			if _is_broken(control):
				broken.append("%s@%s" % [control.name, str(control.get_global_rect())])
		_check("UI-AT-8 every control in step %d is on screen" % index, broken.is_empty(),
			"%d broken: %s" % [broken.size(), ", ".join(broken.slice(0, 4))])
		
		# The keyboard needs somewhere to go.
		var focus: Control = get_root().gui_get_focus_owner()
		_check("UI-AT-8 step %d gives the keyboard a focus owner" % index, focus != null,
			"focus owner is null")
	
	wizard._show_step(0)


func _collect_controls(node: Node, out: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control:
			out.append(child)
		_collect_controls(child, out)


## The controls a player can actually operate: the things that must be
## on screen and clickable.
func _collect_interactive(node: Node, out: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control:
			var control: Control = child
			if control is Button or control is OptionButton or control is SpinBox \
					or control is CheckBox or control is LineEdit:
				out.append(control)
		_collect_interactive(child, out)


## Is this control unusable because it has no size, or because one of its
## ancestors is collapsed to zero and clips it away?
func _is_broken(control: Control) -> bool:
	var rect: Rect2 = control.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return true
	# Walk the ancestors: if any of them has a zero-sized rect, the control
	# is clipped out of existence even though it is "visible".
	var node: Node = control.get_parent()
	while node is Control:
		var ancestor: Control = node
		if ancestor.size.x <= 0.0 or ancestor.size.y <= 0.0:
			return true
		node = ancestor.get_parent()
	return false


# --- Step 1: priorities ---------------------------------------------------

func _test_priorities_gate() -> void:
	# Next stays disabled until a valid assignment exists.
	wizard._show_step(0)
	_check("UI-AT-2 Next is disabled with no priorities", wizard.next_button.disabled)
	
	# Every category must be recorded, including one the player never
	# touches. A dropdown only reports a *change*, so a category left at
	# its default of 0 would otherwise never be recorded -- and the
	# assignment needs all five.
	wizard._show_step(0)
	await process_frame
	_check("UI-AT-2 every priority category is recorded",
		wizard.draft.priorities.size() == 5, str(wizard.draft.priorities.keys()))
	_check("UI-AT-2 an untouched category is recorded at 0",
		int(wizard.draft.priorities.get("Vehicle Class", -1)) == 0,
		str(wizard.draft.priorities))
	
	# A duplicate level is not accepted.
	_set_priorities({"Race": 2, "Attributes": 2, "Skills": 1, "Advantages": 0, "Vehicle Class": 3})
	wizard._update_footer()
	_check("UI-AT-2 a duplicate priority keeps Next disabled", wizard.next_button.disabled)
	
	# A valid permutation enables it.
	_set_priorities({"Race": 2, "Attributes": 4, "Skills": 3, "Advantages": 1, "Vehicle Class": 0})
	wizard._update_footer()
	_check("UI-AT-2 a valid priority assignment enables Next", not wizard.next_button.disabled)
	
	# The priorities resolve into the values they grant.
	var d = wizard.draft
	_check("UI-AT-2 priorities resolve to race and points",
		d.race == "Clan Warrior" and d.attribute_points == 30
		and d.skill_points == 20 and d.advantage_points == 1
		and d.vehicle_class == "None",
		"%s / %d / %d / %d / %s" % [d.race, d.attribute_points, d.skill_points, d.advantage_points, d.vehicle_class])
	
	# A focused dropdown must answer the arrow keys directly, so a player
	# can change a value without opening the popup.
	wizard._show_step(0)
	await process_frame
	var step: Control = wizard.body.get_child(0)
	var panel: VBoxContainer = step.get_child(0).get_child(0)
	var race_option: OptionButton = panel.get_node("Row_Race").get_child(1)
	race_option.grab_focus()
	race_option.select(0)
	await process_frame
	_send_arrow(race_option, "ui_down")
	_check("UI-AT-2 the arrow keys change a focused dropdown",
		race_option.selected == 1, str(race_option.selected))
	_check("UI-AT-2 the arrow key change reaches the draft",
		int(wizard.draft.priorities.get("Race", -1)) == 1,
		str(wizard.draft.priorities))
	_send_arrow(race_option, "ui_down")
	_send_arrow(race_option, "ui_down")
	_check("UI-AT-2 the arrow keys stop at the top of the range",
		race_option.selected == 3, str(race_option.selected))
	_send_arrow(race_option, "ui_up")
	_check("UI-AT-2 the arrow keys go back down", race_option.selected == 2,
		str(race_option.selected))
	
	# Set priorities again for the tests that follow.
	_set_priorities({"Race": 2, "Attributes": 4, "Skills": 3, "Advantages": 1, "Vehicle Class": 0})


## Deliver an action to a control the way the GUI would.
func _send_arrow(control: Control, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	control._gui_input(event)


func _set_priorities(priorities: Dictionary) -> void:
	wizard.draft.priorities = priorities.duplicate()
	wizard.draft.apply_priorities()


# --- Step 2: advantages ----------------------------------------------------

func _test_advantage_purchase() -> void:
	wizard._show_step(1)
	var before: int = wizard.draft.remaining_advantage_points()
	
	# Buy the cheapest thing on offer.
	var step: Control = wizard.body.get_child(0)
	var list: VBoxContainer = step.get_child(0).get_node("AdvantagesScroll/AdvantagesList")
	var bought: String = ""
	for i in range(list.get_child_count()):
		var row: Control = list.get_child(i)
		if not row.name.begins_with("Offer_"):
			continue
		for j in range(row.get_child_count()):
			var b: Control = row.get_child(j)
			if b is Button and str(b.text).begins_with("Buy"):
				b.pressed.emit()
				bought = row.name
				break
		break
	_check("UI-AT-3 an advantage can be bought from the UI", not bought.is_empty(), bought)
	_check("UI-AT-3 buying an advantage spends its points",
		wizard.draft.remaining_advantage_points() < before,
		"%d -> %d" % [before, wizard.draft.remaining_advantage_points()])


# --- Step 3: attributes ---------------------------------------------------

func _test_attribute_allocation() -> void:
	wizard._show_step(2)
	await process_frame
	var step: Control = wizard.body.get_child(0)
	var panel: VBoxContainer = step.get_child(0).get_child(0)
	
	# The spin box holds the TOTAL number of points in the attribute, so
	# its maximum must be the racial cap -- not the remaining headroom.
	#
	# With the headroom as the cap, a character whose racial maximum is 6
	# could never go past 3 once 3 points were in, and the rest of the
	# attribute was unreachable.
	var build_row: HBoxContainer = panel.get_node("Row_BUILD")
	var build_spin: SpinBox = build_row.get_child(1)
	_check("UI-AT-4 an empty attribute offers the full racial maximum",
		int(build_spin.max_value) == 6, str(build_spin.max_value))
	build_spin.set_value_no_signal(3)
	build_spin.value_changed.emit(3)
	await process_frame
	_check("UI-AT-4 a partly-filled attribute still offers the full racial maximum",
		int(build_spin.max_value) == 6, str(build_spin.max_value))
	_check("UI-AT-4 the partly-filled attribute keeps its value",
		int(build_spin.value) == 3, str(build_spin.value))
	
	# Allocate every point through the real SpinBoxes.
	# Clan Warrior: 30 points, INTUITION costs two points per point of value.
	var want: Dictionary = {"BUILD": 6, "REFLEX": 6, "LEARN": 6, "CHARISMA": 4, "INTUITION": 8}
	for attribute in want:
		var row: HBoxContainer = panel.get_node("Row_%s" % attribute)
		var spin: SpinBox = row.get_child(1)
		spin.set_value_no_signal(int(want[attribute]))
		spin.value_changed.emit(int(want[attribute]))
	
	_check("UI-AT-4 all attribute points are spent",
		wizard.draft.remaining_attribute_points() == 0,
		"remaining %d" % wizard.draft.remaining_attribute_points())
	
	# The final values include the racial modifiers.
	var attrs: Dictionary = wizard.draft.final_attributes
	_check("UI-AT-4 the racial modifiers are applied",
		int(attrs["REFLEX"]) == 7 and int(attrs["INTUITION"]) == 5,
		str(attrs))
	
	# The SpinBox maximum must never sit below the points already allocated
	# (Godot would clamp the value and destroy the allocation).
	_check("UI-AT-4 the attribute spin box keeps the allocated value",
		int(build_spin.value) == 6, str(build_spin.value))
	
	# The final values must not exceed the racial maximums. R-S1-5.
	var maximums: Dictionary = Rules.race_maximums(wizard.draft.race)
	var over: Array[String] = []
	for attribute in attrs:
		if int(attrs[attribute]) > int(maximums.get(attribute, 0)):
			over.append("%s %d > %d" % [attribute, int(attrs[attribute]), int(maximums.get(attribute, 0))])
	_check("UI-AT-4 no attribute exceeds its racial maximum", over.is_empty(),
		", ".join(over))
	
	# The keyboard must land somewhere the player can type. A SpinBox
	# cannot take focus itself, so the line edit inside it is focused.
	var focus: Control = get_root().gui_get_focus_owner()
	var focus_is_the_build_field: bool = focus != null and focus is LineEdit \
		and focus.get_parent() == build_spin
	_check("UI-AT-4 the keyboard lands in the first attribute field",
		focus_is_the_build_field, str(focus))
	
	# The derived values are shown.
	_check("UI-AT-4 saving throws and characteristics are derived",
		wizard.draft.saving_throws.size() == 5 and wizard.draft.characteristics.size() == 4)
	
	# Now the step is complete, so Next is enabled.
	wizard._update_footer()
	_check("UI-AT-4 Next is enabled once every point is spent", not wizard.next_button.disabled)


# --- Step 4: skills -------------------------------------------------------

func _test_skill_package() -> void:
	wizard._show_step(3)
	var step: Control = wizard.body.get_child(0)
	var panel: VBoxContainer = step.get_child(0).get_child(0)
	var list: VBoxContainer = panel.get_node("PackageList")
	
	var bought: String = ""
	for i in range(list.get_child_count()):
		var row: Control = list.get_child(i)
		if not row.name.begins_with("Package_"):
			continue
		row.get_node("Buy").pressed.emit()
		bought = str(row.name).trim_prefix("Package_")
		break
	_check("UI-AT-5 a skill package can be bought from the UI", not bought.is_empty(), bought)
	_check("UI-AT-5 the package grants skills",
		wizard.draft.purchased_skills.size() > 0,
		str(wizard.draft.purchased_skills.size()))
	_check("UI-AT-5 the package name is recorded", wizard.draft.selected_package == bought,
		"%s != %s" % [wizard.draft.selected_package, bought])
	
	# The skill list is present and capped at LEARN.
	var skill_list: VBoxContainer = panel.get_node("SkillList")
	_check("UI-AT-5 the individual skill list is populated", skill_list.get_child_count() > 40,
		str(skill_list.get_child_count()))


# --- Step 5: equipment ----------------------------------------------------

func _test_equipment() -> void:
	wizard._show_step(4)
	var step: Control = wizard.body.get_child(0)
	var panel: VBoxContainer = step.get_child(0).get_child(0)
	var list: VBoxContainer = panel.get_node("EquipmentList")
	
	var bought: bool = false
	for i in range(list.get_child_count()):
		var row: Control = list.get_child(i)
		if row.name == "Archetype_Standard":
			row.get_node("Buy").pressed.emit()
			bought = true
			break
	_check("UI-AT-6 an archetype loadout can be bought", bought)
	_check("UI-AT-6 the credits are deducted",
		wizard.draft.remaining_credits() < wizard.draft.credits,
		"%d -> %d" % [wizard.draft.credits, wizard.draft.remaining_credits()])
	
	# The individual item list is populated from the equipment tables.
	var item_rows: int = 0
	for i in range(list.get_child_count()):
		if str(list.get_child(i).name).begins_with("Item_"):
			item_rows += 1
	_check("UI-AT-6 the individual item list is populated", item_rows > 10, str(item_rows))
	
	# Removing an item refunds the credits.
	var before: int = wizard.draft.remaining_credits()
	for i in range(list.get_child_count()):
		var row: Control = list.get_child(i)
		if str(row.name).begins_with("Bought_"):
			row.get_node("Remove").pressed.emit()
			break
	_check("UI-AT-6 removing an item refunds the credits",
		wizard.draft.remaining_credits() > before,
		"%d -> %d" % [before, wizard.draft.remaining_credits()])


# --- Step 6: export -------------------------------------------------------

func _test_export() -> void:
	wizard._show_step(5)
	_check("UI-AT-7 the last step is the character sheet", wizard.title_label.text == "Character Sheet", wizard.title_label.text)
	
	# Finishing writes the file.
	wizard._on_next()
	_check("UI-AT-7 finishing writes the character file",
		FileAccess.file_exists("user://character.json"),
		wizard.message_label.text)
	
	# And the file is a valid export.
	var text: String = FileAccess.get_file_as_string("user://character.json")
	var parsed = JSON.parse_string(text)
	_check("UI-AT-7 the written file parses as JSON", parsed != null)
	if parsed != null:
		_check("UI-AT-7 the written file has the export shape",
			parsed.has("version") and parsed.has("exported") and parsed.has("character"))
		var character: Dictionary = parsed.get("character", {})
		_check("UI-AT-7 the exported character carries the built values",
			str(character.get("race", "")) == "Clan Warrior"
			and character.get("attributes", {}).size() == 5
			and character.get("skills", {}).size() > 0
			and character.get("equipment", []).size() > 0,
			str(character.keys()))
		# The exported credits are the character's credit POOL, matching the
		# reference schema -- not the balance left after the equipment.
		_check("UI-AT-7 the exported credits are the character's credit pool",
			int(character.get("credits", -1)) == wizard.draft.credits,
			"%s vs %d" % [str(character.get("credits")), wizard.draft.credits])


# --- The finished state ---------------------------------------------------

func _test_finished_state() -> void:
	# Saving must be obvious.
	#
	# The character is written and the wizard stays open, so a thin line
	# of text in the same colour as an error message is easy to miss --
	# and pressing "Finish" again would just re-save with no visible
	# change. The finished state says so.
	wizard._show_step(5)
	await process_frame
	var step: Control = wizard.body.get_child(0)
	var sheet_panel: Control = step.get_child(0).get_child(0)
	var saved_panel: Control = sheet_panel.get_node("SavedPanel")
	_check("UI-AT-12 the saved confirmation is hidden before saving",
		not saved_panel.visible)
	# It has to be ABOVE the sheet. The sheet is long, so a confirmation
	# underneath it would sit below the fold -- exactly where a player
	# who has just pressed Finish would not look.
	_check("UI-AT-12 the saved confirmation is above the sheet, not below the fold",
		sheet_panel.get_child(0) == saved_panel,
		str(sheet_panel.get_child(0).name))
	
	wizard._on_next()
	await process_frame
	_check("UI-AT-12 the saved confirmation appears after saving",
		saved_panel.visible)
	var saved_text: String = saved_panel.get_child(0).text
	_check("UI-AT-12 the confirmation names the file and says it is saved",
		saved_text.contains("Character saved") and saved_text.contains("user://character.json"),
		saved_text)
	
	# The message line is a success, not an error.
	_check("UI-AT-12 the message line reports the save",
		wizard.message_label.text.contains("Character saved"),
		wizard.message_label.text)
	
	# The Finish button becomes a Saved button, and there is a way to
	# start another character.
	_check("UI-AT-12 the Finish button becomes Saved",
		wizard.next_button.text == "Saved" and wizard.next_button.disabled,
		"%s disabled=%s" % [wizard.next_button.text, str(wizard.next_button.disabled)])
	_check("UI-AT-12 a New Character button appears", wizard.new_character_button.visible)
	
	# A new character starts from scratch. The priorities are back at
	# their defaults (which is what resolves the race), and nothing has
	# been bought.
	wizard.new_character_button.pressed.emit()
	await process_frame
	var fresh_priorities: bool = true
	for category in wizard.draft.priorities:
		if int(wizard.draft.priorities[category]) != 0:
			fresh_priorities = false
	_check("UI-AT-12 a new character starts from scratch",
		wizard.step_index == 0
		and fresh_priorities
		and wizard.draft.equipment.is_empty()
		and wizard.draft.purchased_skills.is_empty()
		and wizard.draft.purchased_advantages.is_empty()
		and wizard.draft.attribute_spent.is_empty(),
		"step %d race=%s" % [wizard.step_index, wizard.draft.race])
	# Next is legitimately disabled on the first step until the priority
	# assignment is valid; what matters is that the finished state is gone.
	_check("UI-AT-12 the new character resets the finished state",
		not wizard.new_character_button.visible
		and wizard.next_button.text == "Next",
		"%s" % wizard.next_button.text)


# --- Credits ---------------------------------------------------------------

func _test_credits() -> void:
	# A character may finish creation without spending all of its credits.
	# R-S1-9.
	wizard._show_step(4)
	var step: Control = wizard.body.get_child(0)
	var panel: VBoxContainer = step.get_child(0).get_child(0)
	var list: VBoxContainer = panel.get_node("EquipmentList")
	
	# Buy the standard archetype, so the balance is part-spent.
	for i in range(list.get_child_count()):
		var row: Control = list.get_child(i)
		if row.name == "Archetype_Standard":
			row.get_node("Buy").pressed.emit()
			break
	var remaining: int = wizard.draft.remaining_credits()
	_check("UI-AT-11 spending equipment leaves credits behind",
		remaining > 0 and remaining < wizard.draft.credits,
		"%d of %d" % [remaining, wizard.draft.credits])
	
	# The equipment step is complete even with credits left, and so is
	# the whole character.
	_check("UI-AT-11 the equipment step is complete with credits unspent",
		step.is_complete(), str(remaining))
	wizard._update_footer()
	_check("UI-AT-11 Next is enabled with credits unspent", not wizard.next_button.disabled)
	
	# The sheet shows the pool, the spend and the balance.
	wizard._show_step(5)
	var sheet: Control = wizard.body.get_child(0)
	var sheet_text: String = sheet.get_child(0).get_child(0).get_node("Sheet").text
	_check("UI-AT-11 the sheet reports the credits left",
		sheet_text.contains("%d remaining" % remaining), sheet_text)
	
	# The export keeps the pool, so the balance is still derivable.
	var exported: Dictionary = wizard.draft.to_export()
	var character: Dictionary = exported.get("character", {})
	_check("UI-AT-11 the export keeps the credit pool",
		int(character.get("credits", -1)) == wizard.draft.credits,
		str(character.get("credits")))
	_check("UI-AT-11 the balance is derivable from the pool and the equipment",
		int(character.get("credits", 0))
			- int(wizard.draft.equipment_cost()) == remaining,
		"%d - %d != %d" % [int(character.get("credits", 0)),
			wizard.draft.equipment_cost(), remaining])


# --- The exported character against the rulebook -------------------------

func _test_export_against_rulebook() -> void:
	# Every value in a finished character, checked against the rulebook
	# itself rather than against the engine that produced it.
	#
	# The rulebook corpus is parsed out of the book's own tables and
	# formulas (tools/gen_rulebook_corpus.py), so this is an independent
	# check of the exported sheet, not a restatement of the engine.
	var path: String = "res://data/rulebook_corpus.json"
	if not FileAccess.file_exists(path):
		_check("UI-AT-13 the rulebook corpus is present", false, path)
		return
	var corpus = JSON.parse_string(FileAccess.get_file_as_string(path))
	if corpus == null:
		_check("UI-AT-13 the rulebook corpus parses", false)
		return
	var formulas: Dictionary = corpus.get("formulas", {})
	var saving: Dictionary = formulas.get("saving_throw", {})
	var saving_base: int = int(saving.get("base", 18))
	var saving_multiplier: int = int(saving.get("multiplier", 2))
	var characteristic_base: int = int(formulas.get("characteristics", {}).get("base", 18))
	var pairs: Dictionary = formulas.get("characteristics", {}).get("pairs", {})
	
	var exported: Dictionary = wizard.draft.to_export()
	var character: Dictionary = exported.get("character", {})
	var attributes: Dictionary = character.get("attributes", {})
	
	# 1. The attributes are the points assigned, plus the racial
	#    modifier, with Intuition at half its points.
	var race: String = str(character.get("race", ""))
	var modifiers: Dictionary = corpus.get("racial_modifiers", {}).get(race, {})
	var spent: Dictionary = character.get("attribute_points_spent", {})
	var attribute_errors: Array[String] = []
	for attribute in attributes:
		var points: int = int(spent.get(attribute, 0))
		var modifier: int = int(modifiers.get(attribute, 0))
		var want: int = points + modifier
		if attribute == "INTUITION":
			want = int(floor(float(points) / 2.0)) + modifier
		if int(attributes[attribute]) != want:
			attribute_errors.append("%s: rulebook %d, sheet %d" % [
				attribute, want, int(attributes[attribute])])
	_check("UI-AT-13 the sheet's attributes follow the rulebook's allocation rules",
		attribute_errors.is_empty(), "; ".join(attribute_errors))
	
	# 2. The saving throws.
	var throws: Dictionary = character.get("saving_throws", {})
	var throw_errors: Array[String] = []
	for attribute in attributes:
		var want: int = saving_base - (saving_multiplier * int(attributes[attribute]))
		if int(throws.get(attribute, -999)) != want:
			throw_errors.append("%s: rulebook %d, sheet %d" % [
				attribute, want, int(throws.get(attribute, -999))])
	_check("UI-AT-13 the sheet's saving throws follow the rulebook's formula",
		throw_errors.is_empty(), "; ".join(throw_errors))
	
	# 3. The characteristics.
	var characteristics: Dictionary = character.get("characteristics", {})
	var characteristic_errors: Array[String] = []
	for characteristic in pairs:
		var pair: Array = pairs[characteristic]
		var want: int = characteristic_base - (int(attributes.get(pair[0], 0)) + int(attributes.get(pair[1], 0)))
		if int(characteristics.get(characteristic, -999)) != want:
			characteristic_errors.append("%s: rulebook %d, sheet %d" % [
				characteristic, want, int(characteristics.get(characteristic, -999))])
	_check("UI-AT-13 the sheet's characteristics follow the rulebook's formulas",
		characteristic_errors.is_empty(), "; ".join(characteristic_errors))
	
	# 4. The racial modifiers recorded on the sheet.
	var sheet_modifiers: Dictionary = character.get("racial_modifiers", {})
	var modifier_errors: Array[String] = []
	for attribute in modifiers:
		if int(sheet_modifiers.get(attribute, 999)) != int(modifiers[attribute]):
			modifier_errors.append("%s: rulebook %d, sheet %d" % [
				attribute, int(modifiers[attribute]),
				int(sheet_modifiers.get(attribute, 999))])
	_check("UI-AT-13 the sheet's racial modifiers match the rulebook",
		modifier_errors.is_empty(), "; ".join(modifier_errors))
