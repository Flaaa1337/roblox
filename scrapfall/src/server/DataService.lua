-- Player save data: loading, saving, autosave and leaderstats.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}
local S

local STORE_NAME = "Scrapfall_Player_v1"
local BOARD_NAME = "Scrapfall_TotalExtracted_v1"
local AUTOSAVE_INTERVAL = 120

local TEMPLATE = {
	credits = 300,
	xp = 0,
	-- New players start with a small kit already packed so their first raid
	-- is one click away.
	stash = {
		{ id = "Bandage", count = 2 },
	},
	loadout = {
		weapons = { "ScrapPistol", "" },
		items = { { id = "LightAmmo", count = 60 }, { id = "Bandage", count = 2 } },
	},
	upgrades = { Backpack = 0, Stash = 0 },
	tokens = { Insurance = 0 },
	quarters = {
		owned = false,
		benchTier = 1,
		decor = { "", "", "", "", "", "", "", "" }, -- decor id per slot
		ownedDecor = {}, -- [decorId] = count owned
	},
	stats = { raids = 0, extracts = 0, kills = 0, deaths = 0, bestExtract = 0 },
	totalExtracted = 0,
	receipts = {},
}

local store, earnedBoard
pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
	earnedBoard = DataStoreService:GetOrderedDataStore(BOARD_NAME)
end)

local profiles = {} -- [Player] = { data = table, canSave = boolean }

local removingHooks = {}

-- Runs before a leaving player's data is saved (e.g. to settle a raid).
function DataService.AddRemovingHook(fn)
	table.insert(removingHooks, fn)
end

local changedEvent = Instance.new("BindableEvent")
DataService.Changed = changedEvent.Event

local function deepCopy(t)
	local copy = {}
	for k, v in t do
		copy[k] = if type(v) == "table" then deepCopy(v) else v
	end
	return copy
end

local function reconcile(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = if type(v) == "table" then deepCopy(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" then
			reconcile(data[k], v)
		end
	end
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

-- Returns data, canSave. If the store can't be read we play with fresh data
-- but never save it, so a DataStore outage can't wipe anyone's progress.
local function load(player: Player)
	if not store then
		return deepCopy(TEMPLATE), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			local data = if type(result) == "table" then result else deepCopy(TEMPLATE)
			reconcile(data, TEMPLATE)
			return data, true
		end
		warn("[Data] load failed for", player.Name, result)
		task.wait(attempt * 2)
	end
	return deepCopy(TEMPLATE), false
end

local function updateLeaderstats(player: Player)
	local profile = profiles[player]
	local stats = player:FindFirstChild("leaderstats")
	if not profile or not stats then
		return
	end
	stats.Credits.Value = profile.data.credits
	stats.Level.Value = DataService.Level(profile.data)
end

function DataService.Get(player: Player)
	local profile = profiles[player]
	return profile and profile.data
end

function DataService.WaitForProfile(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 15)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.2)
	end
	return DataService.Get(player)
end

function DataService.MarkChanged(player: Player)
	updateLeaderstats(player)
	changedEvent:Fire(player)
end

function DataService.Level(data): number
	-- level n needs n * XpPerLevel more XP than level n-1
	local level, need, xp = 1, Config.XpPerLevel, data.xp
	while xp >= need do
		xp -= need
		level += 1
		need = level * Config.XpPerLevel
	end
	return level
end

function DataService.AddXp(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	local before = DataService.Level(data)
	data.xp += math.floor(amount)
	local after = DataService.Level(data)
	if after > before then
		S.Notify(player, "⭐ RANK UP! You are now Raider Rank " .. after, "Gold", true)
	end
	DataService.MarkChanged(player)
end

function DataService.AddCredits(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	data.credits += math.floor(amount)
	DataService.MarkChanged(player)
end

function DataService.SpendCredits(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if not data or data.credits < amount then
		return false
	end
	data.credits -= amount
	DataService.MarkChanged(player)
	return true
end

function DataService.Save(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return false
	end
	local data = profile.data
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function()
			return data
		end)
	end)
	if not ok then
		warn("[Data] save failed for", player.Name, err)
	elseif earnedBoard then
		pcall(function()
			earnedBoard:SetAsync(tostring(player.UserId), math.floor(data.totalExtracted))
		end)
	end
	return ok
end

function DataService.GetEarnedBoard()
	return earnedBoard
end

local function onPlayerAdded(player: Player)
	local data, canSave = load(player)
	if not player.Parent then
		return
	end
	profiles[player] = { data = data, canSave = canSave }

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local credits = Instance.new("IntValue")
	credits.Name = "Credits"
	credits.Parent = stats
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = stats
	stats.Parent = player

	if not canSave then
		S.Notify(player, "Saving is unavailable right now - progress this session won't be kept.", "Red")
	end
	DataService.MarkChanged(player)
end

function DataService.Init(services)
	S = services
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		for _, hook in removingHooks do
			local ok, err = pcall(hook, player)
			if not ok then
				warn("[Data] removing hook failed:", err)
			end
		end
		DataService.Save(player)
		profiles[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(DataService.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.Save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
