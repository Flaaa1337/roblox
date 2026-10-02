--!strict
-- Server-authoritative portal travel between the hub and expedition zones
-- (spec 5.3). The server validates the request, streams the destination
-- around the player, moves the character and verifies the arrival. Travel
-- never touches inventory or ownership.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = require(Shared.Config.GameConfig)
local ZoneDefinitions = require(Shared.Config.ZoneDefinitions)
local Contracts = require(Shared.Net.Contracts)
local RateLimiter = require(Shared.Util.RateLimiter)
local Cleanup = require(Shared.Util.Cleanup)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)
local TelemetryService = require(script.Parent.TelemetryService)

local PortalService = {}

local HUB = "hub"

local world: WorldBuilder.World
local remotes: { [string]: RemoteEvent }
local limiter = RateLimiter.new(GameConfig.portal.cooldownSeconds)
local traveling: { [Player]: boolean } = {}
local scopes: { [Player]: Cleanup.Cleanup } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function PortalService.areaOf(player: Player): string
	local area = player:GetAttribute("AreaId")
	return if type(area) == "string" then area else HUB
end

local function hubArrival(): CFrame
	local spawn = world.spawn
	return spawn.CFrame * CFrame.new(0, 3.5, 0)
end

local function notice(player: Player, code: string)
	remotes[Contracts.Events.Notice]:FireClient(player, code)
end

-- Moves the player and confirms they did not fall into unloaded space.
local function travel(player: Player, areaId: string, destination: CFrame)
	traveling[player] = true
	local transition = remotes[Contracts.Events.AreaTransition]
	transition:FireClient(player, "start", areaId)

	local streamed = pcall(function()
		player:RequestStreamAroundAsync(destination.Position, GameConfig.portal.streamTimeoutSeconds)
	end)
	if not streamed then
		warn("[PortalService] streaming request failed; moving anyway with fall check", player.Name)
	end

	local root = rootOf(player)
	local character = player.Character
	if not root or not character then
		traveling[player] = nil
		transition:FireClient(player, "failed", PortalService.areaOf(player), "TravelFailed")
		return
	end
	character:PivotTo(destination)
	root.AssemblyLinearVelocity = Vector3.zero
	player:SetAttribute("AreaId", areaId)
	transition:FireClient(player, "arrived", areaId)
	if areaId ~= HUB then
		TelemetryService.custom(player, "zone_entered")
	end

	-- Safety net: if the character dropped far below the arrival point,
	-- put it back on the arrival pad (never leave a player in the void).
	task.delay(GameConfig.portal.fallCheckDelaySeconds, function()
		traveling[player] = nil
		local r = rootOf(player)
		if r and player.Parent and PortalService.areaOf(player) == areaId and r.Position.Y < destination.Position.Y - GameConfig.portal.fallDistance then
			local c = player.Character
			if c then
				c:PivotTo(destination)
				r.AssemblyLinearVelocity = Vector3.zero
				notice(player, "TravelFailed")
			end
		end
	end)
end

-- Validates and executes a portal use. `fromArea` is where the portal is.
function PortalService.requestTravel(player: Player, portal: Model, fromArea: string, toArea: string): (boolean, string?)
	if traveling[player] then
		return false, "PortalCooldown"
	end
	if PortalService.areaOf(player) ~= fromArea then
		return false, "PortalTooFar"
	end
	local root = rootOf(player)
	if not root then
		return false, "TravelFailed"
	end
	local pivot = portal:GetPivot().Position
	local flat = Vector3.new(root.Position.X - pivot.X, 0, root.Position.Z - pivot.Z)
	if flat.Magnitude > GameConfig.portal.maxUseDistance then
		return false, "PortalTooFar"
	end
	local destination: CFrame
	if toArea == HUB then
		destination = hubArrival()
	else
		local zone = ZoneDefinitions[toArea]
		local info = world.zones[toArea]
		if not zone or not zone.implemented or not info then
			return false, "PortalLocked"
		end
		destination = info.arrival
	end
	if not limiter:tryUse(player) then
		return false, "PortalCooldown"
	end
	task.spawn(travel, player, toArea, destination)
	return true, nil
end

local function attachPrompt(portal: Model, actionKey: string, objectKey: string, objectParams: { [string]: string }?, onTriggered: (Player) -> ())
	-- the prompt lives on the walkable base so it is in reach at ground level
	local base = portal:FindFirstChild("Base")
	local holder = if base and base:IsA("BasePart") then base else portal.PrimaryPart
	assert(holder, "portal has no parts")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PortalPrompt"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = GameConfig.portal.promptDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	-- English defaults; the client replaces them with the player's language
	prompt.ActionText = "Enter"
	prompt.ObjectText = "Portal"
	prompt:SetAttribute("ActionKey", actionKey)
	prompt:SetAttribute("ObjectKey", objectKey)
	for name, value in (objectParams or {}) :: { [string]: string } do
		prompt:SetAttribute("ObjectParam_" .. name, value)
	end
	CollectionService:AddTag(prompt, "AH_LocalizedPrompt")
	prompt.Triggered:Connect(onTriggered)
	prompt.Parent = holder
end

function PortalService.init(w: WorldBuilder.World, r: { [string]: RemoteEvent })
	world = w
	remotes = r

	for zoneId, portal in world.hubPortals do
		local zone = ZoneDefinitions[zoneId]
		if zone and zone.implemented and world.zones[zoneId] then
			attachPrompt(portal, "action.enter_portal", "portal.to_area", { area = "@" .. zone.nameKey }, function(player)
				local ok, code = PortalService.requestTravel(player, portal, HUB, zoneId)
				if not ok and code then
					notice(player, code)
				end
			end)
		end
	end
	for zoneId, info in world.zones do
		local portal = info.returnPortal
		attachPrompt(portal, "action.return_to_hub", "portal.to_hub", nil, function(player)
			local ok, code = PortalService.requestTravel(player, portal, zoneId, HUB)
			if not ok and code then
				notice(player, code)
			end
		end)
	end
end

function PortalService.start()
	local function onPlayer(player: Player)
		player:SetAttribute("AreaId", HUB)
		local scope = Cleanup.new()
		scopes[player] = scope
		scope:add(player.CharacterAdded:Connect(function()
			-- respawning always happens at the hub spawn
			traveling[player] = nil
			player:SetAttribute("AreaId", HUB)
		end))
		TelemetryService.custom(player, "onboarding_started")
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		traveling[player] = nil
		limiter:forget(player)
		local scope = scopes[player]
		if scope then
			scope:destroy()
			scopes[player] = nil
		end
	end)
end

return PortalService
