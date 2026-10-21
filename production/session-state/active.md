# Active Session State

## Milestone Status

- **m1 gate: PROCEED** — see `production/session-state/m1-gate-check.md` (11/11 criteria; 74 rules checks, 84 UI checks, 0 failures; human playtest PASS).
- **Human playtest: PASS** — see `production/playtest/character-creation-playtest-2026-10-20.md` (all six steps, completed successfully, no blocking defects).

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
- **Built the UI verification harness** `src/scripts/verify_wizard.gd` — **59 checks, 0 failures**. It drives the *real* controls (OptionButtons, SpinBoxes, Buttons) rather than writing to the draft, so it exercises the same path a player takes.
- **Recorded the UI contract** in `design/systems/character-creation.md` (U-S1-1..U-S1-7): the step model, the six steps and their gates, the architecture, the layout contract, the input contract, and the UI acceptance criteria.
- **Ran the human playtest** and **passed the m1 gate** — `production/playtest/character-creation-playtest-2026-10-20.md` and `production/session-state/m1-gate-check.md`.
- **Made the rulebook a first-class oracle.** `tools/gen_rulebook_corpus.py` parses the rulebook's own tables and formulas out of the OCR'd pages in `mw-doc/mw2/` — the Master Character Table (p. 14), the Racial Maximum Table (p. 18), the Racial Modifiers (p. 18) and the saving-throw and characteristic formulas (p. 19) — into `src/data/rulebook_corpus.json`. `S1-AT-16` diffs the engine against it, and `UI-AT-13` checks a finished exported character against it. Until this, the only oracle was the Python reference the port was written from, so nothing proved the *reference* agreed with the book.

## Key Findings

- **The wizard's body was collapsed to zero height, so nothing in it could be seen or clicked.** A step was a plain `Control`: it has a zero minimum size and does not lay out its own children, so the body gave it no height and the `ScrollContainer` inside it clipped every control away. The controls were all present and correct in the tree — they were simply not on screen. Steps are now `VBoxContainer`s and the wizard expands them. (U-S1-5)
- **A `ScrollContainer` nested inside another one has a minimum height of zero** — it can always scroll — so the inner one collapses and takes its content with it. The skills step had one; a step now has exactly one scroll container.
- **Nothing had keyboard focus**, so Enter and Space went nowhere. Every step now grabs focus for the first *value* control — the first dropdown, spin box or text field — rather than the first focusable control, which on the priorities step is the "Flexible Priorities" checkbox. (U-S1-6)
- **A dropdown only reports a change**, so a category the player left alone — or one set to the value it already shows — was never recorded. "Priority 0" could not be chosen, and since the assignment needs all five categories, a single untouched row left the whole character unresolved. The priorities step now records all five categories from the start.
- **A field that holds a total must be bounded by the absolute cap, not by the headroom.** The attribute fields were capped at `racial maximum - already spent`, so a character whose racial maximum was 6 could never go past 3 once 3 points were in: the remaining 3 points were unreachable and the field simply stopped at 3. The cap is now the racial maximum in points (`maximum - modifier`, and `2 * (maximum - modifier)` for INTUITION, which costs two points per point of value), bounded further by the pool. This matches the reference implementation, which asks for an *increment* bounded the same way. (U-S1-7)
- **The rulebook's Racial Maximum Table lists its columns BLD, REF, ITN, LRN, CHA** — Intuition before Learn. The first run of the rulebook cross-check failed on exactly that, and the fault was in the *checker*: the tool had assumed a fixed column order. The engine's data was correct. The tool now parses the table header. A cross-check earns its place the moment it finds something.
- **The exported `credits` is the character's credit POOL, not the balance left after the equipment.** This is the reference schema's meaning, and the reference's own sample characters are the evidence: each stores a fixed pool (5,000 / 25,000 / 50,000) that does not change with what the character carries, and `john_star` carries 22,810 of equipment against a pool of 5,000 — a remaining balance could not be negative. The port had been exporting the *leftover* in the `credits` field, which disagreed with every reference character; it now exports the pool, and the balance is derived (pool − equipment cost). (R-S1-9, R-S1-10)
- **The reference's credit handling is entirely unenforced** — `credits` is never initialised in `chargen.py`'s `main()`, so the equipment step raises `UnboundLocalError`, and `purchase_equipment` never checks a budget anyway. Recorded as P-BUG-6.
- **`SpinBox` cannot take focus** — its `focus_mode` is `FOCUS_NONE` and the player types into the line edit inside it. Focusing the SpinBox warned and did nothing, so the wizard now focuses the line edit. (U-S1-6)
- **Saving was too easy to miss.** The character is written and the wizard stays open, so the only feedback was a thin line of text in the *same red as an error message*, the button still said "Finish", and there was no way to start another character without restarting the app. The sheet now shows a bordered confirmation **above** the character sheet (below the fold it was invisible), the message line turns green, Finish becomes a disabled **Saved** button, and a **New Character** button appears. (U-S1-6, UI-AT-12)
- **A plain `OptionButton` only changes value through its popup**, and a popup opened with the mouse starts its highlight on "no item", so the first arrow press lands on the first entry instead of moving one step from the current value. `src/ui/level_option.gd` makes a focused dropdown answer the arrow keys directly.
- **The shipped sample characters are 1e-era artifacts, not 2e output.** `character_export.py` uses `STRENGTH`/`MEMORY` attributes and `MUSCLES`/`BODY`/`NERVES`/`MIND` characteristics, which contradict the 2e rules in `chargen.py`. They are kept only because the combat tracker consumes them, and are explicitly *not* used as a parity oracle.
- **The parity oracle is now generated from the reference itself.** `tools/gen_parity_corpus.py` imports `chargen.py` and emits `src/data/parity_corpus.json` (40 attribute sets with the reference's own saving throws and characteristics). The GDScript engine re-derives them and the harness diffs — a true cross-check of the port, not a self-consistency check. **Zero mismatches.**
- **Four defects in the Python reference are corrected by the port** (P-BUG-1..5 in the design doc): the `IMPORT` command uppercases the whole line so a path never matches; a stale hardcoded absolute path; the racial-maximum table being mutated in place by the Exceptional Attribute; no enforcement that Flexible Priorities total 10; and the sample-character schema mismatch.
- **The wizard's step model was a decision, not a default.** Step-by-step (mirroring the reference application) was chosen over a single scrollable page and over a two-pane layout with a live summary. A two-pane layout is the better model for a *future* application in which character generation is one feature among several; it is recorded in the design doc as the preferred model for that scope, and moving there later is cheap because the engine is pure and the state is a single object.
- **`SpinBox` clamps its value to `max_value`.** A maximum computed from the *remaining headroom* rather than from the points already allocated silently destroys the player's allocation — BUILD 4 became 2 mid-flow. The maximum is now floored at the points already allocated, and the pool is enforced in the change handler instead. The harness asserts the value survives (UI-AT-4).
- **`queue_free()` is deferred.** The outgoing step stayed in the wizard body (and stayed the first child) until the end of the frame, so a step swap was not immediately visible. The wizard now removes the child from the tree before queueing it free.
- **Driving the UI from an ad-hoc script is unreliable; driving it from the project's own harness is not.** The ad-hoc MCP probe fought stale state (the scene was not restarting between runs) and produced false failures. The deterministic in-process harness became the source of truth for flow coverage, and the MCP bridge was kept for live inspection.

## Verification

- `godot --headless --path src -s res://scripts/verify_rules.gd` → **74 checks, 0 failures**, exit 0.
- `godot --headless --path src -s res://scripts/verify_wizard.gd` → **84 checks, 0 failures**, exit 0.
- `godot --headless --path src --quit-after 90` → exit 0, 0 script errors.
- `codex-game-studio validate` → **1216 PASS / 0 FAIL / 0 WARN**, exit 0.
- Godot MCP bridge: connects, reports the project by name and path, live scene tree and runtime script inspection both work.
- **Live play-through, driven through the MCP with real input events** (not by calling the handlers): the layout measures `body 1280x664 / step 1280x664 / scroll 1280x664`; a real mouse click opens the Race dropdown and a real click on the popup item selects it (`selected=2`, `priorities={ "Race": 2 }`); the arrow keys step a focused dropdown; all five priorities end up recorded; the Next button is enabled and a real click advances the wizard to the Advantages step; the character resolves to `race=Clan Warrior attrPoints=30 skillPoints=20 advPoints=1 vehicle=None`. Typing `6` into the BUILD attribute field commits `spent={ "BUILD": 6 }` with 12 points left, and typing `99` clamps to the racial maximum of 6. No script warnings or errors remain in `res://rules/`, `res://ui/` or `res://scenes/`.

## Remaining Risks

- The m1 gate has **passed** and the human playtest is recorded. The remaining work is production planning, not verification.
- **No character name, age, height or weight can be entered** — the export carries the fields but the wizard has no inputs for them, so they export as empty/zero. This is the largest gap in the character-creation scope and is the first thing the next milestone should close.
- **Initial Edge is not tracked.** The rulebook (p. 19) says a character starts with Edge 1 unless they have the Extra Edge advantage. It is a character-creation value and the export schema has no field for it.
- Flexible Priorities is surfaced as the same 0–4 dropdowns with a "must total 10" validation, rather than a dedicated 10-point budget editor.
- The 1e-era sample characters will need migration or a 2e sample set for the (future) combat tracker.
- Rulebook areas left out of scope for m1 and flagged rather than guessed: Clan Heritage / trueborn Bloodname restrictions, and the full skill specializations.
- `codex-game-studio init --force-refresh` **wipes `project.godot`** back to a minimal file, losing `run/main_scene` and the `godot_mcp` plugin enable. Do not run it on an already-configured project.
- **After editing a script, the running game can be stale.** The game process launched by the editor may still be running the previous build, which makes a live check report the *old* behaviour. Kill every Godot process, restart the editor, and confirm the build before trusting a live result.
- **The MCP's `simulate_key` sends a keycode but no `unicode`**, so a LineEdit never receives a character. To test typed input, send an `InputEventKey` with `unicode` set. The MCP's `simulate_mouse_click` also sends press+release in one frame, which a popup menu cannot resolve; send the press and the release separately.

## Documentation Impact

- Decision: updated
- Reason: the m1 gate closed and a human playtest was recorded, both of which are documentation in their own right. A new rulebook cross-check was added (the rulebook's own tables and formulas are now parsed into a corpus and diffed against the engine and against a finished exported character), which is new behaviour the design doc now records as S1-AT-16 and UI-AT-13. R-S1-1..R-S1-10, U-S1-1..U-S1-8 and P-BUG-1..P-BUG-6 are unchanged by this.
- Documents: design/systems/character-creation.md, production/session-state/active.md, production/session-state/m1-gate-check.md, production/playtest/character-creation-playtest-2026-10-20.md, production/timeline.md
