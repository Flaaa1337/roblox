# ANOMALY HEIST - Global Roblox Build Specification

**Version:** 2.0 - Worldwide edition, October 2, 2026.  
**Document language:** English.  
**Game source language:** US English (`en-us`).  
**Audience:** International players; creative positioning for ages 13-24, not an assumed or verified audience distribution.  
**Status:** Implementation brief, not an implemented, tested, published, or commercially validated game.  
**Working title:** ANOMALY HEIST. Names and character designs require an ownership/trademark review before commercial release.

> Build an actual Roblox experience: a playable world, connected Luau systems, persistent collections, cross-device controls, worldwide localization, and evidence-based testing. Do not turn this assignment into another concept presentation, website, or pile of disconnected sample scripts.

---

## 0. Instructions to Claude

Act as the implementation lead for this project. Inspect the available workspace and tools, then create the required project files and implement the game in verifiable milestones. Preserve existing work. Do not repeatedly redesign the product instead of building it.

The ambition is a polished commercial-quality experience. Delivering an integrated slice first is a production gate, not a request for beginner-level quality. More simultaneous features are not a substitute for coherent gameplay.

### Instruction precedence

1. The owner's latest explicit decisions.
2. Player ownership safety, platform requirements, and technical correctness.
3. The locked decisions in this specification.
4. The final, simpler Roblox-style concept image.
5. Earlier brainstorming and spectacular promotional illustrations.

### Evidence and permission rules

- With filesystem access, create and edit real files. Without it, provide complete files and exact destination paths.
- Use a Studio integration only when it is actually available and authorized. Do not invent access to Roblox Studio, the owner's machine, or an external account.
- A Rojo build is not a runtime test. A static screenshot is not proof of multiplayer functionality. A concept image is not an in-engine screenshot.
- Record tests as `PASS`, `FAIL`, or `NOT RUN`, with their environment and actual observations.
- Never invent published asset IDs, purchase IDs, benchmark results, successful uploads, player counts, market shares, or earnings.
- Do not publish, spend money, modify production data, delete existing work, or install unreviewed software without appropriate approval.
- Do not ask for Roblox session cookies or secrets in chat. Use documented, appropriately scoped access only when required.
- Verify current API signatures and tool versions against official documentation before implementation. Links at the end are starting points, not permission to ignore later changes.
- Ask only genuinely blocking questions. Record reversible assumptions in `docs/DECISIONS.md` and continue.

### Existing setup

The owner has Roblox Studio and its Rojo plugin. Do not assume VS Code, the Rojo command-line tool, a repository, a project file, uploaded assets, or a connected Studio integration already exist. Do not assume the operating system from the owner's language or location.

Rojo needs its command-line/server component as well as the Studio plugin. A particular editor is not required. The project must exist before serving it. Follow the verified installation and project workflow in [R1-R4].

---

## 1. Locked product decisions

| Area | Decision |
|---|---|
| Platform | Roblox, native Luau gameplay and a real 3D environment |
| View | Third-person camera, familiar Roblox movement, R15 initially |
| Product identity | Capture unusual creatures, survive their transport effects, extract, collect, and evolve |
| Audience geography | Worldwide wherever Roblox and this experience can lawfully operate; the US is explicitly included |
| Source language | US English (`en-us`); not German-first |
| Localization scope | Every currently supported Roblox locale is in scope; no seven-language-only architecture |
| Server | Maximum 8 players and exactly 8 usable player bases |
| World | Safe social hub and clearly marked expedition areas |
| Initial deployment | One Place; portals move players between areas within that Place |
| PvP | Restricted to announced risk areas and unsecured expedition cargo |
| Ownership | Secured collections, base contents, and purchased cosmetics cannot be stolen |
| Inventory | Persistent items with immutable, server-created unique IDs |
| Monetization | Off during core development; deterministic cosmetics later |
| Paid randomness | Not part of this product; no paid eggs, luck boosts, random evolutions, or rerolls |
| Trading | Future feature, disabled at first release; not a fake functioning button |
| Art | Polished, readable Roblox-native style, not a cinematic render poster |
| Devices | Touch, keyboard/mouse, and gamepad; enable each release platform only after verification |
| First polished slice | 1 expedition area, 3 distinctive creatures, all 8 base slots, one complete gameplay loop |
| Public v1 content target | 3 expedition areas, 10 species, 2 evolution stages per species, 3 cosmetic mutation variants |

Do not reintroduce contradictions from the brainstorming: six bases for eight players, permanent theft of secured creatures, a keyboard-only interface, or a map that exists only in a picture.

---

## 2. Product promise and gameplay pillars

**One-sentence pitch:** Enter a strange zone, capture an anomaly, and get it home while its unusual behavior makes the escape harder.

**Core loop:**

`Hub -> expedition -> spot a creature -> capture -> carry -> evade hazards/rivals -> extract -> secure -> display/evolve -> choose the next expedition`

The experience must be enjoyable with no purchases, no extremely rare drops, and only one player online.

Four design pillars:

1. **The creature changes the run.** A pigeon that glitches, a refrigerator dog that makes movement slippery, and a noisy toad require different decisions.
2. **Readable risk.** Players understand when cargo can be lost and when ownership is safe.
3. **Visible collection identity.** Bases, evolution silhouettes, and individual animations make collections recognizable without covering the screen in effects.
4. **Accessible execution, meaningful mastery.** Simple input, better routes, timing, hazard understanding, and fair counterplay.

Market positioning is a hypothesis to test. Do not treat earlier chat claims about top-ten games, demographics, or visits as validated evidence. No claims that a demographic universally likes a genre, that a character will become a meme, or that discovery success is guaranteed.

---

## 3. Worldwide scope, including the United States

### 3.1 Worldwide is a product requirement, not a language shortlist

Design for players in the United States and Canada, Latin America and the Caribbean, Europe, Africa, the Middle East, South Asia, East Asia, Southeast Asia, and Oceania.

Do not equate a language with a country. A Spanish-speaking user may be in the US. A French-speaking user may be in Canada or Africa. An English-speaking user may be anywhere. Interface language must not decide prices, nationality, policy eligibility, or matchmaking region.

Supporting Chinese text does not establish availability in mainland China. Likewise, adding a locale does not guarantee distribution in every territory. Keep language support, platform distribution, and per-player policy eligibility as separate concerns. Platform restrictions must not be bypassed.

### 3.2 Supported-locale manifest

Use the official Roblox language-code registry as the source of truth [L2]. At implementation start, refresh it and create `localization/locale-manifest.json` with language code, locale ID, native display name, text direction, coverage status, and last review date.

The following 50 locale IDs appear in the registry checked for this brief. This is the target coverage set, not a claim that translations have already been written or approved:

```text
sq-al  ar-001 bn-bd  nb-no  bs-ba  bg-bg  my-mm  zh-cn  zh-tw  hr-hr
cs-cz  da-dk  nl-nl  en-us  en-gb  et-ee  fil-ph fi-fi  fr-fr  fr-ca
ka-ge  de-de  el-gr  hi-in  hu-hu  id-id  it-it  ja-jp  kk-kz  km-kh
ko-kr  lv-lv  lt-lt  ms-my  pl-pl  pt-br  pt-pt  ro-ro  ru-ru  sr-rs
si-lk  sk-sk  sl-sl  es-es  es-mx  sv-se  th-th  tr-tr  uk-ua  vi-vn
```

Use current documented language/locale mappings rather than guessing or mechanically stripping suffixes. For example, script-based Chinese language identifiers need deliberate handling. If Roblox adds or changes support, update the manifest and tests. Do not silently delete a language because it needs more QA.

Languages not supported by the platform registry must not be advertised as natively supported. Track additional translation requests separately and provide the English fallback while evaluating a compliant implementation.

### 3.3 Source strings and translation architecture

US English is the authored source and final safe fallback. Use short, internationally understandable sentences. Avoid US-only slang, memes that require English wordplay, and cultural references essential to understanding a mechanic.

Implement a `LocalizationController` and shared string schema. Stable identifiers such as `action.capture` and `error.inventory_full` must be independent of displayed words. Keep IDs and source code in English.

Use `LocalizationService` and translation tables for platform integration. Resolve text through a tested wrapper; translation failures must not stop gameplay. Handle language changes without duplicating UI or losing the current screen [L1, L3, L4].

Project fallback policy:

`selected supported locale -> configured language-level entry -> en-us source -> logged developer diagnostic`

The fallback adapter must map real supported IDs, not assume every language has identical regional behavior. Respect applicable Roblox translation settings; do not silently override a user's choice to disable automatic translation.

Every player-facing surface belongs in localization: tutorial, HUD, buttons, creature descriptions, world signs, error messages, cooldown instructions, collection pages, evolution requirements, shop copy, purchase results, settings, accessibility text, release notes, and experience metadata.

Never concatenate translated sentence fragments. Use parameters and complete message templates. Format quantities through a locale-aware adapter, with tested grouping, decimal, plural, and compact-number behavior. Roblox is not a browser: do not assume JavaScript `Intl` exists in Luau.

Example source keys, not a complete localization table:

| Key | US English source | Context |
|---|---|---|
| `objective.first_capture` | Bring your first anomaly home. | First objective |
| `action.capture` | Capture | Interaction label |
| `action.extract` | Extract | Extraction interaction |
| `action.drop` | Drop cargo | Intentional cargo release |
| `status.saving` | Saving your anomaly... | Persistence not yet confirmed |
| `status.secured` | Anomaly secured! | Display only after confirmed ownership |
| `warning.risk_zone` | Unsecured cargo can be stolen here. | Before entering PvP area |
| `info.safe_collection` | Your secured collection is safe. | Ownership explanation |
| `error.inventory_full` | Your collection is full. Make room before capturing. | No automatic item destruction |
| `error.translation_fallback` | Some text is shown in English. | Honest optional settings message |
| `evolution.requirement` | Extract this species {count} times. | Parameterized requirement |
| `settings.reduced_motion` | Reduced motion | Accessibility toggle |

Localized creature display names may differ, but `speciesId` never changes. Maintain a glossary with a plain-language description, tone, species silhouette, and a do-not-translate list. Names must remain pronounceable and distinguishable; never rely on a pun as the only explanation of an effect.

### 3.4 Layout and scripts

- Support long translations with flexible layout and wrapping. Test at least 50% text expansion; this is a project QA stress test, not an assumed expansion for every language.
- Test Arabic shaping, mixed-direction content, and right-to-left layout deliberately. Do not reverse raw strings. Mirror appropriate navigation/layout, not every icon or number indiscriminately.
- Verify CJK, Thai, Bengali, Hindi, Burmese, Khmer, Sinhala, Cyrillic, Georgian, and Latin diacritics on supported devices. Do not claim a bundled font solves every script without testing.
- Keep essential text out of textures. World signs use localizable GUI text or language-neutral symbols.
- Important controls need icon plus text. Color is never the only way to indicate danger, rarity, or button state.
- Compact money labels may differ by locale. Provide full values on an accessible details surface, not a mouse-only tooltip.
- Let translation context select grammatical order. Do not assume the English position of a number or species name works everywhere.

### 3.5 Translation delivery and honest status

For every locale, track `source`, `draft`, `reviewed`, or `blocked`, with completion percentages for critical strings and all strings. A manifest entry is not a finished translation.

Before global v1 release, all 50 current locale targets must have a translation path and tested fallback. Produce translation drafts for all critical strings, review them, and record remaining defects. Do not silently drop languages to ship a supposedly worldwide build. If coverage or review is incomplete, label the release as a beta and report the exact gaps.

Automatic translation availability is not identical to the full supported-locale list. Use Roblox automatic translation where supported, and import/manual translation workflows where needed [L1, L3]. Never mark unreviewed automated text as professionally localized.

Critical strings are objectives, danger/ownership warnings, errors affecting items, purchase descriptions, prices, and confirmation actions. These require explicit semantic review before enabling the corresponding high-risk feature in that locale.

### 3.6 Global operations

Make the base game available continuously. Schedule optional events in repeating UTC windows rather than a single evening in Germany or the US. Store event times in UTC, display locally, and make gameplay eligibility server-authoritative. Do not let local clock changes grant rewards.

Prefer repeating or catch-up opportunities to punitive daily streaks. The same obtainable gameplay rewards must not require logging in during school, work, or sleep hours in one region.

Test 50, 150, and 250 ms simulated network delay as project test profiles, plus loss and reconnection. These are test conditions, not assumed regional averages. Do not promise manual selection of Roblox data-center locations or deploy a custom matchmaking system before need is demonstrated.

Where allowed, use platform-provided aggregate analytics to compare onboarding, errors, and performance by locale/device. Do not collect birthdays, addresses, IPs, or private messages to infer audience segments. Follow current per-player policy signals instead of maintaining nationality-based guesses [P1].

---

## 4. Visual direction: something Roblox can actually render

### 4.1 Reference use

The companion pack contains `references/roblox_style_reference.png`: the last, more restrained concept collage. It is optional visual guidance, not an implemented game.

Keep the blocky silhouettes, daylight, readable paths, modular environment, and modest effects. Do not copy the image's spelling errors, arbitrary catch percentages, fake player rankings, or contradictory rarity labels.

Earlier neon-heavy posters are not the render target. Produce genuine Studio/client captures to evaluate the implementation. Do not use a generated illustration as a claimed gameplay screenshot.

### 4.2 Art specification

A compact research outpost mixed with an abandoned town: pale stone paving, concrete, muted metal, planters, cables, workshop props, simple trees, and a few striking portal rings.

Use neutral surfaces with controlled accents. Cyan marks safe equipment, violet marks anomalies, and orange marks hazards; supplement each with shapes/icons. Most of the frame should not glow.

Creatures use coherent low-poly geometry and one memorable silhouette feature each. Use simple opaque materials where possible. Reserve transparency for a small number of identifiable effects.

Hub lighting is daylight. Darker areas remain readable on a phone at low quality. Avoid excessive bloom, permanent screen shake, global motion blur, constant lightning, dense fog, and photorealistic monsters beside simple avatars.

Normal gameplay framing comes first: a standard third-person camera, visible feet and path, recognizable destination, readable interaction target, and uncluttered HUD.

### 4.3 Art production requirements

Provide a modular kit: floor sections, walls, doorways, ramps, stairs, railings, arch/portal segments, base pedestals, signs, crates, benches, trees, rocks, and workshop machines.

Use primitive Parts for the first working build. They must form a designed environment, not a bare baseplate with labels. Final hero creatures should receive proportion, silhouette, animation, and material passes.

Every hero species needs idle, capture response, carried loop, reveal, and display animations. A dramatic evolution must alter silhouette, not only increase particle count.

A premium-looking scene must still work with effects reduced or off.

---

## 5. Map and world layout

All dimensions below are starting design values in studs, not platform limits.

### 5.1 Hub

Approximately 256 x 256 studs, with a center landmark and eight 32 x 32 base plots distributed around an approximately 100-stud radius. Main paths are at least 14 studs wide. No mandatory precision jumping in safe areas.

At spawn, show the beginner portal and the player's base direction. Collection management, research/evolution, settings, and eventually cosmetics must be easy to reach. The future trading area is ordinary social seating while trading is disabled.

Create precisely eight base assignments, allocated and released by the server. Bases are views of player data, not the authoritative storage of that data. Empty slots must look intentionally vacant.

The hub is safe: no cargo theft, push attacks, destructive tools, or predatory spawn positioning.

### 5.2 Expedition areas

Use separated areas within the same Place first. Initial area widths are approximately 224-288 studs. Example centers are `(0, 0, 768)`, `(768, 0, 0)`, and `(-768, 0, 0)` relative to the hub; adjust after testing streaming and traversal.

| Area | Visual identity | Main gameplay demand |
|---|---|---|
| Glitch Grove | Green trees, damaged research devices, restrained violet glitches | Beginner routes, predictable guardians, readable extraction |
| Scrap District | Containers, repair bays, service alleys, ramps | Break sightlines; choose an open shortcut or a longer sheltered route |
| Void Station | Readable dark laboratory, suspended decorative pieces, geometric hazard lanes | Time movement through telegraphed hazards and higher-risk routes |

Each area needs a safe arrival point, two extraction points, alternative routes, clear boundaries, creature spawn markers, guardian paths, and recovery positions. A player must not need a purchase or an advanced movement exploit to reach an exit.

Build authored layouts first. Procedural room assembly can be added only after the authored routes have proven fun and navigable.

### 5.3 Portal safety

The server validates zone unlock, current state, and destination. The client shows a short transition while required nearby content becomes usable. Provide a timeout and safe fallback; never silently place the player in an unloaded void.

Use documented streaming behavior and tolerate objects streaming out [T1]. `StreamingEnabled` is an edit-time configuration, not a property to toggle from a runtime Script.

Keep portal transitions separate from inventory commits. Do not make teleport success the source of ownership.

---

## 6. First-session experience

These timings are design targets measured from when the player can control the character, not promises about network loading.

| Time | Experience |
|---|---|
| 0-10 seconds | See their base and one clear goal: bring an anomaly home |
| 10-25 seconds | Enter a personal/protected introduction route and notice a Glitch Pigeon |
| 25-45 seconds | Hold the capture action, pick it up, experience its announced glitch |
| 45-90 seconds | Reach the marked extraction point and secure the creature |
| Immediately after | Place it on a pedestal, see progress, choose another run |

The first creature is a guaranteed, explicitly authored introduction reward. Do not fake a rare random roll. Its `mutationId` is fixed to `normal`.

Save tutorial progress and use an idempotent starter grant. Rejoining, skipping hints, or replaying the tutorial must not duplicate rewards. Make instructions skippable and replayable without resetting earned progress.

No forced shop opening, purchase prompt, voice-chat requirement, external signup, or mandatory long cutscene. The first run must work without other players.

---

## 7. Capture, cargo, and extraction

### 7.1 Capture

Approach an eligible creature and hold interaction for about 1.2 seconds. The server verifies proximity, line of sight, player state, target state, zone, and inventory capacity. Reserve the target during capture and release it on interruption.

Do not implement the concept image's arbitrary 12% capture chance. Capture succeeds when its gameplay conditions succeed. The challenge is the route and escape, not a hidden paid-or-unpaid catch failure.

One unsecured creature per player. Reserve an inventory slot for it so another action cannot fill the inventory between capture and extraction.

### 7.2 Authoritative state machine

```text
Wild -> Reserved -> Carried -> Extracting -> Committing -> Secured
            |          |
            v          v
           Wild      Dropped -> Reserved -> Carried
```

Additional rules:

- Capture interruption returns `Reserved` to `Wild`.
- Extraction interruption before committing returns to `Carried`.
- Unsecured abandoned loot may expire to `Despawned`.
- `Committing` is exclusive: no stealing, dropping, recycling, or second commit.
- `Secured` items cannot return to the world-cargo state through a client request.
- Every transition has a server-checked state version and a single current owner/reservation.

Models and animations represent state; they never determine ownership.

### 7.3 Carrying

Display the creature in the avatar's arms or a compact harness. Keep the path and camera readable. Use a cosmetic carried representation rather than a chaotic collision-heavy assembly whose physics determines inventory ownership.

Effects must be telegraphed, bounded, and individually removable. Do not suddenly reverse all controls, teleport through walls, globally change gravity, or remove safe ownership as a joke.

Clean up effects on drop, extraction, death, character replacement, disconnect, and model removal. Preserve and restore prior movement modifiers through one centralized modifier system.

### 7.4 Extraction and confirmed ownership

Stand inside a valid extraction zone for about 2.5 seconds. The countdown may be interrupted. On completion, enter `Committing`, lock cargo, and submit one idempotent grant with stable item and grant IDs.

Display `Saving your anomaly...` until persistence confirms ownership. Only then show `Anomaly secured!`, award the extraction reward, and run the reveal. In any uncertain write result, reconcile the same identifiers; never generate a new item or reroll its mutation.

The persistence layer must define whether an operation is unsent, pending, committed, or failed. A disconnect during a write is not automatically a failed write. Rejoining must reconcile committed records and any deliberately persisted pending intent.

A full server crash before anything was durably recorded cannot be repaired from memory that no longer exists. Do not promise otherwise. The guarantee is that confirmed saved ownership is not intentionally discarded, and retries of the same known operation do not duplicate it.

### 7.5 Edge cases

A full inventory blocks capture before taking the creature. Reset/death before commitment does not produce a secured reward. Normal disconnect removes unsecured cargo under the documented abandonment rule; it is not a transfer mechanism.

When a save is unhealthy, block further ownership-changing operations and show a clear status. Do not load an empty profile over existing data or tell a player a creature is safe when that has not been confirmed.

---

## 8. Launch creature roster

Use original implementations and properly licensed assets. These working concepts are not legal clearance to use a name, third-party meme audio, anime design, logo, or another game's model.

| Stable ID | Display name | Shape | Transport behavior |
|---|---|---|---|
| `glitch_pigeon` | Glitch Pigeon | Gray pigeon with one segmented violet wing | Announces a short sideways glitch; move only to a validated free position |
| `fridge_dog` | Fridge Dog | Compact white refrigerator body, dog face, short legs | Brief cold-air burst introduces bounded sliding without removing steering |
| `siren_toad` | Siren Toad | Green toad with a speaker-like throat | Telegraphs a call that alerts nearby guardians and produces a visible sound ring |
| `cement_baby` | Cement Baby | Friendly small concrete figure with square proportions | Lowers jump height; every required exit route remains accessible |
| `tv_head` | TV Head | Small robot with a CRT-style face | Periodic scan briefly reveals the carrier within a limited local area |
| `nuclear_capy` | Nuclear Capy | Rounded capybara with luminous back panels | Charge meter rewards brief calm movement; overload causes only a short, bounded slowdown |
| `invisible_horse` | Invisible Horse | Visible hooves, bridle, subtle body outline | Predictable temporary acceleration changes; no invisible unfair combat hitbox |
| `astro_cat` | Astro Cat | Cat in a simple round space helmet | Announced low-gravity hop, with safe landing rules |
| `bubble_shark` | Bubble Shark | Small shark in a stylized translucent bubble | Announces a sideways push; collision checks prevent wall clipping |
| `void_wyrm` | Void Wyrm | Short dark segmented serpent with violet joints | Briefly attracts one bounded pursuer that timing and routes can counter |

Build Glitch Pigeon, Fridge Dog, and Siren Toad first. A separate slice spawn table uses only those implemented species, initially 50/30/20. Do not activate launch tables pointing at nonexistent content.

For each species deliver a configuration record, primitive fallback, final asset status, animation manifest, effect module, cleanup tests, localized description, collection portrait, and evolved-form plan.

---

## 9. Rarity, mutation, and evolution

Keep these independent:

- `speciesId`: identity and transport mechanic.
- `rarity`: base collection category for the species.
- `mutationId`: cosmetic variant.
- `evolutionStage`: earned development of the same item.

Evolution does not secretly change the item's origin rarity. A rare mutation does not increase PvP damage.

### 9.1 Initial distributions

Common: Glitch Pigeon. Uncommon: Fridge Dog and Siren Toad. Rare: Cement Baby, TV Head, and Nuclear Capy. Epic: Invisible Horse, Astro Cat, and Bubble Shark. Legendary: Void Wyrm.

Mutation weights: `normal` 85%, `neon` 12%, `glitched` 3%. Roll once on the server when world loot is created, store the outcome in its record, and keep it fixed through capture/drop/recovery. These are proposed tuning values, not market benchmarks.

| Launch area | Species spawn weights, totaling 100 |
|---|---|
| Glitch Grove | Glitch Pigeon 45; Siren Toad 30; Nuclear Capy 20; Invisible Horse 5 |
| Scrap District | Fridge Dog 40; Cement Baby 30; TV Head 25; Astro Cat 5 |
| Void Station | Bubble Shark 40; Invisible Horse 30; Astro Cat 20; Void Wyrm 10 |

These weights describe a spawn selection, not a player's probability per minute of obtaining an item. Population, competition, spawn cooldown, eligibility, and successful extraction affect acquisition.

### 9.2 Evolution

Two stages per species at v1: base and evolved. Requirements are visible, deterministic, and earnable: species extraction mastery, Resonance, and Research Shards.

Evolution retains the item UUID. Deduct costs and change stage in one authoritative profile operation. Retrying the same request cannot consume resources twice. Update pedestal, follower, inventory, and saved data consistently.

A Glitch Pigeon develops segmented wings; Fridge Dog becomes a compact rolling refrigeration unit; Siren Toad gains folding sound horns. Use controlled proportions instead of enormous auras.

No destructive random evolution, paid success chance, or secret reroll. Future stages require content and balance review.

---

## 10. Economy and progression

### 10.1 Resources

**Resonance:** earned soft currency.  
**Research Shards:** earned material from contracts and intentional duplicate recycling.  
**Research XP:** non-spendable progress used for zone eligibility.

No purchasable gameplay currency in v1. No real-money conversion. Store bounded integers; carry any production fractions in a controlled fixed-point accumulator.

### 10.2 Starting balance proposal

All numbers in this section are project tuning assumptions. Put them in versioned configuration, simulate them, and change them based on testing.

| Rarity | Resonance per successful extraction | Base production per displayed creature per online minute |
|---|---:|---:|
| Common | 50 | 2 |
| Uncommon | 70 | 3 |
| Rare | 100 | 4 |
| Epic | 140 | 5 |
| Legendary | 200 | 6 |

Evolved-form production multiplier: 1.25. Mutation multiplier: 1.0. Starting wallet: 20 Resonance. Start with 3 active production pedestals; cap at 8. Initial collection capacity: 60; earnable upgrades may raise it to a configured cap.

Pedestal 4-8 prices: 150, 400, 900, 1,800, and 3,500 Resonance. Example evolution costs by rarity: 250/400/650/1,000/1,600 Resonance and 5/8/12/18/25 Shards, plus 10 successful extractions of that species. These are not paid gates.

Give 10 Research XP per successful regular extraction. The tutorial grant is explicitly single-use and records whether it counts toward progression. Initial proposal: it counts once. Unlock Scrap District after 3 secured extractions; Void Station after 18 plus discovery of 6 species.

### 10.3 Production and active play

Online production only at v1. One central server scheduler calculates production; do not run an infinite loop per creature. Pause safely during profile write unavailability. Never use client clocks for rewards.

Production is a modest collection benefit, not the main reason to leave the game running. Simulate low-skill, average, and fast runs over 30 minutes, 2 hours, and 7 sessions. Compare active gains, idle gains, progression time, and currency sinks.

If passive income dominates the intended progression, rebalance it rather than add punishment for leaving. Do not introduce streak loss, hunger decay, paid recovery, or overnight chores to force retention.

### 10.4 Recycling and contracts

Recycling gives a stated, deterministic number of Research Shards. Favorited, equipped, displayed, pending, and transaction-locked items are excluded by default. Preview the affected items and irreversible outcome before confirmation.

Do not auto-delete new rare items. Duplicate handling must be understandable on touch and controller.

Contracts use actual play: extract a particular species, try a route, avoid a guardian, or visit another safe base. No requirement to buy, send external links, spam friends, or communicate outside allowed Roblox channels.

---

## 11. Bases, collection, and companions

A base contains active pedestals, a collection access point, a research/evolution station, a modest cosmetic customization surface, and room for visitors.

Display a maximum of 8 production creatures. Do not render every stored creature into the world. Collection previews should load on demand; close and release them when the menu closes.

One optional cosmetic follower per player, disabled or simplified in low-quality mode. It must not obstruct the camera, determine attack hitboxes, or grant a paid advantage.

Show each item's species, rarity, mutation, stage, favorite status, production contribution, and evolution requirements. Provide filters and sorting. Search must respect localized names while retaining stable IDs internally.

Visits are social viewing, not access to another player's inventory endpoints. Secure collection changes always require server-confirmed ownership.

---

## 12. Guardians and fair PvP

### 12.1 Solo-capable guardians

Use a small state machine: patrol, investigate, chase, attack telegraph, recover, return. Guardians create a meaningful run on an empty server.

Bound detection and chase distances. Use readable attack cues and recovery windows. Avoid frequent path recomputation for every NPC. Keep early guardian populations small and configurable.

### 12.2 Risk rules

PvP is off in the hub, introduction route, arrival protection, and every explicitly safe area. Entering a risk area displays a localized warning and persistent icon.

Only unsecured cargo is at stake. Do not steal stored creatures, charge a recovery fee, destroy paid cosmetics, or allow direct access to base storage.

Prototype two actions: **Dash** for escape and **Pulse** for short-range disruption. No weapon inventory or damage-stat arms race is needed for v1.

Starting PvP parameters, subject to playtest:

- Dash travels approximately 14 studs with collision checks and a 7-second cooldown.
- Pulse has approximately 8-stud reach, a visible wind-up, line-of-sight validation, and a 6-second cooldown.
- A carrier begins with 2 stability points. A valid Pulse removes 1; at zero, cargo drops.
- After a hit, grant approximately 2 seconds of disruption immunity. Restore stability after a defined hit-free interval.
- Newly dropped loot has a short shared pickup delay to prevent zero-frame pickup exploits.

The server resolves timing and eligibility. Account for legitimate movement mechanics and latency; do not permanently punish a player from a single movement anomaly [S1, S2].

### 12.3 Anti-grief design

Ensure more than one exit route. Prevent camping within arrival protection and extraction-safe boundaries. Provide defensive options that do not require payment. Watch repeated targeting and abandonment metrics during testing.

Never make a no-cargo player a profitable victim. Do not reward farming the same new player. Separate safe extraction completion from any celebratory animation.

---

## 13. UI, controls, and accessibility

### 13.1 Required screens

Loading/status, onboarding, gameplay HUD, cargo status, extraction progress, collection, item details, base arrangement, evolution confirmation, zone selection, contracts, settings, and clear error states.

A cosmetics shop appears only when fully implemented and authorized. Trading stays hidden while disabled. Do not display working-looking controls that do nothing.

The HUD prioritizes current objective, cargo condition, extraction direction, action availability, and currency. Defer complex collection statistics to their screen.

### 13.2 Action-based input

Use a project input layer over documented Roblox cross-platform input APIs [I1]. Keep action names separate from hardware keys. The suggested mappings below must be checked against native controls and accessibility needs:

| Action | Keyboard/mouse proposal | Touch requirement | Gamepad requirement |
|---|---|---|---|
| Move / camera / jump | Native Roblox controls | Native controls | Native controls |
| Capture / interact | E or native proximity prompt | Large contextual hold button | Contextual action with correct glyph |
| Dash | Q | Thumb-reachable action | Dedicated binding |
| Pulse | F | Separate contextual action | Dedicated binding |
| Drop cargo | G, with deliberate confirmation/hold | Deliberate hold | Deliberate hold |
| Collection | B | Persistent reachable button | Menu binding and full focus navigation |
| Menu back | Esc where appropriate | Visible back button | Platform-appropriate back action |

Do not hardcode keyboard letters in tutorials or text. Display bindings according to the current input device, including when switching devices mid-session. Never replace native jump with an unrelated action.

Every important flow must work without hover, right-click, dragging precision, chat input, or a physical keyboard. Disable gameplay actions while their corresponding UI context is active.

### 13.3 Accessibility and performance settings

Offer reduced motion, screen-shake intensity including zero, effects quality, separate audio controls, and clear high-contrast interaction cues. Use captions/visual indicators for important sound events.

Critical touch targets should be comfortably usable on a small landscape phone; start with a 48-pixel design target at the reference UI scale and verify physically. Test safe areas, notches, long translations, gamepad focus order, and large text.

Avoid rapid full-screen flashes and repetitive intense strobing. A creature's mechanic must remain understandable when its decorative effects are disabled.

---

## 14. Project architecture

Use native Luau with `--!strict` in maintained gameplay modules where practical. Favor explicit, small modules and documented dependencies over unnecessary frameworks.

Choose and pin tools only after inspecting the environment. Existing compatible choices take precedence over installing another framework. Do not pin fictional versions.

Suggested source layout; create files as their milestone requires them, not as empty active services:

```text
anomaly-heist/
  CLAUDE.md
  README.md
  default.project.json
  .gitignore
  toolchain manifest and lockfile, when used
  docs/
    BUILD_SPEC.md
    SETUP.md
    ARCHITECTURE.md
    NETWORK.md
    DATA.md
    ART.md
    LOCALIZATION.md
    TEST_PLAN.md
    TEST_RESULTS.md
    STATUS.md
    TASKS.md
    DECISIONS.md
    RELEASE_CHECKLIST.md
  localization/
    locale-manifest.json
    source.en-us.json
    glossary.md
    coverage.json
    translations/
    generated/Localization.csv
  src/
    shared/
      Types.luau
      Config/
        GameConfig.luau
        CreatureDefinitions.luau
        ZoneDefinitions.luau
        EconomyConfig.luau
        FeatureFlags.luau
      Net/
        Contracts.luau
        ErrorCodes.luau
      Util/
        Cleanup.luau
        Signal.luau
        NumberFormat.luau
    server/
      Bootstrap.server.luau
      Services/
        PlayerDataService.luau
        WorldService.luau
        BaseService.luau
        CreatureService.luau
        CaptureService.luau
        CargoService.luau
        ExtractionService.luau
        EconomyService.luau
        EvolutionService.luau
        GuardianService.luau
        CombatService.luau
        PolicyServiceAdapter.luau
        TelemetryService.luau
      Persistence/
        ProfileRepository.luau
        Schema.luau
        Migrations/
      World/
        WorldBuilder.luau
        PrimitiveCreatureFactory.luau
        ZoneLayouts.luau
    client/
      Bootstrap.client.luau
      Controllers/
        InputController.luau
        HUDController.luau
        CollectionController.luau
        CargoController.luau
        EffectsController.luau
        LocalizationController.luau
        SettingsController.luau
      UI/
        Components/
        Screens/
    server_assets/
    shared_assets/
  tests/
    unit/
    integration/
    scenarios/
    fixtures/
  tools/
    build.ps1
    build.sh
    validate-config script
    validate-localization script
    simulate-economy script
  references/
    roblox_style_reference.png
  build/
```

`ProfileRepository`, `Signal`, and the other project module names are proposed project code, not claims that these are Roblox built-in services. Use a reviewed library where appropriate, but document its exact version/license and do not mix competing profile-ownership systems.

Map `src/shared` into `ReplicatedStorage.Shared`, server code into `ServerScriptService`, client code into `StarterPlayerScripts`, private templates into `ServerStorage`, and the generated localization table into the selected replicated localization location. Respect Rojo file conventions and verify `.luau` support with the installed version [R3, R4].

### 14.1 Ownership of files and Studio objects

Declare which trees are source-controlled and which assets are authored in Studio. Do not overwrite unsaved hand-built content by syncing a broad replacement tree. Export/version necessary authored models and document the handoff.

Do not claim every asset property can live-sync. Some content requires a rebuilt Place or a Studio import path [R4]. Keep credentials and production configuration out of replicated source.

### 14.2 Startup and lifecycle

Explicit initialization sequence: config validation -> remotes/contracts -> data layer -> world -> core gameplay services -> client readiness.

Use a documented `Init`/`Start` pattern or equivalent. Avoid circular dependencies, uncontrolled top-level yields, and indefinite `WaitForChild` calls on optional content.

Each player and character receives scoped cleanup. Track and dispose event connections, timers, temporary effects, camera overrides, previews, and reservations.

A critical initialization failure must be reported clearly and safely block affected gameplay, not leave half-active inventory operations.

---

## 15. A reproducible world and asset pipeline

### 15.1 No invisible manual work

The first build must be playable without external meshes. Implement a deterministic `WorldBuilder` that creates the hub, eight bases, portals, one complete zone, extraction areas, guardian paths, spawn markers, and primitive versions of the first three creatures.

World generation must be idempotent inside an explicitly owned folder. Re-running it must not duplicate the entire map or erase unrelated Studio work. Include an owner-approved edit-time bake path if the team needs to inspect geometry before Play.

Runtime generation is acceptable for the first build, but document that an unopened Place may show only its bootstrap content until Play. Do not claim a fully hand-authored map exists when the world is generated at runtime.

### 15.2 Asset manifest

Track `assetKey`, source file, creator/license, import settings, experience/group ownership, published asset ID if real, fallback, moderation status, and final/placeholder status.

Missing meshes, animations, icons, or sounds must have intentional fallback behavior. Do not substitute random untrusted Toolbox scripts. Audit third-party assets before use.

Public production assets need actual upload/permission checks. Keep paid uploads and external purchases approval-gated. No copied meme audio or ripped copyrighted game assets.

### 15.3 Visual acceptance set

Capture actual in-engine views of the hub, beginner route, capture interaction, carried creature, extraction, player base, collection menu, and evolved creature. Include one mobile-size HUD capture and one low-effects capture.

A visual reference does not authorize adding new systems. The art review measures coherence, readability, and feasibility, not resemblance to an impossible cinematic render.

---

## 16. Server authority and network contracts

Clients request intentions. Servers resolve truth. Currency, ownership, drops, cooldowns, costs, progression, evolution, and purchase grants never come from a client-trusted value.

Validate remote types, identifiers, ranges, state, permissions, proximity, and frequency. Treat prompts and touch-triggered actions as untrusted inputs too. Reject non-finite numbers, unreasonable payloads, and malformed tables [S1].

Initial remote contract proposal:

| Request | Minimal client intention | Server responsibilities |
|---|---|---|
| `BeginCapture` | Target ID and request ID | Eligible target, distance, LOS, empty cargo, inventory slot |
| `CancelCapture` | Current request ID | Release only this player's valid reservation |
| `RequestDrop` | Current cargo ID | Correct owner, valid state and drop position |
| `BeginExtraction` | Extraction point ID | Cargo ownership, location, state, profile health |
| `RequestDash` | Bounded direction | Cooldown, permitted motion, collision, current modifiers |
| `RequestPulse` | Bounded aim intent | Range, LOS, target eligibility, zone, cooldown |
| `AssignPedestal` | Item ID and slot ID | Ownership, slot availability, no lock conflict |
| `RequestEvolution` | Item ID and request ID | Requirements, costs, ownership, idempotency |
| `RequestRecycle` | Item ID list and request ID | Limits, protected items, ownership, explicit confirmation |
| `UpdateSettings` | Allowlisted key/value | Valid value and bounded write frequency |

Responses use error codes and typed data; the client localizes messages. Avoid broadcasting private profile data. Send snapshots when needed and bounded deltas thereafter, not the full inventory every frame.

Set explicit server rate budgets per action and per player. Do not treat a suggested throttle number as secure without load testing. Derive sender identity from the remote callback, never a user-supplied UserId.

Prevent the effect system from becoming a broadcast amplifier. Decorative visual responses are client-rendered from validated server events, with local quality and distance limits.

---

## 17. Persistence and ownership safety

### 17.1 Profile schema

Define a versioned schema, for example:

```text
schemaVersion
profileRevision
currency: resonance, researchShards
progress: researchXP, securedExtractions, discoveredSpecies, speciesMastery
inventory: itemId -> item record
base: unlockedPedestals, pedestalAssignments, cosmeticSelections
settings: localeOverride, reducedMotion, effectsQuality, audioLevels
tutorial: step, starterGrantApplied
operations: durable idempotency records with a documented retention policy
commerce: entitlements and receipt records when commerce is introduced
```

Item record:

```text
itemId, speciesId, rarity, mutationId, evolutionStage,
createdAtUtc, originalOwnerUserId, acquisitionGrantId,
favorite, schemaVersion
```

Use stable server-generated IDs. Do not store Instances, live connections, or transient world positions as an ownership model. Keep counters bounded and reject unsupported schema values.

### 17.2 Repository strategy

Use `DataStoreService` behind a tested repository abstraction. Separate development, staging, and production namespaces. Studio test access must not point at production collections [D1].

Choose a reviewed session-ownership solution or implement and test a lease/lock protocol with revision/fencing checks. Merely calling `UpdateAsync` does not make an entire economy concurrency-safe. Never have two independent modules overwriting the same profile.

Serialize ownership-changing operations per profile. Use pure, non-yielding update transformations and bounded retries; handle throttling and transient errors deliberately [D1, D2].

The operation ID and outcome must be persisted together with the inventory/currency change. Do not mark an operation complete only in server memory.

### 17.3 Invariants

- An item UUID appears at most once in a player's inventory.
- World cargo has one authoritative state and carrier.
- One grant ID yields at most one item and its associated extraction reward.
- An evolution or recycle request charges/removes once.
- Item state and related resource changes commit together within their profile operation.
- No external side effects run inside a retryable data transformation.
- A load error never becomes permission to replace an existing account with an empty profile.
- Confirmed secured items remain present after reconnect.
- `Committing` items cannot be traded, recycled, dropped, or assigned twice.
- A missing or expired session lease prevents further writes by the old owner.

Design the lifecycle of operation records; an unbounded table of every request is not an acceptable long-term solution. Do not prune purchase receipts or grant tombstones while a legitimate replay can still re-grant them. Document retention and reconciliation before enabling the related feature.

### 17.4 Saving policy

Use a central autosave scheduler with jitter and budget awareness. Explicitly checkpoint high-value ownership operations. Shutdown saving is best effort, not a substitute for earlier durable commits.

Document which low-value display/production changes may await an autosave and the maximum intended unsaved interval. Do not imply every animation frame is durable.

Test load failure, ambiguous write completion, duplicate request, disconnect during commit, stale server ownership, migration, and simulated process termination. If a hard-crash test cannot be performed, record it as not run.

### 17.5 Migrations and recovery

Create migration fixtures for older schemas. Preserve owned items and balances; never silently reset on migration error. Keep a rollback/recovery plan for a bad release. Do not edit live data to make a test pass.

---

## 18. Monetization suitable for the worldwide product

Commerce is disabled until core fun, persistence, localization, and platform-policy gates pass.

Initial permitted offers: clearly described base themes, capture-device appearances, nameplate styles, and cosmetic reveal effects. Effects cannot obscure opponents or give a meaningful gameplay advantage.

Use passes or another appropriate documented entitlement mechanism for permanent one-time benefits. Use developer products only for genuinely repeatable purchases, with a durable, idempotent `ProcessReceipt` implementation before activation [M1].

Never grant a developer-product purchase based only on a client purchase-completed callback. A failed or ambiguous save must not become a confirmed grant.

### 18.1 Global pricing

Fetch and display current player-appropriate Robux prices through the documented marketplace flow. Do not hardcode USD, EUR, a screenshot price, or one supposedly universal Robux price in UI or textures. Use current regional/managed-pricing tools where appropriate and test actual displayed prices [M2].

A user's language does not determine economic location. Let Roblox's supported systems determine applicable pricing; do not infer it from the locale manifest.

Purchased cosmetics are account-bound in v1. Do not add gifting or transfer paths that create cross-region price arbitrage. Any future transfer feature requires its own pricing and policy review.

### 18.2 Product restrictions

No paid randomness, paid luck, random paid evolution, paid theft protection, pay-to-win speed, or paid recovery of a stolen item. Earned currencies cannot be bought to indirectly turn an apparently free random mechanic into paid randomness.

Do not use fake urgency, misleading discounts, fake limited stock, or purchase prompts aimed at a frustrated player who just lost a run.

Use current `PolicyService` eligibility where features require it. If policy lookup fails, fail closed for the affected optional feature while keeping the safe core game available [P1, P2]. A country list or age guess is not a replacement.

---

## 19. Trading and later expansion

### 19.1 Trading is not part of the first public release

Keep its feature flag off on both server and client. Preserve item provenance and extensible data structures, but do not expose active trade endpoints before implementation and tests.

A future trading milestone requires: clear offers; item locking; two-stage confirmation; acceptance reset after every offer change; disconnect recovery; durable trade IDs; auditability; policy checks; and anti-duplication tests.

Two separate player `UpdateAsync` calls do not constitute a proven atomic trade. Specify a recoverable transaction/journal protocol, including recovery after either participant's write, before implementation. No item may be both tradable and eligible for another ownership-changing action.

Do not mix tradable paid items into an unpaid collection system without tracing their provenance and policy requirements.

### 19.2 Explicitly deferred

Cross-server trading, auctions, guilds, raids, ranked combat, infinite procedural worlds, real-world commerce, user-uploaded content, voice-specific gameplay, paid subscriptions, and a multi-Place architecture.

These may be considered after the actual v1 loop is healthy. Do not install inactive half-systems that complicate the first release.

---

## 20. Performance and networking budgets

These are initial project engineering targets, not Roblox guarantees or claims that they have been measured.

| Area | Initial target / test |
|---|---|
| Lower-end mobile | Stable 30 FPS target on a named real baseline device at low effects |
| Mainstream desktop | 60 FPS target on a recorded reference configuration |
| Server occupancy | Profile at 1, 2, and 8 players |
| NPC/content load | Test planned peak population plus one controlled stress case |
| Network delay | Test 50/150/250 ms profiles and loss/reconnect cases |
| Session stability | Minimum 30-minute soak, followed by longer beta testing |
| Lifecycle cleanup | At least 10 respawns, 10 zone transitions, and repeated menu open/close |
| UI | Small landscape phone, tablet, desktop, and gamepad navigation |
| Effects | No gameplay failure when decorative particles and shake are disabled |

Choose realistic device baselines before claiming targets have been met. Record actual device, graphics settings, resolution, client/server conditions, memory, frame time, and content load. Studio emulation alone does not prove mobile performance [Q1].

Use streaming, reuse meshes/textures, limit transparency overlap, bound lights and particles, and keep collision complexity low [T1, T2]. Do not keep every model permanently streamed just to hide lifecycle bugs.

Keep static geometry anchored. Avoid one Humanoid per decorative pet and per-frame loops per pedestal. Centralize periodic updates and reduce distant cosmetic work.

Use bounded asset preloading for what the first run needs, not the entire catalog. Do not lock the player behind a fake progress bar until all cosmetics load.

If performance is poor, profile the actual scene before guessing. Record a performance budget change in `docs/DECISIONS.md` instead of silently lowering quality on every platform.

---

## 21. Analytics and balance validation

Use documented economy, funnel, and custom event capabilities [A1, A2]. Verify quotas and schemas during implementation. Missing analytics must never break saving or gameplay.

Project event vocabulary:

```text
onboarding_started
first_creature_seen
first_capture_started
first_capture_completed
first_extraction_committed
first_pedestal_assigned
first_upgrade_completed
zone_unlocked
run_started
run_ended
cargo_dropped
pvp_encounter_resolved
item_evolved
item_recycled
localization_fallback
profile_load_failed
profile_commit_retry
```

Events describing rewards come from authoritative results. An extraction attempt and a durable extraction success are different events. Use bounded categorical dimensions; do not send a unique item ID as an analytics category.

Measure onboarding completion, time to first successful run, run duration, extraction success, repeat targeting, losses immediately followed by exits, active versus passive income, crash/error patterns, locale fallback frequency, and input/device friction.

Report sample size and observation period. Do not invent target retention percentages, conversion rates, revenue, or ranking guarantees. Compare cohorts carefully; small samples and acquisition sources can distort conclusions.

Do not rely only on a session-end event: abrupt exits may prevent it. Build funnels from milestone events and available platform metrics.

---

## 22. Safety, content, and international accessibility

Keep humor absurd rather than humiliating or dependent on stereotypes. Use fictional science, cartoon danger, and stylized non-graphic conflict. The audience positioning does not mean the game may bypass content-maturity rules.

Use `TextChatService` for allowed text communication and preserve its filtering and permission behavior [C1]. Do not make a custom chat, sign, naming, or ping system that bypasses platform communication restrictions. The v1 loop must remain playable with chat unavailable.

Avoid free-form player-written base signs or creature names at launch. If added later, design the required filtering and reporting workflow before release.

No required external community signup, private contact sharing, invasive profile collection, or unmoderated user uploads. Do not ask players to provide their age in a custom form.

Review localization for unintended slurs, religious/political symbolism, distressing content, confusing purchase language, and cultural references that impair comprehension. Do not make claims of universal legal compliance from localization alone.

The owner must complete current publishing, maturity, permissions, and distribution steps accurately. Optional eligibility-restricted features must be independently switchable.

---

## 23. Feature flags and configuration discipline

Maintain server-authoritative flags for PvP, commerce, trading, live events, mutation generation, experimental movement, and asset rollouts. Defaults are conservative; commerce and trading start false.

The client may display flags but never enable server capabilities. Disabling an ownership-changing feature must also disable its request handlers.

Validate config on startup: known species, existing assets/fallbacks, valid zone references, spawn weights, bounded currencies, valid evolution recipes, and supported locale IDs.

Use a slice content profile until all launch species exist. Do not let one unknown creature definition cause a live player's inventory to be deleted; quarantine and report invalid content safely.

Balance/config versions must be included in test results. Paid-offer changes, migrations, and feature enabling are release decisions, not silent background actions.

---

## 24. Implementation milestones and acceptance gates

### M0 - Environment and reproducible foundation

Inspect workspace, operating system, available tools, and existing files. Create a working Rojo project, setup guide, build scripts, compact `CLAUDE.md`, source layout, and status log. Establish English source strings and the all-locale manifest immediately.

**Pass:** A real Place build is produced by an actually run command, or the exact unexecuted command is clearly marked when tools are unavailable. No hidden manual dependencies. Do not claim a successful build without an output file.

### M1 - Walkable, visually coherent Roblox space

Implement deterministic hub/zone building, eight plots, clear routes, primitive first-three creatures, camera/input integration, and initial localized HUD.

**Pass:** A player can walk from spawn through a portal to the first zone and return. A genuine Studio capture shows the intended Roblox-native look. Small-screen UI and one long-text/RTL test reveal no blocking layout issue. Record any Studio test still pending.

### M2 - One excellent complete run

Implement capture, one-slot cargo, all three distinct effects, guardians, extraction state, reveal, base display, and tutorial. Use a clearly labeled in-memory test adapter only until persistent storage is added; never present it as saved progress.

**Pass:** The three species create different playable escapes. A solo player completes the run. Capture conflicts and cleanup behave correctly. No shop is required.

### M3 - Durable progression and economy

Implement profile ownership, migrations, idempotent extraction/evolution/recycling, pedestal production, resource spending, and rejoin behavior. Run an economy simulation and record actual results.

**Pass:** Confirmed items survive rejoin; duplicate operations grant once; simulated failures do not produce empty-profile overwrites. Persistence limitations are documented. Nothing may go public before this gate.

### M4 - Fair multiplayer risk

Enable validated Dash/Pulse interactions, risk-zone boundaries, stability/drop rules, arrival protection, and eight-player occupancy.

**Pass:** Multiple clients can contest unsecured cargo without duplication or theft of secured collections. High-latency cases do not produce obvious unfair state changes. A controller/touch player can execute the core actions.

### M5 - v1 content and worldwide presentation

Expand to ten species, three authored zones, two stages per species, final visual polish, all-source-string extraction, translation drafts across all supported locales, correct fallback, accessible settings, and localized metadata.

**Pass:** No launch table references absent content. Coverage and review status are reported for every locale. Fonts, long text, RTL, numbers, and device layouts are tested. Unfinished translations are not represented as reviewed.

### M6 - Closed beta, operations, and release readiness

Complete real-device profiling, longer soak tests, error review, data recovery exercises, release/rollback documentation, platform setup, and permitted distribution settings. Test cosmetic purchases only after their separate gate and explicit owner approval.

**Pass:** Critical gameplay, data, policy, localization, and device failures are resolved. Remaining limitations are disclosed. The owner explicitly approves publishing.

### M7 - Post-launch improvements

Prioritize observed defects and confusing/failing flows before adding more monetization or complexity. Trading and larger live events require separate specifications and acceptance gates.

Do not give an unqualified completion date before understanding asset production, available Studio access, and integration work.

---

## 25. Test matrix

For every test record: ID, build/config version, date, environment, expected result, actual result, evidence, and `PASS`, `FAIL`, or `NOT RUN`.

| ID | Scenario | Required result |
|---|---|---|
| T01 | Fresh checkout/build | Reproducible build without hidden local files |
| T02 | Server/client boot | Ready state consistent; no unexplained startup errors |
| T03 | Eight players join | Eight distinct bases, no double assignment |
| T04 | Solo server | Complete capture/escape/extraction loop works |
| T05 | Simultaneous capture | Exactly one reservation/carrier |
| T06 | Remote capture through wall/far away | Rejected without state change |
| T07 | Capture canceled/move away | Reservation and slot release correctly |
| T08 | Full inventory | Capture blocked before cargo is taken |
| T09 | Second capture while carrying | Rejected with useful localized message |
| T10 | Duplicate extraction requests | One item and one reward |
| T11 | Death/reset before commit | No secured free grant; clean world state |
| T12 | Disconnect before commit | Documented abandonment behavior, no duplication |
| T13 | Disconnect during commit | Stable operation ID reconciles correctly |
| T14 | Ambiguous write/timeout | No false success or repeat grant |
| T15 | Rejoin after confirmed save | Same secured item exists |
| T16 | Concurrent profile sessions | Old/non-owner session cannot overwrite |
| T17 | Retried data transform | No repeated external side effect |
| T18 | Failed profile load | Existing profile not replaced with empty state |
| T19 | Evolution replay | One charge, one stage change, same UUID |
| T20 | Protected-item recycling | Favorite/display/lock exclusions respected |
| T21 | Use another player's pedestal/item | Rejected |
| T22 | Pulse in safe zone | No hostile effect |
| T23 | Pulse on ineligible/no-cargo target | No profitable theft effect |
| T24 | Drop plus simultaneous pickup | Single cargo owner, no duplication |
| T25 | Attempt theft of secured item | Impossible through cargo endpoints |
| T26 | Remote spam/malformed/non-finite input | Bounded rejection without instability |
| T27 | Legitimate dash/portal under latency | No erroneous permanent punishment |
| T28 | Creature effect interrupted | Movement/camera/physics fully restored |
| T29 | Slow streaming at portal | Safe wait/fallback; no empty-world fall |
| T30 | Touch-only full loop | No keyboard dependency |
| T31 | Gamepad-only menus and loop | Correct focus, prompts, back behavior |
| T32 | Switch input device mid-session | Prompts and action mapping update |
| T33 | Thirty-minute soak | No persistent growth from leaked tasks/effects |
| T34 | Repeated respawn/zone/menu transitions | No duplicate controllers/connections |
| T35 | Old profile migration | Inventory and currencies preserved |
| T36 | Analytics unavailable | Gameplay/persistence still function |
| T37 | Missing external asset | Intentional fallback, no startup break |
| T38 | Disabled trading/commerce | Endpoints off, no misleading live buttons |
| T39 | Missing purchase ID | Offer unavailable, no fabricated purchase |
| T40 | Repeat receipt/save error, when enabled | Exactly one durable entitlement/grant |
| T41 | Invalid content configuration | Clear validation error, no destructive reset |
| T42 | US English account | Natural US English source, correct controls/prices |
| T43 | UK English / French / Portuguese / Spanish variants | Correct configured regional fallback |
| T44 | Missing translation/service failure | English fallback, no raw key or crash |
| T45 | Change language while playing | Current state preserved and UI refreshed |
| T46 | All manifest locales | Locale resolves or explicit documented block |
| T47 | Long strings on small phone | Critical content/actions not clipped |
| T48 | Arabic and mixed-direction text | Correct shaping, legible ordering, usable layout |
| T49 | CJK/Indic/Thai/other script samples | Legible glyphs, wrapping, no missing essential text |
| T50 | Localized number/time output | No misleading quantity or event deadline |
| T51 | Regional price display | Actual applicable price, not cached universal copy |
| T52 | Policy response fails/restricts feature | Affected optional feature off; core play continues |
| T53 | No chat permission | Core loop works; no communication bypass |
| T54 | UTC event / clock spoof | Same server eligibility; local display only |
| T55 | Reduced motion / sound off | Required cues remain understandable |
| T56 | Global release metadata | No claim of completed translations beyond evidence |
| T57 | Stale profile lease mid-operation | Old writer blocked and safe UI state |
| T58 | Run-to-production balance | Measured active play remains meaningful |
| T59 | Mutation across drop/recovery | Original rolled identity preserved |
| T60 | Purchase or item success localization | Confirmation only after actual authoritative success |

Inject failures at ownership transitions, not only in the normal success path. Include at least one fresh tester who does not already know the design. For localization, use qualified review where semantic correctness is important; do not invent reviewer approval.

---

## 26. Build commands and Studio handoff

Create the required files before showing commands that depend on them. The following examples assume the Rojo CLI is available on PATH and `default.project.json` exists.

Windows PowerShell:

```powershell
Set-Location "C:\Projects\anomaly-heist"
New-Item -ItemType Directory -Force -Path build | Out-Null
rojo --version
rojo build default.project.json -o build/AnomalyHeist.rbxlx
rojo serve default.project.json
```

Without a PATH entry, use the actual installed executable location:

```powershell
& "C:\Tools\Rojo\rojo.exe" serve default.project.json
```

macOS/Linux shell for the CLI workflow:

```sh
cd /actual/path/to/anomaly-heist
mkdir -p build
rojo --version
rojo build default.project.json -o build/AnomalyHeist.rbxlx
rojo serve default.project.json
```

These shell examples do not imply Roblox Studio runs natively on every CLI platform. Document the actual supported Studio environment being used.

If starting from an empty folder, either create this specification's project files directly or use the documented `rojo init` workflow in a new location. Never run initialization over valuable existing files blindly [R1, R2].

The handoff must explain: where the Place file is, how to open it, what is generated at runtime, how the Studio plugin connects to the local server, which trees sync, how to start solo/multi-client tests, where to read Output, and how to reproduce a failed test.

Explicit manual/owner steps include:

- Experience owner/group and development/staging/production Place IDs.
- Maximum players, avatar configuration, platform support, and content maturity.
- Streaming and other edit-time settings.
- Non-production DataStore test access and asset permissions.
- Source language, supported languages, translation import, metadata, and translation review.
- Any actual pass/product creation and pricing configuration.
- Publishing approval and rollback/version management.

Do not fabricate a `.rbxlx` file by renaming a text document. Do not tell the owner to run `rojo serve` from an arbitrary folder containing only `rojo.exe` and no project.

---

## 27. Definition of done and delivery artifacts

A release-ready claim requires a real build, verified runtime behavior, and recorded results. A playable development build may still have clearly marked placeholders and blocked release tasks.

Required final project deliverables:

1. Complete source, pinned/reproducible tooling, and valid Rojo mapping.
2. Actually built Place artifact, when the environment can produce it.
3. Playable world and integrated capture-to-collection loop.
4. Asset manifest and explicit placeholder/upload/permission status.
5. Versioned data schema, network contracts, migration and recovery documentation.
6. Global localization source, all-locale manifest, translation coverage/review status, and generation/import tools.
7. Cross-input controls, accessibility settings, and actual device/performance evidence.
8. Test suite/scenarios, real test results, and unresolved issue list.
9. Exact Studio/Creator Dashboard setup and release checklist.
10. Honest completion summary: implemented, tested, not tested, blocked, next action.

Missing optional uploaded assets may use fallbacks in a prototype. Missing validation must not be relabeled as a finished production launch.

---

## 28. How to work across implementation sessions

Keep `docs/STATUS.md`, `docs/TASKS.md`, `docs/DECISIONS.md`, and `docs/TEST_RESULTS.md` current. Include the active milestone, last working build command, actual tool versions, current issues, and next concrete task.

The root `CLAUDE.md` should remain a compact, high-signal entry point; store this detailed specification in `docs/BUILD_SPEC.md`. Claude Code's documented guidance favors concise project instructions and placing task-specific detail outside the always-loaded overview [K1].

After each meaningful implementation batch, report files changed, commands actually executed, tests actually run, unresolved blockers, and the next task. Never present unexecuted tests as successful.

Do not ask the owner to repeat decisions that this brief already settles. Do not stop at a new architecture diagram when an implementation step is feasible. Conversely, do not fill critical systems with TODO stubs and call the milestone complete.

**Begin with M0, then work toward a real walkable M1 build.** Without runtime access, deliver the complete buildable files and exact Studio verification steps, with the runtime tests clearly marked `NOT RUN`.

---

## 29. Official technical references

Checked for this brief on October 2, 2026. These sources support platform/tool behavior. Creature designs, prices, spawn distributions, budgets, and milestone targets above are project proposals, not claims taken from Roblox research. Re-check changing APIs and policies before shipping.

### Roblox localization

- [L1] [Localization overview](https://create.roblox.com/docs/production/localization)
- [L2] [Supported language codes and locale IDs](https://create.roblox.com/docs/production/localization/language-codes)
- [L3] [Adding translations and regional language variants](https://create.roblox.com/docs/production/localization/add-translations)
- [L4] [Localization scripting](https://create.roblox.com/docs/production/localization/localize-with-scripting)

### Rojo and project setup

- [R1] [Rojo installation](https://rojo.space/docs/v7/getting-started/installation/)
- [R2] [Creating, building, and serving a Rojo project](https://rojo.space/docs/v7/getting-started/new-game/)
- [R3] [Rojo project format](https://rojo.space/docs/v7/project-format/)
- [R4] [Rojo synchronization details and limitations](https://rojo.space/docs/v7/sync-details/)

### Server correctness and data

- [S1] [Securing the client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary)
- [S2] [Server-side detection and proportionate responses](https://create.roblox.com/docs/scripting/security/server-side-detection)
- [D1] [Data stores](https://create.roblox.com/docs/cloud-services/data-stores)
- [D2] [GlobalDataStore API](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore)

### Input, performance, testing, and communication

- [I1] [Input Action System](https://create.roblox.com/docs/input/input-action-system)
- [T1] [Instance streaming](https://create.roblox.com/docs/workspace/streaming)
- [T2] [Design for performance](https://create.roblox.com/docs/performance-optimization/design)
- [Q1] [Studio testing modes and emulation](https://create.roblox.com/docs/studio/testing-modes)
- [C1] [TextChatService and text chat](https://create.roblox.com/docs/chat/in-experience-text-chat)

### Commerce and per-player policies

- [M1] [Developer products and receipt handling](https://create.roblox.com/docs/production/monetization/developer-products)
- [M2] [Regional/managed pricing](https://create.roblox.com/docs/production/monetization/regional-pricing)
- [P1] [PolicyService](https://create.roblox.com/docs/reference/engine/classes/PolicyService)
- [P2] [Paid random items and related policy restrictions](https://create.roblox.com/docs/production/monetization/paid-random-items)

### Analytics and Claude project instructions

- [A1] [Analytics event types](https://create.roblox.com/docs/production/analytics/event-types)
- [A2] [Funnel events](https://create.roblox.com/docs/production/analytics/funnel-events)
- [K1] [Claude Code project instruction files](https://code.claude.com/docs/en/claude-directory)

---

## 30. Owner's start prompt for Claude

> Read this build specification fully before editing. Build ANOMALY HEIST as a real, polished Roblox experience, not another concept document. The US is explicitly included: source text is US English and the product targets worldwide players across all Roblox-supported locales. Inspect the actual workspace, installed tools, and permissions first. Do not assume VS Code, the Rojo CLI, uploaded assets, or Studio access already exist. Preserve existing work. Start with M0 and progress toward the first walkable M1 build using complete project files and primitive asset fallbacks. Keep the latest Roblox-style image as visual guidance, not as proof of implementation. Follow the ownership, localization, performance, and acceptance requirements. Report what you changed, what you actually tested, what remains untested, and the exact next Studio step. Do not publish, spend money, modify production data, or invent successful tests.
