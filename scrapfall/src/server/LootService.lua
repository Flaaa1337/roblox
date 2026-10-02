-- Searchable containers: map crates (respawn), robot wrecks and the bags
-- dead raiders leave behind (temporary).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))

local LootService = {}
local S

local rng = Random.new()
local containers = {} -- [id] = container
local nextId = 0
local viewers = {} -- [Player] = container id currently open

local TITLES = {
	Crate = "Supply Crate", Toolbox = "Toolbox", MedCabinet = "Med Cabinet", WeaponCase = "Weapon Case",
	RobotCache = "Robot Cache", DeathCache = "Raider Backpack", Wreck = "Robot Wreck",
}

local function sendContents(player: Player, c)
	S.Remotes.Container:FireClient(player, "Open", { id = c.id, title = c.title, contents = c.contents or {} })
end

local function refreshViewers(c)
	for player, id in viewers do
		if id == c.id then
			if player.Parent then
				sendContents(player, c)
			else
				viewers[player] = nil
			end
		end
	end
end

local function setOpenLook(c, empty: boolean)
	local lid = c.model:FindFirstChild("Lid")
	if lid then
		lid.Transparency = if empty then 1 else 0
	end
	c.model.Color = if empty then c.baseColor:Lerp(Color3.new(0, 0, 0), 0.5) else c.baseColor
	c.prompt.ObjectText = (if empty then "(empty) " else "") .. c.title
end

local function register(model: BasePart, prompt: ProximityPrompt, kind: string, mapId: string, temporary: boolean, title: string?)
	nextId += 1
	local c = {
		id = nextId, kind = kind, model = model, prompt = prompt, mapId = mapId, temporary = temporary,
		title = title or TITLES[kind] or kind, contents = nil, baseColor = model.Color,
	}
	containers[c.id] = c
	prompt.Triggered:Connect(function(player)
		LootService.Search(player, c.id)
	end)
	return c
end

function LootService.Search(player: Player, id: number)
	local c = containers[id]
	local root = S.GetRoot(player)
	if not c or not root or not S.Raid.IsInRaid(player) or player:GetAttribute("MapId") ~= c.mapId then
		return
	end
	if (root.Position - c.model.Position).Magnitude > Config.LootRange then
		return
	end
	if c.contents == nil then
		c.contents = Items.Roll(c.kind, rng)
	end
	viewers[player] = c.id
	sendContents(player, c)
	S.Analytics.Funnel(player, 3)
end

local function onEmptied(c)
	if c.temporary then
		containers[c.id] = nil
		task.delay(1, function()
			c.model:Destroy()
		end)
		return
	end
	setOpenLook(c, true)
	c.respawnAt = os.clock() + Config.ContainerRespawn
end

-- index = slot to take, or 0 for "take all".
function LootService.Take(player: Player, payload)
	if type(payload) ~= "table" or type(payload.id) ~= "number" or type(payload.index) ~= "number" then
		return
	end
	local c = containers[payload.id]
	local root = S.GetRoot(player)
	if not c or not c.contents or viewers[player] ~= c.id or not root or not S.Raid.IsInRaid(player) then
		return
	end
	if (root.Position - c.model.Position).Magnitude > Config.LootRange + 4 then
		S.Notify(player, "Too far away.", "Red")
		return
	end
	local indices = {}
	if payload.index == 0 then
		for i = #c.contents, 1, -1 do
			table.insert(indices, i)
		end
	elseif c.contents[payload.index] then
		indices = { payload.index }
	end
	local full = false
	for _, i in indices do
		local slot = c.contents[i]
		local left = S.Inventory.Give(player, slot.id, slot.count)
		if left > 0 then
			slot.count = left
			full = true
		else
			table.remove(c.contents, i)
		end
	end
	if full then
		S.Notify(player, "Backpack full! Drop or use something.", "Red")
	end
	refreshViewers(c)
	if #c.contents == 0 then
		onEmptied(c)
	end
end

function LootService.Close(player: Player)
	viewers[player] = nil
end

-- Temporary container (death bag, robot wreck, dropped bag) with fixed contents.
function LootService.SpawnTemporary(cf: CFrame, kind: string, contents, mapId: string, title: string?)
	if #contents == 0 then
		return
	end
	local model, prompt = S.MapBuilder.MakeContainer(cf, kind, S.World.dynamic)
	local c = register(model, prompt, kind, mapId, true, title)
	c.contents = contents
	local lifetime = if kind == "Wreck" then Config.WreckLifetime else Config.DeathCacheLifetime
	task.delay(lifetime, function()
		if containers[c.id] == c then
			containers[c.id] = nil
			for player, id in viewers do
				if id == c.id then
					viewers[player] = nil
					S.Remotes.Container:FireClient(player, "Close")
				end
			end
			model:Destroy()
		end
	end)
	return c
end

function LootService.Init(services)
	S = services
end

function LootService.Start()
	for mapId, map in S.World.maps do
		local folder = Instance.new("Folder")
		folder.Name = "Containers"
		folder.Parent = map.folder
		for _, spot in map.containerSpots do
			local model, prompt = S.MapBuilder.MakeContainer(spot.cf, spot.kind, folder)
			register(model, prompt, spot.kind, mapId, false)
		end
	end

	-- Respawn emptied map containers
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for _, c in containers do
				if c.respawnAt and now >= c.respawnAt then
					c.respawnAt = nil
					c.contents = nil
					setOpenLook(c, false)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		viewers[player] = nil
	end)
end

return LootService
