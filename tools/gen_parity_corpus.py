#!/usr/bin/env python3
"""Generate a parity corpus from the Python reference.

The sample characters shipped in data/characters/ are 1e-era artifacts
(STRENGTH/MEMORY attributes, MUSCLES/BODY characteristics) and are NOT
output of the 2e chargen.py we are porting. So the parity corpus is
generated directly from the reference's own derived-value functions.

Writes src/data/parity_corpus.json: a set of attribute sets and the
saving throws / characteristics the reference computes for them. The
GDScript engine re-derives the same values and the harness diffs them.
"""
import json
import random
import sys

sys.path.insert(0, "/home/nicolas/project/mw-depo/mw-script")
import chargen  # noqa: E402

OUT = "/home/nicolas/project/mechwarrior-pcs-v2/src/data/parity_corpus.json"

random.seed(20261020)

cases = []
seen = set()

# A spread of hand-picked attribute sets, including the extremes.
picked = [
    {"BUILD": 6, "REFLEX": 6, "LEARN": 6, "CHARISMA": 6, "INTUITION": 6},
    {"BUILD": 0, "REFLEX": 0, "LEARN": 0, "CHARISMA": 0, "INTUITION": 0},
    {"BUILD": 5, "REFLEX": 4, "LEARN": 3, "CHARISMA": 2, "INTUITION": 1},
    {"BUILD": 2, "REFLEX": 8, "LEARN": 6, "CHARISMA": 1, "INTUITION": 7},
    {"BUILD": 8, "REFLEX": 7, "LEARN": 6, "CHARISMA": 5, "INTUITION": 6},
    {"BUILD": 4, "REFLEX": 5, "LEARN": 4, "CHARISMA": 3, "INTUITION": 2},
]
for attrs in picked:
    seen.add(tuple(sorted(attrs.items())))

# Plus a random spread, so the corpus is not all hand-picked corners.
random.seed(20261020)
while len(picked) < 40:
    attrs = {a: random.randint(0, 8) for a in
             ["BUILD", "REFLEX", "LEARN", "CHARISMA", "INTUITION"]}
    key = tuple(sorted(attrs.items()))
    if key in seen:
        continue
    seen.add(key)
    picked.append(attrs)

for attrs in picked:
    throws = chargen.calculate_saving_throws(attrs)
    chars = chargen.calculate_characteristics(attrs)
    cases.append({
        "attributes": attrs,
        "saving_throws": throws,
        "characteristics": chars,
    })

with open(OUT, "w") as f:
    json.dump({"generated_from": "mw-depo/mw-script/chargen.py", "cases": cases}, f, indent=2, sort_keys=True)

print(f"Wrote {len(cases)} parity cases -> {OUT}")
print("Sample:", json.dumps(cases[0], sort_keys=True))
