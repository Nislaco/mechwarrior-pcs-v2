extends RefCounted

## In-progress character, carried across the wizard steps.
##
## Pure state: the wizard's steps read and write this, and the rules
## engine (src/rules/) is the only thing that interprets it. That keeps
## the UI a thin shell over verified logic.

const Rules := preload("res://rules/mw_rules.gd")
const SkillRules := preload("res://rules/mw_rules_skills.gd")

## Where a finished character is written. R-S1-10.
##
## It lives here so that the wizard and the character sheet can both name
## it without either preloading the other.
const SAVE_PATH: String = "user://character.json"

var name: String = ""
var age: int = 0
var height: int = 0
var weight: int = 0

# --- Priorities (R-S1-1) ---
var use_flexible_priorities: bool = false
var priorities: Dictionary = {}          # category -> level 0-4

# --- Derived from priorities (R-S1-2) ---
var race: String = ""
var attribute_points: int = 0
var skill_points: int = 0
var advantage_points: int = 0
var vehicle_class: String = "None"
var vehicle_priority: int = 0

# --- Advantages (R-S1-4) ---
var purchased_advantages: Dictionary = {}  # name -> cost paid
var exceptional_attribute: String = ""

# --- Attributes (R-S1-5..R-S1-7) ---
var attribute_spent: Dictionary = {}       # attribute -> points spent
var final_attributes: Dictionary = {}
var saving_throws: Dictionary = {}
var characteristics: Dictionary = {}

# --- Skills (R-S1-8) ---
var purchased_skills: Dictionary = {}      # skill -> level
var selected_package: String = ""
## Levels a purchased package granted each skill, "for free" up to those
## levels. Any level above a package base is charged at the standard
## incremental cost (triangular). Empty when no package is bought.
var package_base_skills: Dictionary = {}  # skill -> level granted by package
## The flat point fee paid for the selected package (0 if none).
var package_flat_cost: int = 0
var skill_targets: Dictionary = {}

# --- Equipment (R-S1-9) ---
var equipment: Array = []
var credits: int = 50000

# --- Derived ---
var service_notes: Array[String] = []


## Re-derive everything that depends on the priorities.
## Called whenever the priority assignment changes.
func apply_priorities() -> void:
	if priorities.size() < 5:
		return
	var resolved: Dictionary = Rules.resolve_priorities(priorities)
	race = str(resolved["race"])
	attribute_points = int(resolved["attribute_points"])
	skill_points = int(resolved["skill_points"])
	advantage_points = int(resolved["advantage_points"])
	vehicle_class = str(resolved["vehicle_class"])
	vehicle_priority = int(resolved["vehicle_priority"])


## Recompute the derived attribute values and everything from them.
## R-S1-5, R-S1-6, R-S1-7.
func recompute_attributes() -> void:
	if race.is_empty():
		return
	final_attributes = Rules.final_attributes(race, attribute_spent, exceptional_attribute)
	saving_throws = Rules.calculate_saving_throws(final_attributes)
	characteristics = Rules.calculate_characteristics(final_attributes)
	service_notes = Rules.service_eligibility_notes(race, final_attributes)


## Points still unspent on attributes.
func remaining_attribute_points() -> int:
	var spent: int = 0
	for attribute in attribute_spent:
		spent += int(attribute_spent[attribute])
	return attribute_points - spent


## Points still unspent on skills.
##
## R-S1-8.  A skill's total point cost is triangular: reaching level L
## costs L*(L+1)/2 points (level 1 = 1, level 2 = 3, level 3 = 6, ...).
## Raising a skill from level L-1 to level L costs L points (the marginal
## cost equals the target level).  A skill package is a flat fee in
## points; it grants its skills up to their package levels for free, and
## any level above a package base is charged at the standard incremental
## cost.  The package cost itself is deducted from the same pool.
func remaining_skill_points() -> int:
	var spent: int = 0
	for skill in purchased_skills:
		var level: int = int(purchased_skills[skill])
		var base: int = int(package_base_skills.get(skill, 0))
		# Triangular cost above package base: L*(L+1)/2 - B*(B+1)/2
		spent += (level * (level + 1) / 2) - (base * (base + 1) / 2)
	spent += package_flat_cost
	return skill_points - spent


## Advantage points still unspent.
func remaining_advantage_points() -> int:
	var spent: int = 0
	for advantage in purchased_advantages:
		spent += int(purchased_advantages[advantage])
	return advantage_points - spent


## Credits still available for equipment.
##
## A character does NOT have to spend all of its credits. What is left
## over is still the character's. R-S1-9.
func remaining_credits() -> int:
	return credits - SkillRules.equipment_total_cost(equipment)


## The cost of the equipment the character is carrying.
func equipment_cost() -> int:
	return SkillRules.equipment_total_cost(equipment)


## Build the exportable character sheet. R-S1-10.
##
## The exported `credits` is the character's credit POOL, not the balance
## left after the equipment. That is what the reference schema means by
## it: every reference sample character stores a fixed pool (5,000 /
## 25,000 / 50,000) that does not change with what the character buys,
## and one of them carries more equipment than its pool entirely. The
## balance left over is derived from the pool and the equipment.
func to_character_sheet() -> Dictionary:
	return SkillRules.build_character_sheet(
		name,
		race,
		attribute_spent,
		final_attributes,
		saving_throws,
		characteristics,
		purchased_advantages,
		purchased_skills,
		equipment,
		credits,
		skill_targets,
		_service_note_text()
	)


func _service_note_text() -> String:
	if service_notes.is_empty():
		return ""
	return " | ".join(service_notes)


## The export payload. R-S1-10.
func to_export() -> Dictionary:
	return SkillRules.export_character(to_character_sheet())
