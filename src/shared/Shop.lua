-- Coin shop: permanent upgrades, cosmetic trails and daily rewards.

local Shop = {}

Shop.Upgrades = {
	Hook = {
		name = "Hook Range", desc = "Grab loot from further away.",
		max = 8, baseCost = 50, growth = 1.7, base = 18, per = 6, unit = " studs",
	},
	Backpack = {
		name = "Backpack", desc = "Carry more weight at once.",
		max = 10, baseCost = 75, growth = 1.7, base = 10, per = 5, unit = " kg",
	},
	Luck = {
		name = "Lucky Hook", desc = "Chance to double an item's value when you cash out.",
		max = 10, baseCost = 150, growth = 1.8, base = 0, per = 5, unit = "%",
	},
}

Shop.UpgradeOrder = { "Hook", "Backpack", "Luck" }

function Shop.UpgradeCost(id: string, level: number): number
	local u = Shop.Upgrades[id]
	return math.floor(u.baseCost * u.growth ^ level)
end

function Shop.UpgradeValue(id: string, level: number): number
	local u = Shop.Upgrades[id]
	return u.base + u.per * level
end

Shop.Trails = {
	{
		id = "Sky", name = "Sky Trail", price = 200,
		colors = { Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 255, 255) },
	},
	{
		id = "Sunset", name = "Sunset Trail", price = 600,
		colors = { Color3.fromRGB(255, 120, 60), Color3.fromRGB(255, 60, 140) },
	},
	{
		id = "Gold", name = "Golden Trail", price = 1500,
		colors = { Color3.fromRGB(255, 215, 60), Color3.fromRGB(255, 150, 20) },
	},
	{
		id = "Rainbow", name = "Rainbow Trail", price = 5000,
		colors = {
			Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 170, 40), Color3.fromRGB(255, 240, 60),
			Color3.fromRGB(60, 220, 90), Color3.fromRGB(60, 140, 255), Color3.fromRGB(170, 80, 255),
		},
	},
	{
		id = "Storm", name = "Storm Trail (VIP)", price = 0, vip = true,
		colors = { Color3.fromRGB(70, 60, 140), Color3.fromRGB(180, 230, 255) },
	},
}

function Shop.GetTrail(id: string)
	for _, trail in Shop.Trails do
		if trail.id == id then
			return trail
		end
	end
	return nil
end

-- Reward for day 1..7 of a login streak (repeats after day 7).
Shop.DailyRewards = { 50, 80, 120, 180, 250, 350, 600 }
Shop.DailyCooldown = 20 * 3600
Shop.DailyStreakWindow = 48 * 3600

return Shop
