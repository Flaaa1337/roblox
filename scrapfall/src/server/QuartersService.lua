-- Private Quarters: your own room with a personal (upgradable) workbench,
-- stash access and decoration slots for furniture and trophies.
-- Unlocked with credits OR the Quarters game pass.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local Crafting = require(Shared:WaitForChild("Crafting"))

local Quarters = {}
local S, Stacks

local rooms = {} -- [Player] = room
local usedIndex = {} -- [index] = Player

function Quarters.Owns(player: Player): boolean
	local data = S.Data.Get(player)
	return (data ~= nil and data.quarters.owned) or S.Monetization.OwnsPass(player, "Quarters")
end

local function renderDecor(player: Player)
	local room = rooms[player]
	local data = S.Data.Get(player)
	if not room or not data then
		return
	end
	room.decorFolder:ClearAllChildren()
	for slot, decorId in data.quarters.decor do
		local def = decorId ~= "" and Crafting.Decor[decorId]
		local cf = room.slots[slot]
		if def and cf then
			local model = Instance.new("Model")
			model.Name = decorId
			for _, p in def.parts do
				local part = Instance.new("Part")
				part.Anchored = true
				part.Size = p.size
				part.Color = p.color
				part.Material = Enum.Material[p.material] or Enum.Material.SmoothPlastic
				if p.shape == "Ball" then
					part.Shape = Enum.PartType.Ball
				elseif p.shape == "Cylinder" then
					part.Shape = Enum.PartType.Cylinder
				end
				part.CFrame = cf * CFrame.new(p.offset) * (if p.shape == "Cylinder" then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity)
				part.TopSurface = Enum.SurfaceType.Smooth
				part.Parent = model
				if def.light and p.material == "Neon" then
					local light = Instance.new("PointLight")
					light.Color = p.color
					light.Range = 14
					light.Parent = part
				end
			end
			model.Parent = room.decorFolder
		end
	end
end

local function ensureRoom(player: Player)
	if rooms[player] then
		return rooms[player]
	end
	local index = 1
	while usedIndex[index] do
		index += 1
	end
	usedIndex[index] = player
	local room = S.MapBuilder.BuildQuarters(index, player.DisplayName)
	room.index = index
	rooms[player] = room
	for _, prompt in room.prompts do
		prompt.Triggered:Connect(function(who)
			if who ~= player then
				return
			end
			local panel = prompt:GetAttribute("Panel")
			if panel == "Exit" then
				Quarters.Exit(player)
			elseif panel == "Workbench" then
				local data = S.Data.Get(player)
				S.Outpost.OpenPanel(player, "Workbench", data and data.quarters.benchTier or 1, prompt.Parent.Position)
			else
				S.Outpost.OpenPanel(player, panel)
			end
		end)
	end
	renderDecor(player)
	return room
end

function Quarters.Visit(player: Player)
	if S.Raid.IsInRaid(player) or not S.Data.Get(player) then
		return
	end
	if not Quarters.Owns(player) then
		S.Outpost.OpenPanel(player, "QuartersBuy")
		return
	end
	local room = ensureRoom(player)
	S.Teleport(player, room.spawn)
	player:SetAttribute("InQuarters", true)
end

function Quarters.Exit(player: Player)
	player:SetAttribute("InQuarters", false)
	S.Teleport(player, S.Raid.OutpostSpot())
end

function Quarters.Buy(player: Player)
	if Quarters.Owns(player) then
		Quarters.Visit(player)
		return
	end
	local data = S.Data.Get(player)
	if not data then
		return
	end
	if not S.Data.SpendCredits(player, Config.QuartersCreditPrice) then
		S.Notify(player, string.format("You need %d credits (or get the Quarters pass in the store).", Config.QuartersCreditPrice), "Red")
		return
	end
	data.quarters.owned = true
	S.Data.MarkChanged(player)
	S.Notify(player, "🏠 Private Quarters unlocked!", "Gold", true)
	S.Analytics.Spend(player, Config.QuartersCreditPrice, "Quarters")
	Quarters.Visit(player)
end

function Quarters.BuyDecor(player: Player, decorId)
	local def = type(decorId) == "string" and Crafting.Decor[decorId]
	local data = S.Data.Get(player)
	if not def or not data or not Quarters.Owns(player) or S.Raid.IsInRaid(player) then
		return
	end
	for _, input in def.inputs or {} do
		if Stacks.Count(data.stash, input.id) < input.count then
			S.Notify(player, "You need " .. input.count .. "x " .. Items.Get(input.id).name .. " in your stash.", "Red")
			return
		end
	end
	if not S.Data.SpendCredits(player, def.price) then
		S.Notify(player, "Not enough credits.", "Red")
		return
	end
	for _, input in def.inputs or {} do
		Stacks.Remove(data.stash, input.id, input.count)
	end
	data.quarters.ownedDecor[decorId] = (data.quarters.ownedDecor[decorId] or 0) + 1
	-- auto-place in the first free slot
	for i = 1, Crafting.DecorSlots do
		if data.quarters.decor[i] == "" then
			data.quarters.decor[i] = decorId
			break
		end
	end
	S.Data.MarkChanged(player)
	renderDecor(player)
	S.Notify(player, "Added " .. def.name .. " to your quarters!", "Green")
	S.Analytics.Spend(player, def.price, "Decor_" .. decorId)
end

-- payload = { slot = number, id = decorId or "" }
function Quarters.Place(player: Player, payload)
	local data = S.Data.Get(player)
	if not data or type(payload) ~= "table" or type(payload.slot) ~= "number" or type(payload.id) ~= "string" then
		return
	end
	local slot = math.floor(payload.slot)
	if slot < 1 or slot > Crafting.DecorSlots then
		return
	end
	if payload.id ~= "" then
		if not Crafting.Decor[payload.id] then
			return
		end
		local placed = 0
		for i, id in data.quarters.decor do
			if id == payload.id and i ~= slot then
				placed += 1
			end
		end
		if placed >= (data.quarters.ownedDecor[payload.id] or 0) then
			S.Notify(player, "You don't own another one of those.", "Red")
			return
		end
	end
	data.quarters.decor[slot] = payload.id
	S.Data.MarkChanged(player)
	renderDecor(player)
end

function Quarters.UpgradeBench(player: Player)
	local data = S.Data.Get(player)
	if not data or not Quarters.Owns(player) or S.Raid.IsInRaid(player) then
		return
	end
	local nextTier = data.quarters.benchTier + 1
	local cost = Config.BenchUpgrades[nextTier]
	if not cost then
		S.Notify(player, "Workbench is already max level.", "Gray")
		return
	end
	for _, input in cost.items do
		if Stacks.Count(data.stash, input.id) < input.count then
			S.Notify(player, "You need " .. input.count .. "x " .. Items.Get(input.id).name .. " in your stash.", "Red")
			return
		end
	end
	if not S.Data.SpendCredits(player, cost.credits) then
		S.Notify(player, "Not enough credits.", "Red")
		return
	end
	for _, input in cost.items do
		Stacks.Remove(data.stash, input.id, input.count)
	end
	data.quarters.benchTier = nextTier
	S.Data.MarkChanged(player)
	S.Notify(player, "🔧 Workbench upgraded to Level " .. nextTier .. "!", "Gold", true)
	S.Analytics.Spend(player, cost.credits, "Bench_" .. nextTier)
	S.Outpost.OpenPanel(player, "Workbench", nextTier)
end

function Quarters.Init(services)
	S = services
	Stacks = S.Stacks
end

function Quarters.Start()
	Players.PlayerRemoving:Connect(function(player)
		local room = rooms[player]
		if room then
			usedIndex[room.index] = nil
			room.model:Destroy()
			rooms[player] = nil
		end
	end)
end

return Quarters
