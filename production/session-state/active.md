# Active Session State

## Scope

- **Created the project** `mechwarrior-pcs-v2` — a MechWarrior 2nd Edition personal-scale **character creation** companion (m1 scope: character creation only; the combat tracker, hex map, and creature gen are later milestones).
- **Installed the Godot MCP bridge** at `src/addons/godot_mcp` with the headless-safe GUI guard patched, and enabled it in `project.godot`. This is the piece that was missing from the previous attempt (`mw-depo/mw-app/Godot`) and blocked all GUI diagnosis.
- **Fixed the boot scene** properly: `run/main_scene` is declared under `[application]` in `project.godot` (the previous attempt used the non-standard `config/main_scene`, so Godot reported "no main scene defined"), and `src/scenes/main.tscn` uses the valid `script =` form. The previous attempt's `main.tscn` combined `type=` with `instance=`, which Godot cannot parse — the project never launched.
- **Mined the data** from `mw-depo/mw-script` (the working Python reference): equipment tables (`weapons/armor/electronics/medical/gear`), the 69-skill list, and the 3 sample characters. Extracted the 54 skill packages directly out of `chargen.py` with `tools/extract_skill_packages.py` rather than hand-transcribing them.
- **Ported the character-creation rules to GDScript** as a pure, UI-free engine:
  - `src/rules/mw_rules.gd` — priorities (standard + flexible), racial modifiers/maxima, advantages, attribute distribution, saving throws, characteristics, service-eligibility notes.
  - `src/rules/mw_rules_skills.gd` — skill packages (fixed + flexible), skill-level caps, equipment archetypes, combat-stat derivation, character sheet build/export/import/verify.
- **Authored the rules contract** at `design/systems/character-creation.md` (R-S1-1..R-S1-10, acceptance criteria, five known defects in the Python reference that the port corrects, and the rejected prior art).
- **Built the verification harness** `src/scripts/verify_rules.gd` — **65 checks, 0 failures**.

## Key Findings

- **The shipped sample characters are 1e-era artifacts, not 2e output.** `character_export.py` uses `STRENGTH`/`MEMORY` attributes and `MUSCLES`/`BODY`/`NERVES`/`MIND` characteristics, which contradict the 2e rules in `chargen.py`. They are kept only because the combat tracker consumes them, and are explicitly *not* used as a parity oracle.
- **The parity oracle is now generated from the reference itself.** `tools/gen_parity_corpus.py` imports `chargen.py` and emits `src/data/parity_corpus.json` (40 attribute sets with the reference's own saving throws and characteristics). The GDScript engine re-derives them and the harness diffs — a true cross-check of the port, not a self-consistency check. **Zero mismatches.**
- **Four defects in the Python reference are corrected by the port** (P-BUG-1..5 in the design doc): the `IMPORT` command uppercases the whole line so a path never matches; a stale hardcoded absolute path; the racial-maximum table being mutated in place by the Exceptional Attribute; no enforcement that Flexible Priorities total 10; and the sample-character schema mismatch.

## Verification

- `godot --headless --path src -s res://scripts/verify_rules.gd` → **65 checks, 0 failures**, exit 0.
- `godot --headless --path src --quit-after 90` → exit 0, 0 script errors.
- `codex-game-studio validate` → **1216 PASS / 0 FAIL / 0 WARN**, exit 0.
- Godot MCP bridge: connects, reports the project by name and path, live scene tree and runtime script inspection both work.

## Remaining Risks

- The wizard UI is not built yet — the engine is complete and verified, but nothing drives it.
- Skill-package eligibility in the UI needs a decision on which packages to surface when several are affordable.
- The 1e-era sample characters will need migration or a 2e sample set for the (future) combat tracker.
- Rulebook areas left out of scope for m1 and flagged rather than guessed: Clan Heritage / trueborn Bloodname restrictions, and the full skill specializations.

## Documentation Impact

- Decision: updated
- Reason: a functional change was made — the rules engine, the harness, the data files, and the project scaffolding are new. The owning design document (`design/systems/character-creation.md`) was authored in the same change and records the rules, the acceptance criteria, the corrected reference behaviours, and the parity method.
- Documents: design/systems/character-creation.md
