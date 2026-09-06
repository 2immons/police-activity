# LimboAI suspect MVP

`npc.tscn` is the single active suspect implementation in `experiments/player/test_scene.tscn`. It owns damage, ragdoll and the LimboAI action bridge directly; there is no legacy NPC superclass.

## Composition

- `NPC` is a thin facade and owns activation plus semantic commands used by BT tasks.
- `AIController` reuses the existing perception, knowledge/blackboard, continuous aim, movement, Glock firearm and animation presentation components.
- `SuspectMind` owns the high-level utility decision. Persistent weights live in `SuspectPersonality` resources.
- `BTPlayer` executes the selected intention. Limbo Blackboard mirrors working context; it is not authoritative for health, ammo, movement or personality.
- BT actions only submit semantic movement intent. The `CharacterBody3D` root performs one `move_and_slide()` through `SuspectMovement` per physics frame.
- `EscapePoint` and both `BreakLOSPoint` markers are authored in the test scene.

## Blackboard values

`officer_visible`, `last_seen_officer_position`, `officer_distance`, `escape_point`, `escape_route_viability`, `selected_break_los_point`, `desired_action`, `current_action`, `under_fire`.

## Behavior tree

`ai/trees/npc.tres` has a `BTDynamicSelector` root. Its `BlackboardPlan` declares the shared perception, combat and tactical variables. Branches use Limbo's built-in `BTCheckVar` to inspect `desired_action`; the only custom task is `ai/tasks/bt_execute_suspect_action.gd`, which bridges a selected branch to CharacterBody gameplay execution and returns Limbo statuses.

## Decisions

- `ESCAPE` rises with escape drive and current route viability.
- `FIRE_TO_ESCAPE` rises when an armed, aggressive suspect sees an officer controlling the route. It fires from the visible Glock muzzle using continuous aim and the shared penetration solver.
- `SURRENDER` rises with compliance, self-preservation, threat and poor escape opportunity.
- `BREAK_LOS` uses manually authored points when threat is high, direct escape is poor and aggression is insufficient for firearm pressure.

When the officer leaves the route, viability increases and `ESCAPE` replaces `FIRE_TO_ESCAPE` from current tactical facts. There is no shooting timer or scripted transition. If LOS is lost, calculations use the last seen position.

## Running

Open `experiments/player/test_scene.tscn`. F3 activates the suspect, F1 recreates it at `NpcSpawn`, and F2 reloads the entire scene. Move away from the direct suspect-to-exit corridor to expose the FireToEscape-to-Escape transition. The world-space label shows decisions and scores; the LimboAI runtime debugger remains available on `BTPlayer`.

F1 injects the scene-authored EscapePoint and both BreakLOSPoints into the fresh runtime instance before `_ready()`, so reset does not lose tactical context. `AIDebugDraw` renders blue desired-aim and red actual-muzzle rays.

Automated acceptance coverage is in `npc/tests/suspect_mvp_test.gd` for unblocked escape, blocked FireToEscape with an actual shot, immediate escape transition, surrender, BreakLOS, lost-sight memory and the activation/reset gates.

## MVP limitations

The current animation library has no verified hands-up clip, so surrender uses a stable stopped idle hook. BreakLOS uses two authored points and a simple LOS/reachability score. Navigation falls back to direct steering when the sandbox has no baked navigation path.
