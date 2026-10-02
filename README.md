# 🎈 OVERBOARD!

**Der ganze Server sitzt in EINEM Heißluftballon.** Beute schwebt vorbei – aber jedes Item macht den Ballon schwerer. Wird es knapp, stimmt die Crew ab, **wer über Bord fliegt**.

## Spielablauf

1. **Harbor (Lobby):** 15 Sekunden Countdown, dann steigen alle in den Ballon.
2. **Beute haken:** Auf schwebende Items klicken/tippen. Seltenere Items sind wertvoller, aber auch **schwerer**.
3. **Gewicht = Gefahr:** Über jedem Kopf steht, wie viel jemand trägt. Zu viel Gewicht → der Ballon sinkt.
4. **Brenner:** `E` am Brenner drücken lässt den Ballon steigen (verbraucht Treibstoff). Treibstoff gibt es als schwebende Kanister.
5. **Sky Ports (alle 1200 m):** Nur hier wird Beute zu Coins. Gier gegen Sicherheit!
6. **Abstimmung:** Bei niedriger Höhe (oder per Vote-Horn) stimmt die Crew ab, wer über Bord fliegt.
7. **Schubsen:** `Q` schubst andere – manchmal über die Reling.
8. **Rettungsfloß:** Wer über Bord geht, springt über Kisten, sammelt Treibstofffässer und schießt sie mit der Sky Cannon zum Ballon hoch. Nach 3 Lieferungen geht's zurück an Bord.
9. **Absturz:** Erreicht der Ballon das Meer, ist alle getragene Beute weg. Jeder bekommt einen Distanz-Bonus, dann startet die nächste Runde.

**Bots:** Solange wenige Spieler da sind, füllen 🤖-Bots mit Persönlichkeit (Greedy Gary, Captain Panic, …) den Korb auf. Sie sammeln, stimmen ab und werden rausgeworfen. Kommen echte Spieler dazu, steigen Bots aus. Einstellbar über `BotsEnabled` / `BotCrewSize`.

**Langzeitmotivation:** Upgrades (Hook-Reichweite, Rucksack, Glück), Trails, tägliche Belohnung mit Streak, globale Rangliste, persönliche Bestdistanz.

---

## Einrichtung OHNE Rojo (am einfachsten)

1. Auf GitHub die Datei **`OVERBOARD.rbxlx`** öffnen → **Download** (Pfeil-Symbol „Download raw file“).
2. Die Datei per Doppelklick öffnen oder in Roblox Studio *File → Open from File…* wählen.
3. *File → Publish to Roblox* (damit Speichern & Robux-Käufe funktionieren).
4. *Game Settings → Security → Enable Studio Access to API Services* einschalten.
5. **Play** drücken – nach 15 Sekunden hebt der Ballon ab.

Wichtig: Wenn der Code im Repo geändert wird, muss die `.rbxlx` neu gebaut werden
(`rojo build default.project.json -o OVERBOARD.rbxlx`) – das übernimmt Claude bei jeder Änderung.
Änderungen, die du selbst in Studio machst, sind in der Datei nicht enthalten.

## Einrichtung (Rojo, für später)

1. Repo klonen und im Ordner `rojo serve` ausführen.
2. Roblox Studio → neue **Baseplate** öffnen → Rojo-Plugin → **Connect**.
3. Die `Baseplate` im Workspace löschen (das Spiel baut seine Welt selbst).
4. **Speichern testen:** *Game Settings → Security → Enable Studio Access to API Services* einschalten (sonst funktionieren Coins/DataStores nur ohne Speichern).
5. **Play** drücken. Nach 15 Sekunden startet der erste Flug.
6. *Empfohlen:* *Game Settings → Places → Server Size* auf **8** setzen. Wenige Spieler landen dann zusammen in einem Server statt verteilt in leeren.
7. `StreamingEnabled` ist im Projekt bereits ausgeschaltet (die drei Zonen liegen weit auseinander).

### Robux-Produkte anlegen

Im [Creator Dashboard](https://create.roblox.com/dashboard/creations) unter *Monetization* anlegen und die IDs in `src/shared/Config.lua` eintragen. Steht eine ID auf `0`, wird das Item im Spiel ausgeblendet.

| Typ | Name in Config | Wirkung | Preis-Vorschlag |
|---|---|---|---|
| Game Pass | `VIP` | 2x Coins, goldener Name, Storm-Trail | 299 R$ |
| Game Pass | `Lifejacket` | Beute bleibt bei Über-Bord/Absturz | 199 R$ |
| Game Pass | `MegaHook` | +12 Reichweite, +10 kg Rucksack | 149 R$ |
| Product | `EmergencyBurner` | +30 Höhe für **alle**, Server-Ansage | 49 R$ |
| Product | `TreasureRain` | feste Menge seltener Beute für alle | 99 R$ |
| Product | `Rescue` | sofort vom Floß zurück an Bord | 25 R$ |
| Product | `CoinsSmall/Medium/Large` | 500 / 1.500 / 5.000 Coins | 49 / 129 / 349 R$ |

Alle Käufe sind fair und transparent: **keine zufälligen Bezahl-Items** (Treasure Rain hat einen festen Inhalt). Kann ein Produkt gerade nicht genutzt werden, wird es gespeichert und automatisch im richtigen Moment eingesetzt.

### Balancing

Alle Zahlen stehen in `src/shared/Config.lua` (Sinkgeschwindigkeit, Abstand der Sky Ports, Vote-Regeln, Bot-Anzahl …). Items und Seltenheiten stehen in `src/shared/Loot.lua`, Shop-Preise in `src/shared/Shop.lua`.

---

## Projektstruktur

```
src/shared/   Config, Loot-Tabelle, Shop-Daten (Server + Client)
src/server/   Main (verbindet alles)
              FlightService   Runden, Höhe, Gewicht, Sky Ports, Zonen
              LootService     schwebende Beute & Kulisse
              VoteService     Über-Bord-Abstimmungen
              BotService      Bot-Crew bei wenigen Spielern
              RaftService     Rettungsfloß & Sky Cannon
              ShopService     Upgrades, Trails, Daily Rewards
              MonetizationService  Game Passes & Produkte
              DataService     Speichern (DataStore)
              AnalyticsService     Messpunkte fürs Creator Dashboard
              LeaderboardService   globale Rangliste
              WorldBuilder    baut die komplette Map per Code
src/client/   HUD, Rucksack, Abstimmung, Shop, Steuerung
```

---

## Erfolg messen

Das Spiel meldet Daten an **Creator Dashboard → Analytics**:
- **Onboarding-Funnel:** Joined → erster Flug → erstes Item → erster Cash-out → erstes Upgrade. Hier sieht man, wo neue Spieler abspringen.
- **Economy:** Woher Coins kommen und wofür sie ausgegeben werden.
- **Custom Events:** Über-Bord, Abstimmungen, gelieferte Fässer, Käufe.

Grobe Richtwerte aus der Community (keine Garantie): Day-1-Retention **über ~20 %** und durchschnittliche Spielzeit **über ~10 Minuten** gelten als gutes Zeichen, um Werbung hochzuskalieren. Liegt man deutlich darunter, zuerst den Kern-Spaß verbessern.

## Launch-Plan

1. **Icon & Thumbnails:** das Wichtigste überhaupt. Idee: Spieler fliegt schreiend aus dem Ballon, die anderen jubeln, dazu ein riesiger Rainbow Anvil.
2. **Mit Freunden testen** und Clips aufnehmen (Abstimmungen und Schubsen sind die viralen Momente).
3. **TikTok/YouTube Shorts:** täglich kurze Clips („We voted my best friend off the balloon“).
4. **Kleines Werbebudget** (Roblox Ads) einsetzen und die Funnel-Daten prüfen.
5. **Regelmäßige Updates** (neue Items, Events, Ballon-Skins) halten Spieler und Algorithmus aktiv.

## Roblox Studio MCP (optional)

Für KI-Unterstützung direkt in Studio: auf deinem PC Claude Code oder Claude Desktop installieren und dann
in Studio unter *Assistant → Settings → MCP Servers* verbinden oder den offiziellen
[Roblox MCP Server](https://github.com/Roblox/studio-rust-mcp-server) einrichten. Der Code in diesem Repo wird
unabhängig davon über Rojo synchronisiert.
