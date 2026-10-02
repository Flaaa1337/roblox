-- Loot and scenery that drifts past the (stationary) balloon.
-- The balloon never actually moves - the world flows past it, which keeps
-- standing in the basket rock solid for players.

local TweenService = game:GetService("TweenService")

local LootService = {}
local S, Config, LootDefs

local rng = Random.new()
local movers = {} -- [Model] = { lv = LinearVelocity, factor = number, born = number, item = def?, taken = bool }
local speed = 0
local spawnTimer = 0
local cloudTimer = 0

local SPAWN_AHEAD = 240
local DESPAWN_BEHIND = 260
local MAX_LIFETIME = 70

local function weldTo(primary: BasePart, other: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = primary
	weld.Part1 = other
	weld.Parent = other
end

local function makeMover(model: Model, primary: BasePart, factor: number, spin: number)
	model.PrimaryPart = primary
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			if d ~= primary then
				d.Massless = true
				weldTo(primary, d)
			end
		end
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = primary
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = math.huge
	lv.VectorVelocity = Vector3.new(-speed * factor, 0, 0)
	lv.Parent = primary
	local av = Instance.new("AngularVelocity")
	av.Attachment0 = attachment
	av.RelativeTo = Enum.ActuatorRelativeTo.World
	av.MaxTorque = math.huge
	av.AngularVelocity = Vector3.new(0, spin, 0)
	av.Parent = primary

	model.Parent = S.World.flying
	pcall(function()
		primary:SetNetworkOwner(nil)
	end)
	local info = { lv = lv, factor = factor, born = os.clock(), model = model, primary = primary }
	movers[model] = info
	return info
end

local function removeMover(model: Model)
	movers[model] = nil
	model:Destroy()
end

---------------------------------------------------------------------------
-- Loot
---------------------------------------------------------------------------
local function buildLootModel(def)
	local model = Instance.new("Model")
	model.Name = "Loot_" .. (def.id or "Fuel")

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType[def.shape]
	body.Size = def.size
	body.Color = def.color
	body.Material = if def.rarity == "Mythic" or def.rarity == "Legendary"
		then Enum.Material.Neon
		else Enum.Material.SmoothPlastic
	body.Parent = model

	local rarityColor = LootDefs.Rarities[def.rarity].color
	local balloon = Instance.new("Part")
	balloon.Name = "Balloon"
	balloon.Shape = Enum.PartType.Ball
	balloon.Size = Vector3.new(2.6, 2.6, 2.6)
	balloon.Color = if def.fuel then Color3.fromRGB(255, 90, 60) else rarityColor
	balloon.Material = Enum.Material.SmoothPlastic
	balloon.CFrame = body.CFrame * CFrame.new(0, 4.2, 0)
	balloon.Parent = model

	local string_ = Instance.new("Part")
	string_.Name = "String"
	string_.Size = Vector3.new(0.12, 2.6, 0.12)
	string_.Color = Color3.new(1, 1, 1)
	string_.CFrame = body.CFrame * CFrame.new(0, 2.2, 0)
	string_.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 46)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.MaxDistance = 140
	gui.Parent = body
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.55)
	title.BackgroundTransparency = 1
	title.Text = if def.fuel then "⛽ FUEL +" .. Config.FuelCanisterAmount else def.name
	title.TextColor3 = rarityColor
	title.TextScaled = true
	title.Font = Enum.Font.FredokaOne
	title.TextStrokeTransparency = 0.2
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromScale(0, 0.55)
	sub.Size = UDim2.fromScale(1, 0.45)
	sub.BackgroundTransparency = 1
	sub.Text = if def.fuel then "click to hook!" else string.format("%d kg • %d 💰", def.weight, def.value)
	sub.TextColor3 = Color3.new(1, 1, 1)
	sub.TextScaled = true
	sub.Font = Enum.Font.GothamBold
	sub.TextStrokeTransparency = 0.3
	sub.Parent = gui

	if LootDefs.Rarities[def.rarity].order >= 5 then
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = rarityColor
		highlight.Parent = model
	end

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 120
	click.Parent = model

	return model, body, click
end

local function pullTo(info, target: Vector3)
	info.taken = true
	movers[info.model] = nil
	info.primary.Anchored = true
	local tween = TweenService:Create(info.primary, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(target),
	})
	tween:Play()
	task.delay(0.3, function()
		info.model:Destroy()
	end)
end

-- Shared by players and bots. Returns ok, reason.
function LootService.Grab(info, grabber)
	if info.taken or not info.model.Parent then
		return false, "Too slow!"
	end
	local def = info.item
	if def.fuel then
		S.Flight.AddFuel(Config.FuelCanisterAmount)
		return true
	end
	if typeof(grabber) == "Instance" then
		return S.Flight.TryCarry(grabber, def)
	end
	return S.Bots.TryCarry(grabber, def)
end

local function onClicked(info, player: Player)
	if info.taken then
		return
	end
	local root = S.Flight.GetRoot(player)
	if not root or not S.Flight.IsAboard(player) then
		return
	end
	if (info.primary.Position - root.Position).Magnitude > S.Flight.GetHookRange(player) + 3 then
		S.Notify(player, "Out of reach! Upgrade your Hook Range in the shop.", "Gray")
		return
	end
	local ok, reason = LootService.Grab(info, player)
	if not ok then
		S.Notify(player, reason, "Gray")
		return
	end
	pullTo(info, root.Position)
	local def = info.item
	if def.fuel then
		S.Notify(player, "⛽ +" .. Config.FuelCanisterAmount .. " fuel for the balloon!", "Green")
	elseif LootDefs.Rarities[def.rarity].order >= 5 then
		S.Notify(nil, string.format("✨ %s hooked a %s %s! (%d kg)", player.DisplayName, def.rarity, def.name, def.weight), def.rarity)
	end
	S.Analytics.Custom(player, "LootHooked_" .. def.rarity)
end

local function spawnLoot(def, position: Vector3, factor: number)
	local model, body, click = buildLootModel(def)
	body.CFrame = CFrame.new(position)
	-- rebuild relative positions now that the body moved
	model.Balloon.CFrame = body.CFrame * CFrame.new(0, 4.2, 0)
	model.String.CFrame = body.CFrame * CFrame.new(0, 2.2, 0)
	local info = makeMover(model, body, factor, rng:NextNumber(-0.6, 0.6))
	info.item = def
	info.taken = false
	click.MouseClick:Connect(function(player)
		onClicked(info, player)
	end)
	return info
end

local function spawnPosition(): Vector3
	local top = S.World.balloon.top
	local R = Config.BasketRadius
	local z
	if rng:NextNumber() < 0.65 then
		z = rng:NextNumber(-(R + 18), R + 18)
	else
		z = rng:NextNumber(-70, 70)
	end
	local y = if math.abs(z) < R + 3 then rng:NextNumber(10, 18) else rng:NextNumber(-4, 16)
	return top + Vector3.new(SPAWN_AHEAD, y, z)
end

function LootService.SpawnBurst(itemIds)
	local top = S.World.balloon.top
	for i, id in itemIds do
		local def = LootDefs.Items[id]
		if def then
			local a = (i / #itemIds) * math.pi * 2
			local r = rng:NextNumber(10, Config.BasketRadius + 6)
			spawnLoot(def, top + Vector3.new(math.cos(a) * r + 30, rng:NextNumber(8, 14), math.sin(a) * r), 0.25)
		end
	end
end

-- For bots: every loot in reach of a point.
function LootService.FindNear(position: Vector3, range: number)
	local list = {}
	for _, info in movers do
		if info.item and not info.taken and (info.primary.Position - position).Magnitude <= range then
			table.insert(list, info)
		end
	end
	return list
end
LootService.PullTo = pullTo

---------------------------------------------------------------------------
-- Scenery
---------------------------------------------------------------------------
local function spawnCloud(xOffset: number?)
	local top = S.World.balloon.top
	local model = Instance.new("Model")
	model.Name = "Cloud"
	local center = top + Vector3.new(xOffset or 600, rng:NextNumber(-90, 60), rng:NextNumber(-350, 350))
	if math.abs(center.Z - top.Z) < 60 and math.abs(center.Y - top.Y) < 50 then
		center += Vector3.new(0, -80, 0) -- keep clouds out of the basket
	end
	local primary
	for i = 1, rng:NextInteger(3, 6) do
		local size = rng:NextNumber(14, 30)
		local puff = Instance.new("Part")
		puff.Shape = Enum.PartType.Ball
		puff.Size = Vector3.new(size, size, size)
		puff.Color = Color3.fromRGB(255, 255, 255)
		puff.Material = Enum.Material.SmoothPlastic
		puff.Transparency = 0.15
		puff.CanQuery = false
		puff.CastShadow = false
		puff.CFrame = CFrame.new(center + Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(-4, 6), rng:NextNumber(-12, 12)))
		puff.Parent = model
		primary = primary or puff
	end
	makeMover(model, primary, rng:NextNumber(0.8, 1.2), 0)
end

local function spawnIsland()
	local top = S.World.balloon.top
	local model = Instance.new("Model")
	model.Name = "Island"
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local center = top + Vector3.new(600, -rng:NextNumber(60, 110), side * rng:NextNumber(90, 250))
	local rock = Instance.new("Part")
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.new(40, 40, 40)
	rock.Color = Color3.fromRGB(120, 110, 100)
	rock.Material = Enum.Material.Rock
	rock.CFrame = CFrame.new(center)
	rock.CanQuery = false
	rock.Parent = model
	local grass = Instance.new("Part")
	grass.Shape = Enum.PartType.Cylinder
	grass.Size = Vector3.new(3, 44, 44)
	grass.Color = Color3.fromRGB(90, 190, 80)
	grass.Material = Enum.Material.Grass
	grass.CFrame = CFrame.new(center + Vector3.new(0, 12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	grass.CanQuery = false
	grass.Parent = model
	makeMover(model, rock, 1, 0)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function LootService.SetSpeed(newSpeed: number)
	speed = newSpeed
	for _, info in movers do
		info.lv.VectorVelocity = Vector3.new(-speed * info.factor, 0, 0)
	end
end

function LootService.Prewarm()
	for x = -500, 500, 90 do
		spawnCloud(x + rng:NextNumber(-30, 30))
	end
end

function LootService.ClearAll()
	for model in movers do
		model:Destroy()
	end
	table.clear(movers)
	S.World.flying:ClearAllChildren()
end

function LootService.Step(dt: number, distance: number)
	spawnTimer += dt
	cloudTimer += dt
	if spawnTimer >= Config.LootInterval then
		spawnTimer = 0
		if rng:NextNumber() < Config.FuelCanisterChance then
			spawnLoot(LootDefs.Fuel, spawnPosition(), 1)
		else
			local luck = 1 + distance * Config.LuckPerMeter
			spawnLoot(LootDefs.Roll(rng, luck), spawnPosition(), rng:NextNumber(0.8, 1.15))
		end
	end
	if cloudTimer >= 4 then
		cloudTimer = 0
		spawnCloud()
		if rng:NextNumber() < 0.25 then
			spawnIsland()
		end
	end

	local limitX = S.World.balloon.top.X - DESPAWN_BEHIND * 2.3
	local clock = os.clock()
	for model, info in movers do
		local x = info.primary.Position.X
		local tooOld = clock - info.born > MAX_LIFETIME * (if info.item then 1 else 2)
		if x < limitX or tooOld or (info.item and x < S.World.balloon.top.X - DESPAWN_BEHIND) then
			removeMover(model)
		end
	end
end

function LootService.Init(services)
	S = services
	Config = S.Config
	LootDefs = S.LootDefs
end

function LootService.Start() end

return LootService
