-- Central tuning file. Almost every gameplay number lives here so the game
-- can be balanced without touching the logic.

local Config = {}

Config.GameName = "OVERBOARD!"

---------------------------------------------------------------------------
-- Monetization (create these on the Creator Dashboard, then paste the IDs)
-- An ID of 0 means "not set up yet": the item is hidden/disabled in game.
---------------------------------------------------------------------------
Config.GamePasses = {
	VIP = 0, -- 2x coins on every cash-out + VIP-only Storm trail
	Lifejacket = 0, -- keep your loot when you fall overboard or the balloon crashes
	MegaHook = 0, -- +12 hook range and +10 kg backpack
}

Config.Products = {
	EmergencyBurner = 0, -- +30 altitude for the whole balloon (saves everyone)
	Rescue = 0, -- instantly climb back from the raft to the balloon
	TreasureRain = 0, -- fixed burst of rare loot around the balloon for everyone
	CoinsSmall = 0,
	CoinsMedium = 0,
	CoinsLarge = 0,
}

Config.ProductCoins = {
	CoinsSmall = 500,
	CoinsMedium = 1500,
	CoinsLarge = 5000,
}

-- Fixed (non-random) contents of a Treasure Rain, so no paid randomness.
Config.TreasureRainItems = {
	"Chest", "Chest", "Chest", "Gull", "Gull", "Egg", "Egg", "Crown",
}

Config.EmergencyBurnerAltitude = 30

-- Optional Roblox group: members get a coin bonus (0 = disabled).
Config.GroupId = 0
Config.GroupBonus = 0.1

---------------------------------------------------------------------------
-- World layout (the three zones are far apart so they never overlap)
---------------------------------------------------------------------------
Config.HarborPos = Vector3.new(0, 0, 0)
Config.BalloonPos = Vector3.new(3000, 400, 0) -- top surface of the basket floor
Config.BasketRadius = 22
Config.RaftPos = Vector3.new(-3000, 20, 0) -- top surface of the rescue raft

---------------------------------------------------------------------------
-- Flight
---------------------------------------------------------------------------
Config.Intermission = 15
Config.StartAltitude = 100
Config.MaxAltitude = 100
Config.StartFuel = 30
Config.MaxFuel = 100
Config.Speed = 14 -- metres per second (also the studs/s the scenery moves)

-- Altitude change per second:
--   BaseLift - load * WeightSink - distance * LeakPerMeter (+ BurnerLift)
-- where load = total weight aboard / balloon capacity.
Config.BaseLift = 0.5
Config.WeightSink = 1.0
Config.LeakPerMeter = 0.0001
Config.BurnerLift = 1.4
Config.BurnerFuelPerSecond = 1
Config.BurnerPump = 2 -- seconds of burn added per press
Config.BurnerMaxTime = 6

Config.BodyWeight = 5
Config.CapacityPerPlayer = 18
Config.MinCapacityPlayers = 4

Config.PortEvery = 1200 -- metres between Sky Ports (cash-out stops)
Config.DockTime = 12
Config.DockFuel = 15
Config.DistanceCoinsPer = 50 -- 1 coin per 50 m flown, paid at the end

Config.LootInterval = 1.1
Config.FuelCanisterChance = 0.15
Config.FuelCanisterAmount = 8
Config.LuckPerMeter = 1 / 3000 -- rare loot gets more common the further you fly

-- Emergency Burner tokens bought outside a flight trigger automatically
-- when the balloon drops below this altitude.
Config.AutoBurnerAltitude = 15

---------------------------------------------------------------------------
-- Social chaos
---------------------------------------------------------------------------
Config.ShoveEnabled = true
Config.ShoveCooldown = 8
Config.ShoveRange = 7
Config.ShoveForce = 70

Config.VoteDuration = 12
Config.VoteCooldown = 75
Config.AutoVoteAltitude = 30
Config.MinPlayersForVote = 3
Config.MinVotesToThrow = 2

---------------------------------------------------------------------------
-- Bot crew: keeps the balloon lively while the game has few players.
-- Bots fill the basket up to BotCrewSize passengers and hop off when real
-- players join. They are clearly marked with a robot icon.
---------------------------------------------------------------------------
Config.BotsEnabled = true
Config.BotCrewSize = 5
Config.BotHookRange = 22

---------------------------------------------------------------------------
-- Rescue raft
---------------------------------------------------------------------------
Config.DeliveriesToReturn = 3
Config.BarrelFuel = 12
Config.BarrelRespawn = 8
Config.DeliveryCoins = 5

return Config
