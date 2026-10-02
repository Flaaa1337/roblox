-- Everything that can float past the balloon.
-- Heavier items are worth more: that trade-off is the whole game.

local Loot = {}

Loot.Rarities = {
	Common = { order = 1, color = Color3.fromRGB(210, 210, 210), chance = 55 },
	Uncommon = { order = 2, color = Color3.fromRGB(90, 220, 110), chance = 25 },
	Rare = { order = 3, color = Color3.fromRGB(70, 150, 255), chance = 12 },
	Epic = { order = 4, color = Color3.fromRGB(185, 95, 255), chance = 5.5 },
	Legendary = { order = 5, color = Color3.fromRGB(255, 190, 40), chance = 2 },
	Mythic = { order = 6, color = Color3.fromRGB(255, 60, 130), chance = 0.5 },
}

Loot.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

Loot.Items = {
	Duck = {
		name = "Rubber Duck", rarity = "Common", weight = 1, value = 4,
		color = Color3.fromRGB(255, 220, 40), shape = "Ball", size = Vector3.new(1.6, 1.6, 1.6),
	},
	Boot = {
		name = "Old Boot", rarity = "Common", weight = 2, value = 3,
		color = Color3.fromRGB(110, 75, 45), shape = "Block", size = Vector3.new(1.4, 1.8, 2.4),
	},
	Bottle = {
		name = "Message in a Bottle", rarity = "Common", weight = 1, value = 7,
		color = Color3.fromRGB(120, 200, 150), shape = "Cylinder", size = Vector3.new(2.4, 1, 1),
	},
	Hat = {
		name = "Pirate Hat", rarity = "Uncommon", weight = 2, value = 16,
		color = Color3.fromRGB(30, 30, 35), shape = "Block", size = Vector3.new(2.6, 1, 2.6),
	},
	GoldFish = {
		name = "Golden Fish", rarity = "Uncommon", weight = 2, value = 22,
		color = Color3.fromRGB(255, 170, 40), shape = "Block", size = Vector3.new(2.2, 1.2, 0.6),
	},
	Chest = {
		name = "Treasure Chest", rarity = "Rare", weight = 5, value = 70,
		color = Color3.fromRGB(150, 95, 40), shape = "Block", size = Vector3.new(3, 2.2, 2),
	},
	Gull = {
		name = "Crystal Seagull", rarity = "Rare", weight = 3, value = 55,
		color = Color3.fromRGB(150, 240, 255), shape = "Block", size = Vector3.new(2.6, 1.2, 1.2),
	},
	Egg = {
		name = "Cloud Whale Egg", rarity = "Epic", weight = 6, value = 170,
		color = Color3.fromRGB(245, 245, 255), shape = "Ball", size = Vector3.new(3, 3, 3),
	},
	Crown = {
		name = "Sky Crown", rarity = "Legendary", weight = 4, value = 450,
		color = Color3.fromRGB(255, 205, 50), shape = "Cylinder", size = Vector3.new(1.4, 2.4, 2.4),
	},
	Anvil = {
		name = "Rainbow Anvil", rarity = "Mythic", weight = 14, value = 1500,
		color = Color3.fromRGB(255, 80, 200), shape = "Block", size = Vector3.new(3.4, 2, 2),
	},
}

Loot.Fuel = {
	name = "Fuel Canister", rarity = "Common", weight = 0, value = 0, fuel = true,
	color = Color3.fromRGB(230, 50, 40), shape = "Cylinder", size = Vector3.new(2, 1.4, 1.4),
}

Loot.ByRarity = {}
for id, def in Loot.Items do
	def.id = id
	Loot.ByRarity[def.rarity] = Loot.ByRarity[def.rarity] or {}
	table.insert(Loot.ByRarity[def.rarity], id)
end
for _, list in Loot.ByRarity do
	table.sort(list)
end

-- luckMult boosts Rare and above.
function Loot.Roll(rng: Random, luckMult: number)
	local total = 0
	local weights = {}
	for _, rarity in Loot.RarityOrder do
		local info = Loot.Rarities[rarity]
		local w = info.chance
		if info.order >= 3 then
			w *= luckMult
		end
		weights[rarity] = w
		total += w
	end
	local pick = rng:NextNumber() * total
	local chosen = "Common"
	for _, rarity in Loot.RarityOrder do
		pick -= weights[rarity]
		if pick <= 0 then
			chosen = rarity
			break
		end
	end
	local list = Loot.ByRarity[chosen]
	return Loot.Items[list[rng:NextInteger(1, #list)]]
end

return Loot
