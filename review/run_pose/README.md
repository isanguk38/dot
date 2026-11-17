# Run pose review 01

Pending user review. Not referenced by the game.

Source: `assets/player/run.png`, first 64x64 cell, original game art.

The head is translated unchanged. The torso and original wrapped arms are rotated
together by 19 degrees. The original legs are separated and rotated at their
joints, without scaling. The near boot retains its original horizontal shape.
Nearest-neighbor sampling preserves the original palette; it can change the
stair-step contour of diagonal limbs, so visual approval is still required.

No image-generation model was used for this revision. No existing runtime sprite,
scene, or controller was changed. Later poses, combat, and effects remain pending.

Reproduce: `python tools/review_run_pose.py` (Pillow required).
