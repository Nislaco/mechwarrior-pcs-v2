# Gate Check — m1 (Playable Prototype)

**Date:** 2026-10-20
**Gate:** m1 — Playable Prototype
**Owner:** producer
**Verdict:** **PROCEED**

---

# Summary

The MechWarrior 2e character-creation companion passes the m1 gate. The
rules engine agrees with the **rulebook itself** — not only with the
Python reference the port was written from — and the wizard that drives
it was played end to end by a human without a blocking defect.

The playtest also closed the last gap in the gate criteria. The tester
played all six steps but did not check the exported file by hand, so that
criterion was automated against the primary source instead: the
rulebook's own tables and formulas are parsed out of the OCR'd pages and
diffed against a finished character. That is a stronger guarantee than a
hand check, and it immediately caught an error — in the *checker*, not the
engine (the rulebook lists the Racial Maximum Table's columns as BLD,
REF, **ITN**, LRN, CHA, and the tool had assumed a fixed order).

---

# Gate Criteria & Evidence

| # | Criterion | Evidence | Verdict |
|---|-----------|----------|---------|
| G1 | The rules engine agrees with the rulebook | `verify_rules.gd` → **74 checks, 0 failures**. S1-AT-16 diffs the engine against `src/data/rulebook_corpus.json`, parsed from the book's own Master Character Table (p. 14), Racial Maximum Table (p. 18), Racial Modifiers (p. 18) and formulas (p. 19) | PASS |
| G2 | The rulebook's own worked example reproduces | S1-AT-16 — "Garret has a Build 5… 18−10 = 8" and "ITN 5 and CHA 4… the result is 9" | PASS |
| G3 | The port agrees with the Python reference | S1-AT-14 — 40-case parity corpus generated from `chargen.py` itself, **zero mismatches** | PASS |
| G4 | The wizard drives the engine correctly | `verify_wizard.gd` → **84 checks, 0 failures**, driving the real controls (OptionButtons, SpinBoxes, Buttons), not the draft | PASS |
| G5 | A finished character matches the rulebook | UI-AT-13 — every attribute, saving throw, characteristic and racial modifier on an exported sheet, checked against the rulebook corpus | PASS |
| G6 | The scene loads with no script errors | `godot --headless --path src --quit-after 120` → **0 SCRIPT ERRORs** | PASS |
| G7 | The live game runs with zero runtime errors | MCP `get_editor_errors` after `play_scene` on a fresh editor → **0** warnings or errors in `res://rules/`, `res://ui/`, `res://scenes/` | PASS |
| G8 | The whole flow completes and writes the character | Live MCP drive: all six steps → Finish → `user://character.json` written (`credits=50000`); and with credits unspent, `creditsLeft=50000 nextDisabled=false` and the export keeps the credit pool | PASS |
| G9 | A human played it end to end | `production/playtest/character-creation-playtest-2026-10-20.md` — all six steps, **completed successfully**, no blocking defects, minor cosmetic observations only | PASS |
| G10 | Studio validation green | `codex-game-studio validate` → **1216 PASS / 0 FAIL / 0 WARN**, exit 0 | PASS |
| G11 | Documentation impact recorded | `codex-game-studio docs-impact --base HEAD` → PASS; R-S1-1..R-S1-10, U-S1-1..U-S1-8 and P-BUG-1..P-BUG-6 are recorded in `design/systems/character-creation.md` | PASS |

**11 of 11 criteria PASS.**

---

# Concerns (non-blocking, carried forward)

| Concern | Severity | Owner | Disposition |
|---------|----------|-------|-------------|
| No character name, age, height or weight can be entered — the sheet exports them as empty/zero | Medium | game-designer | Post-gate. The export schema has the fields; the wizard has no inputs for them |
| Initial Edge is not tracked (rulebook p. 19: Edge 1 unless the Extra Edge advantage) | Low | game-designer | Post-gate. Out of the m1 scope, but it is a character-creation value and the export schema has no field for it |
| Flexible Priorities is surfaced as the same 0–4 dropdowns with a "must total 10" validation, rather than a dedicated 10-point budget editor | Medium | game-designer | Post-gate |
| The exported `credits` is the credit pool; the balance is derived, not stored | Low | gameplay-programmer | Documented in R-S1-10. The future combat tracker must derive it |
| The 1e-era sample characters are still 1e-era artifacts | Low | gameplay-programmer | Kept for the combat tracker. A 2e sample set comes from the port and the parity corpus |
| The playtest's cosmetic observations were not itemised | Low | producer | Capture at the next pass; none was reported as a defect |
| No localisation, audio, or theming beyond the built-in Godot theme | Low | ui-programmer | Post-gate |
| Clan Heritage / trueborn Bloodname restrictions, and full skill specializations, are out of scope | Medium | game-designer | Flagged rather than guessed; the rulebook areas are recorded in the design doc |

---

# Defects Found and Fixed During Development (all before this gate)

The three defects the tester reported during this session were all found
by *playing* the build, not by the harness. They are recorded here
because they are the reason the harness was extended.

| ID | Defect | Impact | Fix | Regression Guard |
|----|--------|--------|-----|------------------|
| GATE-D1 | The wizard body was collapsed to **zero height**. A step was a plain `Control` — zero minimum size, and it does not lay out its own children — so the body gave it no height and the `ScrollContainer` inside it clipped every control away. The controls were in the tree, correct, and unreachable | The whole wizard was unusable | Steps are `VBoxContainer`s; the wizard expands them; a step has exactly one scroll container | UI-AT-8 measures the layout of all six steps |
| GATE-D2 | Attribute fields were capped at the **remaining headroom** instead of the racial maximum, so a character could never go past 3 points in an attribute | A character could not be fully spent | The cap is the absolute racial maximum in points, bounded further by the pool | UI-AT-11 |
| GATE-D3 | Nothing had keyboard focus, so Enter and Space went nowhere; and a dropdown only reports a *change*, so a category left at 0 was never recorded | The keyboard was unusable; "Priority 0" was unchooseable and the character could not resolve | Every step focuses the first value control; `LevelOption` answers the arrow keys; all five categories are recorded from the start | UI-AT-2, UI-AT-9, UI-AT-10 |
| GATE-D4 | Saving a character was easy to miss — a thin line of text in the same red as an error message, below the fold | A saved character looked like a failed save | A bordered confirmation above the sheet, a green message, a disabled "Saved" button, and a "New Character" button | UI-AT-12 |

---

# Verdict

**PROCEED.** The m1 gate is met: the rules engine is verified against the
rulebook *and* against the Python reference independently, the wizard
drives it correctly, the whole flow completes and writes a character, and
a human played it end to end without a blocking defect.

The next milestone is production planning for the remaining scope. The
concerns above are the backlog for it.

**Next owner:** producer, to plan the next milestone.
