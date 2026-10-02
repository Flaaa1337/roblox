-- Every item in SCRAPFALL: weapons, ammo, meds and salvage.
-- price = trader buy price (nil = can't be bought), value = sell price.

local Items = {}

Items.Rarities = {
	Common = { order = 1, color = Color3.fromRGB(200, 200, 200) },
	Uncommon = { order = 2, color = Color3.fromRGB(90, 220, 110) },
	Rare = { order = 3, color = Color3.fromRGB(70, 150, 255) },
	Epic = { order = 4, color = Color3.fromRGB(185, 95, 255) },
	Legendary = { order = 5, color = Color3.fromRGB(255, 185, 40) },
}

Items.Defs = {
	-- Weapons -------------------------------------------------------------
	ScrapPistol = {
		name = "Scrap Pistol", category = "weapon", rarity = "Common", stack = 1, value = 25, price = 120,
		weapon = { damage = 18, rpm = 260, mag = 12, ammo = "LightAmmo", range = 220, spread = 1.2, reload = 1.4, pellets = 1, auto = false },
		color = Color3.fromRGB(120, 110, 100),
	},
	Rattler = {
		name = "Rattler SMG", category = "weapon", rarity = "Uncommon", stack = 1, value = 140, price = 550,
		weapon = { damage = 12, rpm = 620, mag = 30, ammo = "LightAmmo", range = 180, spread = 2.6, reload = 1.8, pellets = 1, auto = true },
		color = Color3.fromRGB(70, 90, 70),
	},
	Hammer = {
		name = "Hammer Rifle", category = "weapon", rarity = "Rare", stack = 1, value = 260, price = 1100,
		weapon = { damage = 23, rpm = 430, mag = 25, ammo = "HeavyAmmo", range = 320, spread = 1.5, reload = 2.1, pellets = 1, auto = true },
		color = Color3.fromRGB(60, 60, 70),
	},
	Breacher = {
		name = "Breacher Shotgun", category = "weapon", rarity = "Rare", stack = 1, value = 220, price = 900,
		weapon = { damage = 10, rpm = 75, mag = 6, ammo = "Shells", range = 70, spread = 6, reload = 2.6, pellets = 8, auto = false },
		color = Color3.fromRGB(110, 70, 40),
	},
	Longshot = {
		name = "Longshot Rifle", category = "weapon", rarity = "Epic", stack = 1, value = 450, price = 1800,
		weapon = { damage = 75, rpm = 48, mag = 5, ammo = "HeavyAmmo", range = 600, spread = 0.15, reload = 2.8, pellets = 1, auto = false },
		color = Color3.fromRGB(40, 50, 70),
	},

	-- Ammo ----------------------------------------------------------------
	LightAmmo = { name = "Light Ammo", category = "ammo", rarity = "Common", stack = 120, value = 1, price = 2 },
	HeavyAmmo = { name = "Heavy Ammo", category = "ammo", rarity = "Common", stack = 80, value = 2, price = 4 },
	Shells = { name = "Shotgun Shells", category = "ammo", rarity = "Common", stack = 40, value = 3, price = 6 },

	-- Meds ----------------------------------------------------------------
	Bandage = { name = "Bandage", category = "med", rarity = "Common", stack = 5, value = 15, price = 40, heal = 35, useTime = 2.5 },
	MedKit = { name = "Med Kit", category = "med", rarity = "Uncommon", stack = 3, value = 60, price = 160, heal = 100, useTime = 5 },
	ShieldCell = { name = "Shield Cell", category = "med", rarity = "Uncommon", stack = 3, value = 50, price = 130, shield = 50, useTime = 3 },

	-- Salvage (sell for credits) -------------------------------------------
	ScrapMetal = { name = "Scrap Metal", category = "salvage", rarity = "Common", stack = 20, value = 8 },
	Wires = { name = "Copper Wires", category = "salvage", rarity = "Common", stack = 20, value = 12 },
	CircuitBoard = { name = "Circuit Board", category = "salvage", rarity = "Uncommon", stack = 10, value = 35 },
	Battery = { name = "Fusion Battery", category = "salvage", rarity = "Uncommon", stack = 10, value = 45 },
	Servo = { name = "Servo Motor", category = "salvage", rarity = "Rare", stack = 5, value = 95 },
	OpticLens = { name = "Optic Lens", category = "salvage", rarity = "Rare", stack = 5, value = 120 },
	RobotCore = { name = "Robot Core", category = "salvage", rarity = "Epic", stack = 5, value = 320 },
	PrototypeChip = { name = "Prototype Chip", category = "salvage", rarity = "Legendary", stack = 3, value = 1200 },
	ColossusHeart = { name = "Colossus Heart", category = "salvage", rarity = "Legendary", stack = 1, value = 2500 },
}

for id, def in Items.Defs do
	def.id = id
end

-- What the trader sells, in display order.
Items.TraderStock = {
	{ id = "ScrapPistol", count = 1 },
	{ id = "Rattler", count = 1 },
	{ id = "Breacher", count = 1 },
	{ id = "Hammer", count = 1 },
	{ id = "Longshot", count = 1 },
	{ id = "LightAmmo", count = 60 },
	{ id = "HeavyAmmo", count = 40 },
	{ id = "Shells", count = 20 },
	{ id = "Bandage", count = 3 },
	{ id = "MedKit", count = 1 },
	{ id = "ShieldCell", count = 1 },
}

---------------------------------------------------------------------------
-- Loot tables: list of { id, weight, min, max }. rolls = how many draws.
---------------------------------------------------------------------------
Items.LootTables = {
	Crate = {
		rolls = { 2, 4 },
		entries = {
			{ "ScrapMetal", 30, 2, 6 }, { "Wires", 22, 1, 4 }, { "LightAmmo", 14, 15, 40 },
			{ "HeavyAmmo", 8, 10, 25 }, { "Shells", 6, 6, 12 }, { "Bandage", 10, 1, 2 },
			{ "CircuitBoard", 8, 1, 2 }, { "Battery", 4, 1, 1 },
		},
	},
	Toolbox = {
		rolls = { 2, 4 },
		entries = {
			{ "ScrapMetal", 20, 3, 8 }, { "Wires", 20, 2, 5 }, { "CircuitBoard", 18, 1, 3 },
			{ "Battery", 14, 1, 2 }, { "Servo", 8, 1, 1 }, { "OpticLens", 4, 1, 1 },
		},
	},
	MedCabinet = {
		rolls = { 1, 3 },
		entries = { { "Bandage", 50, 1, 3 }, { "MedKit", 20, 1, 1 }, { "ShieldCell", 20, 1, 1 } },
	},
	WeaponCase = {
		rolls = { 1, 2 },
		entries = {
			{ "Rattler", 20, 1, 1 }, { "Breacher", 14, 1, 1 }, { "Hammer", 10, 1, 1 }, { "Longshot", 4, 1, 1 },
			{ "LightAmmo", 20, 30, 60 }, { "HeavyAmmo", 18, 20, 40 }, { "Shells", 12, 8, 16 },
		},
	},
	RobotCache = {
		rolls = { 2, 3 },
		entries = {
			{ "Servo", 20, 1, 2 }, { "OpticLens", 18, 1, 2 }, { "RobotCore", 14, 1, 1 },
			{ "PrototypeChip", 4, 1, 1 }, { "Battery", 20, 1, 3 }, { "ShieldCell", 12, 1, 2 },
		},
	},
}

function Items.Get(id: string)
	return Items.Defs[id]
end

function Items.Roll(tableName: string, rng: Random)
	local lootTable = Items.LootTables[tableName]
	local result = {}
	if not lootTable then
		return result
	end
	local total = 0
	for _, e in lootTable.entries do
		total += e[2]
	end
	for _ = 1, rng:NextInteger(lootTable.rolls[1], lootTable.rolls[2]) do
		local pick = rng:NextNumber() * total
		for _, e in lootTable.entries do
			pick -= e[2]
			if pick <= 0 then
				table.insert(result, { id = e[1], count = rng:NextInteger(e[3], e[4]) })
				break
			end
		end
	end
	return result
end

return Items
