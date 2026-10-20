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
- **Built the character-creation wizard** — the step-by-step flow that mirrors the reference application:
  - `src/ui/character_draft.gd` — the single state object carried across the steps. Pure state; the rules engine is the only thing that interprets it.
  - `src/ui/wizard.gd` — the shell: header, body, message line, footer. Owns navigation and the validation gate, holds no rules.
  - `src/ui/steps/step_{priorities,advantages,attributes,skills,equipment,summary}.gd` — the six steps.
  - `src/scenes/main.gd` / `main.tscn` — the boot scene hosts the wizard.
  - The UI is **built in code**, not authored in a `.tscn`. The previous attempt's `main.tscn` combined `type=` with `instance=`, which Godot cannot parse; a hand-authored scene file for a flow this dynamic is the most likely place for a mistake to hide.
- **Built the UI verification harness** `src/scripts/verify_wizard.gd` — **29 checks, 0 failures**. It drives the *real* controls (OptionButtons, SpinBoxes, Buttons) rather than writing to the draft, so it exercises the same path a player takes.
- **Recorded the UI contract** in `design/systems/character-creation.md` (U-S1-1..U-S1-4): the step model, the six steps and their gates, the architecture, and the UI acceptance criteria.

## Key Findings

- **The shipped sample characters are 1e-era artifacts, not 2e output.** `character_export.py` uses `STRENGTH`/`MEMORY` attributes and `MUSCLES`/`BODY`/`NERVES`/`MIND` characteristics, which contradict the 2e rules in `chargen.py`. They are kept only because the combat tracker consumes them, and are explicitly *not* used as a parity oracle.
- **The parity oracle is now generated from the reference itself.** `tools/gen_parity_corpus.py` imports `chargen.py` and emits `src/data/parity_corpus.json` (40 attribute sets with the reference's own saving throws and characteristics). The GDScript engine re-derives them and the harness diffs — a true cross-check of the port, not a self-consistency check. **Zero mismatches.**
- **Four defects in the Python reference are corrected by the port** (P-BUG-1..5 in the design doc): the `IMPORT` command uppercases the whole line so a path never matches; a stale hardcoded absolute path; the racial-maximum table being mutated in place by the Exceptional Attribute; no enforcement that Flexible Priorities total 10; and the sample-character schema mismatch.
- **The wizard's step model was a decision, not a default.** Step-by-step (mirroring the reference application) was chosen over a single scrollable page and over a two-pane layout with a live summary. A two-pane layout is the better model for a *future* application in which character generation is one feature among several; it is recorded in the design doc as the preferred model for that scope, and moving there later is cheap because the engine is pure and the state is a single object.
- **`SpinBox` clamps its value to `max_value`.** A maximum computed from the *remaining headroom* rather than from the points already allocated silently destroys the player's allocation — BUILD 4 became 2 mid-flow. The maximum is now floored at the points already allocated, and the pool is enforced in the change handler instead. The harness asserts the value survives (UI-AT-4).
- **`queue_free()` is deferred.** The outgoing step stayed in the wizard body (and stayed the first child) until the end of the frame, so a step swap was not immediately visible. The wizard now removes the child from the tree before queueing it free.
- **Driving the UI from an ad-hoc script is unreliable; driving it from the project's own harness is not.** The ad-hoc MCP probe fought stale state (the scene was not restarting between runs) and produced false failures. The deterministic in-process harness became the source of truth for flow coverage, and the MCP bridge was kept for live inspection.

## Verification

- `godot --headless --path src -s res://scripts/verify_rules.gd` → **65 checks, 0 failures**, exit 0.
- `godot --headless --path src -s res://scripts/verify_wizard.gd` → **29 checks, 0 failures**, exit 0.
- `godot --headless --path src --quit-after 90` → exit 0, 0 script errors.
- `codex-game-studio validate` → **1216 PASS / 0 FAIL / 0 WARN**, exit 0.
- Godot MCP bridge: connects, reports the project by name and path, live scene tree and runtime script inspection both work. Live inspection confirmed all six wizard steps render and navigate with exactly one step in the body, and that **no script warnings or errors remain in `res://rules/`, `res://ui/`, or `res://scenes/`** (the only remaining warnings come from the MCP plugin's own generated scripts).

## Remaining Risks

- The wizard has not been **played by a human** yet — it is verified by harness and by live inspection, but not by a person. That is the m1 gate's remaining playtest item.
- Skill-package eligibility in the UI needs a decision on which packages to surface when several are affordable.
- The 1e-era sample characters will need migration or a 2e sample set for the (future) combat tracker.
- Rulebook areas left out of scope for m1 and flagged rather than guessed: Clan Heritage / trueborn Bloodname restrictions, and the full skill specializations.
- `codex-game-studio init --force-refresh` **wipes `project.godot`** back to a minimal file, losing `run/main_scene` and the `godot_mcp` plugin enable. Do not run it on an already-configured project.

## Documentation Impact

- Decision: updated
- Reason: a functional change was made — the character-creation wizard UI, the UI harness, and the new UI contract are all new, and the wizard's step model is a design decision that the owning document now records. The rules contract (R-S1-1..R-S1-10) is unchanged; the UI contract (U-S1-1..U-S1-4) was added alongside it, along with the UI acceptance criteria and the reason the two-pane model is deferred to a later scope.
- Documents: design/systems/character-creation.md, production/session-state/active.md
