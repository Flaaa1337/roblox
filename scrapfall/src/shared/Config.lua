-- SCRAPFALL tuning. Gameplay numbers live here so balancing never needs
-- logic changes.

local Config = {}

Config.GameName = "SCRAPFALL"

---------------------------------------------------------------------------
-- Monetization (paste IDs from the Creator Dashboard; 0 = hidden/disabled)
---------------------------------------------------------------------------
Config.GamePasses = {
	VIP = 0, -- +25% credits when selling, gold name
	BigPockets = 0, -- safe pocket holds 3 stacks instead of 1
	ExtraStash = 0, -- +40 stash slots
	Quarters = 0, -- unlocks your Private Quarters instantly (also buyable with credits)
}

Config.Products = {
	Insurance = 0, -- next time you die, your weapons come back to your stash
	CreditsSmall = 0,
	CreditsMedium = 0,
	CreditsLarge = 0,
}

Config.ProductCredits = {
	CreditsSmall = 1000,
	CreditsMedium = 3000,
	CreditsLarge = 10000,
}

Config.VipSellBonus = 0.25
Config.GroupId = 0
Config.GroupSellBonus = 0.1

---------------------------------------------------------------------------
-- World
---------------------------------------------------------------------------
Config.HubPos = Vector3.new(0, 0, 0) -- the Outpost (underground town)

-- Raid maps, picked at the map terminal in the Outpost. Same seed = same
-- layout in every server, so players can learn the maps.
Config.Maps = {
	{
		id = "Rustfield", name = "Rustfield Ruins", desc = "Ruined city blocks, close fights, crashed giant in the centre.",
		pos = Vector3.new(3000, 0, 0), size = 640, seed = 1337,
		buildings = { 1, 2 }, containers = 28, rocks = 70, crashSite = true,
		ground = Color3.fromRGB(120, 110, 90), danger = "Medium",
	},
	{
		id = "Quarry", name = "Dustbowl Quarry", desc = "Wide open dust plains. Long sightlines, more drones.",
		pos = Vector3.new(6000, 0, 0), size = 700, seed = 4242,
		buildings = { 0, 1 }, containers = 40, rocks = 140, crashSite = false,
		ground = Color3.fromRGB(170, 140, 100), danger = "High",
		robotWeights = { Crawler = 30, Buzzer = 40, Watcher = 15, Sentinel = 15 },
	},
}

-- Private Quarters: every player's own room
Config.QuartersOrigin = Vector3.new(0, 0, 3000)
Config.QuartersSpacing = 160
Config.QuartersCreditPrice = 7500

---------------------------------------------------------------------------
-- Raids (drop-in: every player has their own timer, no lobby waiting)
---------------------------------------------------------------------------
Config.RaidDuration = 12 * 60
Config.StormDamagePerSecond = 6 -- after the timer runs out
Config.SpawnProtection = 6

Config.ExtractHoldTime = 2
Config.ExtractCountdown = 20
Config.ExtractRadius = 12
Config.ExtractCooldown = 25
Config.ExtractAlertRadius = 140 -- robots in this radius rush the lift

Config.BenchUpgrades = {
	-- personal workbench in your quarters (the Outpost bench is always tier 1)
	[2] = { credits = 2000, items = { { id = "Servo", count = 2 }, { id = "CircuitBoard", count = 4 } } },
	[3] = { credits = 6000, items = { { id = "RobotCore", count = 2 }, { id = "OpticLens", count = 2 } } },
}

Config.StarterKit = {
	weapon = "ScrapPistol",
	items = { { id = "LightAmmo", count = 48 }, { id = "Bandage", count = 2 } },
}

---------------------------------------------------------------------------
-- Inventory
---------------------------------------------------------------------------
Config.BackpackBase = 10
Config.BackpackPerUpgrade = 2
Config.BackpackMaxUpgrades = 7
Config.BackpackUpgradeCost = { 500, 900, 1500, 2400, 3600, 5200, 7500 }

Config.StashBase = 40
Config.StashPerUpgrade = 10
Config.StashMaxUpgrades = 6
Config.StashUpgradeCost = { 400, 800, 1400, 2200, 3200, 4500 }

Config.SafePocketSlots = 1
Config.BigPocketsSlots = 3

Config.WeaponSlots = 2

---------------------------------------------------------------------------
-- Combat
---------------------------------------------------------------------------
Config.MaxShield = 50
Config.PvPEnabled = true
Config.PvPDamageMultiplier = 0.7
Config.PlayerHeadshotMultiplier = 1.5
Config.GunNoiseRadius = 70 -- robots within this range hear your shots
Config.MaxAimOriginOffset = 25 -- anti-cheat: camera can't be further than this from the head

---------------------------------------------------------------------------
-- Robots
---------------------------------------------------------------------------
Config.RobotBase = 8 -- robots alive with nobody in the raid zone yet
Config.RobotPerRaider = 4
Config.RobotMax = 30
Config.RobotRespawnDelay = 20
Config.BossRespawn = 6 * 60

---------------------------------------------------------------------------
-- Loot containers
---------------------------------------------------------------------------
Config.ContainerRespawn = 5 * 60
Config.LootRange = 12
Config.DeathCacheLifetime = 5 * 60
Config.WreckLifetime = 3 * 60

---------------------------------------------------------------------------
-- Progression
---------------------------------------------------------------------------
Config.XpPerKill = { Crawler = 10, Buzzer = 20, Watcher = 25, Sentinel = 50, Colossus = 400, Raider = 60 }
Config.XpPerExtract = 100
Config.XpPerLevel = 400 -- level n needs n * XpPerLevel XP

return Config
