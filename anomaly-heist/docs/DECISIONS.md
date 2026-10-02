# Decisions

- D-001 Owner decision (overrides spec workflow): the owner does not use Rojo. Every delivery includes a
  ready-to-open place file (`ANOMALY_HEIST.rbxlx` in the repo root). Rojo is used only inside the dev
  environment to build it.
- D-002 Project lives in `anomaly-heist/` inside the existing repo; OVERBOARD and SCRAPFALL are untouched.
- D-003 Locale registry fetched from the public Roblox/creator-docs repository (create.roblox.com blocked here).
- D-004 Coverage status adds `pending` (no translations yet, English fallback) to source/draft/reviewed/blocked.
- D-005 Regional variants fall back to each other (en-gb->en-us, fr-ca<->fr-fr, es-es<->es-mx, pt-pt<->pt-br);
  scripts never cross (zh-cn and zh-tw do not fall back to each other).
- D-006 Lighting uses ShadowMap (not Future) for lower-end mobile performance.
- D-007 StreamingEnabled is on; portals request streaming and re-place players who fall.
- D-008 Number formatting keeps Western digits in every locale; separators are per language.
