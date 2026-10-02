-- Coin shop (upgrades, trails), daily login rewards and the profile snapshot
-- the client UI is built from.

local ShopService = {}
local S, Config, Shop

local function dailyState(data)
	local now = os.time()
	local available = now - data.daily.last >= Shop.DailyCooldown
	local streak = data.daily.streak
	if now - data.daily.last > Shop.DailyStreakWindow then
		streak = 0
	end
	local nextIndex = (streak % #Shop.DailyRewards) + 1
	return available, streak, Shop.DailyRewards[nextIndex]
end

function ShopService.Snapshot(player: Player)
	local data = S.Data.Get(player)
	if not data then
		return nil
	end
	local available, streak, reward = dailyState(data)
	local passes = {}
	for name in Config.GamePasses do
		passes[name] = S.Monetization.OwnsPass(player, name)
	end
	return {
		coins = data.coins,
		bestDistance = data.bestDistance,
		upgrades = data.upgrades,
		trails = data.trails,
		equippedTrail = data.equippedTrail,
		tokens = data.tokens,
		daily = { available = available, streak = streak, reward = reward },
		passes = passes,
	}
end

function ShopService.ApplyTrail(player: Player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local data = S.Data.Get(player)
	if not root or not data then
		return
	end
	local old = root:FindFirstChild("OB_Trail")
	if old then
		old:Destroy()
	end
	for _, name in { "OB_TrailA0", "OB_TrailA1" } do
		local a = root:FindFirstChild(name)
		if a then
			a:Destroy()
		end
	end
	local trailDef = Shop.GetTrail(data.equippedTrail)
	if not trailDef then
		return
	end
	if trailDef.vip and not S.Monetization.OwnsPass(player, "VIP") then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "OB_TrailA0"
	a0.Position = Vector3.new(0, 0.8, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "OB_TrailA1"
	a1.Position = Vector3.new(0, -0.8, 0)
	a1.Parent = root
	local keypoints = {}
	for i, color in trailDef.colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(1, #trailDef.colors - 1), color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, trailDef.colors[1]))
	end
	local trail = Instance.new("Trail")
	trail.Name = "OB_Trail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(keypoints)
	trail.Lifetime = 0.6
	trail.LightEmission = 0.5
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = root
end

function ShopService.BuyUpgrade(player: Player, id)
	local def = type(id) == "string" and Shop.Upgrades[id]
	local data = S.Data.Get(player)
	if not def or not data then
		return
	end
	local level = data.upgrades[id] or 0
	if level >= def.max then
		S.Notify(player, def.name .. " is already maxed!", "Gray")
		return
	end
	local cost = Shop.UpgradeCost(id, level)
	if not S.Data.SpendCoins(player, cost) then
		S.Notify(player, "Not enough coins! Fly further and cash out at Sky Ports.", "Red")
		return
	end
	data.upgrades[id] = level + 1
	S.Data.MarkChanged(player)
	S.Flight.SyncCarry(player)
	S.Notify(player, string.format("⬆️ %s upgraded to level %d!", def.name, level + 1), "Green")
	S.Analytics.Spend(player, cost, "Upgrade_" .. id)
end

function ShopService.BuyTrail(player: Player, id)
	local trail = type(id) == "string" and Shop.GetTrail(id)
	local data = S.Data.Get(player)
	if not trail or not data or trail.vip then
		return
	end
	if data.trails[id] then
		ShopService.EquipTrail(player, id)
		return
	end
	if not S.Data.SpendCoins(player, trail.price) then
		S.Notify(player, "Not enough coins for " .. trail.name .. "!", "Red")
		return
	end
	data.trails[id] = true
	S.Analytics.Spend(player, trail.price, "Trail_" .. id)
	ShopService.EquipTrail(player, id)
end

function ShopService.EquipTrail(player: Player, id)
	local data = S.Data.Get(player)
	if not data or type(id) ~= "string" then
		return
	end
	if id ~= "" then
		local trail = Shop.GetTrail(id)
		if not trail then
			return
		end
		local owned = data.trails[id] or (trail.vip and S.Monetization.OwnsPass(player, "VIP"))
		if not owned then
			return
		end
	end
	data.equippedTrail = id
	S.Data.MarkChanged(player)
	ShopService.ApplyTrail(player)
end

function ShopService.ClaimDaily(player: Player)
	local data = S.Data.Get(player)
	if not data then
		return
	end
	local available, streak, reward = dailyState(data)
	if not available then
		S.Notify(player, "Come back tomorrow for your next daily reward!", "Gray")
		return
	end
	data.daily.streak = streak + 1
	data.daily.last = os.time()
	S.Data.AddCoins(player, reward, true)
	S.Notify(player, string.format("🎁 Day %d reward: +%d coins!", data.daily.streak, reward), "Gold", true)
	S.Analytics.Earn(player, reward, "DailyReward")
end

function ShopService.Init(services)
	S = services
	Config = S.Config
	Shop = S.Shop
end

function ShopService.Start()
	S.Data.Changed:Connect(function(player)
		local snapshot = ShopService.Snapshot(player)
		if snapshot then
			S.Remotes.Profile:FireClient(player, snapshot)
		end
	end)
end

return ShopService
