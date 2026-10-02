-- The core loop: intermission -> flight (with Sky Port stops) -> crash -> repeat.
-- Also owns each player's zone (Harbor / Balloon / Raft) and the loot they carry.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flight = {}
local S, Config, Shop

local stateFolder -- replicated attributes the client HUD reads

local flight = {
	state = "Waiting", -- Waiting | Intermission | Flying | Docked | Crashed
	altitude = 0,
	distance = 0,
	fuel = 0,
	nextPort = 0,
	portIndex = 0,
	burnTime = 0,
	dockUntil = 0,
	rate = 0,
	load = 0,
	participants = {}, -- [Player] = true for everyone who took part in this flight
}

local pstate = {} -- [Player] = per-player runtime state

local function now()
	return workspace:GetServerTimeNow()
end

local function getRoot(player: Player)
	local char = player.Character
	if not char then
		return nil
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart")
end
Flight.GetRoot = getRoot

function Flight.IsActive(): boolean
	return flight.state == "Flying" or flight.state == "Docked"
end

function Flight.GetState()
	return flight
end

function Flight.GetPlayerState(player: Player)
	return pstate[player]
end

function Flight.IsAboard(player: Player): boolean
	local ps = pstate[player]
	return ps ~= nil and ps.zone == "Balloon" and Flight.IsActive()
end

function Flight.GetAboard()
	local list = {}
	if not Flight.IsActive() then
		return list
	end
	for player, ps in pstate do
		if ps.zone == "Balloon" then
			table.insert(list, player)
		end
	end
	return list
end

---------------------------------------------------------------------------
-- Teleporting & zones
---------------------------------------------------------------------------
function Flight.Teleport(player: Player, cf: CFrame)
	local char = player.Character
	if not char then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 3)
	end)
	char:PivotTo(cf)
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

function Flight.BasketSpot(): CFrame
	local r = 6 + math.random() * (Config.BasketRadius - 10)
	local a = math.random() * math.pi * 2
	return CFrame.new(S.World.balloon.top + Vector3.new(math.cos(a) * r, 3.5, math.sin(a) * r))
end

local function harborSpot(): CFrame
	return CFrame.new(Config.HarborPos + Vector3.new(math.random(-8, 8), 4, math.random(-8, 8)))
end

local function raftSpot(): CFrame
	return CFrame.new(Config.RaftPos + Vector3.new(math.random(-10, 10), 3.5, math.random(-10, 10)))
end
Flight.RaftSpot = raftSpot

function Flight.SetZone(player: Player, zone: string)
	local ps = pstate[player]
	if not ps then
		return
	end
	ps.zone = zone
	player:SetAttribute("Zone", zone)
	if zone ~= "Raft" then
		ps.deliveries = 0
		player:SetAttribute("Deliveries", 0)
		if S.Raft then
			S.Raft.ClearBarrel(player)
		end
	end
end

local function placeByZone(player: Player)
	local ps = pstate[player]
	if not ps then
		return
	end
	if ps.zone == "Balloon" then
		Flight.Teleport(player, Flight.BasketSpot())
	elseif ps.zone == "Raft" then
		Flight.Teleport(player, raftSpot())
	else
		Flight.Teleport(player, harborSpot())
	end
end

function Flight.Board(player: Player)
	if not Flight.IsActive() or not pstate[player] then
		return
	end
	flight.participants[player] = true
	Flight.SetZone(player, "Balloon")
	placeByZone(player)
end

function Flight.ReturnToBalloon(player: Player, message: string?)
	local ps = pstate[player]
	if not ps or ps.zone ~= "Raft" or not Flight.IsActive() then
		return false
	end
	Flight.Board(player)
	S.Notify(player, message or "Back on the balloon!", "Green")
	S.Analytics.Custom(player, "ReturnedToBalloon")
	return true
end

---------------------------------------------------------------------------
-- Carrying loot
---------------------------------------------------------------------------
function Flight.GetCapacity(player: Player): number
	local data = S.Data.Get(player)
	local cap = Shop.UpgradeValue("Backpack", data and data.upgrades.Backpack or 0)
	if S.Monetization.OwnsPass(player, "MegaHook") then
		cap += 10
	end
	return cap
end

function Flight.GetHookRange(player: Player): number
	local data = S.Data.Get(player)
	local range = Shop.UpgradeValue("Hook", data and data.upgrades.Hook or 0)
	if S.Monetization.OwnsPass(player, "MegaHook") then
		range += 12
	end
	return range
end

local function updateTag(player: Player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("WeightTag")
	local ps = pstate[player]
	if not tag or not ps then
		return
	end
	tag.Weight.Text = string.format("🎒 %d kg", ps.weight)
	local ratio = ps.weight / math.max(1, Flight.GetCapacity(player))
	tag.Weight.TextColor3 = Color3.fromRGB(255, 255, 255):Lerp(Color3.fromRGB(255, 70, 70), math.clamp(ratio, 0, 1))
end

local function createTag(player: Player, char: Model)
	local head = char:WaitForChild("Head", 10)
	if not head then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "WeightTag"
	tag.Size = UDim2.fromOffset(160, 50)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 120
	tag.Parent = head
	local name = Instance.new("TextLabel")
	name.Name = "PlayerName"
	name.Size = UDim2.fromScale(1, 0.5)
	name.BackgroundTransparency = 1
	name.Text = player.DisplayName
	name.TextScaled = true
	name.Font = Enum.Font.GothamBold
	name.TextColor3 = if S.Monetization.OwnsPass(player, "VIP")
		then Color3.fromRGB(255, 215, 80)
		else Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Parent = tag
	local weight = Instance.new("TextLabel")
	weight.Name = "Weight"
	weight.Position = UDim2.fromScale(0, 0.5)
	weight.Size = UDim2.fromScale(1, 0.5)
	weight.BackgroundTransparency = 1
	weight.TextScaled = true
	weight.Font = Enum.Font.GothamBold
	weight.TextStrokeTransparency = 0.3
	weight.Parent = tag
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	updateTag(player)
end

function Flight.SyncCarry(player: Player)
	local ps = pstate[player]
	if not ps then
		return
	end
	local weight = 0
	for _, item in ps.carried do
		weight += item.weight
	end
	ps.weight = weight
	player:SetAttribute("CarryWeight", weight)
	player:SetAttribute("CarryCap", Flight.GetCapacity(player))
	player:SetAttribute("HookRange", Flight.GetHookRange(player))
	S.Remotes.Carry:FireClient(player, ps.carried)
	updateTag(player)
end

function Flight.TryCarry(player: Player, item)
	local ps = pstate[player]
	if not ps or not Flight.IsAboard(player) then
		return false, "You need to be on the balloon!"
	end
	if ps.weight + item.weight > Flight.GetCapacity(player) then
		return false, "Backpack full! Drop something or upgrade your Backpack."
	end
	table.insert(ps.carried, {
		id = item.id, name = item.name, rarity = item.rarity, weight = item.weight, value = item.value,
	})
	Flight.SyncCarry(player)
	return true
end

function Flight.DropItem(player: Player, index)
	local ps = pstate[player]
	if not ps or type(index) ~= "number" then
		return
	end
	local item = ps.carried[math.floor(index)]
	if not item then
		return
	end
	table.remove(ps.carried, math.floor(index))
	Flight.SyncCarry(player)
	S.Notify(player, string.format("Tossed %s overboard (-%d kg)", item.name, item.weight), "Gray")
end

-- Returns true if the loot was lost.
local function loseLoot(player: Player): boolean
	local ps = pstate[player]
	if not ps or #ps.carried == 0 then
		return false
	end
	if S.Monetization.OwnsPass(player, "Lifejacket") then
		S.Notify(player, "🦺 Your Lifejacket saved your loot!", "Gold")
		return false
	end
	table.clear(ps.carried)
	Flight.SyncCarry(player)
	return true
end

function Flight.CoinMultiplier(player: Player): number
	local mult = 1
	if S.Monetization.OwnsPass(player, "VIP") then
		mult *= 2
	end
	if S.Monetization.IsGroupMember(player) then
		mult *= 1 + Config.GroupBonus
	end
	return mult
end

function Flight.CashOut(player: Player)
	local ps = pstate[player]
	local data = S.Data.Get(player)
	if not ps or not data or #ps.carried == 0 then
		return 0
	end
	local luckChance = Shop.UpgradeValue("Luck", data.upgrades.Luck) / 100
	local total, doubled = 0, 0
	for _, item in ps.carried do
		local value = item.value
		if math.random() < luckChance then
			value *= 2
			doubled += 1
		end
		total += value
	end
	total = math.floor(total * Flight.CoinMultiplier(player))
	local count = #ps.carried
	table.clear(ps.carried)
	Flight.SyncCarry(player)
	S.Data.AddCoins(player, total, true)
	local extra = if doubled > 0 then string.format(" (%d lucky doubles!)", doubled) else ""
	S.Notify(player, string.format("💰 Cashed out %d items for %d coins!%s", count, total, extra), "Gold", true)
	S.Analytics.Earn(player, total, "CashOut")
	return total
end

---------------------------------------------------------------------------
-- Overboard, flinging & shoving
---------------------------------------------------------------------------
function Flight.Fling(player: Player, velocity: Vector3)
	S.Remotes.Fling:FireClient(player, velocity)
end

function Flight.SetFallReason(player: Player, reason: string, seconds: number)
	local ps = pstate[player]
	if ps then
		ps.fallReason = reason
		ps.fallReasonUntil = os.clock() + seconds
	end
end

function Flight.Overboard(player: Player, reason: string?)
	local ps = pstate[player]
	if not ps or ps.zone ~= "Balloon" or not Flight.IsActive() then
		return
	end
	if not reason and ps.fallReason and os.clock() < ps.fallReasonUntil then
		reason = ps.fallReason
	end
	ps.fallReason = nil
	local lost = loseLoot(player)
	Flight.SetZone(player, "Raft")
	S.Notify(nil, string.format("🌊 %s went OVERBOARD! %s", player.DisplayName, reason or ""), "Red")
	S.Notify(player, if lost then "SPLASH! Your loot sank..." else "SPLASH!", "Red", true)
	S.Analytics.Custom(player, "Overboard")

	if getRoot(player) then
		task.spawn(Flight.Teleport, player, raftSpot())
	end

	local data = S.Data.Get(player)
	if data and data.tokens.Rescue > 0 then
		data.tokens.Rescue -= 1
		S.Data.MarkChanged(player)
		task.delay(2, Flight.ReturnToBalloon, player, "🪢 Rescue Rope used - you're back!")
	end
end

function Flight.Shove(player: Player)
	if not Config.ShoveEnabled or flight.state ~= "Flying" then
		return
	end
	local ps = pstate[player]
	if not ps or ps.zone ~= "Balloon" or now() < ps.shoveReadyAt then
		return
	end
	local root = getRoot(player)
	if not root then
		return
	end
	ps.shoveReadyAt = now() + Config.ShoveCooldown
	player:SetAttribute("ShoveReadyAt", ps.shoveReadyAt)

	local look = root.CFrame.LookVector
	local bestTarget, bestRoot, bestDist = nil, nil, Config.ShoveRange
	local function consider(target, targetRoot)
		local offset = targetRoot.Position - root.Position
		local dist = offset.Magnitude
		if dist > 0.1 and dist < bestDist and look:Dot(offset.Unit) > 0.2 then
			bestTarget, bestRoot, bestDist = target, targetRoot, dist
		end
	end
	for other, ops in pstate do
		if other ~= player and ops.zone == "Balloon" then
			local otherRoot = getRoot(other)
			if otherRoot then
				consider(other, otherRoot)
			end
		end
	end
	for _, bot in S.Bots.GetAboard() do
		local botRoot = bot.model and bot.model:FindFirstChild("HumanoidRootPart")
		if botRoot then
			consider(bot, botRoot)
		end
	end
	if not bestTarget then
		return
	end

	local dir = (bestRoot.Position - root.Position) * Vector3.new(1, 0, 1)
	dir = if dir.Magnitude > 0.01 then dir.Unit else look
	local velocity = dir * Config.ShoveForce + Vector3.new(0, 30, 0)
	if typeof(bestTarget) == "Instance" then
		Flight.Fling(bestTarget, velocity)
		Flight.SetFallReason(bestTarget, "(shoved by " .. player.DisplayName .. ")", 5)
		S.Notify(bestTarget, player.DisplayName .. " shoved you!", "Orange")
	else
		S.Bots.Fling(bestTarget, velocity, "(shoved by " .. player.DisplayName .. ")")
	end
end

---------------------------------------------------------------------------
-- Balloon physics
---------------------------------------------------------------------------
function Flight.AddFuel(amount: number)
	flight.fuel = math.clamp(flight.fuel + amount, 0, Config.MaxFuel)
end

function Flight.AddAltitude(amount: number)
	flight.altitude = math.clamp(flight.altitude + amount, 0, Config.MaxAltitude)
end

function Flight.PumpBurner(by: string?)
	if flight.state ~= "Flying" then
		return false
	end
	if flight.fuel <= 0 then
		return false
	end
	flight.burnTime = math.min(flight.burnTime + Config.BurnerPump, Config.BurnerMaxTime)
	return true
end

function Flight.GetBalloonCapacity(): number
	local passengers = #Players:GetPlayers() + #S.Bots.GetAboard()
	return Config.CapacityPerPlayer * math.max(Config.MinCapacityPlayers, passengers)
end

function Flight.TotalWeight(): number
	local total = 0
	for _, player in Flight.GetAboard() do
		total += Config.BodyWeight + pstate[player].weight
	end
	for _, bot in S.Bots.GetAboard() do
		total += Config.BodyWeight + bot.weight
	end
	return total
end

local function publishState()
	stateFolder:SetAttribute("State", flight.state)
	stateFolder:SetAttribute("Altitude", math.floor(flight.altitude * 10) / 10)
	stateFolder:SetAttribute("Distance", math.floor(flight.distance))
	stateFolder:SetAttribute("Fuel", math.floor(flight.fuel))
	stateFolder:SetAttribute("NextPort", math.floor(flight.nextPort))
	stateFolder:SetAttribute("Load", math.floor(flight.load * 100) / 100)
	stateFolder:SetAttribute("Rate", math.floor(flight.rate * 100) / 100)
	stateFolder:SetAttribute("Burning", flight.burnTime > 0 and flight.fuel > 0)
	stateFolder:SetAttribute("DockEndsAt", if flight.state == "Docked" then now() + (flight.dockUntil - os.clock()) else 0)

	local balloon = S.World.balloon
	balloon.fire.Enabled = flight.burnTime > 0 and flight.fuel > 0
	local top = balloon.top
	balloon.sea.CFrame = CFrame.new(top - Vector3.new(0, 12 + flight.altitude * 2.4, 0))
end

local function useTokens(tokenName: string, apply)
	for _, player in Players:GetPlayers() do
		local data = S.Data.Get(player)
		if data and data.tokens[tokenName] > 0 then
			data.tokens[tokenName] -= 1
			S.Data.MarkChanged(player)
			apply(player)
			return true
		end
	end
	return false
end

function Flight.EmergencyBurner(player: Player)
	Flight.AddAltitude(Config.EmergencyBurnerAltitude)
	Flight.AddFuel(10)
	S.Notify(nil, "🔥 " .. player.DisplayName .. " fired the EMERGENCY BURNER and saved everyone!", "Gold", true)
end

function Flight.TreasureRain(player: Player)
	S.Loot.SpawnBurst(Config.TreasureRainItems)
	S.Notify(nil, "💎 " .. player.DisplayName .. " started a TREASURE RAIN! Grab it!", "Gold", true)
end

local function startDock()
	flight.state = "Docked"
	flight.portIndex += 1
	flight.dockUntil = os.clock() + Config.DockTime
	flight.burnTime = 0
	Flight.AddFuel(Config.DockFuel)
	S.Loot.SetSpeed(0)
	S.World.ShowDock(true)
	S.Notify(nil, string.format("⚓ SKY PORT #%d! Loot is cashed out. +%d fuel", flight.portIndex, Config.DockFuel), "Gold", true)
	for _, player in Flight.GetAboard() do
		Flight.CashOut(player)
		S.Analytics.Progress(player, "SkyPort", flight.portIndex)
	end
	S.Bots.OnDock()
	for player, ps in pstate do
		if ps.zone == "Raft" then
			Flight.ReturnToBalloon(player, "⚓ The Sky Port crew pulled you back aboard!")
		end
	end
end

local function endDock()
	flight.state = "Flying"
	flight.nextPort = flight.distance + Config.PortEvery
	S.Loot.SetSpeed(Config.Speed)
	S.World.ShowDock(false)
	S.Notify(nil, "🎈 Departing! Next Sky Port in " .. Config.PortEvery .. " m", "White")
end

local function crash()
	flight.state = "Crashed"
	S.Vote.Cancel()
	S.Loot.SetSpeed(0)
	S.Notify(nil, string.format("💥 SPLASH! The balloon hit the sea after %d m!", math.floor(flight.distance)), "Red", true)

	local distanceCoins = math.floor(flight.distance / Config.DistanceCoinsPer)
	for player in flight.participants do
		if player.Parent then
			local ps = pstate[player]
			if ps and ps.zone == "Balloon" then
				loseLoot(player)
			end
			local data = S.Data.Get(player)
			if data then
				data.flights += 1
				if flight.distance > data.bestDistance then
					data.bestDistance = math.floor(flight.distance)
					S.Notify(player, "🏅 New personal best: " .. data.bestDistance .. " m!", "Gold")
				end
				local coins = math.floor(distanceCoins * Flight.CoinMultiplier(player))
				if coins > 0 then
					S.Data.AddCoins(player, coins, true)
					S.Notify(player, string.format("✈ Flight bonus: +%d coins for %d m", coins, math.floor(flight.distance)), "Gold")
					S.Analytics.Earn(player, coins, "DistanceBonus")
				end
				S.Data.MarkChanged(player)
			end
			S.Analytics.Custom(player, "FlightEnded", math.floor(flight.distance))
		end
	end
	publishState()
	task.wait(3)

	S.Loot.ClearAll()
	S.Bots.Clear()
	for player, ps in pstate do
		Flight.SetZone(player, "Harbor")
		if getRoot(player) then
			task.spawn(Flight.Teleport, player, harborSpot())
		end
	end
	table.clear(flight.participants)
end

local function startFlight()
	flight.state = "Flying"
	flight.altitude = Config.StartAltitude
	flight.distance = 0
	flight.fuel = Config.StartFuel
	flight.nextPort = Config.PortEvery
	flight.portIndex = 0
	flight.burnTime = 0
	S.Loot.SetSpeed(Config.Speed)
	S.Loot.Prewarm()
	for player in pstate do
		if getRoot(player) then
			task.spawn(Flight.Board, player)
			S.Analytics.Funnel(player, 2, "BoardedFirstFlight")
		end
	end
	S.Bots.Refresh()
	S.Notify(nil, "🎈 LIFT OFF! Grab loot, but watch the weight!", "White", true)
	task.delay(2, useTokens, "TreasureRain", Flight.TreasureRain)
end

local function step(dt: number)
	if flight.state == "Flying" then
		local burning = flight.burnTime > 0 and flight.fuel > 0
		flight.burnTime = math.max(0, flight.burnTime - dt)
		if burning then
			flight.fuel = math.max(0, flight.fuel - Config.BurnerFuelPerSecond * dt)
		end
		flight.load = Flight.TotalWeight() / Flight.GetBalloonCapacity()
		flight.rate = Config.BaseLift
			- flight.load * Config.WeightSink
			- flight.distance * Config.LeakPerMeter
			+ (if burning then Config.BurnerLift else 0)
		flight.altitude = math.clamp(flight.altitude + flight.rate * dt, 0, Config.MaxAltitude)
		flight.distance += Config.Speed * dt

		if flight.altitude < Config.AutoBurnerAltitude then
			useTokens("EmergencyBurner", Flight.EmergencyBurner)
		end

		S.Loot.Step(dt, flight.distance)
		S.Bots.Step(dt, flight)
		S.Vote.Step(flight.altitude)

		if flight.altitude <= 0 then
			crash()
			return
		elseif flight.distance >= flight.nextPort then
			startDock()
		end
	elseif flight.state == "Docked" then
		S.Bots.Step(dt, flight)
		if os.clock() >= flight.dockUntil then
			endDock()
		end
	end
	publishState()
end

---------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------
local function onCharacterAdded(player: Player, char: Model)
	if not char:IsDescendantOf(workspace) then
		char.AncestryChanged:Wait()
	end
	task.spawn(createTag, player, char)
	S.ShopSvc.ApplyTrail(player)

	local humanoid = char:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(function()
			if Flight.IsAboard(player) then
				Flight.Overboard(player, "(fell apart)")
			end
		end)
	end

	task.wait(0.2)
	local ps = pstate[player]
	if not ps then
		return
	end
	if Flight.IsActive() and ps.zone == "Harbor" then
		Flight.Board(player)
		S.Bots.Refresh()
	else
		placeByZone(player)
	end
end

local function onPlayerAdded(player: Player)
	pstate[player] = {
		zone = "Harbor",
		carried = {},
		weight = 0,
		deliveries = 0,
		shoveReadyAt = 0,
		fallReason = nil,
		fallReasonUntil = 0,
	}
	player:SetAttribute("Zone", "Harbor")
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	task.spawn(function()
		S.Data.WaitForProfile(player)
		Flight.SyncCarry(player)
		S.ShopSvc.ApplyTrail(player)
	end)
end

-- Falling out of a zone
local function watchFalls()
	while true do
		task.wait(0.2)
		for player, ps in pstate do
			local root = getRoot(player)
			if root then
				local y = root.Position.Y
				if ps.zone == "Balloon" and Flight.IsActive() then
					if y < S.World.balloon.top.Y - 25 then
						Flight.Overboard(player)
					end
				elseif ps.zone == "Raft" then
					if y < Config.RaftPos.Y - 15 then
						Flight.Teleport(player, raftSpot())
					end
				elseif y < Config.HarborPos.Y - 30 then
					Flight.Teleport(player, harborSpot())
				end
			end
		end
	end
end

function Flight.Init(services)
	S = services
	Config = S.Config
	Shop = S.Shop
	stateFolder = Instance.new("Folder")
	stateFolder.Name = "FlightState"
	stateFolder.Parent = ReplicatedStorage
end

function Flight.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		pstate[player] = nil
		flight.participants[player] = nil
		task.defer(S.Bots.Refresh)
	end)

	S.World.balloon.burnerPrompt.Triggered:Connect(function(player)
		if not Flight.IsAboard(player) then
			return
		end
		if not Flight.PumpBurner(player.Name) and flight.state == "Flying" then
			S.Notify(player, "⛽ No fuel! Hook fuel canisters or wait for the raft crew.", "Red")
		end
	end)

	task.spawn(watchFalls)

	task.spawn(function()
		while true do
			flight.state = "Waiting"
			publishState()
			while #Players:GetPlayers() == 0 do
				task.wait(1)
			end
			flight.state = "Intermission"
			for t = Config.Intermission, 1, -1 do
				stateFolder:SetAttribute("Countdown", t)
				publishState()
				task.wait(1)
			end
			stateFolder:SetAttribute("Countdown", 0)

			startFlight()
			local last = os.clock()
			while Flight.IsActive() do
				task.wait(0.1)
				local t = os.clock()
				step(t - last)
				last = t
				if #Players:GetPlayers() == 0 and Flight.IsActive() then
					crash()
				end
			end
		end
	end)
end

return Flight
