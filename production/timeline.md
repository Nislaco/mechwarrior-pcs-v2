# Timeline

- **2026-10-20** — Project scaffolded. Rules engine ported to GDScript and
  verified against the Python reference with zero mismatches over a 40-case
  parity corpus. The character-creation wizard is built and covered by an
  84-check UI harness.
- **2026-10-20** — The rulebook itself became a second oracle: its Master
  Character Table, Racial Maximum Table, racial modifiers and characteristic
  formulas are parsed out of the OCR'd pages and diffed against the engine
  and against a finished exported character.
- **2026-10-20** — **m1 gate: PROCEED.** A human played the wizard end to
  end (all six steps) and completed it successfully; no blocking defects.
  See `production/session-state/m1-gate-check.md`.

# Milestones

- m1: Playable prototype (Week 4) — **PASSED 2026-10-20**
- m2: Production scope (name/appearance inputs, Edge, a proper Flexible
  Priorities editor, localisation, theming) — not started

# Risks

- The character sheet exports a name, age, height and weight, but the wizard
  has no inputs for them, so they export as empty/zero. This is the largest
  gap in the character-creation scope.
- Initial Edge is not tracked, though the rulebook makes it a
  character-creation value.
- Scope may exceed the first validation gate.

# Next Validation Gate

Plan the m2 milestone: close the character-identity gap (name, age, height,
weight) and decide on Initial Edge, then re-run the m1 gate criteria
against the extended character sheet.
