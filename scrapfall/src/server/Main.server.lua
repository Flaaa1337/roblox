-- SCRAPFALL server entry point: remotes, service wiring and action routing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in { "Action", "Fire", "Notify", "Profile", "Inventory", "Container", "OpenPanel" } do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
local effect = Instance.new("UnreliableRemoteEvent")
effect.Name = "Effect"
effect.Parent = remotes
remotes.Parent = ReplicatedStorage

local S = {
	Config = require(Shared.Config),
	Remotes = remotes,
}

function S.Notify(target: Player?, text: string, color: string?, big: boolean?)
	if target then
		remotes.Notify:FireClient(target, text, color or "White", big == true)
	else
		remotes.Notify:FireAllClients(text, color or "White", big == true)
	end
end

function S.GetRoot(player: Player)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart")
end

function S.Teleport(player: Player, cf: CFrame)
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

local modules = script.Parent
S.Stacks = require(modules.Stacks)
S.Analytics = require(modules.AnalyticsService)
S.Data = require(modules.DataService)
S.Monetization = require(modules.MonetizationService)
S.MapBuilder = require(modules.MapBuilder)
S.Inventory = require(modules.InventoryService)
S.Loot = require(modules.LootService)
S.Combat = require(modules.CombatService)
S.Robots = require(modules.RobotService)
S.Raid = require(modules.RaidService)
S.Outpost = require(modules.OutpostService)
S.Quarters = require(modules.QuartersService)
S.Leaderboard = require(modules.LeaderboardService)

local order = {
	S.Analytics, S.Data, S.Monetization, S.MapBuilder, S.Inventory, S.Loot, S.Combat,
	S.Robots, S.Raid, S.Outpost, S.Quarters, S.Leaderboard,
}
for _, service in order do
	service.Init(S)
end
S.MapBuilder.Build()
for _, service in order do
	if service.Start then
		service.Start()
	end
end

---------------------------------------------------------------------------
-- Client -> server actions. Every handler validates its own arguments.
---------------------------------------------------------------------------
local handlers = {
	-- raid
	Reload = function(p) S.Combat.Reload(p) end,
	Equip = function(p, slot) S.Combat.Equip(p, slot) end,
	UseItem = function(p, index) S.Combat.UseItem(p, index) end,
	ToSafe = function(p, index) S.Inventory.ToSafe(p, index) end,
	FromSafe = function(p, index) S.Inventory.FromSafe(p, index) end,
	DropItem = function(p, index) S.Inventory.Drop(p, index) end,
	Holster = function(p, slot) S.Inventory.Holster(p, slot) end,
	Take = function(p, payload) S.Loot.Take(p, payload) end,
	CloseContainer = function(p) S.Loot.Close(p) end,
	-- outpost
	Buy = function(p, index) S.Outpost.Buy(p, index) end,
	Sell = function(p, index) S.Outpost.Sell(p, index) end,
	SellSalvage = function(p) S.Outpost.SellSalvage(p) end,
	ToLoadout = function(p, index) S.Outpost.ToLoadout(p, index) end,
	ToStash = function(p, payload) S.Outpost.ToStash(p, payload) end,
	Upgrade = function(p, which) S.Outpost.Upgrade(p, which) end,
	Craft = function(p, index) S.Outpost.Craft(p, index) end,
	Deploy = function(p, mapId) S.Raid.Deploy(p, mapId) end,
	RequestProfile = function(p)
		S.Outpost.Push(p)
		S.Inventory.Sync(p)
	end,
	-- quarters
	BuyQuarters = function(p) S.Quarters.Buy(p) end,
	VisitQuarters = function(p) S.Quarters.Visit(p) end,
	ExitQuarters = function(p) S.Quarters.Exit(p) end,
	BuyDecor = function(p, id) S.Quarters.BuyDecor(p, id) end,
	PlaceDecor = function(p, payload) S.Quarters.Place(p, payload) end,
	UpgradeBench = function(p) S.Quarters.UpgradeBench(p) end,
}

local budget = {}
remotes.Action.OnServerEvent:Connect(function(player, action, arg)
	local handler = type(action) == "string" and handlers[action]
	if not handler then
		return
	end
	local now = os.clock()
	local b = budget[player]
	if not b or now - b.start > 1 then
		b = { start = now, count = 0 }
		budget[player] = b
	end
	b.count += 1
	if b.count > 20 then
		return
	end
	local ok, err = pcall(handler, player, arg)
	if not ok then
		warn("[Action]", action, err)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	budget[player] = nil
end)
