# ANOMALY HEIST - Project Instructions

## Read first

Read `docs/BUILD_SPEC.md` fully before the first implementation pass. It is the authoritative product and engineering brief. On later passes, read the relevant sections plus the current project status. This pack is a specification, not an existing game implementation.

The owner wants a polished Roblox experience, not another concept presentation. Create actual connected Luau modules, a reproducible Rojo project, a playable world, and honest verification results.

## Product decisions

- Third-person Roblox game: capture unusual creatures, carry them through hazards, extract, collect, display, and evolve.
- Eight players and exactly eight player bases per server.
- One Place initially: safe hub plus separated expedition areas.
- US English (`en-us`) is the source language and fallback. The United States is explicitly in scope.
- Worldwide localization targets every supported Roblox locale, not only a selected language shortlist. Refresh the official locale registry before implementation.
- Keyboard/mouse, touch, and gamepad are design requirements. Enable release platforms after testing.
- PvP concerns unsecured expedition cargo only. Secured collections and purchased cosmetics cannot be stolen.
- Build one polished zone and three mechanically distinct creatures before expanding to three zones and ten species.
- Trading and commerce start disabled. No paid randomness or pay-to-win movement.
- Source-code identifiers and developer documentation are English; player-facing text is localized.

## Visual target

Use `references/roblox_style_reference.png` only as style guidance. Prefer readable low-poly geometry, daylight, modular research-outpost architecture, restrained effects, and real Roblox avatars.

Do not reproduce the picture's arbitrary catch percentages, text errors, fake rankings, or exaggerated effects. Do not claim the reference is a screenshot of an implemented game.

## Inspect before acting

The owner has Roblox Studio and a Rojo Studio plugin. VS Code, the Rojo CLI, a repository, uploaded assets, and connected Studio tools are not guaranteed.

Inspect the actual environment. Preserve existing files. Ask only blocking questions. Record reversible assumptions and continue.

Use actual authorized tools. Never invent successful commands, Studio tests, benchmark results, asset IDs, uploaded assets, or account access.

## Implementation rules

- Use native Luau, strict typing where practical, and explicit module boundaries.
- Clients send intent; servers decide ownership, currency, cooldowns, hits, progression, and grants.
- Validate all externally triggered actions and enforce server rate limits.
- Keep capture/cargo/extraction as an authoritative state machine with one owner.
- Use stable item IDs and idempotent grant/operation IDs.
- Do not show a secured-item success message before its ownership commit is confirmed.
- Use one tested profile repository with session ownership and serialized operations.
- An ambiguous save is not permission to grant again or overwrite a profile with defaults.
- Separate development, staging, and production data.
- Build a deterministic primitive-asset world so missing external uploads do not prevent a first run.
- Define source-controlled versus Studio-authored trees before enabling broad synchronization.
- Every effect/controller needs cleanup across drop, extraction, death, disconnect, respawn, and streaming.
- Put tunable values and feature flags in versioned configuration.
- Do not leave active required features as empty TODO stubs.

## Internationalization rules

Use stable text keys, parameters, a source glossary, translation tables, and a tested English fallback. Localize objectives, errors, signs, item descriptions, ownership warnings, menus, purchase messages, and metadata.

Do not infer country, price, eligibility, or age from language. Respect current platform policy and translation settings.

Test long strings, Arabic direction/shaping, CJK and other scripts, plural/number formatting, small screens, and language switching. Track draft versus reviewed coverage for every locale honestly.

Show actual player-appropriate prices when commerce is enabled. Store event time in UTC and display locally. No single-region-only event schedule or language-dependent gameplay gate.

## Commands

After the CLI and project exist, use the actual environment's equivalent of:

```sh
rojo --version
rojo build default.project.json -o build/AnomalyHeist.rbxlx
rojo serve default.project.json
```

Create `build/` before building. Follow `docs/BUILD_SPEC.md` for setup alternatives. Verify exact versions and dependencies rather than assuming them.

A build is not a Studio runtime test. A multi-client test is not proof of low-end-device performance.

## Milestone sequence

M0 environment/build foundation -> M1 walkable visual space -> M2 complete three-creature loop -> M3 persistence/economy -> M4 fair multiplayer -> M5 launch content/global localization -> M6 beta/release readiness.

Do not publish before critical data, gameplay, localization, policy, and performance checks pass and the owner explicitly approves.

## Reporting and permissions

Maintain `docs/STATUS.md`, `docs/TASKS.md`, `docs/DECISIONS.md`, and `docs/TEST_RESULTS.md` as implementation begins.

Each work batch reports: files changed, commands executed, tests actually run, blockers, and next task. Test statuses are `PASS`, `FAIL`, or `NOT RUN`.

Never publish, spend money, alter production data, delete unrelated work, or obtain secrets without appropriate authorization. Never request Roblox session cookies in chat.

Begin with workspace inspection and M0. Work toward an actual M1 build, not another general brainstorm. If Studio access is unavailable, deliver complete files and exact manual verification steps with runtime checks marked `NOT RUN`.
