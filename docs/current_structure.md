# Pixel Ninja: current structure

## Runtime

- `project.godot`: 480x270 viewport, integer upscaling, nearest-neighbor sampling.
- `main.tscn` / `main.gd`: 1600px test course, terrain collision, player spawn,
  launchable practice targets, camera limits, controls HUD, combo counter and reset.
- `player.tscn`: CharacterBody2D, fixed 14x46 collision, 64px AnimatedSprite2D,
  camera. The legacy Area2D is disabled; active strikes use immediate shape queries.
- `player.gd`: movement, coyote time, jump buffer, one air jump/somersault,
  backward hop, buffered ground/aerial combo state, launcher, hitstop and frame timing.
- `dummy.gd`: CharacterBody2D practice target with gravity, launch velocity,
  aerial hit reactions, knockback, brief hit flash and reset.
- `enemy.gd`: one red-clad human dojo sparring opponent with HP, telegraphed attacks,
  ground/air reactions, knockdown/get-up and persistent death. F toggles attacks.
- `uppercut_fx.gd`: mirrored rising effect rooted two pixels below the casting
  player's feet. It stays in stage coordinates while the player jumps.
- `stage_surface.gd`: pixel stone paving, cedar beams and a tiled low canopy.
- `assets/ninja` / `assets/enemy`: character atlases with 64x64 cells.

Terrain is collision layer 1, targets layer 2, player layer 4. Player and targets
collide with terrain; players do not push the training targets with their bodies.
Attack queries hit layer 2 only and trigger once per strike's active frame.

## Controls

- Left/right arrows or A/D: move.
- X: jab -> jab -> kick. Punch is removed from runtime animations.
- Z: uppercut. A connected uppercut launches target and player into the air.
- X after Z: up to three aerial attacks, ending in a kick.
- C / Space: jump; one additional airborne press performs a somersault jump.
- Down/S + C: backward hop on the ground, preserving facing.
- Down/S: crouch, with left/right for slow crouched movement (65px/s).
- Down/S + X: crouched jab only; Down/S + Z: low kick only.
- R: reset player and practice targets.
- V: hold frontal guard. Incoming damage becomes 30%, rounded up to at least one;
  rear attacks bypass guard, and remaining chip damage can kill.
- F: toggle human opponent attacks. This is a stationary sparring opponent with
  close-range attacks, not navigation/chase AI.

The ground chain has a 0.30s grace window. Inputs are read during hitstop.
Connected hits freeze the actor and target for 42ms (normal) or 65ms (launcher /
finisher). Rendering frames pause with the attack state; movement is not sheared
to create a fake forward lean.

Crouching changes the grounded collider from 14x46 to 14x30, keeping its bottom
anchored. A standing-size physics query checks headroom before standing, jumping,
uppercutting or backstepping. In the 36px-clearance tunnel, releasing Down leaves
the body crouched until the player exits. Low X and low Z are separate actions,
not a forced two-attack chain.

Player HP is 100, human HP 120. Normal enemy punches deal 12 damage (4 through
guard); every third punch is heavy, deals 18 and knocks down an unguarded player.
Hitstun interrupts attacks; short damage invulnerability avoids duplicate contacts.
Guard has its own recoil. Low kicks supply a trip flag distinct from a normal
finisher. Fallen actors use low collision shapes and restore standing shapes when
getting up. Dead actors leave attack-query layers and hold the final death frame.

## Art production and review

Approved design source: `review/run_pose/run_redraw_source_v7.png`.
Each action was generated with this same reference, including slim proportions,
both forearm wraps and white/cyan sneakers. Full prompts: `review/approved_prompts.json`.

`tools/build_approved_assets.py` copies raw sources into `review/approved/source`,
removes backgrounds, uses a single scale per strip derived from visor dimensions,
and packs 64x64 cells. The scale is not independently fitted to each pose.
Somersaults use a centered pivot; normal poses use a shared foot baseline.
Generated pose anatomy can still vary slightly; inspect the action board and GIFs
instead of assuming numeric normalization makes every detail identical.

Earlier generated art and rigid-part experiments are not used by the runtime.
The pre-change scripts and scenes are backed up under `review/legacy`.

## Effects status

The gold hit burst remains review-only. The uppercut arc is now explicitly approved
and loaded from `assets/fx/uppercut.png`. It is mirrored, enlarged at integer pixel
scale and rooted below the caster's feet, then rises in stage coordinates instead
of following the character into the air. The old files under
`review/approved/effects` are historical offline previews.

Impact timing: small core -> peak star -> separate outward fragments -> fade.
Uppercut timing: lower hook -> rising crescent -> overhead arc -> scattered pixels.
Preparation keeps their scale fixed across frames and uses binary alpha plus nearest
sampling. `*_on_character.gif` is offline compositing, not a gameplay capture.

## Verification

`tests/combat_smoke.gd` runs 30 checks against real scenes and physics, checking input mappings,
ground chain hit count, uppercut launch, aerial three-hit follow-up, backstep direction
and landing, air jump, running animation, separate low attacks and low-tunnel
collision / standing clearance. Run through the bundled engine:

    .engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/combat_smoke.gd

Set APPDATA to the project's `.runtime` directory, as `Play.bat` does. Add
`-- --capture` without `--headless` for rendered screenshots in `review/approved`.

`tests/human_combat.gd` separately verifies human recoil, knockdown/recovery, both
deaths, chip/frontal/rear guard damage, real enemy attacks, corpse exclusion, reset,
AI toggle, jab-only opener and mirrored ground-rooted uppercut origins. Its captures
are saved to `review/combat_expansion`.
