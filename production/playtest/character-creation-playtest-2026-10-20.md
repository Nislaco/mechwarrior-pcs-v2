# Human Playtest — Character Creation Wizard (m1)

**Date:** 2026-10-20
**Build:** `mechwarrior-pcs-v2` @ `27d2d80` (plus the rulebook cross-check added in the same change)
**Tester:** the project owner (the person who reported the three usability defects)
**Result:** **PASS** — no blocking defects

---

## What was played

The tester played the character-creation wizard end to end, through all six
steps: **Priorities → Advantages → Attributes → Skills → Equipment →
Character Sheet**, and completed the creation.

The tester had already driven the build through the usability defects
reported earlier in this session (the collapsed body, the attribute cap,
and the invisible save confirmation), so the playtest ran against a build
that had those fixed.

## What the tester reported

| Question | Answer |
|----------|--------|
| Coverage | All six steps. **The exported file was not checked by hand.** |
| Observations | Minor cosmetic things only. No functional problems, nothing that blocked completion. |
| Outcome | Completed successfully. |

The tester did not itemise the cosmetic observations, so they are not
enumerated below. Nothing in them was reported as a defect.

## The one gap this leaves, and how it was closed

The m1 gate asked for the exported character to be *checked against the
rulebook by hand*. The tester did not do that, so the criterion was not
satisfied by the playtest.

Rather than leave it open, the check was automated against the **primary
source** — the rulebook itself — which is a stronger guarantee than a hand
check:

- `tools/gen_rulebook_corpus.py` parses the rulebook's own tables
  straight out of the OCR'd pages in `mw-doc/mw2/`: the **Master Character
  Table** (p. 14), the **Racial Maximum Table** (p. 18), the **Racial
  Modifiers** (p. 18), and the **saving throw and characteristic
  formulas** (p. 19). It writes `src/data/rulebook_corpus.json`.
- `S1-AT-16` in `src/scripts/verify_rules.gd` diffs the engine against
  that corpus: the priority table, the racial maximums, the racial
  modifiers, the saving throws, the characteristics, Intuition's
  two-points-per-value rule, and the rulebook's **own worked example**
  (Garett: Build 5 → saving roll 8; ITN 5 + CHA 4 → Social 9).
- `UI-AT-13` in `src/scripts/verify_wizard.gd` checks a **finished exported
  character** — every attribute, saving throw, characteristic and racial
  modifier on the sheet — against the same rulebook corpus.

This makes the rulebook an oracle in its own right, independent of the
Python reference the port was written from. The two oracles are
independent: the Python was hand-written from the book, the corpus is
parsed from the book.

**It immediately earned its place.** The first run of `S1-AT-16` failed,
and the cause was the *checker*, not the engine: the rulebook's Racial
Maximum Table lists its columns **BLD, REF, ITN, LRN, CHA** — Intuition
before Learn — and the tool had assumed a fixed order. The engine's data
was correct all along. The tool now parses the table header instead of
assuming an order.

## Evidence

| Evidence | Result |
|----------|--------|
| `verify_rules.gd` | **74 checks, 0 failures** (7 of them the new rulebook cross-check) |
| `verify_wizard.gd` | **84 checks, 0 failures** (4 of them the new exported-sheet cross-check) |
| Headless scene load | 0 script errors |
| Live game, MCP-driven | 0 runtime errors or warnings in `res://rules/`, `res://ui/`, `res://scenes/` |
| `codex-game-studio validate` | **1216 PASS / 0 FAIL / 0 WARN** |
| `codex-game-studio docs-impact` | PASS |

## Defects found during this playtest

**None.** The tester reported minor cosmetic observations only, and
completed the creation successfully.

## Concerns carried forward (non-blocking)

| Concern | Severity | Owner | Disposition |
|---------|----------|-------|-------------|
| The cosmetic observations from the playtest were not itemised | Low | producer | Capture them at the next pass; they are not defects |
| The Flexible Priorities rule is surfaced as the same 0–4 dropdowns with a "must total 10" validation, rather than a dedicated 10-point budget editor | Medium | game-designer | Post-gate |
| No character name, age, height or weight can be entered — the sheet exports zeros | Medium | game-designer | Post-gate: the export schema has the fields, the wizard has no inputs for them |
| **Initial Edge is not tracked.** The rulebook (p. 19) says a character starts with Edge 1 unless they have the Extra Edge advantage | Low | game-designer | Post-gate: out of the m1 scope, but it is a character-creation value and the export schema has no field for it |
| The exported `credits` is the credit pool; the balance is derived, not stored | Low | gameplay-programmer | Documented in R-S1-10; the future combat tracker must derive it |
| The 1e-era sample characters are still 1e-era | Low | gameplay-programmer | Kept for the combat tracker; a 2e sample set comes from the port |
| No localisation, audio, or theming beyond the built-in Godot theme | Low | ui-programmer | Post-gate |
