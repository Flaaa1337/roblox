# Test results

Build/config version: `0.1.0-m1`, 2026-10-02, Linux dev container (no Roblox Studio).

| ID | Test | Result | Evidence |
|---|---|---|---|
| T01 | Fresh build with Rojo 7.6.1 | PASS | `build/AnomalyHeist.rbxlx` produced (1 Script, 1 LocalScript, 26 ModuleScripts, LocalizationTable) |
| — | Luau syntax compile of all `.luau` files | PASS | `luau-compile` on every file |
| — | Strict type analysis (luau-lsp 1.70.1 + Roblox definitions) | PASS | 0 diagnostics after fixes; it found and we fixed a real crash (`Theme.panel` colour overwritten by a function) and an ambiguous-syntax statement |
| — | Localization pipeline `tools/localization.luau --check` | PASS | 50 locales, 50 keys, placeholders consistent, all code keys exist |
| T02 | Server/client boot in Studio | NOT RUN | no Studio access here |
| M1 | Walk spawn -> portal -> Glitch Grove -> back | NOT RUN | needs Studio |
| T03 | Eight players get distinct bases | NOT RUN | |
| T29 | Slow streaming at portal | NOT RUN | |
| T44/T47/T48 | Fallback, long text, Arabic RTL layout | NOT RUN | pseudo-locales implemented, not yet viewed |
