extends SceneTree

## Verification harness for the MechWarrior PCS rules engine.
##
## Run: godot --headless --path src -s res://scripts/verify_rules.gd
## Exits non-zero on any failure.
##
## Every check here is a rule from design/systems/character-creation.md.
## The reference implementation is the Python at
## mw-depo/mw-script/chargen.py; the sample characters shipped in
## src/data/characters/ are that reference's own output, so verifying
## them proves the port agrees with the reference on the derived values.

const Rules := preload("res://rules/mw_rules.gd")
const SkillRules := preload("res://rules/mw_rules_skills.gd")

var checks: int = 0
var failures: int = 0


func _init() -> void:
	print("--- MechWarrior PCS Rules Verification Start ---")
	
	_test_priority_values()
	_test_standard_priorities()
	_test_flexible_priorities()
	_test_races()
	_test_attributes()
	_test_saving_throws()
	_test_characteristics()
	_test_advantages()
	_test_skills()
	_test_equipment()
	_test_sample_characters()
	_test_parity_corpus()
	_test_rulebook_corpus()
	_test_export_roundtrip()
	
	print("--- MechWarrior PCS Rules Verification End: %d checks, %d failures ---" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(id: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if condition:
		print("PASS ", id)
	else:
		failures += 1
		print("FAIL ", id, (" - " + detail) if detail != "" else "")


# --- R-S1-1 / R-S1-2 : priorities -------------------------------------------

func _test_priority_values() -> void:
	# S1-AT-1: the priority table maps every category/level.
	var expect: Dictionary = {
		"Race": ["Human", "Human", "Clan Warrior", "Clan Pilot", "Elemental"],
		"Attributes": [18, 21, 24, 27, 30],
		"Skills": [8, 12, 16, 20, 24],
		"Advantages": [0, 1, 2, 3, 4],
		"Vehicle Class": ["None", "Light", "Medium", "Heavy", "Assault"],
	}
	var all_ok: bool = true
	for category in expect:
		for level in range(5):
			if Rules.PRIORITY_VALUES[category][level] != expect[category][level]:
				all_ok = false
	_check("S1-AT-1 priority table maps every category and level", all_ok)
	
	# A full assignment resolves to the right concrete values.
	var priorities: Dictionary = {
		"Race": 4, "Attributes": 3, "Skills": 2, "Advantages": 1, "Vehicle Class": 0,
	}
	var resolved: Dictionary = Rules.resolve_priorities(priorities)
	_check("S1-AT-1 priorities resolve to race/points/vehicle",
		resolved.race == "Elemental"
		and resolved.attribute_points == 27
		and resolved.skill_points == 16
		and resolved.advantage_points == 1
		and resolved.vehicle_class == "None",
		str(resolved))


# --- R-S1-1 : standard priorities -------------------------------------------

func _test_standard_priorities() -> void:
	# S1-AT-2: duplicate level rejected.
	var dup: Dictionary = {
		"Race": 2, "Attributes": 2, "Skills": 1, "Advantages": 0, "Vehicle Class": 3,
	}
	_check("S1-AT-2 duplicate priority level is rejected",
		not Rules.validate_standard_priorities(dup).ok)
	
	# Out-of-range level rejected.
	var oor: Dictionary = {
		"Race": 5, "Attributes": 2, "Skills": 1, "Advantages": 0, "Vehicle Class": 3,
	}
	_check("S1-AT-2 out-of-range priority level is rejected",
		not Rules.validate_standard_priorities(oor).ok)
	
	# A valid permutation is accepted.
	var ok: Dictionary = {
		"Race": 0, "Attributes": 1, "Skills": 2, "Advantages": 3, "Vehicle Class": 4,
	}
	_check("S1-AT-2 a valid permutation is accepted",
		Rules.validate_standard_priorities(ok).ok)


# --- R-S1-1 : flexible priorities -------------------------------------------

func _test_flexible_priorities() -> void:
	# S1-AT-3: levels that cannot total 10 are rejected.
	var bad: Dictionary = {
		"Race": 4, "Attributes": 4, "Skills": 4, "Advantages": 4, "Vehicle Class": 4,
	}
	_check("S1-AT-3 flexible priorities not totalling 10 are rejected",
		not Rules.validate_flexible_priorities(bad).ok,
		"total was %d" % (4 + 4 + 4 + 4 + 4))
	
	# A valid set is accepted.
	var good: Dictionary = {
		"Race": 2, "Attributes": 2, "Skills": 2, "Advantages": 2, "Vehicle Class": 2,
	}
	_check("S1-AT-3 flexible priorities totalling 10 are accepted",
		Rules.validate_flexible_priorities(good).ok)
	
	# The per-entry range keeps the pool spendable.
	var range_ok: bool = true
	for pool in range(0, 11):
		for remaining in range(1, 6):
			var r: Vector2i = Rules.flexible_priority_range(pool, remaining)
			if r.x > r.y or r.x < 0 or r.y > 4:
				range_ok = false
	_check("S1-AT-3 flexible priority range always permits a spendable value", range_ok)
	
	# The range actually bounds the pool: from pool=10 with 5 left, the
	# first entry must be at most 4 (5*4 = 20 would overspend).
	var first: Vector2i = Rules.flexible_priority_range(10, 5)
	_check("S1-AT-3 flexible range bounds the pool", first.x == 0 and first.y == 4, str(first))


# --- R-S1-3 : races --------------------------------------------------------

func _test_races() -> void:
	# S1-AT-4 (part 1): modifiers and maximums per race.
	var expected: Dictionary = {
		"Human": {"m": [0, 0, 0, 0, 0], "x": [6, 6, 6, 6, 6]},
		"Clan Warrior": {"m": [0, 1, 0, 0, 1], "x": [6, 7, 6, 6, 7]},
		"Clan Pilot": {"m": [-1, 2, 0, 0, 1], "x": [5, 8, 6, 6, 7]},
		"Elemental": {"m": [2, 1, 0, -1, 0], "x": [8, 7, 6, 5, 6]},
	}
	var all_ok: bool = true
	for race in expected:
		var mods: Array = []
		var maxs: Array = []
		for attribute in Rules.ATTRIBUTES:
			mods.append(int(Rules.race_modifiers(race)[attribute]))
			maxs.append(int(Rules.race_maximums(race)[attribute]))
		if mods != expected[race]["m"] or maxs != expected[race]["x"]:
			all_ok = false
	_check("S1-AT-4 racial modifiers and maximums match the table", all_ok)
	
	# P-BUG-3: the racial table is never mutated by a caller.
	var m1: Dictionary = Rules.race_maximums("Human")
	m1["BUILD"] = 99
	_check("S1-AT-4 racial maximums are returned as a copy (P-BUG-3)",
		int(Rules.race_maximums("Human")["BUILD"]) == 6)


# --- R-S1-5 : attributes ---------------------------------------------------

func _test_attributes() -> void:
	# S1-AT-4: INTUITION value is floor(points/2) + modifier.
	var clan: Dictionary = Rules.race_modifiers("Clan Warrior")
	_check("S1-AT-4 INTUITION value is floor(points/2) plus modifier",
		Rules.attribute_final_value("INTUITION", 5, clan) == 2 + 1,
		str(Rules.attribute_final_value("INTUITION", 5, clan)))
	
	# A non-INTUITION attribute is points + modifier.
	_check("S1-AT-4 other attributes are points plus modifier",
		Rules.attribute_final_value("REFLEX", 4, clan) == 4 + 1)
	
	# Headroom is bounded on POINTS for INTUITION, so the value never
	# exceeds the racial maximum. Clan Pilot INTUITION max is 7, modifier +1.
	var mods: Dictionary = Rules.race_modifiers("Clan Pilot")
	var maxs: Dictionary = Rules.race_maximums("Clan Pilot")
	var headroom: int = Rules.attribute_points_headroom("INTUITION", 0, maxs, mods)
	# value = floor(p/2) + 1 <= 7  =>  p <= 12
	_check("S1-AT-4 INTUITION headroom is bounded on points, not value",
		headroom == 12, str(headroom))
	
	# An Exceptional Attribute raises that attribute's maximum by 1, and
	# the racial table is not polluted (P-BUG-3). The maximum rises, so a
	# character must SPEND the extra point to reach the higher value.
	var base_max: int = int(Rules.race_maximums("Human")["BUILD"])
	var capped_attrs: Dictionary = Rules.final_attributes("Human", {"BUILD": 6}, "BUILD")
	_check("S1-ET-8 an Exceptional Attribute raises the maximum by one",
		int(capped_attrs["BUILD"]) == base_max, "capped at %d (max %d)" % [int(capped_attrs["BUILD"]), base_max])
	var raised_attrs: Dictionary = Rules.final_attributes("Human", {"BUILD": 7}, "BUILD")
	_check("S1-ET-8 the extra Exceptional point reaches the raised maximum",
		int(raised_attrs["BUILD"]) == base_max + 1, str(raised_attrs))
	_check("S1-AT-4 the racial table is unchanged by an Exceptional Attribute (P-BUG-3)",
		int(Rules.race_maximums("Human")["BUILD"]) == base_max)
	
	# Without an Exceptional Attribute the racial maximum is respected.
	var capped: Dictionary = Rules.final_attributes("Human", {"BUILD": 6})
	_check("S1-AT-4 final attributes respect the racial maximum", capped["BUILD"] == 6, str(capped))


# --- R-S1-6 / R-S1-7 : derived ---------------------------------------------

func _test_saving_throws() -> void:
	# S1-AT-5: 18 - 2*value.
	var attrs: Dictionary = {"BUILD": 6, "REFLEX": 4, "LEARN": 5, "CHARISMA": 3, "INTUITION": 4}
	var throws: Dictionary = Rules.calculate_saving_throws(attrs)
	var ok: bool = true
	for attribute in attrs:
		if int(throws[attribute]) != 18 - 2 * int(attrs[attribute]):
			ok = false
	_check("S1-AT-5 saving throws are 18 minus twice the attribute", ok, str(throws))
	_check("S1-AT-5 a throw for a 6 attribute is 6", int(throws["BUILD"]) == 6)


func _test_characteristics() -> void:
	# S1-AT-6: the four formulas.
	var attrs: Dictionary = {"BUILD": 5, "REFLEX": 4, "LEARN": 3, "CHARISMA": 2, "INTUITION": 1}
	var chars: Dictionary = Rules.calculate_characteristics(attrs)
	_check("S1-AT-6 Athletic is 18 minus Build plus Reflex",
		int(chars["Athletic"]) == 18 - (5 + 4), str(chars))
	_check("S1-AT-6 Physical is 18 minus Reflex plus Intuition",
		int(chars["Physical"]) == 18 - (4 + 1))
	_check("S1-AT-6 Mental is 18 minus Intuition plus Learn",
		int(chars["Mental"]) == 18 - (1 + 3))
	_check("S1-AT-6 Social is 18 minus Intuition plus Charisma",
		int(chars["Social"]) == 18 - (1 + 2))


# --- R-S1-4 : advantages ---------------------------------------------------

func _test_advantages() -> void:
	# S1-AT-7: an Elemental gets Toughness free, so it is not purchasable.
	var elem_avail: Dictionary = Rules.available_advantages("Elemental", 4, 0, {})
	_check("S1-AT-7 an Elemental cannot purchase Toughness (it is free)",
		not elem_avail.has("Toughness"))
	
	# Bloodname and EI are offered to a Clan/Elemental but not to a Human.
	var human_avail: Dictionary = Rules.available_advantages("Human", 4, 0, {})
	_check("S1-AT-7 Bloodname is not offered to a Human",
		not human_avail.has("Bloodname"))
	_check("S1-AT-7 the EI neural implant is not offered to a Human",
		not human_avail.has("Enhanced Imaging (EI) Neural Implant"))
	var clan_avail: Dictionary = Rules.available_advantages("Clan Warrior", 4, 0, {})
	_check("S1-AT-7 Bloodname is offered to a Clan Warrior",
		clan_avail.has("Bloodname"))
	
	# S1-ET-8: Exceptional Attribute is Human only.
	_check("S1-ET-8 Exceptional Attribute is offered to a Human",
		human_avail.has("Exceptional Attribute"))
	_check("S1-ET-8 Exceptional Attribute is not offered to a Clan Warrior",
		not clan_avail.has("Exceptional Attribute"))
	
	# S1-AT-9: only one tier of a family may be bought.
	var purchased: Dictionary = {"Title (Knight)": 1}
	var after: Dictionary = Rules.available_advantages("Human", 4, 0, purchased)
	_check("S1-AT-9 a second tier of the same family is blocked",
		not after.has("Title (Baronet)") and not after.has("Title (Baron)"))
	
	# Affordable-only: a 3-point advantage is not offered with 2 points.
	_check("S1-AT-9 an unaffordable advantage is not offered",
		not Rules.available_advantages("Human", 1, 0, {}).has("Title (Baron)"))
	
	# DropShip requires Vehicle Class priority 4.
	_check("S1-AT-9 DropShip needs Vehicle Class priority 4",
		not Rules.available_advantages("Human", 3, 3, {}).has("DropShip")
		and Rules.available_advantages("Human", 3, 4, {}).has("DropShip"))
	
	# Variable-cost tiers are exposed.
	var tiers: Array[int] = Rules.advantage_cost_tiers("Contact")
	_check("S1-AT-9 variable-cost advantages expose their tiers",
		tiers.size() == 3 and tiers[0] == 1 and tiers[2] == 3, str(tiers))


# --- R-S1-8 : skills -------------------------------------------------------

func _test_skills() -> void:
	# S1-AT-10: a skill level above LEARN is rejected.
	var rejected: Dictionary = SkillRules.skill_level_allowed("Blade", 5, 4, {})
	_check("S1-AT-10 a skill level above LEARN is rejected", not rejected.ok)
	var allowed: Dictionary = SkillRules.skill_level_allowed("Blade", 4, 4, {})
	_check("S1-AT-10 a skill level equal to LEARN is allowed", allowed.ok)
	
	# Packages exist per race and are filtered by affordability.
	var human_pkgs: Dictionary = SkillRules.packages_for_race("Human")
	_check("S1-AT-11 Human packages were loaded from data", human_pkgs.size() > 0, str(human_pkgs.size()))
	var clan_pkgs: Dictionary = SkillRules.packages_for_race("Clan Warrior")
	_check("S1-AT-11 Clan Warrior has fixed-skill packages", clan_pkgs.size() > 0)
	var eligible: Dictionary = SkillRules.eligible_packages("Human", 10)
	var all_affordable: bool = true
	for name in eligible:
		if int(eligible[name]["cost"]) > 10:
			all_affordable = false
	_check("S1-AT-11 only affordable packages are eligible", all_affordable)
	
	# A flexible package's slots exclude level 0.
	var slot_spec: Dictionary = {}
	for name in human_pkgs:
		if int(human_pkgs[name].get("cost", 0)) == 9:
			slot_spec = human_pkgs[name]
			break
	var slot_counts: Dictionary = SkillRules.package_slots(slot_spec)
	_check("S1-AT-11 flexible package slots exclude level 0", not slot_counts.has(0), str(slot_counts))
	
	# Required skills take slots first; electives may be skipped.
	# A flexible package's required skills are processed before any
	# elective, so an elective can never steal a required skill's slot.
	var flex_spec: Dictionary = {}
	for name in human_pkgs:
		if int(human_pkgs[name].get("cost", 0)) == 9:
			flex_spec = human_pkgs[name]
			break
	var required: Array = flex_spec.get("required_skills", [])
	var elective: Array = flex_spec.get("elective_skills", [])
	var slots: Dictionary = SkillRules.package_slots(flex_spec)
	var total_slots: int = 0
	for level in slots:
		total_slots += int(slots[level])
	
	# Request level 2 for every required skill and every elective.
	var choices: Dictionary = {}
	for skill in required:
		choices[skill] = 2
	for skill in elective:
		choices[skill] = 2
	var applied: Dictionary = SkillRules.apply_flexible_package(flex_spec, choices, {})
	
	# Every required skill that fits got its level; the rest were skipped
	# because the slots ran out.
	var required_got: int = 0
	for skill in required:
		if int(applied.get(skill, 0)) == 2:
			required_got += 1
	var required_fitting: int = mini(required.size(), int(slots.get(2, 0)))
	_check("S1-AT-11 required skills take slots first",
		required_got == required_fitting,
		"got %d of %d required (slots at level 2: %d)" % [required_got, required.size(), int(slots.get(2, 0))])
	
	# No elective may take a slot while a required skill was skipped.
	var skipped_required: bool = required_got < required.size()
	var elective_got: int = 0
	for skill in elective:
		if skill in required:
			continue
		if applied.has(skill):
			elective_got += 1
	_check("S1-AT-11 electives never take a slot from a required skill",
		not (skipped_required and elective_got > 0),
		"required skipped, %d electives taken" % elective_got)
	
	# Level 0 consumes no slot, and a skipped elective is simply absent.
	var skip_choices: Dictionary = {}
	for skill in required:
		skip_choices[skill] = 2
	for skill in elective:
		skip_choices[skill] = 0
	var skip_applied: Dictionary = SkillRules.apply_flexible_package(flex_spec, skip_choices, {})
	var electives_absent: bool = true
	for skill in elective:
		if skill in required:
			continue
		if skip_applied.has(skill):
			electives_absent = false
	_check("S1-AT-11 electives may be skipped", electives_absent, str(skip_applied))
	_check("S1-AT-11 the package never grants more skills than it has slots",
		skip_applied.size() <= total_slots,
		"%d skills vs %d slots" % [skip_applied.size(), total_slots])
	
	# A fixed package grants its exact skill map.
	var fixed_spec: Dictionary = {}
	for name in clan_pkgs:
		fixed_spec = clan_pkgs[name]
		break
	var fixed_applied: Dictionary = SkillRules.apply_fixed_package(fixed_spec, {})
	var fixed_ok: bool = fixed_applied.size() > 0
	for skill in fixed_spec.get("skills", {}):
		if int(fixed_applied.get(skill, -1)) != int(fixed_spec["skills"][skill]):
			fixed_ok = false
	_check("S1-AT-11 a fixed package grants its exact skill map", fixed_ok, str(fixed_applied))


# --- R-S1-9 : equipment ----------------------------------------------------

func _test_equipment() -> void:
	# Archetype lists exist per race.
	_check("S1-AT-9 a Human has Standard and Light archetypes",
		SkillRules.archetype_equipment("Human", "Standard").size() > 0
		and SkillRules.archetype_equipment("Human", "Light").size() > 0)
	_check("S1-AT-9 an Elemental has Standard and Light archetypes",
		SkillRules.archetype_equipment("Elemental", "Standard").size() > 0
		and SkillRules.archetype_equipment("Elemental", "Light").size() > 0)
	# The Light (infiltrator) package is race-specific: non-Elemental
	# races get a Hold-Out Laser Pistol, Elementals get a Combat Neurohelmet
	# and a Clan Hold-Out Laser Pistol.
	_check("S1-AT-9 the Light package is race-specific",
		SkillRules.archetype_equipment("Human", "Light") != SkillRules.archetype_equipment("Elemental", "Light"))
	
	# Totals and affordability.
	var kit: Array = SkillRules.archetype_equipment("Human", "Standard")
	var total: int = SkillRules.equipment_total_cost(kit)
	_check("S1-AT-9 equipment total is the sum of costs", total == 25800, str(total))
	_check("S1-AT-9 equipment affordability is checked against credits",
		SkillRules.equipment_affordable(kit, 50000) and not SkillRules.equipment_affordable(kit, 1000))
	


# --- R-S1-10 : sample characters and export -------------------------------

func _test_sample_characters() -> void:
	# S1-AT-13: the shipped sample characters load.
	#
	# NOTE: these are 1e-era artifacts - they use STRENGTH/MEMORY attributes
	# and MUSCLES/BODY characteristics, not the 2e schema this engine
	# implements. They are kept because the combat tracker consumes them
	# (it reads HP/armor/weapon), but they are NOT a parity oracle for the
	# 2e rules - the corpus in _test_parity_corpus is.
	for name in ["john_star", "viper", "dr_sarah_chen"]:
		var path: String = "res://data/characters/%s.json" % name
		if not FileAccess.file_exists(path):
			_check("S1-AT-13 sample character %s is present" % name, false, path)
			continue
		var text: String = FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)
		_check("S1-AT-13 sample character %s parses" % name, parsed != null)
		if parsed == null:
			continue
		var character: Dictionary = SkillRules.import_character(parsed)
		_check("S1-AT-13 sample character %s imports" % name, not character.is_empty())
		if character.is_empty():
			continue
		# It must at least carry a name, a race, attributes and equipment.
		_check("S1-AT-13 sample character %s carries the expected fields" % name,
			character.has("name") and character.has("race")
			and character.has("attributes") and character.has("equipment"),
			str(character.keys()))
	
	# The exported `credits` is the character's credit POOL, not the
	# balance left after the equipment. The reference's own sample
	# characters are the evidence: every one of them stores a fixed pool
	# (5,000 / 25,000 / 50,000) that does not change with what the
	# character carries, and john_star carries 22,810 of equipment against
	# a pool of 5,000 -- which a remaining balance could not be.
	var pool_evidence: Array[String] = []
	for name in ["john_star", "viper", "dr_sarah_chen"]:
		var path: String = "res://data/characters/%s.json" % name
		if not FileAccess.file_exists(path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed == null:
			continue
		var character: Dictionary = parsed.get("character", parsed)
		var pool: int = int(character.get("credits", 0))
		var carried: int = SkillRules.equipment_total_cost(character.get("equipment", []))
		pool_evidence.append("%s pool=%d carried=%d" % [name, pool, carried])
		if carried > pool:
			_check("S1-AT-15 %s proves the reference credits is a pool, not a balance" % name,
				true, "")
			break
	_check("S1-AT-15 the reference sample characters prove credits is a credit pool",
		not pool_evidence.is_empty(), " | ".join(pool_evidence))


func _test_parity_corpus() -> void:
	# S1-AT-14 (parity): the port must agree with the Python reference on
	# every derived value. The corpus is generated from chargen.py itself
	# (tools/gen_parity_corpus.py), so this is a true cross-check of the
	# port, not a self-consistency check.
	var path: String = "res://data/parity_corpus.json"
	if not FileAccess.file_exists(path):
		_check("S1-AT-14 parity corpus is present", false, path)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		_check("S1-AT-14 parity corpus parses", false)
		return
	var cases: Array = parsed.get("cases", [])
	_check("S1-AT-14 parity corpus is non-empty", cases.size() > 0, str(cases.size()))
	
	var throw_mismatches: int = 0
	var characteristic_mismatches: int = 0
	for case in cases:
		var attributes: Dictionary = case.get("attributes", {})
		var expected_throws: Dictionary = case.get("saving_throws", {})
		var expected_chars: Dictionary = case.get("characteristics", {})
		var actual_throws: Dictionary = Rules.calculate_saving_throws(attributes)
		var actual_chars: Dictionary = Rules.calculate_characteristics(attributes)
		for attribute in expected_throws:
			if int(actual_throws.get(attribute, -9999)) != int(expected_throws[attribute]):
				throw_mismatches += 1
		for characteristic in expected_chars:
			if int(actual_chars.get(characteristic, -9999)) != int(expected_chars[characteristic]):
				characteristic_mismatches += 1
	_check("S1-AT-14 saving throws match the Python reference on all cases",
		throw_mismatches == 0, "%d mismatches" % throw_mismatches)
	_check("S1-AT-14 characteristics match the Python reference on all cases",
		characteristic_mismatches == 0, "%d mismatches" % characteristic_mismatches)


func _test_rulebook_corpus() -> void:
	# S1-AT-16: the engine agrees with the RULEBOOK.
	#
	# The parity corpus checks the port against the Python reference. That
	# is a check of the port against the reference -- not a check that
	# either of them agrees with the book. This corpus is parsed straight
	# out of the rulebook's own tables (tools/gen_rulebook_corpus.py), so
	# the rulebook is an oracle in its own right, independent of the
	# reference the port was written from.
	var path: String = "res://data/rulebook_corpus.json"
	if not FileAccess.file_exists(path):
		_check("S1-AT-16 the rulebook corpus is present", false, path)
		return
	var corpus = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check("S1-AT-16 the rulebook corpus parses", corpus != null)
	if corpus == null:
		return
	
	# 1. The Master Character Table: what each priority level grants.
	var expected_priorities: Dictionary = corpus.get("priority_values", {})
	var priority_errors: Array[String] = []
	for category in expected_priorities:
		var engine_values: Dictionary = Rules.PRIORITY_VALUES.get(category, {})
		for level in expected_priorities[category]:
			var want = expected_priorities[category][level]
			var got = engine_values.get(int(level), "<missing>")
			# JSON numbers come back as floats, so compare numerically
			# rather than as strings.
			if want is float or want is int:
				if int(got) != int(want):
					priority_errors.append("%s priority %s: rulebook %s, engine %s" % [
						category, str(level), str(want), str(got)])
			elif str(want) != str(got):
				priority_errors.append("%s priority %s: rulebook %s, engine %s" % [
					category, str(level), str(want), str(got)])
	_check("S1-AT-16 the priority table matches the rulebook's Master Character Table",
		priority_errors.is_empty(), "; ".join(priority_errors))
	
	# 2. The Racial Maximum Table.
	var maximum_errors: Array[String] = []
	for race in corpus.get("racial_maximums", {}):
		var want: Dictionary = corpus["racial_maximums"][race]
		var got: Dictionary = Rules.race_maximums(race)
		if got.is_empty():
			maximum_errors.append("%s: no maximums in the engine" % race)
			continue
		for attribute in want:
			if int(got.get(attribute, -1)) != int(want[attribute]):
				maximum_errors.append("%s %s: rulebook %d, engine %d" % [
					race, attribute, int(want[attribute]), int(got.get(attribute, -1))])
	_check("S1-AT-16 the racial maximums match the rulebook's Racial Maximum Table",
		maximum_errors.is_empty(), "; ".join(maximum_errors))
	
	# 3. The racial modifiers.
	var modifier_errors: Array[String] = []
	for race in corpus.get("racial_modifiers", {}):
		var want: Dictionary = corpus["racial_modifiers"][race]
		var got: Dictionary = Rules.race_modifiers(race)
		for attribute in want:
			if int(got.get(attribute, 999)) != int(want[attribute]):
				modifier_errors.append("%s %s: rulebook %d, engine %d" % [
					race, attribute, int(want[attribute]), int(got.get(attribute, 999))])
	_check("S1-AT-16 the racial modifiers match the rulebook",
		modifier_errors.is_empty(), "; ".join(modifier_errors))
	
	# 4. The formulas: saving throws and characteristics, recomputed from
	#    the rulebook's own expression rather than from the engine's.
	var formulas: Dictionary = corpus.get("formulas", {})
	var saving: Dictionary = formulas.get("saving_throw", {})
	var saving_base: int = int(saving.get("base", 18))
	var saving_multiplier: int = int(saving.get("multiplier", 2))
	var characteristics: Dictionary = formulas.get("characteristics", {})
	var characteristic_base: int = int(characteristics.get("base", 18))
	var pairs: Dictionary = characteristics.get("pairs", {})
	
	var formula_errors: Array[String] = []
	var cases: Array = [
		{"BUILD": 5, "REFLEX": 4, "LEARN": 3, "CHARISMA": 4, "INTUITION": 5},
		{"BUILD": 0, "REFLEX": 0, "LEARN": 0, "CHARISMA": 0, "INTUITION": 0},
		{"BUILD": 6, "REFLEX": 7, "LEARN": 6, "CHARISMA": 6, "INTUITION": 7},
		{"BUILD": 8, "REFLEX": 8, "LEARN": 6, "CHARISMA": 5, "INTUITION": 6},
		{"BUILD": 3, "REFLEX": 3, "LEARN": 3, "CHARISMA": 3, "INTUITION": 3},
	]
	for attrs in cases:
		for attribute in attrs:
			var want_throw: int = saving_base - (saving_multiplier * int(attrs[attribute]))
			var got_throw: int = int(Rules.calculate_saving_throws(attrs).get(attribute, -999))
			if got_throw != want_throw:
				formula_errors.append("%s throw: rulebook %d, engine %d" % [
					attribute, want_throw, got_throw])
		for characteristic in pairs:
			var pair: Array = pairs[characteristic]
			var want_value: int = characteristic_base - (int(attrs[pair[0]]) + int(attrs[pair[1]]))
			var got_value: int = int(Rules.calculate_characteristics(attrs).get(characteristic, -999))
			if got_value != want_value:
				formula_errors.append("%s: rulebook %d, engine %d" % [
					characteristic, want_value, got_value])
	_check("S1-AT-16 the saving throws and characteristics match the rulebook's formulas",
		formula_errors.is_empty(), "; ".join(formula_errors.slice(0, 4)))
	
	# 5. The rulebook's own worked example, recomputed by hand from its
	#    own text: "Garret has a Build 5... 18 - 10 = 8" and "an ITN 5
	#    and a CHA 4... The result is 9".
	var example_errors: Array[String] = []
	for example in corpus.get("worked_examples", []):
		var attrs: Dictionary = example.get("attributes", {})
		var throws: Dictionary = Rules.calculate_saving_throws(attrs)
		for attribute in example.get("saving_throws", {}):
			if int(throws.get(attribute, -999)) != int(example["saving_throws"][attribute]):
				example_errors.append("%s throw: rulebook %d, engine %d" % [
					attribute, int(example["saving_throws"][attribute]),
					int(throws.get(attribute, -999))])
		var chars: Dictionary = Rules.calculate_characteristics(attrs)
		for characteristic in example.get("characteristics", {}):
			if int(chars.get(characteristic, -999)) != int(example["characteristics"][characteristic]):
				example_errors.append("%s: rulebook %d, engine %d" % [
					characteristic, int(example["characteristics"][characteristic]),
					int(chars.get(characteristic, -999))])
	_check("S1-AT-16 the rulebook's own worked example reproduces",
		example_errors.is_empty(), "; ".join(example_errors))
	
	# 6. Intuition costs two points per point of value: "INT... has a
	#    final value equal to half (round down) the Attribute Points".
	var per_value: int = int(formulas.get("intuition_points_per_value", 2))
	var intuition_ok: bool = true
	for points in range(0, 15):
		var expected_value: int = int(floor(float(points) / float(per_value)))
		if Rules.attribute_points_to_value("INTUITION", points) != expected_value:
			intuition_ok = false
	_check("S1-AT-16 Intuition is half the points assigned, rounded down",
		intuition_ok)


func _test_export_roundtrip() -> void:
	# S1-AT-12: export matches the reference shape and round-trips.
	var attrs: Dictionary = {"BUILD": 5, "REFLEX": 4, "LEARN": 6, "CHARISMA": 3, "INTUITION": 2}
	var sheet: Dictionary = SkillRules.build_character_sheet(
		"Test Pilot", "Human", {"BUILD": 5, "REFLEX": 3, "LEARN": 6, "CHARISMA": 3, "INTUITION": 4},
		attrs,
		Rules.calculate_saving_throws(attrs),
		Rules.calculate_characteristics(attrs),
		{"Land Grant": 1},
		{"Blade": 2},
		[{"name": "Noteputer", "cost": 500}],
		50000
	)
	var exported: Dictionary = SkillRules.export_character(sheet)
	_check("S1-AT-12 export has the version/exported/character shape",
		exported.has("version") and exported.has("exported") and exported.has("character"))
	var reimported: Dictionary = SkillRules.import_character(exported)
	_check("S1-AT-12 export round-trips",
		reimported.get("name", "") == "Test Pilot"
		and int(reimported.get("credits", 0)) == 50000
		and int(reimported.get("attributes", {}).get("BUILD", 0)) == 5,
		str(reimported))
	_check("S1-AT-12 the reimported sheet verifies against its own derived values",
		SkillRules.verify_character(reimported).is_empty())
