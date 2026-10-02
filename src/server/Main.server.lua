-- OVERBOARD! server entry point. Creates the remotes, wires every service
-- together and routes client actions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in { "Action", "Notify", "Profile", "Carry", "Vote", "Fling" } do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
remotes.Parent = ReplicatedStorage

local S = {
	Config = require(Shared.Config),
	LootDefs = require(Shared.Loot),
	Shop = require(Shared.Shop),
	Remotes = remotes,
}

-- target = nil sends to everyone. color is a name the client maps to a colour
-- ("Gold", "Red", a rarity name, ...). big = show as a large banner.
function S.Notify(target: Player?, text: string, color: string?, big: boolean?)
	if target then
		remotes.Notify:FireClient(target, text, color or "White", big == true)
	else
		remotes.Notify:FireAllClients(text, color or "White", big == true)
	end
end

local modules = script.Parent
S.Analytics = require(modules.AnalyticsService)
S.Data = require(modules.DataService)
S.Monetization = require(modules.MonetizationService)
S.WorldBuilder = require(modules.WorldBuilder)
S.Flight = require(modules.FlightService)
S.Loot = require(modules.LootService)
S.Vote = require(modules.VoteService)
S.Bots = require(modules.BotService)
S.Raft = require(modules.RaftService)
S.ShopSvc = require(modules.ShopService)
S.Leaderboard = require(modules.LeaderboardService)

local order = {
	S.Analytics, S.Data, S.Monetization, S.WorldBuilder, S.Flight, S.Loot,
	S.Vote, S.Bots, S.Raft, S.ShopSvc, S.Leaderboard,
}
for _, service in order do
	service.Init(S)
end
S.WorldBuilder.Build()
for _, service in order do
	if service.Start then
		service.Start()
	end
end

---------------------------------------------------------------------------
-- Client -> server actions (all arguments are validated in the services)
---------------------------------------------------------------------------
local handlers = {
	Shove = function(player)
		S.Flight.Shove(player)
	end,
	Drop = function(player, index)
		S.Flight.DropItem(player, index)
	end,
	CallVote = function(player)
		S.Vote.Call(player)
	end,
	Vote = function(player, targetId)
		S.Vote.Cast(player, targetId)
	end,
	BuyUpgrade = function(player, id)
		S.ShopSvc.BuyUpgrade(player, id)
	end,
	BuyTrail = function(player, id)
		S.ShopSvc.BuyTrail(player, id)
	end,
	EquipTrail = function(player, id)
		S.ShopSvc.EquipTrail(player, id)
	end,
	ClaimDaily = function(player)
		S.ShopSvc.ClaimDaily(player)
	end,
	RequestProfile = function(player)
		local snapshot = S.ShopSvc.Snapshot(player)
		if snapshot then
			remotes.Profile:FireClient(player, snapshot)
		end
		S.Flight.SyncCarry(player)
	end,
}

local budget = {} -- simple rate limit: 15 actions per second per player
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
	if b.count > 15 then
		return
	end
	handler(player, arg)
end)

Players.PlayerRemoving:Connect(function(player)
	budget[player] = nil
end)
