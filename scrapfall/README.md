# ⚙️ SCRAPFALL

PvPvE-Extraction-Shooter für Roblox: Plündern, gegen Killer-Roboter kämpfen, lebend rauskommen.
(Inspiriert vom Genre – eigene Namen, eigene Welt, eigene Roboter.)

## Spielablauf

1. **Outpost** (begehbare Untergrund-Stadt): Händler, Lager & Ausrüstung, Werkbank Lv1, Upgrades, Rangliste.
2. **Kartenterminal:** Karte wählen und einsteigen. Jeder Spieler hat seinen eigenen Timer – kein Warten auf eine Lobby.
   - **Rustfield Ruins** – Stadt-Ruinen, Nahkämpfe, Absturzstelle mit dem Boss **COLOSSUS**
   - **Dustbowl Quarry** – offene Ebene, weite Sicht, mehr Drohnen
3. **Plündern:** Kisten (Supply Crate, Toolbox, Med Cabinet, Weapon Case, Robot Cache) per Halten von `E` durchsuchen.
4. **Roboter:**
   - Crawler (kleine Krabbler, Rudel)
   - Buzzer-Drohnen (Laser mit Vorwarnung)
   - Watcher (Späher – ruft Verstärkung!)
   - Sentinel (schwer, Schwachpunkt hinten)
   - COLOSSUS (Boss, Raketen)
   Schüsse sind laut und locken Roboter an.
5. **Extraktion:** Aufzug rufen, 20 Sekunden verteidigen, dann geht's mit der Beute nach Hause.
6. **Tod:** Alles Mitgenommene bleibt als Rucksack liegen (andere können ihn plündern). Die **sichere Tasche** bleibt erhalten.
7. **Sturm:** Nach 12 Minuten nimmt man Schaden – rechtzeitig raus!
8. **Kein Absturz in die Pleite:** Ohne Waffe gibt es automatisch ein kostenloses Starter-Kit.

## Progression

- **Händler:** Waffen, Munition, Heilung kaufen; Beute verkaufen.
- **Werkbank:** Lv1 im Outpost (frei). Lv2/Lv3 nur im eigenen Quartier → bessere Rezepte (Rattler, Hammer, Longshot …).
- **Private Quarters:** eigener Raum mit persönlicher Werkbank, Lager-Zugang und 8 Deko-Plätzen (Möbel + Trophäen aus seltener Beute, z. B. *Colossus Heart Trophy*). Freischalten mit **7.500 Credits** oder **Game Pass**.
- **Upgrades:** größerer Rucksack, größeres Lager. **Raider Rank** (XP für Kills & Extraktionen).

## Monetarisierung (IDs in `src/shared/Config.lua` eintragen; 0 = ausgeblendet)

| Typ | Name | Wirkung | Preis-Vorschlag |
|---|---|---|---|
| Game Pass | `Quarters` | Quartier sofort freischalten | 199 R$ |
| Game Pass | `VIP` | +25 % Verkaufserlös, goldener Name | 299 R$ |
| Game Pass | `BigPockets` | sichere Tasche: 3 statt 1 Platz | 249 R$ |
| Game Pass | `ExtraStash` | +40 Lagerplätze | 149 R$ |
| Product | `Insurance` | nächster Tod: Waffen kommen zurück | 49 R$ |
| Product | `CreditsSmall/Medium/Large` | 1.000 / 3.000 / 10.000 Credits | 49 / 129 / 349 R$ |

Keine zufälligen Bezahl-Items.

## Öffnen

**Ohne Rojo:** `SCRAPFALL.rbxlx` (im Hauptordner) in Roblox Studio öffnen → *File → Publish to Roblox* →
*Game Settings → Security → Enable Studio Access to API Services* → **Play**.

**Mit Rojo:** im Ordner `scrapfall` → `rojo serve`.

Empfohlen: *Game Settings → Places → Server Size* = **12**.

## Steuerung

PC: Maus zielen, Klick schießen, `R` nachladen, `1`/`2` Waffe, `H` heilen, `TAB` Rucksack, `E` interagieren, `ALT` Maus freigeben.
Handy: FIRE-Knopf + Buttons, Ziehen zum Zielen. Controller: R2 schießen, X nachladen, Y wechseln.

## Echte Modelle & Sounds einbauen (Asset-Slots)

Das Spiel hat Platzhalter-Optik aus Code. Sobald du echte Modelle hast, ziehst du sie in
**ReplicatedStorage → GameAssets** – mit dem passenden Namen – und das Spiel nutzt sie automatisch:

| Ordner | Namen | Hinweise |
|---|---|---|
| `Robots` | `Crawler`, `Buzzer`, `Watcher`, `Sentinel`, `Colossus` | Vorderseite = blaue Pfeilrichtung (−Z). Optional ein Teil `WeakPoint` (3× Schaden) und `Eye` (Laser-Ursprung). Größe wird automatisch angepasst. |
| `Weapons` | `ScrapPistol`, `Rattler`, `Hammer`, `Breacher`, `Longshot` | Ein Teil `Handle` (wird gehalten) und `Muzzle` (Laufende). Lauf zeigt nach −Z. |
| `Props` | `Crate`, `Toolbox`, `MedCabinet`, `WeaponCase`, `RobotCache`, `DeathCache`, `Wreck` | Kisten-Modelle |
| `Sounds` | `Shot_LightAmmo`, `Shot_HeavyAmmo`, `Shot_Shells`, `Laser`, `Bolt`, `Explosion`, `Hit`, `Kill`, `Hurt`, `LiftAlarm`, `Extract`, `Spotted`, `Reload`, `Heal` | `Sound`-Objekte |

**Woher?**
1. **Roblox Creator Store** (Toolbox in Studio): Modelle & Sounds. Am besten Filter **„Verified creators“**.
   Suchbegriffe: *sci-fi drone*, *mech robot*, *spider robot*, *post apocalyptic*, *rusty car*, *military crate*,
   für Sounds: *gunshot*, *laser*, *robot alarm*, *explosion*.
   ⚠️ Kostenlose Modelle enthalten manchmal Schad-Skripte. Das Spiel **löscht automatisch alle Skripte** in
   `GameAssets`, trotzdem nur Modelle ohne Skripte nehmen.
2. **KI-Generierung in Studio:** Je nach Studio-Version kannst du über den Assistenten 3D-Modelle aus Text erzeugen
   (z. B. „rusty spider robot with red eye“).
3. **Für den echten „krassen“ Look:** einen 3D-Artist beauftragen (Roblox Talent Hub, Fiverr), damit alles
   einen einheitlichen Stil hat. Das ist der Schritt, der aus „gut“ ein Top-Spiel macht.

**Wichtig:** Wenn ich dir später eine neue `SCRAPFALL.rbxlx` schicke, sind deine eingefügten Modelle dort nicht drin.
Deshalb: Rechtsklick auf `GameAssets` → **Save to File** (`GameAssets.rbxm`) und mir schicken bzw. auf GitHub in
`scrapfall/assets/` hochladen – dann baue ich sie fest ein.

## Noch zu tun (Feinschliff)

- Sounds (Schüsse, Roboter, Aufzug) aus dem Creator Store einfügen – aktuell ohne Ton.
- Echte 3D-Modelle für Waffen/Roboter (aktuell aus einfachen Bauteilen gebaut, voll spielbar).
- Balancing nach den ersten Tests (alles in `Config.lua`, `Items.lua`, `Robots.lua`, `Crafting.lua`).

## Automatischer Test

`lune run tools/harness.luau scrapfall` startet Server + Oberfläche ohne Studio und spielt einen kompletten
Ablauf durch (Einsatz, Schießen, Roboter, Kisten, Extraktion, Händler, Werkbank, Quartier, Tod).
Findet Startabstürze und falsche Eigenschaften – ersetzt aber nicht das Testen in Studio (keine Physik).
