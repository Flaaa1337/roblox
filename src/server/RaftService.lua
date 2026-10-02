-- Going overboard is not game over: on the raft you hop across crates,
-- grab fuel barrels and fire them up to the balloon with the Sky Cannon.
-- Every delivery helps the people who threw you off... and after a few
-- deliveries you get launched back aboard.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local RaftService = {}
local S, Config

local carrying = {} -- [Player] = back-mounted barrel part

local function playerFromHit(hit: BasePart)
	local model = hit:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model)
end

function RaftService.ClearBarrel(player: Player)
	local barrel = carrying[player]
	if barrel then
		barrel:Destroy()
		carrying[player] = nil
	end
end

local function hasBarrel(player: Player): boolean
	local barrel = carrying[player]
	return barrel ~= nil and barrel.Parent ~= nil
end

local function attachBarrel(player: Player)
	local char = player.Character
	local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
	if not torso then
		return false
	end
	local barrel = Instance.new("Part")
	barrel.Name = "CarriedBarrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(2.6, 2, 2)
	barrel.Color = Color3.fromRGB(255, 120, 40)
	barrel.Material = Enum.Material.Metal
	barrel.CanCollide = false
	barrel.Massless = true
	barrel.CFrame = torso.CFrame * CFrame.new(0, 0, 1.4) * CFrame.Angles(0, 0, math.rad(90))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = barrel
	weld.Parent = barrel
	barrel.Parent = char
	carrying[player] = barrel
	return true
end

local function spawnBarrel(spot: CFrame)
	local barrel = Instance.new("Part")
	barrel.Name = "FuelBarrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(3, 2.4, 2.4)
	barrel.Color = Color3.fromRGB(255, 120, 40)
	barrel.Material = Enum.Material.Metal
	barrel.Anchored = true
	barrel.CanCollide = false
	barrel.CFrame = spot * CFrame.Angles(0, 0, math.rad(90))
	barrel.Parent = S.World.raft.folder
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 60)
	light.Range = 10
	light.Parent = barrel

	local taken = false
	barrel.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = playerFromHit(hit)
		if not player or hasBarrel(player) or player:GetAttribute("Zone") ~= "Raft" then
			return
		end
		if not attachBarrel(player) then
			return
		end
		taken = true
		barrel:Destroy()
		S.Notify(player, "🛢️ Got a fuel barrel! Bring it to the SKY CANNON.", "Orange")
		task.delay(Config.BarrelRespawn, spawnBarrel, spot)
	end)
end

local function fireProjectile(from: Vector3)
	local shot = Instance.new("Part")
	shot.Shape = Enum.PartType.Ball
	shot.Size = Vector3.new(2.5, 2.5, 2.5)
	shot.Color = Color3.fromRGB(255, 140, 40)
	shot.Material = Enum.Material.Neon
	shot.Anchored = true
	shot.CanCollide = false
	shot.CFrame = CFrame.new(from)
	shot.Parent = workspace
	TweenService:Create(shot, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(from + Vector3.new(0, 250, 0)),
	}):Play()
	Debris:AddItem(shot, 1.3)
end

local function deliver(player: Player)
	local ps = S.Flight.GetPlayerState(player)
	if not ps or ps.zone ~= "Raft" or not hasBarrel(player) then
		return
	end
	RaftService.ClearBarrel(player)
	fireProjectile(S.World.raft.cannon.Position + Vector3.new(0, 6, 0))

	if S.Flight.IsActive() then
		S.Flight.AddFuel(Config.BarrelFuel)
		S.Notify(nil, string.format("🚀 %s fired a fuel barrel up to the balloon! (+%d fuel)", player.DisplayName, Config.BarrelFuel), "Orange")
	end
	S.Data.AddCoins(player, Config.DeliveryCoins, true)
	ps.deliveries += 1
	player:SetAttribute("Deliveries", ps.deliveries)
	S.Analytics.Custom(player, "FuelDelivered")

	if ps.deliveries >= Config.DeliveriesToReturn then
		S.Notify(player, "🚀 HERO! The cannon launches YOU back up!", "Green", true)
		local root = S.Flight.GetRoot(player)
		if root then
			S.Flight.Fling(player, Vector3.new(0, 160, 0))
		end
		task.delay(0.8, S.Flight.ReturnToBalloon, player, "Welcome back aboard, hero!")
	else
		S.Notify(player, string.format("Delivered %d/%d - keep going!", ps.deliveries, Config.DeliveriesToReturn), "Orange")
	end
end

function RaftService.Init(services)
	S = services
	Config = S.Config
end

function RaftService.Start()
	for _, spot in S.World.raft.barrelSpots do
		spawnBarrel(spot)
	end
	local debounce = {}
	S.World.raft.cannon.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or debounce[player] then
			return
		end
		debounce[player] = true
		deliver(player)
		task.delay(0.5, function()
			debounce[player] = nil
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		carrying[player] = nil
	end)
end

return RaftService
