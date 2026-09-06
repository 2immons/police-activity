# Repository workflow

When starting a task, read AGENTS.md first and REPO.md second. Use REPO.md to identify the relevant subsystem before scanning the repository. Update REPO.md whenever architectural responsibilities, important files, major scenes, dependency directions or public subsystem APIs change.

# Godot architecture

- `.tscn` = permanent composition: entities, bodies, components, colliders, cameras, pivots, markers, probes, audio, UI and debug nodes. Reusable entities are `PackedScene` instances.
- `.gd` = behavior of already-authored nodes. Do not construct permanent hierarchy in `_ready()`. Runtime `.new()` is appropriate for temporary effects/debug geometry, runtime data and helper objects without a useful scene representation.
- `.tres` and custom `Resource` classes = designer tuning and serializable data. Runtime state belongs to component instances; do not mutate shared configuration Resources.
- Preserve editor-visible source transforms and alignment markers when applying procedural motion.

Prefer composition over inheritance. Each component owns one coherent responsibility and every important state has one owner. Coordinators issue commands and order updates; they do not absorb subsystem algorithms. Do not replace a god object with a manager god object or split cohesive math merely to shorten a file.

Wire local dependencies explicitly with exported references, unique names or short stable NodePaths. Cache stable nodes, markers, bones, animation tracks and probe arrays during initialization. Avoid hierarchy walks such as `get_parent().get_parent()`, repeated hot-path `get_node()`/`find_bone()`, and scene-tree groups as local service locators.

Components communicate through public APIs. Private `_fields` and `_methods` stay private. Use direct calls for synchronous commands/queries and signals for events that may have multiple independent listeners. Keep one owner for logical state; presentation blend amounts may be derived separately.

Use typed GDScript consistently. Replace stable Dictionary-shaped domain data with typed `RefCounted` runtime records or Resources when that improves safety; reuse per-frame records to avoid allocation churn. Required scene dependencies should assert/fail clearly, while optional features may degrade gracefully.

Keep raw keys/buttons at player-facing input boundaries and pass semantic commands into simulation. Separate simulation (state, ammo, physics, obstruction) from procedural presentation (skeleton, camera, audio/effects) where the boundary is meaningful.

Group non-obvious exported tuning with `@export_group`/`@export_subgroup` and document purpose, units and tuning effect with `##` comments. Do not export implementation constants that designers should not tune.

Comments explain intent, constraints, coordinate-space conversions or non-obvious math. Do not narrate syntax. Preserve useful optional debug visualization and focused experiment tests.

# Refactoring and verification

Audit dependencies before broad moves. Refactor incrementally, stabilize public APIs first and preserve current game feel unless behavior is explicitly being changed. Keep experimental mechanics under `experiments/` and add focused deterministic tests where they protect complex behavior.

Before finishing, review permanent `Node.new()` usage, private cross-component access, hierarchy walks, hot-path lookups, magic tuning and oversized mixed-responsibility functions. Run the relevant Godot scenes/tests and fix parser errors, invalid NodePaths, broken Resources/signals and scene-ownership problems. Document intentional remaining debt in REPO.md.
