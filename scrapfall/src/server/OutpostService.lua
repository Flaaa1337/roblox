-- The Outpost: trader, stash & loadout, workbench crafting, upgrades and the
-- map terminal. Also builds the profile snapshot the client UI shows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local Crafting = require(Shared:WaitForChild("Crafting"))

local Outpost = {}
local S, Stacks

local openBench = {} -- [Player] = { tier, position }

function Outpost.StashCapacity(player: Player): number
	local data = S.Data.Get(player)
	local cap = Config.StashBase + (data and data.upgrades.Stash or 0) * Config.StashPerUpgrade
	if S.Monetization.OwnsPass(player, "ExtraStash") then
		cap += 40
	end
	return cap
end

local function sellMultiplier(player: Player): number
	local mult = 1
	if S.Monetization.OwnsPass(player, "VIP") then
		mult += Config.VipSellBonus
	end
	if S.Monetization.IsGroupMember(player) then
		mult += Config.GroupSellBonus
	end
	return mult
end

local function levelInfo(xp: number)
	local level, need = 1, Config.XpPerLevel
	while xp >= need do
		xp -= need
		level += 1
		need = level * Config.XpPerLevel
	end
	return level, xp, need
end

function Outpost.Snapshot(player: Player)
	local data = S.Data.Get(player)
	if not data then
		return nil
	end
	local level, into, need = levelInfo(data.xp)
	local passes = {}
	for name in Config.GamePasses do
		passes[name] = S.Monetization.OwnsPass(player, name)
	end
	local raiders = {}
	for _, p in Players:GetPlayers() do
		local mapId = p:GetAttribute("MapId")
		if mapId and mapId ~= "" then
			raiders[mapId] = (raiders[mapId] or 0) + 1
		end
	end
	local maps = {}
	for _, map in Config.Maps do
		table.insert(maps, { id = map.id, name = map.name, desc = map.desc, danger = map.danger, raiders = raiders[map.id] or 0 })
	end
	return {
		credits = data.credits,
		level = level, xpInto = into, xpNeed = need,
		stash = data.stash,
		stashCapacity = Outpost.StashCapacity(player),
		loadout = data.loadout,
		backpackCapacity = S.Inventory.Capacity(player),
		upgrades = data.upgrades,
		sellMultiplier = sellMultiplier(player),
		passes = passes,
		tokens = data.tokens,
		stats = data.stats,
		quarters = {
			owned = S.Quarters.Owns(player),
			benchTier = data.quarters.benchTier,
			decor = data.quarters.decor,
			ownedDecor = data.quarters.ownedDecor,
		},
		maps = maps,
		bench = openBench[player] and openBench[player].tier or 0,
	}
end

function Outpost.Push(player: Player)
	local snap = Outpost.Snapshot(player)
	if snap then
		S.Remotes.Profile:FireClient(player, snap)
	end
end

function Outpost.OpenPanel(player: Player, panel: string, benchTier: number?, benchPos: Vector3?)
	if benchTier then
		local previous = openBench[player]
		openBench[player] = { tier = benchTier, position = benchPos or (previous and previous.position) }
	end
	Outpost.Push(player)
	S.Remotes.OpenPanel:FireClient(player, panel)
end

local function inOutpost(player: Player): boolean
	return not S.Raid.IsInRaid(player) and S.Data.Get(player) ~= nil
end

---------------------------------------------------------------------------
-- Trader
---------------------------------------------------------------------------
function Outpost.Buy(player: Player, index)
	local offer = type(index) == "number" and Items.TraderStock[index]
	if not offer or not inOutpost(player) then
		return
	end
	local data = S.Data.Get(player)
	local def = Items.Get(offer.id)
	local cost = def.price * offer.count
	if Stacks.Fits(data.stash, Outpost.StashCapacity(player), offer.id, offer.count) < offer.count then
		S.Notify(player, "Your stash is full.", "Red")
		return
	end
	if not S.Data.SpendCredits(player, cost) then
		S.Notify(player, "Not enough credits.", "Red")
		return
	end
	Stacks.Add(data.stash, Outpost.StashCapacity(player), offer.id, offer.count)
	S.Data.MarkChanged(player)
	S.Notify(player, string.format("Bought %dx %s", offer.count, def.name), "Green")
	S.Analytics.Spend(player, cost, "Trader_" .. offer.id)
end

local function sellSlot(player: Player, data, index: number): number
	local slot = data.stash[index]
	if not slot then
		return 0
	end
	local def = Items.Get(slot.id)
	local credits = math.floor(def.value * slot.count * sellMultiplier(player))
	table.remove(data.stash, index)
	data.credits += credits
	return credits
end

function Outpost.Sell(player: Player, index)
	if type(index) ~= "number" or not inOutpost(player) then
		return
	end
	local data = S.Data.Get(player)
	local credits = sellSlot(player, data, index)
	if credits > 0 then
		S.Data.MarkChanged(player)
		S.Notify(player, "+" .. credits .. " credits", "Gold")
		S.Analytics.Earn(player, credits, "Sell")
	end
end

function Outpost.SellSalvage(player: Player)
	if not inOutpost(player) then
		return
	end
	local data = S.Data.Get(player)
	local total = 0
	for i = #data.stash, 1, -1 do
		if Items.Get(data.stash[i].id).category == "salvage" then
			total += sellSlot(player, data, i)
		end
	end
	if total > 0 then
		S.Data.MarkChanged(player)
		S.Notify(player, "Sold all salvage for " .. total .. " credits", "Gold", true)
		S.Analytics.Earn(player, total, "SellAll")
	end
end

---------------------------------------------------------------------------
-- Stash <-> loadout
---------------------------------------------------------------------------
function Outpost.ToLoadout(player: Player, index)
	if type(index) ~= "number" or not inOutpost(player) then
		return
	end
	local data = S.Data.Get(player)
	local slot = data.stash[index]
	if not slot then
		return
	end
	local def = Items.Get(slot.id)
	if def.weapon then
		for i = 1, Config.WeaponSlots do
			if data.loadout.weapons[i] == "" then
				data.loadout.weapons[i] = slot.id
				Stacks.Remove(data.stash, slot.id, 1)
				S.Data.MarkChanged(player)
				return
			end
		end
		-- both weapon slots used: carry it in the backpack instead
	end
	local fits = Stacks.Fits(data.loadout.items, S.Inventory.Capacity(player), slot.id, slot.count)
	if fits <= 0 then
		S.Notify(player, "Loadout backpack is full.", "Red")
		return
	end
	local id = slot.id
	Stacks.Remove(data.stash, id, fits)
	Stacks.Add(data.loadout.items, S.Inventory.Capacity(player), id, fits)
	S.Data.MarkChanged(player)
end

function Outpost.ToStash(player: Player, payload)
	if type(payload) ~= "table" or type(payload.index) ~= "number" or not inOutpost(player) then
		return
	end
	local data = S.Data.Get(player)
	local capacity = Outpost.StashCapacity(player)
	if payload.kind == "weapon" then
		local id = data.loadout.weapons[payload.index]
		if id and id ~= "" then
			if Stacks.Add(data.stash, capacity, id, 1) == 0 then
				data.loadout.weapons[payload.index] = ""
			else
				S.Notify(player, "Stash is full.", "Red")
			end
		end
	else
		local slot = data.loadout.items[payload.index]
		if slot then
			local left = Stacks.Add(data.stash, capacity, slot.id, slot.count)
			if left == 0 then
				table.remove(data.loadout.items, payload.index)
			else
				slot.count = left
				S.Notify(player, "Stash is full.", "Red")
			end
		end
	end
	S.Data.MarkChanged(player)
end

---------------------------------------------------------------------------
-- Upgrades
---------------------------------------------------------------------------
function Outpost.Upgrade(player: Player, which)
	if not inOutpost(player) then
		return
	end
	local data = S.Data.Get(player)
	local costs, max
	if which == "Backpack" then
		costs, max = Config.BackpackUpgradeCost, Config.BackpackMaxUpgrades
	elseif which == "Stash" then
		costs, max = Config.StashUpgradeCost, Config.StashMaxUpgrades
	else
		return
	end
	local level = data.upgrades[which]
	if level >= max then
		S.Notify(player, "Already maxed!", "Gray")
		return
	end
	local cost = costs[level + 1]
	if not S.Data.SpendCredits(player, cost) then
		S.Notify(player, "Not enough credits.", "Red")
		return
	end
	data.upgrades[which] = level + 1
	S.Data.MarkChanged(player)
	S.Notify(player, which .. " upgraded!", "Green", true)
	S.Analytics.Spend(player, cost, "Upgrade_" .. which)
end

---------------------------------------------------------------------------
-- Crafting
---------------------------------------------------------------------------
function Outpost.Craft(player: Player, index)
	local recipe = type(index) == "number" and Crafting.Recipes[index]
	local bench = openBench[player]
	local root = S.GetRoot(player)
	if not recipe or not bench or not root or not inOutpost(player) then
		return
	end
	if bench.position and (root.Position - bench.position).Magnitude > 20 then
		S.Notify(player, "Stand at a workbench to craft.", "Red")
		return
	end
	if recipe.tier > bench.tier then
		S.Notify(player, "Needs a Level " .. recipe.tier .. " workbench (upgrade yours in your Private Quarters).", "Red")
		return
	end
	local data = S.Data.Get(player)
	for _, input in recipe.inputs do
		if Stacks.Count(data.stash, input.id) < input.count then
			S.Notify(player, "Missing " .. Items.Get(input.id).name .. " in your stash.", "Red")
			return
		end
	end
	if data.credits < recipe.credits then
		S.Notify(player, "Not enough credits.", "Red")
		return
	end
	-- Remove inputs first so freed slots can hold the result.
	for _, input in recipe.inputs do
		Stacks.Remove(data.stash, input.id, input.count)
	end
	local left = Stacks.Add(data.stash, Outpost.StashCapacity(player), recipe.id, recipe.count)
	if left > 0 then
		-- roll back
		Stacks.Remove(data.stash, recipe.id, recipe.count - left)
		for _, input in recipe.inputs do
			Stacks.Add(data.stash, math.huge, input.id, input.count)
		end
		S.Notify(player, "Stash is full.", "Red")
		S.Data.MarkChanged(player)
		return
	end
	data.credits -= recipe.credits
	S.Data.MarkChanged(player)
	S.Notify(player, string.format("🔧 Crafted %dx %s", recipe.count, Items.Get(recipe.id).name), "Green")
	S.Analytics.Custom(player, "Craft_" .. recipe.id)
end

function Outpost.Init(services)
	S = services
	Stacks = S.Stacks
end

function Outpost.Start()
	for _, prompt in S.World.hub.prompts do
		prompt.Triggered:Connect(function(player)
			if S.Raid.IsInRaid(player) then
				return
			end
			local panel = prompt:GetAttribute("Panel")
			if panel == "Quarters" then
				S.Quarters.Visit(player)
			elseif panel == "Workbench" then
				Outpost.OpenPanel(player, "Workbench", 1, prompt.Parent.Position)
			else
				Outpost.OpenPanel(player, panel)
			end
		end)
	end
	S.Data.Changed:Connect(Outpost.Push)
	Players.PlayerRemoving:Connect(function(player)
		openBench[player] = nil
	end)
end

return Outpost
