# Pixel Ninja prototype

Double-click **Play.bat**. The bundled Godot engine is in `.engine`.

| Control | Action |
| --- | --- |
| Left/right or A/D | Move |
| X | Buffered jab -> jab -> kick chain (punch removed) |
| Z | Uppercut / launch |
| X after connected Z | Three-hit aerial follow-up |
| C or Space | Jump, then one somersault air jump |
| Down/S + C | Backstep while retaining facing |
| Down/S | Crouch; combine with left/right to move slowly |
| Down/S + X | Crouching jab only |
| Down/S + Z | Low kick only |
| V (hold) | Frontal guard: 70% damage reduction; remaining damage still applies |
| F | Toggle human opponent attacks |
| R | Reset player and practice targets |

Practice targets are the orange blocks. A red-clad human sparring opponent waits
near x=300, attacks at close range, and has 120 HP. Every third strike is a heavy
punch that can knock an unguarded player down. The player has 100 HP.
Connect Z from close range and press X during the uppercut to queue aerial attacks.
Down+Z trips the human opponent. Knocked-down actors fall, remain prone briefly,
then get up. Death plays a separate fall and holds its final frame; R revives both.
The low tunnel at x=350 requires crouching. Releasing Down inside will keep you
crouched until there is enough room to stand. Backstep and standing jumps are
blocked while there is insufficient headroom.

Art: `review/approved/all_actions.png` and the individual action GIFs.
The uppercut effect is now applied: mirrored from the original preview, rooted
two pixels below the caster's feet and rising from the ground. The separate gold
hit-spark effect remains review-only.

The stage uses a moonlit bamboo / dojo background, stone paving and cedar platforms.
New reaction art and gameplay captures are in `review/combat_expansion`.

See `docs/current_structure.md` for architecture and validation details.
