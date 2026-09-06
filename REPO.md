# Project Overview

Experimental Godot 4 first-person police simulation. The current vertical slice combines full-body locomotion, procedural camera and weapon handling, environmental body reactions, physical doors, ballistic penetration, damage/ragdoll and a tactical NPC sandbox.

# Main Runtime Architecture

```text
TestScene
├── Player
│   ├── locomotion/input/damage lifecycle (player.gd)
│   ├── body rig and SkeletonModifier3D stack
│   ├── LookRig + CameraMotion
│   ├── WeaponRig + weapon pose modifier
│   ├── BodyEnvironmentInteraction
│   ├── Stress + SuppressionFeedback
│   └── DoorInteraction
├── SuspectNpc
│   ├── damage/ragdoll lifecycle + Limbo action facade
│   ├── perception + Limbo Blackboard + suspect mind
│   └── movement + aim + NPC firearm + animation/debug
└── authored doors, escape/break-LOS points and test geometry
```

# Major Systems

## Player Movement and Damage

- Purpose: locomotion modes, body rotation, collider stance, animation/audio selection and player hit/death lifecycle.
- Main file: `experiments/player/player.gd`.
- Scene: `experiments/player/player.tscn` (`Player`, body rig, hit zones, collider, `Footsteps`).
- Dependencies: `MovementSettings`, look public API, weapon state queries, environment sensor and door interaction.
- Public API: `move_player()`, `is_sprinting()`, `is_jogging()`, `is_crouching()`, `is_aim_fast_walking()`, damage receiver methods and reset helpers used by tests.
- Resource: `experiments/player/movement_settings.tres`.

## Look, Camera and Body Look

- Purpose: mouse yaw/pitch and free look, first/third-person placement, lean, eye anchor synchronization, body/head pose and camera motion.
- Main files: `experiments/player/look_at_modifier_3d.gd`, `experiments/player/skeleton_ik_3d.gd`, `experiments/player_camera/camera_motion.gd`.
- Scene nodes: `LookAtModifier3D`, its `Camera3D`/`CameraMotion`, and body `SkeletonModifier3D` nodes authored in the imported-body scene overrides.
- Dependencies: player locomotion queries and weapon public recoil-compensation/state API.
- Public API: view/movement bases, free-look commands/queries, camera aim offset, first-person selection and death detach.
- Resources: `lean_settings.tres`, `camera_motion_settings.tres`.

## Player Weapon

- Purpose: weapon mode orchestration and procedural pose/arm presentation. Firearm, recoil and obstruction are separate scene components owned by the weapon subsystem.
- Main files: `experiments/weapon_system/weapon_controller.gd`, `firearm_controller.gd`, `weapon_recoil_controller.gd`, `weapon_obstruction_controller.gd`.
- Scene nodes: `WeaponController` in the skeleton modifier stack; `WeaponRuntime/Firearm`, `Recoil`, `Obstruction` under `Player`; weapon markers/probes/audio/flash are authored in `weapon_rig.tscn` and `glock_17.tscn`.
- Dependencies: explicit player/look/environment/door references. The pose modifier queries simulation components; simulation components never manipulate the skeleton.
- Public API: equip/aim/ready/reload/fire commands and state queries; recoil compensation; obstruction compression query.
- Resources: `weapon_settings.tres`, ballistic penetration Resources.

## Body Environment Interaction

- Purpose: convert authored ShapeCast probes into semantic nearby-surface data and continuous squeeze/reflex amounts.
- Main file/scene: `experiments/player/environment_interaction/body_environment_interaction.gd` and `.tscn`.
- Dependencies: intended velocity and public semantic stance flags supplied by the player coordinator.
- Public API: `advance()`, `get_interaction()`, `get_collision_reflex_weight()`.
- Resource: `body_environment_interaction_settings.tres`.

## Player Stress and Suppression

- Purpose: accumulate stress from bullet near misses/hits, recover after danger, and expose one normalized value to presentation consumers.
- Main files: `experiments/player/stress/player_stress_controller.gd`, `suppression_overlay.gd`, `suppression_overlay.gdshader`.
- Scene: `suppression_feedback.tscn`, instanced with the `Stress` node in `player.tscn`.
- Dependency direction: NPC firearm code sends semantic stimuli through `Player.receive_suppression()`; stress owns simulation state; weapon and camera query it; the overlay only renders it.
- Public API: `apply_suppression()`, `get_amount()`, `get_weapon_sway()`, `reset()`.
- Resource: `player_stress_settings.tres` owns accumulation, decay, weapon sway and screen-effect tuning.

## Doors and Player Interaction

- Purpose: `PhysicalDoor` owns latch, motor, inertia, handle/panel targets and highlighting; `DoorInteractionController` owns candidate selection, tap/hold input and support-hand intent.
- Main files/scenes: `experiments/doors/door.gd`, `door.tscn`, `door_interaction_controller.gd`, `door_test_scene.tscn`.
- Dependency direction: player interaction calls the door public API; the door never manipulates player bones; the weapon pose modifier consumes the player hand target.
- Resources: `door_settings*.tres`, `door_interaction_settings.tres`.

## Ballistics and Damage

- Purpose: ray penetration, impacts attached to moving colliders, humanoid hit zones, reactions and ragdoll death.
- Main files: `experiments/weapon_system/ballistics/*`, `npc/npc_hit_zone.gd`, `npc/npc_hit_reaction.gd`, `npc/npc.gd`.
- Public API: `BulletPenetrationSolver.trace()`, `receive_bullet_hit()`, `receive_zone_hit()`.

## LimboAI Suspect

- Purpose: escape/arrest-survival focused suspect MVP with `IDLE`, `ESCAPE`, `BREAK_LOS`, `FIRE_TO_ESCAPE` and `SURRENDER` intentions.
- Main scene/facade: `npc/npc.tscn` and `npc/npc.gd`; components and tuning live in `npc/ai/`; Limbo assets live in `ai/trees/` and `ai/tasks/`.
- Dependency direction: existing perception/knowledge, continuous aim, movement, animation, Glock muzzle firearm, penetration and damage components feed `LimboSuspectMind`; the mind publishes one desired action; `BTPlayer` routes it through a `BTDynamicSelector` and calls public NPC commands.
- Authored tactical context: `EscapePoint` plus two `BreakLOSPoint` markers live in `test_scene.tscn`. Route control uses visible or last-known officer position and never reads an unseen live transform.
- Runtime control: `NPC.set_ai_active()` owns `BTPlayer.active`; F3 activates, F1 recreates at `NpcSpawn`, and F2 reloads player and suspect.
- `BTPlayer.blackboard` is the single runtime fact store. `ai/trees/npc.tres` declares its variables in `BlackboardPlan`; perception, mind, tactical query, movement, aim and weapon share that Limbo Blackboard directly. Branch conditions use built-in `BTCheckVar`.
- `npc/npc.gd` directly owns damage/death/ragdoll lifecycle and exposes Limbo action commands; it has no legacy superclass.
- Limbo tasks submit action/movement intent; `NPC._physics_process()` is the sole `CharacterBody3D` movement tick. Mind intent changes restart the running tree so a stale long-running action cannot survive a utility decision switch. `FIRE_TO_ESCAPE` keeps tactical repositioning active while the independently updated aim/firearm fires. F1 restores authored tactical references before adding the replacement to the tree.
- `AIDebugDraw` is a top-level world-space mesh: blue is desired aim, red is the physical muzzle/shot axis, yellow connects the eye sensor to last-seen position, purple is the movement destination, and green/red is the escape route. Direct steering uses collision-tangent recovery while the sandbox has no baked navigation map.
- Experiment guide and limitations: `npc/README.md`; focused acceptance coverage: `npc/tests/suspect_mvp_test.gd`.

# Important Scenes

- `experiments/player/test_scene.tscn`: integrated gameplay sandbox and current main test environment.
- `experiments/player/player.tscn`: reusable player composition.
- `experiments/player/prefabs/weapon_rig.tscn`: weapon instance, holster marker and obstruction probes.
- `experiments/doors/door.tscn`: reusable physical door with editor-visible hinge, handles and targets.
- `experiments/doors/door_test_scene.tscn`: focused door interaction test.
- `npc/npc.tscn`: reusable LimboAI suspect body, weapon, hit zones, ragdoll and authored AI components.
- `experiments/player/stress/suppression_feedback.tscn`: reusable full-screen vignette and edge-blur presentation.

# Runtime Update Flow

Player physics: input/locomotion state -> character movement -> door body contacts -> environment probes -> body rotation/animation/audio. Skeleton processing then applies body look/hit reaction and weapon pose/arm IK. Camera motion updates presentation after movement and refreshes the camera transform.

Weapon frame: weapon logical state -> firearm timers/reload -> obstruction query -> base weapon pose -> step/stress sway -> recoil pose -> grip/door/environment arm modification -> muzzle/audio/impact presentation on shot events.

Suppression flow: NPC shot trajectory -> closest-point stimulus or body hit -> player stress simulation -> weapon/camera sway and full-screen peripheral presentation.

NPC frame: perception/memory -> suspect utility mind -> Limbo action routing -> movement + continuous aim/firearm -> presentation animation/debug.

# Dependency Notes

- Raw input belongs at player-facing controllers; simulation receives semantic commands.
- Weapon simulation may query player locomotion through public methods. It must not mutate movement internals.
- Skeleton modifiers own pose changes only. Firearm, door and environment simulation do not write skeleton bones.
- `PhysicalDoor` exposes state, targets and commands; it never knows the player rig.
- Resources are immutable configuration at runtime; component fields own mutable state.
- Stable scene and bone references are cached during initialization.

# Architectural Constraints

- `.tscn` contains permanent composition and alignment markers; `.gd` contains behavior; `.tres` contains tuning/data.
- Preserve the current procedural full-body behavior and authored transforms during refactors.
- Experimental mechanics stay under `experiments/` and retain focused deterministic tests.
- Update this index when responsibilities, important paths, dependency directions or public APIs change.

# Known Technical Debt

- `player.gd` still combines locomotion presentation and damage lifecycle; these are cohesive migration seams for later work but are kept together until regression coverage is stronger.
- Weapon arm presentation remains mathematically dense because authored animation sampling, analytical IK and door-hand blending share one skeleton pass.
- `BodyEnvironmentInteractionController` owns reusable typed `BodySurfaceInteraction` records internally. Its Dictionary-returning method remains only as a compatibility/debug boundary for existing tests.
- Look, lean and camera placement still share one node and should only be separated with visual regression coverage.
- Raw input remains distributed across the player, look, weapon and door-facing controllers. A single input boundary is still desirable, but moving it requires an InputMap migration and explicit input regression coverage.
- Player locomotion simulation, locomotion presentation and damage lifecycle still share `player.gd`; their ownership is documented, but extracting them safely needs broader death/reset and animation coverage.
