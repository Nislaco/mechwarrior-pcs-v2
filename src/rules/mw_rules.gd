extends RefCounted

## MechWarrior 2e character-creation rules engine.
##
## Pure logic: no UI, no scene tree, no autoloads. Everything here is
## deterministic and side-effect free, so it can be driven identically by
## the wizard UI and by the verification harness.
##
## The behavioural reference is the Python implementation at
## mw-depo/mw-script/chargen.py. Where that reference is known to be wrong,
## the corrected behaviour is implemented here and recorded in
## design/systems/character-creation.md (defects P-BUG-1..P-BUG-4).
##
## Rule contract: design/systems/character-creation.md (R-S1-1..R-S1-10).

const CATEGORIES: Array[String] = ["Race", "Attributes", "Skills", "Advantages", "Vehicle Class"]

const ATTRIBUTES: Array[String] = ["BUILD", "REFLEX", "LEARN", "CHARISMA", "INTUITION"]

const VEHICLE_CLASSES: Array[String] = ["None", "Light", "Medium", "Heavy", "Assault"]

## Priority level -> value, per category. R-S1-2.
const PRIORITY_VALUES: Dictionary = {
	"Race": {0: "Human", 1: "Human", 2: "Clan Warrior", 3: "Clan Pilot", 4: "Elemental"},
	"Attributes": {0: 18, 1: 21, 2: 24, 3: 27, 4: 30},
	"Skills": {0: 8, 1: 12, 2: 16, 3: 20, 4: 24},
	"Advantages": {0: 0, 1: 1, 2: 2, 3: 3, 4: 4},
	"Vehicle Class": {0: "None", 1: "Light", 2: "Medium", 3: "Heavy", 4: "Assault"},
}

## Racial modifiers and maximums. R-S1-3.
## Returned as fresh copies so a caller's Exceptional-Attribute bonus can
## never leak into the shared table (defect P-BUG-3).
const RACE_DATA: Dictionary = {
	"Human": {
		"modifiers": {"BUILD": 0, "REFLEX": 0, "LEARN": 0, "CHARISMA": 0, "INTUITION": 0},
		"maximums": {"BUILD": 6, "REFLEX": 6, "LEARN": 6, "CHARISMA": 6, "INTUITION": 6},
	},
	"Clan Warrior": {
		"modifiers": {"BUILD": 0, "REFLEX": 1, "LEARN": 0, "CHARISMA": 0, "INTUITION": 1},
		"maximums": {"BUILD": 6, "REFLEX": 7, "LEARN": 6, "CHARISMA": 6, "INTUITION": 7},
	},
	"Clan Pilot": {
		"modifiers": {"BUILD": -1, "REFLEX": 2, "LEARN": 0, "CHARISMA": 0, "INTUITION": 1},
		"maximums": {"BUILD": 5, "REFLEX": 8, "LEARN": 6, "CHARISMA": 6, "INTUITION": 7},
	},
	"Elemental": {
		"modifiers": {"BUILD": 2, "REFLEX": 1, "LEARN": 0, "CHARISMA": -1, "INTUITION": 0},
		"maximums": {"BUILD": 8, "REFLEX": 7, "LEARN": 6, "CHARISMA": 5, "INTUITION": 6},
	},
}

## Advantage table. R-S1-4.
## cost: int (fixed) or Array[int] (variable cost tiers).
## family: at most one tier per family may be purchased.
const ADVANTAGES: Dictionary = {
	"Ambidextrous": {"cost": 1},
	"Bloodname": {"cost": 3, "clan_only": true},
	"Combat Sense": {"cost": 2},
	"Contact": {"cost": [1, 2, 3]},
	"DropShip": {"cost": [1, 2, 3], "requires_vehicle_priority": 4},
	"Enhanced Imaging (EI) Neural Implant": {"cost": 1, "clan_only": true},
	"Exceptional Attribute": {"cost": 2, "human_only": true},
	"Extra Edge": {"cost": [1, 2, 3]},
	"Land Grant": {"cost": 1},
	"Natural Aptitude (Combat Skill)": {"cost": 3},
	"Natural Aptitude (Non-Combat Skill)": {"cost": 2},
	"Reputation": {"cost": 1},
	"Sixth Sense": {"cost": 2},
	"Title (Knight)": {"cost": 1, "family": "Title"},
	"Title (Baronet)": {"cost": 2, "family": "Title"},
	"Title (Baron)": {"cost": 3, "family": "Title"},
	"Toughness": {"cost": 2},
	"Wealth (5,000 C-Bills)": {"cost": 1, "family": "Wealth"},
	"Wealth (50,000 C-Bills)": {"cost": 2, "family": "Wealth"},
	"Wealth (500,000 C-Bills)": {"cost": 3, "family": "Wealth"},
	"Well-Equipped (1,000 C-Bills)": {"cost": 1, "family": "Well-Equipped"},
	"Well-Equipped (5,000 C-Bills)": {"cost": 2, "family": "Well-Equipped"},
	"Well-Equipped (25,000 C-Bills)": {"cost": 3, "family": "Well-Equipped"},
	"Well-Connected": {"cost": [1, 2, 3]},
}

## Bloodname and the EI neural implant are Clan/Elemental only (Companion pp. 11-13).
const CLAN_ONLY_ADVANTAGES: Array[String] = ["Bloodname", "Enhanced Imaging (EI) Neural Implant"]

## Characteristic formulas. R-S1-7.
const CHARACTERISTIC_BASE: int = 18

## Default starting credits.
const DEFAULT_CREDITS: int = 50000

## Service-eligibility minimums (advisory, not blocking). R-S1-5.
const SERVICE_MIN_INNER_SPHERE: int = 4
const SERVICE_MIN_PRIMARY_CLAN: int = 5


# ---------------------------------------------------------------------------
# R-S1-1 / R-S1-2 — priorities
# ---------------------------------------------------------------------------

## Validate a standard priority assignment: each level 0-4 used exactly once.
## Returns {ok: bool, error: String}.
static func validate_standard_priorities(priorities: Dictionary) -> Dictionary:
	var seen: Dictionary = {}
	for category in CATEGORIES:
		if not priorities.has(category):
			return {"ok": false, "error": "No priority assigned for %s." % category}
		var level: int = int(priorities[category])
		if level < 0 or level > 4:
			return {"ok": false, "error": "Priority for %s must be between 0 and 4." % category}
		if seen.has(level):
			return {"ok": false, "error": "Priority %d is already assigned to %s. Choose a different one." % [level, seen[level]]}
		seen[level] = category
	if seen.size() != 5:
		return {"ok": false, "error": "All five priority levels (0-4) must be assigned."}
	return {"ok": true, "error": ""}


## The range of levels still legal for a category under Flexible Priorities.
## `pool` is the remaining Character Points; `remaining` is how many
## categories are still unassigned (including this one).
## Bounds the entry so the pool can always be fully spent.
static func flexible_priority_range(pool: int, remaining: int) -> Vector2i:
	var min_value: int = clampi(pool - 4 * (remaining - 1), 0, 4)
	var max_value: int = clampi(pool, 0, 4)
	# The pool can always be spent, so the bounds never cross.
	if min_value > max_value:
		min_value = max_value
	return Vector2i(min_value, max_value)


## Validate a flexible priority assignment: each level 0-4, the five
## totalling exactly 10. R-S1-1.
static func validate_flexible_priorities(priorities: Dictionary) -> Dictionary:
	var total: int = 0
	for category in CATEGORIES:
		if not priorities.has(category):
			return {"ok": false, "error": "No priority assigned for %s." % category}
		var level: int = int(priorities[category])
		if level < 0 or level > 4:
			return {"ok": false, "error": "Priority for %s must be between 0 and 4." % category}
		total += level
	if total != 10:
		return {"ok": false, "error": "The five priority levels must total exactly 10 (currently %d)." % total}
	return {"ok": true, "error": ""}


## Resolve a priority assignment into the concrete values it grants.
## R-S1-2. Returns {race, attribute_points, skill_points, advantage_points, vehicle_class}.
static func resolve_priorities(priorities: Dictionary) -> Dictionary:
	return {
		"race": str(PRIORITY_VALUES["Race"][int(priorities["Race"])]),
		"attribute_points": int(PRIORITY_VALUES["Attributes"][int(priorities["Attributes"])]),
		"skill_points": int(PRIORITY_VALUES["Skills"][int(priorities["Skills"])]),
		"advantage_points": int(PRIORITY_VALUES["Advantages"][int(priorities["Advantages"])]),
		"vehicle_class": str(PRIORITY_VALUES["Vehicle Class"][int(priorities["Vehicle Class"])]),
		"vehicle_priority": int(priorities["Vehicle Class"]),
	}


# ---------------------------------------------------------------------------
# R-S1-3 — races
# ---------------------------------------------------------------------------

## Racial modifiers for a race. Always a fresh copy (P-BUG-3).
static func race_modifiers(race: String) -> Dictionary:
	if not RACE_DATA.has(race):
		return {}
	return (RACE_DATA[race]["modifiers"] as Dictionary).duplicate(true)


## Racial maximums for a race. Always a fresh copy.
static func race_maximums(race: String) -> Dictionary:
	if not RACE_DATA.has(race):
		return {}
	return (RACE_DATA[race]["maximums"] as Dictionary).duplicate(true)


# ---------------------------------------------------------------------------
# R-S1-4 — advantages
# ---------------------------------------------------------------------------

## Which advantages are purchasable by this race, and at what cost.
## `points` is the remaining Advantage Points. `vehicle_priority` is 0-4.
## Returns {name: cost} for currently-affordable options.
static func available_advantages(race: String, points: int, vehicle_priority: int, purchased: Dictionary) -> Dictionary:
	var available: Dictionary = {}
	for name in ADVANTAGES:
		if purchased.has(name):
			continue
		var spec: Dictionary = ADVANTAGES[name]
		# Race restrictions.
		if bool(spec.get("clan_only", false)) and race == "Human":
			continue
		if bool(spec.get("human_only", false)) and race != "Human":
			continue
		# Elementals already have Toughness for free.
		if name == "Toughness" and race == "Elemental":
			continue
		# DropShip needs Vehicle Class priority 4.
		if spec.has("requires_vehicle_priority") and vehicle_priority != int(spec["requires_vehicle_priority"]):
			continue
		# Tiered family: one tier only.
		if spec.has("family") and _family_purchased(spec["family"], purchased):
			continue
		# Cost must be affordable.
		var cost: int = _cheapest_affordable_cost(spec["cost"], points)
		if cost > 0:
			available[name] = cost
	return available


static func _family_purchased(family: String, purchased: Dictionary) -> bool:
	for name in purchased:
		if not ADVANTAGES.has(name):
			continue
		if str(ADVANTAGES[name].get("family", "")) == family:
			return true
	return false


## The cheapest cost tier that fits in `points`, or 0 if none do.
static func _cheapest_affordable_cost(cost_spec, points: int) -> int:
	if cost_spec is Array:
		var best: int = 0
		for c in cost_spec:
			if int(c) <= points and (best == 0 or int(c) < best):
				best = int(c)
		return best
	return int(cost_spec) if int(cost_spec) <= points else 0


## The cost tiers of an advantage, for the UI. R-S1-4.
static func advantage_cost_tiers(name: String) -> Array[int]:
	if not ADVANTAGES.has(name):
		return []
	var cost_spec = ADVANTAGES[name]["cost"]
	if cost_spec is Array:
		var tiers: Array[int] = []
		for c in cost_spec:
			tiers.append(int(c))
		return tiers
	return [int(cost_spec)]


## The race of a purchased advantage name -> the family it belongs to ("" if none).
static func advantage_family(name: String) -> String:
	if not ADVANTAGES.has(name):
		return ""
	return str(ADVANTAGES[name].get("family", ""))


# ---------------------------------------------------------------------------
# R-S1-5 — attribute distribution
# ---------------------------------------------------------------------------

## The value an attribute's points buy, before the racial modifier.
## INTUITION is special: value = floor(points / 2). R-S1-5.
static func attribute_points_to_value(attribute: String, points: int) -> int:
	if attribute == "INTUITION":
		return points / 2
	return points


## The final value of an attribute: points->value, plus racial modifier.
static func attribute_final_value(attribute: String, points: int, modifiers: Dictionary) -> int:
	return attribute_points_to_value(attribute, points) + int(modifiers.get(attribute, 0))


## How many more points may be put into an attribute right now.
## For INTUITION this is bounded on POINTS (not value) so the final score
## stays at or below the racial maximum. R-S1-5.
static func attribute_points_headroom(attribute: String, spent_points: int, maximums: Dictionary, modifiers: Dictionary) -> int:
	var maximum: int = int(maximums.get(attribute, 0))
	var modifier: int = int(modifiers.get(attribute, 0))
	var headroom: int
	if attribute == "INTUITION":
		# value = floor(points/2) + modifier <= maximum
		#  => points <= 2 * (maximum - modifier)
		headroom = 2 * (maximum - modifier) - spent_points
	else:
		headroom = maximum - (spent_points + modifier)
	return maxi(0, headroom)


## Distribute attribute points and return the final attribute values.
## `spent` is a map attribute -> points already allocated.
## R-S1-5.
static func final_attributes(race: String, spent: Dictionary, exceptional_attribute: String = "") -> Dictionary:
	var modifiers: Dictionary = race_modifiers(race)
	var maximums: Dictionary = race_maximums(race)
	# P-BUG-3: the Exceptional bonus applies to a COPY, never the shared table.
	if not exceptional_attribute.is_empty() and maximums.has(exceptional_attribute):
		maximums[exceptional_attribute] = int(maximums[exceptional_attribute]) + 1
	var final: Dictionary = {}
	for attribute in ATTRIBUTES:
		final[attribute] = attribute_final_value(attribute, int(spent.get(attribute, 0)), modifiers)
	return final


# ---------------------------------------------------------------------------
# R-S1-6 / R-S1-7 — derived values
# ---------------------------------------------------------------------------

## Saving throws: 18 - (2 * attribute value). R-S1-6.
static func calculate_saving_throws(attributes: Dictionary) -> Dictionary:
	var throws: Dictionary = {}
	for attribute in ATTRIBUTES:
		throws[attribute] = CHARACTERISTIC_BASE - (2 * int(attributes.get(attribute, 0)))
	return throws


## Characteristics. R-S1-7.
static func calculate_characteristics(attributes: Dictionary) -> Dictionary:
	var build: int = int(attributes.get("BUILD", 0))
	var reflex: int = int(attributes.get("REFLEX", 0))
	var learn: int = int(attributes.get("LEARN", 0))
	var charisma: int = int(attributes.get("CHARISMA", 0))
	var intuition: int = int(attributes.get("INTUITION", 0))
	return {
		"Athletic": CHARACTERISTIC_BASE - (build + reflex),
		"Physical": CHARACTERISTIC_BASE - (reflex + intuition),
		"Mental": CHARACTERISTIC_BASE - (intuition + learn),
		"Social": CHARACTERISTIC_BASE - (intuition + charisma),
	}


## Advisory service-eligibility flags. R-S1-5.
## Returns an array of human-readable notes; empty means fully eligible.
static func service_eligibility_notes(race: String, attributes: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var reflex: int = int(attributes.get("REFLEX", 0))
	var intuition: int = int(attributes.get("INTUITION", 0))
	if race == "Clan Warrior":
		if reflex < SERVICE_MIN_PRIMARY_CLAN or intuition < SERVICE_MIN_PRIMARY_CLAN:
			notes.append("Primary Clan MechWarriors normally need Reflexes or Intuition of at least %d (you have %d / %d)." % [SERVICE_MIN_PRIMARY_CLAN, reflex, intuition])
	elif reflex < SERVICE_MIN_INNER_SPHERE or intuition < SERVICE_MIN_INNER_SPHERE:
		notes.append("Service with the Great Houses or Clans normally needs Reflexes or Intuition of at least %d (you have %d / %d)." % [SERVICE_MIN_INNER_SPHERE, reflex, intuition])
	return notes
