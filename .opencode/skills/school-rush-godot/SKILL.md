---
name: school-rush-godot
description: Use when working on the School Rush Godot 4 arcade runner — editing GDScript, scenes, gameplay tuning, UI, audio, saves, or the headless test suite; validating scripts; or exporting builds. Covers project commands, architecture, conventions, common recipes, and pitfalls specific to this repository.
---

# School Rush — Godot development

A 2D three-lane side-scrolling arcade runner built in **Godot 4.7.2** with **GDScript only** (no .NET/C#). Elias runs through Home → Street → Hallway, dodging hazards and collecting school items.

Read this before editing scripts or scenes, then follow the verification steps at the end.

## Quick facts

| Item | Value |
| --- | --- |
| Engine | Godot **4.7.2 stable** (installed at `C:\Program Files\godot\godot.exe`) |
| Renderer | GL Compatibility |
| Language | GDScript only — do not add C# or .NET dependencies |
| Design resolution | 1920×1080, `canvas_items` stretch, 60 FPS target |
| Main scene | `res://scenes/main.tscn` |
| Platforms | Windows, macOS, Linux |
| Save file | `user://save.cfg` via `SaveManager` |

> `README.md` still says Godot 4.4. `project.godot` (`config/features`) and `godot --version` say **4.7** — trust the engine, and update the README if you touch that line.

## Commands

Run everything from the repository root.

```powershell
# Play the game
godot --path .

# Import assets / refresh .godot cache headlessly
godot --headless --path . --import

# Load the project and quit (catches parser/scene errors)
godot --headless --path . --quit

# Parse-check one script
godot --headless --path . --check-only --script res://scripts/entities/player.gd

# Full headless test suite (exit code 0 = pass, 1 = fail)
godot --headless --path . res://tests/test_runner.tscn

# Regenerate chiptune stems and SFX (requires Python + numpy)
python tools/gen_audio.py

# Export Windows build (requires export templates installed)
godot --headless --path . --export-release "Windows Desktop" build/windows/SchoolRush.exe
```

If `godot` is not on `PATH`, call the binary directly: `& "C:\Program Files\godot\godot.exe" ...`.

A passing suite ends with `230 checks, 0 failure(s)` and `ALL TESTS PASSED`. Treat any new `FAIL:` line as a regression.

## Architecture map

| Area | Files | Responsibility |
| --- | --- | --- |
| Flow | `scripts/main.gd`, `scenes/main.tscn` | Menu → cutscene → run → results; pause/options/help overlays; screen swapping |
| Tuning | `scripts/core/game_config.gd` | **All** constants, enums (`Mode`, `Zone`, `RunState`, `Lane`), and pure score/zone/lane helpers |
| Autoloads | `scripts/autoload/save_manager.gd` | Persistent settings, records, shop points/levels; `user://save.cfg` |
| | `scripts/autoload/game_state.gd` | Cross-scene run state (mode, last results, best flag) |
| | `scripts/autoload/audio_director.gd` | Music stems, crossfades, SFX, volume application |
| World | `scripts/world/run_world.gd` | Run loop, distance, speed ramp, zone changes, scoring, results payload; dog alert/dog event state machine |
| | `scripts/world/spawn_director.gd` | Turn-based hazard/item/coin patterns; always leaves a lane open; static fuzzable `generate_pattern()`; separate difficulty-scaled dog timer (Home/Street only) |
| | `scripts/world/zone_layer.gd`, `zone_backdrop.gd` | Parallax/procedural zone visuals |
| Entities | `scripts/entities/player.gd` | `CharacterBody2D`: lanes, jump, slide, dash, hearts, i-frames, hitbox |
| | `scripts/entities/hazard.gd` | 13 hazard kinds (`DOG` is scheduled separately, not a zone pattern kind), overhead vs. ground, moving kinds |
| | `scripts/entities/dog.gd`, `dog_alert.gd` | `Dog extends Hazard` charge entity; 14-frame world-space lane alert; frame animations are `AnimationPlayer` resources (`walk` / `alert`) in the scenes |
| | `scripts/entities/collectible.gd`, `coin.gd` | `Area2D` overlap pickups |
| | `scripts/entities/pursuer.gd` | Dormant → chase → fade → lunge state machine |
| UI | `scripts/ui/*.gd` | Code-built `Control` screens themed through `UiKit` |
| Tests | `tests/test_runner.gd` | Headless suite covering rules, collisions, save, audio, scenes, full flow |

Preloaded scenes live in `scenes/`: `main`, `main_menu`, `cutscene`, `run_world`, `player`, `hazard`, `collectible`, `coin`, `pursuer`, `dog`, `dog_alert`, `hud`.

## Conventions

- **Tabs** for indentation, matching the existing GDScript. Use typed declarations (`var lane: int`, `func move_lane(dir: int) -> void`) and `##` doc comments on classes and non-obvious functions.
- **Tuning lives in `GameConfig`.** Do not hardcode speeds, timings, scores, costs, or lane Y values in entities/UI. If a value is gameplay-relevant, add a named constant (or a static helper) there.
- **Global vs. local state.** Persistent data → `SaveManager`. Cross-screen run data → `GameState`. Autoloads are already registered in `project.godot`; never instantiate duplicates.
- **Signals for flow.** Screens emit `closed` / `*_requested`; `main.gd` owns transitions. Do not reach up the tree with `get_parent()` chains.
- **UI is built in code**, not `.tscn`, with `extends Control` + `class_name`, a `setup(...)` method, and a `closed` signal. Use `UiKit` colors/fonts and `UiKit.make_theme()` for consistency.
- **Rendering.** World, hazard, and pursuer visuals are procedural `_draw()`; Elias uses `assets/characters/elias_sheet.png`. Keep coordinates in the 1920×1080 design space.
- **Physics layers:** `1 = player`, `2 = hazard`, `3 = collectible`, `4 = fx`. The player hitbox uses layer 1 and mask `2 | 4`.
- **Pause:** overlays and always-on nodes set `process_mode = Node.PROCESS_MODE_ALWAYS`; gameplay must honor `get_tree().paused`. Pause is opened by `main.gd`, not by the run.
- **Input:** actions (`lane_up`, `lane_down`, `jump`, `slide`, `dash`, `pause`) are defined in `project.godot` using **physical keycodes**. Use `event.is_action_pressed(...)` and call `get_viewport().set_input_as_handled()` when consuming input.
- **Frame timing:** gameplay runs in `_physics_process`; UI animation/timers in `_process`. Do not mix render-only work into physics.

## Common recipes

### Retune gameplay
1. Change the constant in `scripts/core/game_config.gd`.
2. Check tests that assert the value or derived math (search `tests/test_runner.gd`).
3. Run the headless suite.

### Add a hazard kind
1. Add to `Hazard.Kind` in `scripts/entities/hazard.gd`.
2. Register it in `ZONE_KINDS` and, if applicable, `OVERHEAD_KINDS` / `MOVING_KINDS`. Scheduled-only kinds (like `DOG`) stay out of `ZONE_KINDS`.
3. Implement its `_draw()` shape and collision size; overhead kinds set `requires_slide = true`.
4. Add coverage in `tests/test_runner.gd` (spawn fuzzing must still leave an open lane).

### Add a shop upgrade
1. Extend `SHOP_UPGRADES`, `SHOP_NAMES`, `SHOP_DESCRIPTIONS`, and cost logic in `GameConfig`.
2. Add the default level in `save_manager.gd` (`shop_levels`), plus load/save handling.
3. Apply the effect where it belongs (`player.gd` for movement, `run_world.gd` for scoring).
4. Add purchase/cap/effect assertions to the suite.
5. Surface it in `scripts/ui/shop_panel.gd`.

### Add a UI panel
1. Create `scripts/ui/<name>.gd`: `class_name`, `extends Control`, `signal closed`, `setup(...)`.
2. Build children in `_ready()` with `UiKit` styling; support mouse and keyboard.
3. Wire it in `scripts/main.gd` (`open_*` / `close_*`) and free it on `closed`.
4. Extend `_test_scenes()` so the panel instantiates headlessly.

### Add a test
1. Add `await _test_your_thing()` in `test_runner.gd`'s `_ready()`.
2. Use `_check`, `_check_eq`, `_check_near`; print a clear label.
3. Prefer `run_world`/`player` helpers and `await get_tree().process_frame` before asserting.
4. Always restore global state (`SaveManager`, `GameState`) when a test mutates it.

## Pitfalls

- **Do not edit generated files.** `.godot/` is the import cache and is git-ignored; `*.import` files are engine-generated. Never hand-edit them, and never commit `.godot/`.
- **Headless cannot verify visuals.** `_draw()` runs without errors headlessly, but colors, spacing, and text fit need a desktop editor check. Say so when you change layout.
- **Scene changes need a fresh import.** After adding assets or scenes, run `--import`; otherwise headless loads can fail with missing UIDs.
- **The test suite writes `user://save.cfg`.** It restores values afterward; avoid running tests against a save you care about.
- **Pause-related bugs.** Nodes that should keep running while paused need `PROCESS_MODE_ALWAYS`; everything else must check `get_tree().paused`.
- **Aspect scaling.** The window is 1280×720 but the viewport is 1920×1080; assert positions in design coordinates, not window pixels.
- **Export needs templates.** `--export-release` fails with a clear error until templates are installed (`Editor → Manage Export Templates`).
- **No .NET.** The project uses the standard Godot build; adding C# will break the pipeline.
- **Exit codes matter.** `test_runner.tscn` returns non-zero on failure — use it as the gate before calling work done.
- **Leak warnings at test exit are pre-existing.** The suite may print `ObjectDB instances were leaked` / `resources still in use` even when it passes (exit 0). Don't chase them unless your change made the count grow.

## Definition of done

- [ ] `godot --headless --path . --quit` completes without parser or load errors.
- [ ] `godot --headless --path . res://tests/test_runner.tscn` prints `ALL TESTS PASSED` and exits 0.
- [ ] New gameplay numbers live in `GameConfig`, not inline.
- [ ] New scenes/scripts are reachable via `preload`/`class_name` and covered by a headless test.
- [ ] Save-affecting changes round-trip through `SaveManager`.
- [ ] Any visual/layout change is flagged for a desktop editor check.
