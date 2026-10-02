-- Player save data: loading, saving, autosave and leaderstats.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataService = {}
local S

local STORE_NAME = "Overboard_Player_v1"
local BOARD_NAME = "Overboard_TotalEarned_v1"
local AUTOSAVE_INTERVAL = 120

local TEMPLATE = {
	coins = 0,
	totalEarned = 0,
	bestDistance = 0,
	flights = 0,
	upgrades = { Hook = 0, Backpack = 0, Luck = 0 },
	trails = {},
	equippedTrail = "",
	daily = { streak = 0, last = 0 },
	tokens = { Rescue = 0, EmergencyBurner = 0, TreasureRain = 0 },
	receipts = {},
}

local store, earnedBoard
pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
	earnedBoard = DataStoreService:GetOrderedDataStore(BOARD_NAME)
end)

local profiles = {} -- [Player] = { data = table, canSave = boolean }

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
	stats.Coins.Value = profile.data.coins
	stats.Best.Value = math.floor(profile.data.bestDistance)
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

function DataService.AddCoins(player: Player, amount: number, earned: boolean?)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	amount = math.floor(amount)
	data.coins += amount
	if earned then
		data.totalEarned += amount
	end
	DataService.MarkChanged(player)
end

function DataService.SpendCoins(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if not data or data.coins < amount then
		return false
	end
	data.coins -= amount
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
			earnedBoard:SetAsync(tostring(player.UserId), math.floor(data.totalEarned))
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
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats
	local best = Instance.new("IntValue")
	best.Name = "Best"
	best.Parent = stats
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
