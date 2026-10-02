# Status — 2026-10-02 (paused at the owner's request)

**Active milestone:** M1 (walkable space) — code complete, **not yet run in Roblox Studio**.
**Build:** `rojo build default.project.json -o build/AnomalyHeist.rbxlx` (Rojo 7.6.1, run in the dev container).
A copy for opening without Rojo: `../ANOMALY_HEIST.rbxlx` (repo root).

## Done
- M0: project tree, Rojo project, pinned tools (`rokit.toml`), `.gitignore`, pack docs.
- Localization: 50-locale manifest built from the official registry (fetched from Roblox/creator-docs on GitHub;
  create.roblox.com is blocked in this environment), US-English source (50 keys, 16 critical),
  draft translations for de-de, es-mx, fr-fr, pt-br, ar-001, ja-jp (unreviewed), CSV -> LocalizationTable,
  runtime resolver with fallback chain, Studio pseudo-locales ("long", "rtl").
- M1 code: deterministic WorldBuilder (hub 256x256, landmark, ring/spoke paths >= 14 studs, 8 base plots,
  1 active + 2 dormant portals), Glitch Grove (arrival, return portal, 2 extraction points, main/east/west routes,
  ruined lab, plateau with ramp/stairs, forest, boundaries, spawn/guardian/recovery markers), primitive
  Glitch Pigeon / Fridge Dog / Siren Toad, BaseService (8 plots), server-validated PortalService with
  streaming + fall-safety, client localization/HUD/input/effects.

## Not done yet
- Studio runtime test of M1 (walk spawn -> portal -> zone -> back), screenshots, small-screen + RTL check.
- Lune boot/portal smoke test for this project (the harness exists in ../tools for the other games, not yet adapted).
- Docs: SETUP, ARCHITECTURE, LOCALIZATION, TASKS details.
- M2+ (capture loop, persistence, PvP, content).

## Next step (owner, in Roblox Studio)
Open `ANOMALY_HEIST.rbxlx`, press Play, walk to the glowing portal north of spawn, press the prompt,
look around Glitch Grove, use the return portal. Send a screenshot of the Output window if anything is red.
