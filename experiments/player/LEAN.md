# Lean

Hold Q to lean left, E to lean right. Release to straighten; both keys cancel.
Sprint suppresses lean. The defaults are 14 degrees / 0.32 seconds left,
22 degrees / 0.22 seconds right, with a 0.25 second return and eased movement.
Tune these values and camera roll in `lean_settings.tres`.

`look_at_modifier_3d.gd` handles input and transition state. `skeleton_ik_3d.gd`
rotates the spine subtree about its parent's pelvis position after look rotation.
The pelvis and leg poses remain unchanged, preserving the existing locomotion.
The eye anchor follows the leaned head, and weapon IK runs after the body modifier.
No permanent nodes are constructed in scripts.

The character collision capsule stays upright; this is a pose lean, not physical
ragdoll balancing or a separate torso collision solver.
