-- Raid lifecycle: deploy from the Outpost onto a chosen map, extract at a
-- lift to keep your loot, or die and drop it for someone else.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))

local Raid = {}
local S, Stacks

local raidState = {} -- [Player] = { mapId, endsAt, kills }
local lifts = {} -- [mapId] = { [index] = { state, endsAt, readyAt, info } }

local function serverNow()
	return workspace:GetServerTimeNow()
end

function Raid.IsInRaid(player: Player): boolean
	return raidState[player] ~= nil
end

function Raid.GetMapDef(mapId)
	for _, map in Config.Maps do
		if map.id == mapId then
			return map
		end
	end
	return nil
end

local function setRaidAttributes(player: Player, st)
	player:SetAttribute("InRaid", st ~= nil)
	player:SetAttribute("MapId", if st then st.mapId else "")
	player:SetAttribute("RaidEndsAt", if st then st.endsAt else 0)
end

local function outpostSpot(): CFrame
	return CFrame.new(Config.HubPos + Vector3.new(math.random(-10, 10), 4, 45 + math.random(-6, 6)))
end
Raid.OutpostSpot = outpostSpot

---------------------------------------------------------------------------
-- Deploy
---------------------------------------------------------------------------
local function loadoutIsEmpty(loadout): boolean
	for _, id in loadout.weapons do
		if id ~= "" then
			return false
		end
	end
	return #loadout.items == 0
end

function Raid.Deploy(player: Player, mapId)
	local map = type(mapId) == "string" and S.World.maps[mapId]
	local data = S.Data.Get(player)
	local root = S.GetRoot(player)
	if not map or not data or not root or raidState[player] then
		return
	end

	local loadout = data.loadout
	local freeKit = false
	local hasWeapon = loadout.weapons[1] ~= "" or loadout.weapons[2] ~= ""
	if not hasWeapon then
		-- Never let a broke player get stuck: free starter kit.
		freeKit = loadoutIsEmpty(loadout)
		loadout.weapons[1] = Config.StarterKit.weapon
		if freeKit then
			for _, slot in Config.StarterKit.items do
				table.insert(loadout.items, { id = slot.id, count = slot.count })
			end
		end
	end

	S.Inventory.Create(player, loadout)
	-- Items are now "at risk": remove them from the saved loadout and save
	-- immediately, so leaving mid-raid can't duplicate anything.
	data.loadout = { weapons = { "", "" }, items = {} }
	data.stats.raids += 1
	S.Data.MarkChanged(player)
	task.spawn(S.Data.Save, player)

	player:SetAttribute("InQuarters", false)
	local st = { mapId = mapId, endsAt = serverNow() + Config.RaidDuration, kills = 0, warned = false }
	raidState[player] = st
	setRaidAttributes(player, st)
	S.Combat.ResetPlayer(player)

	local spot = map.insertions[math.random(1, #map.insertions)]
	S.Teleport(player, spot)
	local char = player.Character
	if char then
		local ff = Instance.new("ForceField")
		ff.Visible = true
		ff.Parent = char
		task.delay(Config.SpawnProtection, function()
			if ff.Parent then
				ff:Destroy()
			end
		end)
	end
	S.Notify(player, "⬆ Deployed to " .. map.def.name .. ". Find loot, then reach an EXTRACTION lift!", "Orange", true)
	if freeKit then
		S.Notify(player, "You got a free Scrap Pistol kit. Good luck, raider.", "Gray")
	end
	S.Analytics.Funnel(player, 2)
	S.Analytics.Custom(player, "Deploy_" .. mapId)
end

---------------------------------------------------------------------------
-- Leaving a raid
---------------------------------------------------------------------------
local function endRaid(player: Player)
	raidState[player] = nil
	setRaidAttributes(player, nil)
	S.Inventory.Clear(player)
	S.Loot.Close(player)
	S.Combat.ResetPlayer(player)
end

-- Puts items into the stash; anything that doesn't fit is auto-sold.
function Raid.DepositToStash(player: Player, list): number
	local data = S.Data.Get(player)
	if not data then
		return 0
	end
	local capacity = S.Outpost.StashCapacity(player)
	local overflowCredits = 0
	for _, slot in list do
		local left = Stacks.Add(data.stash, capacity, slot.id, slot.count)
		if left > 0 then
			overflowCredits += Items.Get(slot.id).value * left
		end
	end
	if overflowCredits > 0 then
		data.credits += overflowCredits
		S.Notify(player, string.format("Stash full - sold the overflow for %d credits.", overflowCredits), "Gold")
	end
	return overflowCredits
end

function Raid.Extract(player: Player)
	local st = raidState[player]
	local inv = S.Inventory.Get(player)
	local data = S.Data.Get(player)
	if not st or not inv or not data then
		return
	end
	local list = S.Inventory.AllItems(inv, true)
	local value = Stacks.Value(list)
	Raid.DepositToStash(player, list)
	data.stats.extracts += 1
	data.totalExtracted += value
	if value > data.stats.bestExtract then
		data.stats.bestExtract = value
	end
	endRaid(player)
	S.Data.AddXp(player, Config.XpPerExtract)
	S.Data.MarkChanged(player)
	task.spawn(S.Data.Save, player)
	S.Teleport(player, outpostSpot())
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
	S.Remotes.Effect:FireClient(player, "Sound", "Extract")
	S.Notify(player, string.format("✅ EXTRACTED! Loot worth %d credits is in your stash.", value), "Green", true)
	S.Analytics.Funnel(player, 4)
	S.Analytics.Custom(player, "ExtractValue", value)
end

function Raid.OnDeath(player: Player)
	local st = raidState[player]
	local inv = S.Inventory.Get(player)
	local data = S.Data.Get(player)
	if not st or not inv then
		return
	end
	local root = S.GetRoot(player) or (player.Character and player.Character:FindFirstChild("HumanoidRootPart"))
	local killer = S.Combat.GetKiller(player)

	-- Safe pocket always survives
	Raid.DepositToStash(player, inv.safe)

	local dropped = S.Inventory.AllItems(inv, false)
	if data and data.tokens.Insurance > 0 then
		data.tokens.Insurance -= 1
		local weapons, rest = {}, {}
		for _, slot in dropped do
			if Items.Get(slot.id).weapon then
				table.insert(weapons, slot)
			else
				table.insert(rest, slot)
			end
		end
		Raid.DepositToStash(player, weapons)
		dropped = rest
		S.Notify(player, "🛡️ Insurance returned your weapons to your stash.", "Gold")
	end
	if root and #dropped > 0 then
		S.Loot.SpawnTemporary(CFrame.new(root.Position - Vector3.new(0, 2.5, 0)), "DeathCache", dropped, st.mapId, player.DisplayName .. "'s Backpack")
	end

	if data then
		data.stats.deaths += 1
		S.Data.MarkChanged(player)
		task.spawn(S.Data.Save, player)
	end
	endRaid(player)

	if typeof(killer) == "Instance" and killer ~= player and raidState[killer] then
		raidState[killer].kills += 1
		S.Data.AddXp(killer, Config.XpPerKill.Raider)
		local kd = S.Data.Get(killer)
		if kd then
			kd.stats.kills += 1
		end
		S.Notify(killer, "☠ You took down " .. player.DisplayName .. " - their backpack is up for grabs!", "Orange")
		S.Notify(player, "☠ You were taken down by " .. killer.DisplayName .. ". Your loot is lost.", "Red", true)
	else
		local by = if type(killer) == "table" and killer.def then " by a " .. killer.def.name else ""
		S.Notify(player, "☠ You were destroyed" .. by .. ". Your loot is lost.", "Red", true)
	end
	S.Analytics.Custom(player, "Died")
end

function Raid.OnRobotKilled(player: Player, typeName: string)
	local st = raidState[player]
	if st then
		st.kills += 1
	end
	S.Data.AddXp(player, Config.XpPerKill[typeName] or 10)
	local data = S.Data.Get(player)
	if data then
		data.stats.kills += 1
	end
end

---------------------------------------------------------------------------
-- Extraction lifts
---------------------------------------------------------------------------
local function setLiftLook(lift)
	local color = if lift.state == "Idle" then Color3.fromRGB(60, 200, 90)
		elseif lift.state == "Countdown" then Color3.fromRGB(255, 170, 40)
		else Color3.fromRGB(120, 120, 120)
	lift.info.pad.Color = color
	lift.info.beacon.Color = color
	lift.info.label.TextColor3 = color
	lift.info.prompt.Enabled = lift.state == "Idle"
end

local function runLift(mapId: string, lift, caller: Player)
	lift.state = "Countdown"
	lift.endsAt = os.clock() + Config.ExtractCountdown
	setLiftLook(lift)
	S.Robots.Noise(mapId, lift.info.position, Config.ExtractAlertRadius)
	S.Remotes.Effect:FireAllClients("Sound", "LiftAlarm", lift.info.position)
	for player, st in raidState do
		if st.mapId == mapId then
			S.Notify(player, string.format("🛗 %s called Extraction %d! Lift arrives in %ds.", caller.DisplayName, lift.info.index, Config.ExtractCountdown), "Orange")
		end
	end
	while os.clock() < lift.endsAt do
		lift.info.label.Text = string.format("LIFT IN %ds", math.ceil(lift.endsAt - os.clock()))
		task.wait(0.25)
	end
	local extracted = 0
	for player, st in table.clone(raidState) do
		local root = S.GetRoot(player)
		if st.mapId == mapId and root then
			local flat = Vector3.new(root.Position.X, lift.info.position.Y, root.Position.Z)
			if (flat - lift.info.position).Magnitude <= Config.ExtractRadius + 1 and math.abs(root.Position.Y - lift.info.position.Y) < 10 then
				Raid.Extract(player)
				extracted += 1
			end
		end
	end
	lift.state = "Cooldown"
	lift.info.label.Text = "LIFT RECHARGING"
	setLiftLook(lift)
	task.wait(Config.ExtractCooldown)
	lift.state = "Idle"
	lift.info.label.Text = "EXTRACTION"
	setLiftLook(lift)
end

---------------------------------------------------------------------------
-- Raid timer ("the storm")
---------------------------------------------------------------------------
local function stormTick()
	local t = serverNow()
	for player, st in raidState do
		local left = st.endsAt - t
		if left <= 60 and not st.warned then
			st.warned = true
			S.Notify(player, "⚡ 1 MINUTE until the storm hits! Get to an extraction lift!", "Red", true)
		end
		if left <= 0 then
			S.Combat.DamagePlayer(player, Config.StormDamagePerSecond, nil)
		end
	end
end

function Raid.Init(services)
	S = services
	Stacks = S.Stacks
end

function Raid.Start()
	for mapId, map in S.World.maps do
		lifts[mapId] = {}
		for _, info in map.extracts do
			local lift = { state = "Idle", info = info, endsAt = 0 }
			lifts[mapId][info.index] = lift
			info.prompt.Triggered:Connect(function(player)
				local st = raidState[player]
				if lift.state ~= "Idle" or not st or st.mapId ~= mapId then
					return
				end
				task.spawn(runLift, mapId, lift, player)
			end)
		end
	end

	task.spawn(function()
		while true do
			task.wait(1)
			stormTick()
		end
	end)

	local function onCharacter(player: Player, char: Model)
		local humanoid = char:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				if raidState[player] then
					Raid.OnDeath(player)
				end
			end)
		end
		player:SetAttribute("Shield", 0)
		player:SetAttribute("InQuarters", false)
	end
	local function onPlayer(player: Player)
		setRaidAttributes(player, nil)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	-- Leaving mid-raid counts as dying (the loot was already taken out of
	-- the saved loadout when deploying).
	S.Data.AddRemovingHook(function(player)
		if raidState[player] then
			Raid.OnDeath(player)
		end
		S.Inventory.Forget(player)
	end)
end

return Raid
