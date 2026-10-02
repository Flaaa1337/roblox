--!strict
-- Assigns exactly one of the eight base plots to each player (spec 5.1).
-- Plots are views of player data, not its storage; nothing is saved here.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local BaseService = {}

local plots: { WorldBuilder.Plot } = {}
local owners: { [number]: Player } = {} -- plot index -> player
local assigned: { [Player]: number } = {}

local function signLabels(plot: WorldBuilder.Plot): { TextLabel }
	local labels = {}
	for _, d in plot.signFolder:GetDescendants() do
		if d:IsA("TextLabel") and CollectionService:HasTag(d, "AH_LocalizedText") then
			table.insert(labels, d)
		end
	end
	return labels
end

local function showOwner(plot: WorldBuilder.Plot, player: Player?)
	plot.model:SetAttribute("OwnerUserId", if player then player.UserId else nil)
	for _, label in signLabels(plot) do
		if player then
			label:SetAttribute("TextKey", "base.owned_by")
			label:SetAttribute("Param_name", player.DisplayName)
			label:SetAttribute("OwnerUserId", player.UserId)
			label:SetAttribute("SelfKey", "base.yours")
		else
			label:SetAttribute("TextKey", "base.vacant")
			label:SetAttribute("Param_name", nil)
			label:SetAttribute("OwnerUserId", nil)
			label:SetAttribute("SelfKey", nil)
		end
	end
	plot.marker.Transparency = if player then 0.35 else 0.85
end

-- Returns the assigned plot index, or nil when all eight are taken.
function BaseService.assign(player: Player): number?
	if assigned[player] then
		return assigned[player]
	end
	for _, plot in plots do
		if not owners[plot.index] then
			owners[plot.index] = player
			assigned[player] = plot.index
			showOwner(plot, player)
			player:SetAttribute("PlotIndex", plot.index)
			return plot.index
		end
	end
	warn("[BaseService] no free plot for", player.Name, "- check MaxPlayers (must be 8)")
	player:SetAttribute("PlotIndex", 0)
	return nil
end

function BaseService.release(player: Player)
	local index = assigned[player]
	if not index then
		return
	end
	assigned[player] = nil
	owners[index] = nil
	for _, plot in plots do
		if plot.index == index then
			showOwner(plot, nil)
		end
	end
end

function BaseService.plotOf(player: Player): number?
	return assigned[player]
end

function BaseService.ownerOf(index: number): Player?
	return owners[index]
end

function BaseService.init(world: WorldBuilder.World)
	plots = world.plots
	for _, plot in plots do
		showOwner(plot, nil)
	end
end

function BaseService.start()
	Players.PlayerAdded:Connect(function(player)
		BaseService.assign(player)
	end)
	for _, player in Players:GetPlayers() do
		BaseService.assign(player)
	end
	Players.PlayerRemoving:Connect(BaseService.release)
end

return BaseService
