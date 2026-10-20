extends RefCounted

## MechWarrior 2e character-creation rules engine, part 2:
## skills, equipment, and character-sheet export.
##
## Pure logic: no UI, no scene tree. See mw_rules.gd for the shared tables
## and the rule contract (design/systems/character-creation.md).

const Rules := preload("res://rules/mw_rules.gd")

## Packages are loaded from data/skill_packages.json (extracted from the
## Python reference) and cached here.
static var _packages: Dictionary = {}
static var _packages_loaded: bool = false


static func _load_packages() -> void:
	if _packages_loaded:
		return
	_packages_loaded = true
	var path := "res://data/skill_packages.json"
	if not FileAccess.file_exists(path):
		push_warning("[MWRules] skill_packages.json not found at %s" % path)
		return
	var text: String = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_warning("[MWRules] skill_packages.json failed to parse")
		return
	_packages = parsed


## All skill packages available to a race. R-S1-8.
static func packages_for_race(race: String) -> Dictionary:
	_load_packages()
	if not _packages.has(race):
		return {}
	return (_packages[race] as Dictionary).duplicate(true)


## Packages a character can still afford, given remaining skill points.
## R-S1-8.
static func eligible_packages(race: String, skill_points: int) -> Dictionary:
	var eligible: Dictionary = {}
	for name in packages_for_race(race):
		var spec: Dictionary = packages_for_race(race)[name]
		if int(spec.get("cost", 9999)) <= skill_points:
			eligible[name] = spec
	return eligible


## The maximum skill level a character with this LEARN may take. R-S1-8.
static func max_skill_level(learn: int) -> int:
	return maxi(0, learn)


## Can this skill be raised to this level? R-S1-8.
static func skill_level_allowed(skill: String, level: int, learn: int, purchased: Dictionary) -> Dictionary:
	if level < 0:
		return {"ok": false, "error": "Skill level cannot be negative."}
	if level > max_skill_level(learn):
		return {"ok": false, "error": "No skill level may exceed your LEARN attribute (%d)." % learn}
	return {"ok": true, "error": ""}


## Apply a fixed-skill package. Returns the new skill map.
## R-S1-8.
static func apply_fixed_package(package_spec: Dictionary, purchased: Dictionary) -> Dictionary:
	var result: Dictionary = purchased.duplicate(true)
	for skill in package_spec.get("skills", {}):
		result[skill] = maxi(int(result.get(skill, 0)), int(package_spec["skills"][skill]))
	return result


## The slot budget of a flexible package: {level: count remaining}.
## Level 0 is not a skill level and consumes no slot. R-S1-8.
static func package_slots(package_spec: Dictionary) -> Dictionary:
	var slots: Dictionary = {}
	for level in package_spec.get("skills_at_level", {}):
		var l: int = int(level)
		if l <= 0:
			continue
		slots[l] = int(package_spec["skills_at_level"][level])
	return slots


## Apply a flexible package given the player's per-skill level choices.
## `choices` maps skill name -> level (0 = skipped).
## Required skills take slots first; electives are skipped if no slot fits.
## R-S1-8.
static func apply_flexible_package(package_spec: Dictionary, choices: Dictionary, purchased: Dictionary) -> Dictionary:
	var result: Dictionary = purchased.duplicate(true)
	var slots: Dictionary = package_slots(package_spec)
	var required: Array = package_spec.get("required_skills", [])
	var elective: Array = package_spec.get("elective_skills", [])
	
	# Required skills first - they must take a slot.
	for skill in required:
		var level: int = int(choices.get(skill, 0))
		if level <= 0:
			continue
		if not slots.has(level) or int(slots[level]) <= 0:
			continue
		slots[level] = int(slots[level]) - 1
		result[skill] = maxi(int(result.get(skill, 0)), level)
	
	# Electives may be skipped.
	for skill in elective:
		if skill in required:
			continue
		var level: int = int(choices.get(skill, 0))
		if level <= 0:
			continue
		if not slots.has(level) or int(slots[level]) <= 0:
			continue
		slots[level] = int(slots[level]) - 1
		result[skill] = maxi(int(result.get(skill, 0)), level)
	
	return result


# ---------------------------------------------------------------------------
# R-S1-9 — equipment
# ---------------------------------------------------------------------------

## Archetype equipment lists. Costs are as in the Python reference.
const ARCHETYPE_EQUIPMENT: Dictionary = {
	"Human": {
		"Standard": [
			{"name": "Standard Neural Implant", "cost": 1000},
			{"name": "MechWarrior Combat Suit", "cost": 20000},
			{"name": "Combat Neurohelmet", "cost": 1400},
			{"name": "Neurohelmet", "cost": 900},
			{"name": "Standard Laser Pistol", "cost": 750},
			{"name": "Standard Laser Rifle", "cost": 1250},
			{"name": "Noteputer", "cost": 500},
		],
		"Light": [
			{"name": "Light Neural Implant", "cost": 500},
			{"name": "Light Armor", "cost": 5000},
			{"name": "Energy Weapon", "cost": 2000},
			{"name": "Stealth Equipment", "cost": 3000},
		],
	},
	"Clan Warrior": {
		"Standard": [
			{"name": "Clan Neural Implant", "cost": 1000},
			{"name": "Clan Armor", "cost": 20000},
			{"name": "Clan Laser Pistol", "cost": 750},
			{"name": "Clan Laser Rifle", "cost": 1250},
			{"name": "Noteputer", "cost": 500},
		],
		"Light": [
			{"name": "Light Neural Implant", "cost": 500},
			{"name": "Light Armor", "cost": 5000},
			{"name": "Energy Weapon", "cost": 2000},
			{"name": "Stealth Equipment", "cost": 3000},
		],
	},
	"Clan Pilot": {
		"Standard": [
			{"name": "Clan Neural Implant", "cost": 1000},
			{"name": "Clan Armor", "cost": 20000},
			{"name": "Clan Laser Pistol", "cost": 750},
			{"name": "Clan Laser Rifle", "cost": 1250},
			{"name": "Noteputer", "cost": 500},
		],
		"Light": [
			{"name": "Light Neural Implant", "cost": 500},
			{"name": "Light Armor", "cost": 5000},
			{"name": "Energy Weapon", "cost": 2000},
			{"name": "Stealth Equipment", "cost": 3000},
		],
	},
	"Elemental": {
		"Standard": [
			{"name": "Clan Neural Implant", "cost": 1000},
			{"name": "Clan Battle Armor", "cost": 20000},
			{"name": "Clan Neurohelmet", "cost": 5000},
			{"name": "Clan Laser Pistol", "cost": 750},
			{"name": "Clan Laser Rifle", "cost": 1250},
			{"name": "Noteputer", "cost": 500},
		],
		"Light": [
			{"name": "Light Neural Implant", "cost": 500},
			{"name": "Light Armor", "cost": 5000},
			{"name": "Energy Weapon", "cost": 2000},
			{"name": "Stealth Equipment", "cost": 3000},
		],
	},
}

## The archetype equipment list for a race. R-S1-9.
static func archetype_equipment(race: String, variant: String) -> Array:
	if not ARCHETYPE_EQUIPMENT.has(race):
		return []
	var by_variant: Dictionary = ARCHETYPE_EQUIPMENT[race]
	if not by_variant.has(variant):
		return []
	return (by_variant[variant] as Array).duplicate(true)


## Total cost of an equipment list. R-S1-9.
static func equipment_total_cost(equipment: Array) -> int:
	var total: int = 0
	for item in equipment:
		total += int(item.get("cost", 0))
	return total


## Can this equipment list be afforded? R-S1-9.
static func equipment_affordable(equipment: Array, credits: int) -> bool:
	return equipment_total_cost(equipment) <= credits


## The weapon damage and armor defense a character carries, derived from
## their equipment list. Used by the (future) combat tracker and shown on
## the sheet.
static func equipment_combat_stats(equipment: Array) -> Dictionary:
	var weapon_damage: int = 0
	var armor_defense: int = 0
	for item in equipment:
		var name: String = str(item.get("name", ""))
		var t: String = name.to_lower()
		if t.contains("pistol") or t.contains("rifle") or t.contains("weapon"):
			if weapon_damage == 0:
				weapon_damage = _damage_from_name(name)
		elif t.contains("armor") or t.contains("suit") or t.contains("neurohelmet") or t.contains("helmet"):
			if armor_defense == 0:
				armor_defense = _defense_from_name(name)
	return {"weapon_damage": weapon_damage, "armor_defense": armor_defense}


static func _damage_from_name(name: String) -> int:
	# The reference uses a flat per-archetype damage figure; the sample
	# characters use 8 (John Star) / 6 (Viper) / 4 (Dr. Sarah Chen).
	match name:
		"Standard Laser Pistol", "Standard Laser Rifle", "Clan Laser Pistol", "Clan Laser Rifle":
			return 8
		"Energy Weapon":
			return 6
	return 4


static func _defense_from_name(name: String) -> int:
	match name:
		"MechWarrior Combat Suit", "Clan Armor", "Clan Battle Armor":
			return 2
		"Light Armor":
			return 1
	return 0


# ---------------------------------------------------------------------------
# R-S1-10 — character sheet and export
# ---------------------------------------------------------------------------

## Build the character sheet dictionary. R-S1-10.
## `skill_targets` and `notes` are carried through for export parity.
static func build_character_sheet(
		name: String,
		race: String,
		spent_points: Dictionary,
		attributes: Dictionary,
		saving_throws: Dictionary,
		characteristics: Dictionary,
		advantages: Dictionary,
		skills: Dictionary,
		equipment: Array,
		credits: int,
		skill_targets: Dictionary = {},
		notes: String = "") -> Dictionary:
	var modifiers: Dictionary = Rules.race_modifiers(race)
	return {
		"name": name,
		"race": race,
		"age": 0,
		"height": 0,
		"weight": 0,
		"attributes": attributes,
		"characteristics": characteristics,
		"saving_throws": saving_throws,
		"advantages": advantages,
		"skills": skills,
		"skill_targets": skill_targets,
		"equipment": equipment,
		"credits": credits,
		"notes": notes,
		"attribute_points_spent": spent_points,
		"racial_modifiers": modifiers,
	}


## Serialise a character sheet to the reference JSON shape
## ({version, exported, character}). R-S1-10.
static func export_character(sheet: Dictionary) -> Dictionary:
	return {
		"version": 1,
		"exported": Time.get_datetime_string_from_system(),
		"character": sheet,
	}


## Parse a character sheet from the reference JSON shape.
## Returns {} on failure. R-S1-10.
static func import_character(data: Dictionary) -> Dictionary:
	if not data.has("character"):
		return {}
	var character: Dictionary = data["character"]
	if not character.has("race") or not character.has("attributes"):
		return {}
	return character


## Recompute the derived values of an imported sheet and compare them
## with what it stores. Returns an array of mismatch notes (empty = good).
## Used to prove the port agrees with the reference data. R-S1-10.
static func verify_character(character: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var race: String = str(character.get("race", ""))
	var attributes: Dictionary = character.get("attributes", {})
	if not attributes.is_empty():
		var expected_throws: Dictionary = Rules.calculate_saving_throws(attributes)
		for attribute in expected_throws:
			var stored: int = int(character.get("saving_throws", {}).get(attribute, -9999))
			if stored != int(expected_throws[attribute]):
				notes.append("Saving throw %s: stored %d, recomputed %d" % [attribute, stored, int(expected_throws[attribute])])
		var expected_chars: Dictionary = Rules.calculate_characteristics(attributes)
		for characteristic in expected_chars:
			var stored: int = int(character.get("characteristics", {}).get(characteristic, -9999))
			if stored != int(expected_chars[characteristic]):
				notes.append("Characteristic %s: stored %d, recomputed %d" % [characteristic, stored, int(expected_chars[characteristic])])
	return notes
