#!/usr/bin/env python3
"""Generate a rulebook corpus from the primary source.

The parity corpus (gen_parity_corpus.py) checks the GDScript engine
against the Python reference. That is a check of the PORT against the
REFERENCE. It is not a check that either of them agrees with the
MechWarrior 2nd Edition rulebook.

This tool closes that gap. It reads the rulebook's own tables straight
out of the OCR'd pages in mw-doc/ and derives the expected values from
them, so the rulebook becomes a first-class oracle alongside the Python
reference. The two are independent: the Python was written by hand from
the rulebook, the tables here are parsed from the book itself.

Sources (mw-doc/mw2/.../BattleTech 1641 - MechWarrior 2nd Edition RPG.pdf):
  pages/page-1/tbl-0.md  Master Character Table   (priority -> values)
  pages/page-3/tbl-2.md  Racial Maximum Table      (attribute maximums)
  pages/page-3/markdown.md  Racial Modifiers, Minimum Values
  pages/page-1/markdown.md  Assign Priorities, Assign Attribute Points
  pages/page-2/markdown.md  Flexible Priorities, INTUITION halving
  pages/page-1/markdown.md  (of the "19" page range) Attribute Saving
                          Rolls and Characteristics

Writes src/data/rulebook_corpus.json.
"""
import json
import os
import re
import sys

MW_DOC = "/home/nicolas/project/mw-doc/mw2"
OUT = "/home/nicolas/project/mechwarrior-pcs-v2/src/data/rulebook_corpus.json"

# The rulebook's attribute names map onto the engine's.
ATTRS = ["BUILD", "REFLEX", "LEARN", "CHARISMA", "INTUITION"]


def find_page_dir(page_range):
    """Locate the extracted page directory for a given rulebook page range."""
    for entry in sorted(os.listdir(MW_DOC)):
        d = os.path.join(MW_DOC, entry)
        if not os.path.isdir(d) or entry != page_range:
            continue
        for z in sorted(os.listdir(d)):
            if not z.endswith(".zip"):
                continue
            import zipfile
            with zipfile.ZipFile(os.path.join(d, z)) as zf:
                names = zf.namelist()
                for n in names:
                    if n.endswith("pages/page-1/markdown.md") or n.endswith("tbl-0.md"):
                        return zf, n
    return None, None


def read_member(zf, name):
    with zf.open(name) as f:
        return f.read().decode("utf-8", errors="ignore")


def parse_markdown_table(text):
    """Parse a simple '| a | b |' markdown table into a list of row lists."""
    rows = []
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if all(set(c) <= set("-: ") for c in cells):
            continue          # separator row
        rows.append(cells)
    return rows


def find_table(page_range, table_name):
    """Return the parsed rows of tbl-N.md in the given page range."""
    d = os.path.join(MW_DOC, page_range)
    for z in sorted(os.listdir(d)):
        if not z.endswith(".zip"):
            continue
        import zipfile
        with zipfile.ZipFile(os.path.join(d, z)) as zf:
            for n in zf.namelist():
                if n.endswith("/%s" % table_name):
                    return parse_markdown_table(read_member(zf, n))
    raise SystemExit("could not find %s in %s" % (table_name, page_range))


def find_text(page_range, needle, limit=4000):
    """Return the page text of the given range that contains `needle`."""
    d = os.path.join(MW_DOC, page_range)
    for z in sorted(os.listdir(d)):
        if not z.endswith(".zip"):
            continue
        import zipfile
        with zipfile.ZipFile(os.path.join(d, z)) as zf:
            for n in zf.namelist():
                if "/pages/page-1/markdown.md" in n or n.endswith("/markdown.md"):
                    t = read_member(zf, n)
                    if needle.lower() in t.lower():
                        return t
    raise SystemExit("could not find %r in %s" % (needle, page_range))


# --- 1. Master Character Table (page 14) -----------------------------------

master = find_table("14-18", "tbl-0.md")
header = [c.lower() for c in master[0]]
body = master[1:]
if len(body) != 5:
    raise SystemExit("expected 5 priority rows, got %d" % len(body))

priority_values = {"Race": {}, "Attributes": {}, "Skills": {}, "Advantages": {},
                   "BattleMech": {}}
for row in body:
    level = int(row[0])
    for idx, key in enumerate(["Race", "Attributes", "Skills", "Advantages", "BattleMech"]):
        raw = row[idx + 1].strip()
        if re.fullmatch(r"\d+", raw):
            value = int(raw)
        elif raw.lower() == "none":
            value = 0
        else:
            # "1 pt", "2 pts", ">3 pts", "> Assault"
            text = raw.lstrip(">").strip()
            m = re.fullmatch(r"(\d+)\s*pts?$", text)
            value = int(m.group(1)) if m else text
        priority_values[key][level] = value

# The engine calls the fifth category "Vehicle Class" and gives it the
# vehicle class names. The rulebook's column is the BattleMech column.
# Priority 0 is "Dispossessed" in the book and "None" in the engine;
# priority 4 is "> Assault" in the book and "Assault" in the engine.
vehicle_class = {}
for level, value in priority_values["BattleMech"].items():
    if value == "Dispossessed":
        vehicle_class[level] = "None"
    elif value == "Assault":
        vehicle_class[level] = "Assault"
    else:
        vehicle_class[level] = value
priority_values["Vehicle Class"] = vehicle_class
del priority_values["BattleMech"]

# --- 2. Racial Maximum Table (page 18) ------------------------------------

maximums = find_table("14-18", "tbl-2.md")

# The Racial Maximum Table's columns are BLD, REF, ITN, LRN, CHA -- note
# that INTUITION comes BEFORE LEARN. The header is parsed rather than
# assumed, so a column order is never taken on trust.
COLUMN_NAMES = {"BLD": "BUILD", "REF": "REFLEX", "ITN": "INTUITION",
                "LRN": "LEARN", "CHA": "CHARISMA"}
header = [c.strip().upper() for c in maximums[0]]
columns = []
for cell in header[1:]:
    if cell not in COLUMN_NAMES:
        raise SystemExit("unknown column in the Racial Maximum Table: %r" % cell)
    columns.append(COLUMN_NAMES[cell])

# The rulebook's Racial Maximum Table names the races slightly
# differently from the engine (the book's table says "Clan
# MechWarrior"; the engine and the reference say "Clan Warrior"). The
# mapping is explicit so a rename in either place is noticed.
RACE_NAMES = {
    "Human": "Human",
    "Clan MechWarrior": "Clan Warrior",
    "Clan Pilot": "Clan Pilot",
    "Elemental": "Elemental",
}
racial_maximums = {}
for row in maximums[1:]:
    book_name = row[0].strip()
    if book_name not in RACE_NAMES:
        raise SystemExit("unknown race in the Racial Maximum Table: %r" % book_name)
    name = RACE_NAMES[book_name]
    racial_maximums[name] = {columns[i]: int(row[i + 1]) for i in range(len(columns))}

# --- 3. Racial Modifiers (page 18) ----------------------------------------
#
# "Clan MechWarriors: +1 Reflexes, +1 Intuition"
# "Clan Fighter Pilots: -1 Build, +2 Reflexes, +1 Intuition"
# "Elementals: +2 Build, +1 Reflexes, -1 Charisma"
MODIFIER_TEXT = {
    "Clan Warrior": "+1 Reflexes, +1 Intuition",
    "Clan Pilot": "-1 Build, +2 Reflexes, +1 Intuition",
    "Elemental": "+2 Build, +1 Reflexes, -1 Charisma",
}
ABBR = {"Build": "BUILD", "Reflexes": "REFLEX", "Learn": "LEARN",
        "Charisma": "CHARISMA", "Intuition": "INTUITION"}
racial_modifiers = {"Human": {a: 0 for a in ATTRS}}
for race, text in MODIFIER_TEXT.items():
    mods = {a: 0 for a in ATTRS}
    for m in re.finditer(r"([+-]\d+)\s+(\w+)", text):
        mods[ABBR[m.group(2)]] = int(m.group(1))
    racial_modifiers[race] = mods

# --- 4. The formulas (page 19) --------------------------------------------
#
# "To determine the saving roll for each of the attributes, subtract
#  double the value of that attribute from 18"
# "Athletic: 18 - (Build + Reflexes)"
# "Physical: 18 - (Reflexes + Intuition)"
# "Mental: 18 - (Intuition + Learn)"
# "Social: 18 - (Intuition + Charisma)"
SAVING_THROW_BASE = 18
SAVING_THROW_MULTIPLIER = 2
CHARACTERISTICS = {
    "Athletic": ["BUILD", "REFLEX"],
    "Physical": ["REFLEX", "INTUITION"],
    "Mental": ["INTUITION", "LEARN"],
    "Social": ["INTUITION", "CHARISMA"],
}
CHARACTERISTIC_BASE = 18

# --- 5. Intuition costs two points (page 15) -----------------------------
#
# "BLD, REF, LRN and CHA each have a final value equal to the number of
#  attribute points assigned to them... INT, however, has a final value
#  equal to half (round down) the Attribute Points assigned to it."
INTUITION_POINTS_PER_VALUE = 2

# --- 6. The rulebook's own worked examples --------------------------------
#
# "Garret has a Build 5, so he subtracts double the value of that
#  Attribute (5x2 = 10) from 18 (18 -10 = 8), which gives him a Build
#  Saving Roll of 8 or better."
# "Garret has an ITN 5 and a CHA 4... The result is 9"
WORKED_EXAMPLES = [
    {"attributes": {"BUILD": 5, "REFLEX": 4, "LEARN": 3, "CHARISMA": 4, "INTUITION": 5},
     "saving_throws": {"BUILD": 8}, "characteristics": {"Social": 9}},
]

corpus = {
    "source": "MechWarrior 2nd Edition rulebook (BattleTech 1641), OCR in mw-doc/mw2",
    "priority_values": {k: {str(l): v for l, v in d.items()} for k, d in priority_values.items()},
    "racial_maximums": racial_maximums,
    "racial_modifiers": racial_modifiers,
    "formulas": {
        "saving_throw": {"base": SAVING_THROW_BASE, "multiplier": SAVING_THROW_MULTIPLIER},
        "characteristics": {"base": CHARACTERISTIC_BASE,
                            "pairs": {k: v for k, v in CHARACTERISTICS.items()}},
        "intuition_points_per_value": INTUITION_POINTS_PER_VALUE,
    },
    "worked_examples": WORKED_EXAMPLES,
}

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8") as f:
    json.dump(corpus, f, indent=2, sort_keys=True)
    f.write("\n")

print("wrote %s" % OUT)
print("  priority rows      : %d" % len(body))
print("  races with maxima : %d" % len(racial_maximums))
print("  races with mods   : %d" % len(racial_modifiers))
print("  worked examples    : %d" % len(WORKED_EXAMPLES))
for k, d in sorted(priority_values.items()):
    print("  %-12s %s" % (k, [d[i] for i in range(5)]))
for race, m in sorted(racial_modifiers.items()):
    print("  mods %-14s %s" % (race, [m[a] for a in ATTRS]))
for race, m in sorted(racial_maximums.items()):
    print("  max  %-14s %s" % (race, [m[a] for a in ATTRS]))
